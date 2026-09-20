# t-head/Qwen3-4B-Thinking-2507 修复日志

- **失败报告**：flagrelease_fail_reports/T-Head/FAILED_T-Head_Qwen3-4B-Thinking-2507_202608281759.md
- **原始失败类型**：精度不达标
- **日期**：2026-09-16

## 现象

历史 T-Head 自动化报告使用较早的 vLLM 0.20.2 / plugin-FL 0.2.0 组合，留下的失败证据：

- V2 GPQA 只有 30 题、`63.33%`，且没有 V1 基线，不能直接作为结论；
- 性能比 `98.4%`（vs 合成基线，2 轮算子调优已达上限），V3 沿用 V2；
- 历史结论：仅私有发布，流程自动化结论为迁移失败（服务/精度/性能流程未完整达标）。

本次在新镜像上重跑时出现的现象：

- 首轮高并发评测因服务端 SQLite `database is locked` 中断（thinking 模型长思考输出 + 并发访问导致）；
- 当时目标 GPU2 已被其他模型服务占用，不能强行回收；
- 改用 GPU6 并把评测并发降为 1 后，50 题 GPQA 完整跑完（评测耗时 `27042.81` 秒）；
- 最终未检测到截断，答案格式校正前后分数一致。

## 定位

- 本轮的主要问题不是模型服务启动失败，而是评测并发与服务端运行状态冲突（SQLite 锁 + 长思考输出）；
- GPU2 的占用来自其他独立服务，不能作为本模型资源使用；
- 服务本身健康检查 HTTP `200`，模型名 `Qwen3-4B-Thinking-2507`，没有算子 crash、OOM 或 plugin-FL 报错。

## 处置

1. 保留统一 PPU 镜像和当前 FlagOS 算子白名单（`attention_backend`、`rms_norm`、`rotary_embedding`、`silu_and_mul` 等路径由 FlagOS 接管）；
2. 将 Qwen 服务从被占用的 GPU2 切换到空闲 GPU6；
3. 使用独立的 `/models/_vllm_cache/qwen3-4b-gpu6` 缓存目录；
4. 正式 GPQA 评测并发固定为 `eval_batch_size=1`，避免长思考输出与并发访问导致服务端 SQLite 锁冲突；
5. 对结果执行答案提取审计和截断检查，确认格式校正前后分数一致。

本次实际运行配置：

