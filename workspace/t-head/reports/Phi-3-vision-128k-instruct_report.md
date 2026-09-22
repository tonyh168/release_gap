# t-head/Phi-3-vision-128k-instruct 修复日志

- **失败报告**：flagrelease_fail_reports/T-Head/FAILED_T-Head_Phi-3-vision-128k-instruct_202608282255.md
- **原始失败类型**：精度不达标
- **日期**：2026-09-16

## 现象

历史 T-Head 自动化报告（旧自动化结果）留下的失败证据：

- V2 GPQA 精度 `24.0%`，且原报告没有有效的 V1 精度基线；
- 性能比 `93.5%`（vs 合成基线），V3 沿用 V2；
- 历史结论：仅私有发布，流程自动化结论为迁移失败（V2 精度 24.0%、性能比 93.5%）。

本次在新镜像上重跑后的现象：

- 服务正常启动，健康检查 HTTP `200`，`/v1/models` 返回模型名 `Phi-3-vision-128k-instruct`，监听端口 `18082`，绑定 GPU4；
- 50 题文本 GPQA Diamond 完整结束（评测耗时 `1349.65` 秒），未检测到截断；
- EvalScope 原始分为 `34.0%`，逐题答案提取审计后为 `32.0%`，存在 1 道 parser mismatch、3 道 invalid evalscope extract；
- 审计分仍高于 NV 参考基线 `25.0%`。

## 定位

- 本次没有发现服务启动故障、算子 crash、OOM 或 plugin-FL 报错，`aligned=true`、`raw_aligned=true`、`noise_adjusted=false`；
- 分数差异来自答案提取口径：`evalscope_score=34.0%` 与审计后 `score=32.0%` 相差 1 道 parser mismatch，因此以审计后的 `32.0%` 作为正式分数；
- **本次 GPQA 结果验证的是文本推理路径；视觉输入链路（图像数据集、视觉编码器、多模态 chat template）尚未通过任何图像或真实图文请求验证。**

## 处置

1. 使用统一 PPU 镜像启动 Phi-3 vision，在共享目录加载模型权重；
2. 使用 GPU4、端口 `18082`、TP=1，保留当前 FlagOS 算子白名单（`flash_attention_forward`、`attention_backend`、`rms_norm`、`rotary_embedding`、`silu_and_mul` 等路径由 FlagOS 接管）；
3. 使用独立评测容器执行 GPQA Diamond 50 题；
4. 对 EvalScope 原始分进行逐题答案提取审计，采用校正后的分数作为正式分数，原始分保留作评测器记录；
5. 将视觉能力验证与文本 GPQA 结果分开记录，不把文本通过当作多模态验收。

本次实际运行配置：

| 项目 | 值 |
|------|---|
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100` |
| 镜像 ID | `sha256:a54dcb164e0d9aad003884e6b0691400f6c8db1e56d513b03dc1c65d30f830ce` |
| vLLM / PyTorch | `vllm 0.24.0+empty` / `torch 2.10.0` |
| 模型路径 | `/models/Phi-3-vision-128k-instruct` |
| GPU / 端口 / TP | `CUDA_VISIBLE_DEVICES=4` / `18082` / `1` |
| 服务参数 | `--dtype bfloat16 --max-model-len 32768 --gpu-memory-utilization 0.85 --trust-remote-code --enforce-eager` |
| 评测参数 | EvalScope `1.5.1`，50 题，`eval_batch_size=4`，`max_model_len=32768`，`max_tokens=4096` |
| 服务日志 | `/models/_serve_logs/Phi-3-vision-128k-instruct-20260915_160253.log` |
| 结果文件 | `/mnt/workspace/models/_eval_results/20260915_accuracy/formal_20260915_164849/Phi-3-vision-128k-instruct_retry_20260915_183542/Phi-3-vision-128k-instruct_gpqa_result.json` |

未重新构建或修改 Harbor 中的原始镜像；容器可写层变化仅为安装 ModelScope 及其依赖、产生 ModelScope/pip/vLLM model-info/remote-code 缓存与 FlagGems/Triton 运行时临时文件；未修改 `/workspace/vllm`、`/workspace/vllm-plugin-FL`、`/workspace/FlagGems` 的源码和算子实现。

## 结果

- 修复后分 / NV 基线：文本 GPQA Diamond `32.0%`（审计后正式分，EvalScope 原始分 `34.0%`） / `25.0%`
- 达标判定（accuracy_compare 退出码）：文本精度通过（`aligned=true`，相对退化 `-28.0%`，实际为提升）；源日志只给出 verdict.json，未记录 accuracy_compare 的退出码数值，退出码为 `<待补>`

verdict.json 原文：

```json
{
  "score": 32.0,
  "evalscope_score": 34.0,
  "total_questions": 50,
  "truncation_detected": false,
  "answer_extraction_audit": {
    "checked": 50,
    "format_corrected_score": 32.0,
    "parser_mismatch_count": 1,
    "invalid_evalscope_extract_count": 3
  },
  "verdict": {
    "aligned": true,
    "raw_aligned": true,
    "noise_adjusted": false,
    "nv_score": 25.0,
    "current_score": 32.0,
    "rel_drop": -0.28,
    "threshold": 0.05
  }
}
```

限定说明（照抄源日志的本次处理结论）：当前 PPU 机器上的新镜像服务正常，文本 GPQA 精度通过；**视觉图像链路和完整性能验收本次未覆盖**，图像输入/视觉链路本次未评测，本次完整性能验收未重测。因此本次通过只覆盖文本推理路径，不能代表多模态能力达标。

## 提炼到 KNOWLEDGE 的条目

视觉语言模型的 GPQA 通过只能证明文本路径基本可用，不能代替多模态验收；后续应在服务稳定后补充 `mm_star` 或等价图文数据集，并单独保存图像输入格式、processor、chat template 和逐题结果。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: microsoft/Phi-3-vision-128k-instruct
# IMAGE: harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100
# HARBOR_VER: V3
# GPU: PPU-ZW810E, 16 × 96GB
# TP: 1
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 25.0
# SCORE_FLAGOS: 32.0
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

export VLLM_FL_FLAGOS_WHITELIST=add,addmm,arange_start,argmax,cat,copy_,cos,embedding,eq_scalar,exponential_,fill_scalar_,flash_attention_forward,floor_divide,full,gelu,index,layer_norm,lt_scalar,mm,mm_out,mul,normal_,ones,pow_scalar,rand_like,randn,reciprocal,remainder,sigmoid,sin,softmax,softmax_out,sub,to_copy,true_divide,true_divide_,uniform_,where_self,where_self_out,zero_,zeros,attention_backend,rms_norm,silu_and_mul,rotary_embedding

export PPU_HOME=/usr/local/PPU_SDK
export CUDA_HOME=/usr/local/PPU_SDK/CUDA_SDK
export HF_ENDPOINT=https://hf-mirror.com
/usr/local/bin/vllm serve /models/Phi-3-vision-128k-instruct \
  --served-model-name Phi-3-vision-128k-instruct \
  --host 0.0.0.0 \
  --port 18082 \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.85 \
  --trust-remote-code \
  --enforce-eager
```
