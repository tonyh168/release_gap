# t-head/Qwen2.5-7B-Instruct 修复日志

- **失败报告**：flagrelease_fail_reports/T-Head/FAILED_T-Head_Qwen2.5-7B-Instruct_202609090059.md
- **原始失败类型**：精度不达标
- **日期**：2026-09-17

## 现象

历史自动化流程（V1=none 分支，V2/V3 为同一镜像双 tag 发布）留下的失败证据：

- V2/V3 GPQA 精度 `34.0%`，NV 参考基线 `39.0%`，`rel_drop = 12.82%`，超过 5% 阈值；
- 历史报告明确记录：全量禁用 flaggems 仍为 `34.0%`，即该轮的平台天花板就是 `34.0%`；
- 同一轮性能比 `130.7%`（vs 合成基线）达标；
- 历史结论：仅私有发布（V2/V3 双 tag 已 push Harbor），未对外发布 ModelScope/HuggingFace，流程自动化结论为迁移失败。

本次在 PPU 机器上换统一 PPU 新镜像重跑后的现象：

- 服务健康检查 HTTP `200`，`/v1/models` 返回模型名 `Qwen2.5-7B-Instruct`，监听端口 `18083`，绑定 GPU1；
- 50 题 GPQA Diamond 完整跑完（评测耗时 `1513.43` 秒），未检测到截断；
- 结果 `38.0%`，NV 参考值 `39.0%`，相对退化 `2.56%`。

## 定位

- 本次重跑没有出现服务启动失败、算子 crash、OOM 或 plugin-FL 报错，`aligned=true`、`raw_aligned=true`、`noise_adjusted=false`；
- 源日志明确说明：本文件仅记录本次 50 题结果，不展开根因分析；本次未做算子级二分定位，也没有出现退化算子名；
- 历史失败属于精度不达标（而非服务/性能问题）：性能比 `130.7%` 达标，精度 `34.0%` 也不随 flaggems 开关变化，指向当时镜像/框架组合层面的平台天花板，而非单个替换算子。

## 处置

1. 换用统一 PPU 新镜像，在共享目录加载模型权重，不再复用历史自动化流程的旧镜像组合；
2. 长驻推理容器（PID 1 保持容器存活）内通过 `docker exec` 单卡启动 vLLM 服务；
3. 保留当前 FlagOS 算子白名单（含 `attention_backend`、`rms_norm`、`rotary_embedding`、`silu_and_mul`）；
4. 使用独立评测容器访问 OpenAI API 接口，固定 GPQA Diamond 50 题口径；
5. 结果同时落原始 EvalScope 分、答案提取审计、截断检测和 NV 对齐判定。

本次实际运行配置：