| 项目 | 值 |
|------|---|
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100` |
| 镜像 ID | `sha256:a54dcb164e0d9aad003884e6b0691400f6c8db1e56d513b03dc1c65d30f830ce` |
| vLLM / PyTorch | `vllm 0.24.0+empty` / `torch 2.10.0` |
| 模型路径 | `/models/Qwen3-4B-Thinking-2507` |
| GPU / 端口 / TP | `CUDA_VISIBLE_DEVICES=6` / `18080` / `1` |
| 服务参数 | `--dtype bfloat16 --max-model-len 32768 --gpu-memory-utilization 0.85 --trust-remote-code --enforce-eager` |
| 评测参数 | EvalScope `1.5.1`，50 题，`eval_batch_size=1`，`max_model_len=32768`，`max_tokens=20000` |
| 服务日志 | `/models/_serve_logs/Qwen3-4B-Thinking-2507-20260915_191800-gpu6.log` |
| 结果文件 | `/mnt/workspace/models/_eval_results/20260915_accuracy/qwen_retry_20260915_192500/Qwen3-4B-Thinking-2507_gpqa_result.json` |

镜像未重新构建、重新打 tag 或 push；容器可写层变化仅为安装 `modelscope==1.40.0`、`modelscope-hub==0.4.2` 及 ModelScope/pip/vLLM model-info/HuggingFace remote-code 缓存、FlagGems/Triton 临时文件；未修改 vLLM、plugin-FL、FlagGems 算子实现文件。

## 结果

- 修复后分 / NV 基线：`72.0%`（36/50） / `68.0%`
- 达标判定（accuracy_compare 退出码）：通过（`aligned=true`，相对退化 `-5.88%`，实际为提升）；源日志只给出 verdict.json，未记录 accuracy_compare 的退出码数值，退出码为 `<待补>`

verdict.json 原文：

```json
{
  "score": 72.0,
  "evalscope_score": 72.0,
  "total_questions": 50,
  "truncation_detected": false,
  "answer_extraction_audit": {
    "checked": 50,
    "format_corrected_score": 72.0,
    "parser_mismatch_count": 0,
    "invalid_evalscope_extract_count": 3
  },
  "verdict": {
    "aligned": true,
    "nv_score": 68.0,
    "current_score": 72.0,
    "rel_drop": -0.0588,
    "threshold": 0.05
  }
}
```

限定说明（照抄源日志的本次处理结论）：当前 PPU 机器上的新镜像服务正常，50 题 GPQA 精度通过；性能和完整 V1–V3 对比本次未重测，不能据此宣称 V1–V3 全部通过。

## 提炼到 KNOWLEDGE 的条目

Thinking 模型在 PPU 上做正式精度评测应优先使用 `eval_batch_size=1`，并为每次重启隔离 `VLLM_CACHE_ROOT`、TorchInductor 和 Triton 缓存目录；服务健康、评测完整结束、答案提取审计和截断检查必须同时满足，才能把分数作为正式结果。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: Qwen/Qwen3-4B-Thinking-2507
# IMAGE: harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100
# HARBOR_VER: V3
# GPU: PPU-ZW810E, 16 × 96GB
# TP: 1
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 68.0
# SCORE_FLAGOS: 72.0
# CONTAINER_DEVS: -v /dev:/dev -v /usr/local/PPU_SDK:/usr/local/PPU_SDK -v /mnt/workspace/models:/models --privileged --net=host --ipc=host --shm-size=512g
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --privileged --net=host --ipc=host --shm-size=512g \
  -v /dev:/dev \
  -v /usr/local/PPU_SDK:/usr/local/PPU_SDK \
  -v /mnt/workspace/models:/models \
  --name flagos \
  harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100 \
  /bin/bash
```

### 三、启动服务（容器内执行）

```bash

export VLLM_PLUGINS=fl
export USE_FLAGGEMS=1
export VLLM_FL_PREFER_ENABLED=true

export VLLM_FL_FLAGOS_WHITELIST=add,arange_start,argmax,cat,copy_,cos,cumsum,cumsum_out,true_divide,true_divide_,exponential_,fill_scalar_,full,gather,index,le,lt,lt_scalar,masked_fill_,mm,mm_out,mul,ones,pow_scalar,rand_like,randn,reciprocal,rsub_scalar,scatter_,sin,softmax,softmax_out,sort,sort_stable,sub,to_copy,where_self,where_self_out,zero_,zeros,attention_backend,rms_norm,silu_and_mul,rotary_embedding

export VLLM_CACHE_ROOT=/models/_vllm_cache/qwen3-4b-gpu6
export TORCHINDUCTOR_CACHE_DIR=/models/_vllm_cache/qwen3-4b-gpu6/torchinductor
export TRITON_CACHE_DIR=/models/_vllm_cache/qwen3-4b-gpu6/triton
export VLLM_FL_TRITON_CACHE_ROOT=/models/_vllm_cache/qwen3-4b-gpu6/triton

export PPU_HOME=/usr/local/PPU_SDK
export CUDA_HOME=/usr/local/PPU_SDK/CUDA_SDK
export HF_ENDPOINT=https://hf-mirror.com
/usr/local/bin/vllm serve /models/Qwen3-4B-Thinking-2507 \
  --served-model-name Qwen3-4B-Thinking-2507 \
  --host 0.0.0.0 \
  --port 18080 \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.85 \
  --trust-remote-code \
  --enforce-eager
```