| 项目 | 值 |
|------|---|
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100` |
| 镜像 ID | `sha256:a54dcb164e0d9aad003884e6b0691400f6c8db1e56d513b03dc1c65d30f830ce` |
| vLLM / PyTorch | `vllm 0.24.0+empty` / `torch 2.10.0` |
| 模型路径 | `/models/Qwen2.5-7B-Instruct` |
| GPU / 端口 / TP | `CUDA_VISIBLE_DEVICES=1` / `18083` / `1` |
| 服务参数 | `--dtype bfloat16 --max-model-len 32768 --gpu-memory-utilization 0.85 --trust-remote-code --enforce-eager` |
| 评测参数 | EvalScope `1.5.1`，50 题，`eval_batch_size=4`，`max_model_len=32768`，`max_tokens=24576` |
| 服务日志 | `/models/_serve_logs/Qwen2.5-7B-Instruct-20260916-gpu1.log` |
| 结果文件 | `/mnt/workspace/models/_eval_results/20260916_new_models/50/Qwen2.5-7B-Instruct/Qwen2.5-7B-Instruct_gpqa_result.json` |

镜像未重新构建、重新打 tag 或 push；容器可写层变化仅为安装 `modelscope==1.40.0`、`modelscope-hub==0.4.2` 及 ModelScope/pip/vLLM model-info 缓存、FlagGems/Triton 运行时临时文件；未修改 `/workspace/vllm`、`/workspace/vllm-plugin-FL`、`/workspace/FlagGems` 的源码和算子实现。

## 结果

- 修复后分 / NV 基线：`38.0%`（19/50） / `39.0%`
- 达标判定（accuracy_compare 退出码）：通过（`aligned=true`）；源日志只给出 verdict.json，未记录 accuracy_compare 的退出码数值，退出码为 `<待补>`

verdict.json 原文：

```json
{
  "score": 38.0,
  "evalscope_score": 38.0,
  "total_questions": 50,
  "truncation_detected": false,
  "answer_extraction_audit": {
    "checked": 50,
    "format_corrected_score": 38.0,
    "parser_mismatch_count": 0,
    "invalid_evalscope_extract_count": 1
  },
  "verdict": {
    "aligned": true,
    "raw_aligned": true,
    "noise_adjusted": false,
    "nv_score": 39.0,
    "current_score": 38.0,
    "rel_drop": 0.0256,
    "threshold": 0.05
  }
}
```

限定说明（照抄源日志的本次处理结论）：当前 PPU 机器上的新镜像服务正常，50 题 GPQA 精度通过；本文件仅记录本次 50 题结果，不展开根因分析。本次性能验收未重测，完整 V1–V3 流程对比本次未覆盖，因此不能据此宣称 V1–V3 全部通过。

## 提炼到 KNOWLEDGE 的条目

50 题 GPQA 记录必须同时保存原始 EvalScope 分数、答案提取审计结果、截断检测结果和 NV 对齐判定；模型服务若使用独立 GPU 与独立缓存目录（`VLLM_CACHE_ROOT` / TorchInductor / Triton），必须在记录中固定写清，便于复现实验环境。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: Qwen/Qwen2.5-7B-Instruct
# IMAGE: harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100
# HARBOR_VER: V3
# GPU: PPU-ZW810E, 16 × 96GB
# TP: 1
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 39.0
# SCORE_FLAGOS: 38.0
# CONTAINER_DEVS: -v /dev:/dev -v /usr/local/PPU_SDK:/usr/local/PPU_SDK -v /mnt/workspace/models:/models --privileged --net=host --ipc=host
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --privileged --net=host --ipc=host \
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

export VLLM_FL_FLAGOS_WHITELIST=add,addmm,addmm_,addmm_dtype,addmm_dtype_out,addmm_out,arange_start,argmax,cat,copy_,cos,cumsum,cumsum_out,embedding,eq_scalar,exponential_,fill_scalar_,full,gather,index,layer_norm,le,lt,lt_scalar,mm,mm_out,mul,normal_,ones,pow_scalar,rand_like,randn,reciprocal,remainder,rsub_scalar,scatter_,sigmoid,sin,softmax,softmax_out,sort,sort_stable,sub,to_copy,true_divide,true_divide_,uniform_,where_self,where_self_out,zero_,zeros,attention_backend,rms_norm,silu_and_mul,rotary_embedding

export VLLM_CACHE_ROOT=/models/_vllm_cache/qwen2.5-7b-gpu1
export TORCHINDUCTOR_CACHE_DIR=/models/_vllm_cache/qwen2.5-7b-gpu1/torchinductor
export TRITON_CACHE_DIR=/models/_vllm_cache/qwen2.5-7b-gpu1/triton
export VLLM_FL_TRITON_CACHE_ROOT=/models/_vllm_cache/qwen2.5-7b-gpu1/triton

export PPU_HOME=/usr/local/PPU_SDK
export CUDA_HOME=/usr/local/PPU_SDK/CUDA_SDK
export HF_ENDPOINT=https://hf-mirror.com
/usr/local/bin/vllm serve /models/Qwen2.5-7B-Instruct \
  --served-model-name Qwen2.5-7B-Instruct \
  --host 0.0.0.0 \
  --port 18083 \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.85 \
  --trust-remote-code \
  --enforce-eager
```
