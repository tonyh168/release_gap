# T-Head/Phi-3-vision-128k-instruct 适配与评测记录

- **日期**：`2026-09-16`
- **远端机器**：`244-pm-aliyun-wlcb-zoned-d-810e-96G`（`8.130.132.221`）
- **主机名**：`dsw-879515-f5bf65bfd-jd7bj`
- **历史失败报告**：`flagrelease_fail_reports/T-Head/FAILED_T-Head_Phi-3-vision-128k-instruct_202608282255.md`
- **历史问题类型**：历史 GPQA 精度 `24.0%`、性能比 `93.5%`，自动化流程未达标
- **本次处理结论**：当前 PPU 机器上的新镜像服务正常，文本 GPQA 精度通过；视觉图像链路和完整性能验收本次未覆盖

---

## 背景分析

Phi-3-vision-128k-instruct 是视觉语言模型。历史 T-Head 报告使用旧的自动化结果，V2 GPQA 为 `24.0%`，且原报告没有有效的 V1 精度基线。

本次使用统一 PPU 镜像重新启动服务，在共享目录加载模型，并使用独立评测容器对文本型 GPQA Diamond 进行 50 题重测。GPQA 只验证文本选择题路径，不等价于对图像输入、视觉编码器和多模态 chat template 的完整验收。

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `244-pm-aliyun-wlcb-zoned-d-810e-96G` / `8.130.132.221` |
| 芯片 | PPU-ZW810E，16 × 96GB |
| 推理容器 | `flagrelease_thead_model_dl_20260915` |
| 评测容器 | `flagrelease_thead_eval_20260915` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100` |
| 镜像 ID | `sha256:a54dcb164e0d9aad003884e6b0691400f6c8db1e56d513b03dc1c65d30f830ce` |
| vLLM / PyTorch | `vllm 0.24.0+empty` / `torch 2.10.0` |
| 模型来源 | `microsoft/Phi-3-vision-128k-instruct` |
| 模型路径 | `/models/Phi-3-vision-128k-instruct` |
| 宿主机共享路径 | `/mnt/workspace/models/Phi-3-vision-128k-instruct` |
| GPU | `CUDA_VISIBLE_DEVICES=4` |
| 服务端口 | `18082` |

## Step 0：容器运行配置

三个推理服务共用长驻容器：

```text
entrypoint: ["bash", "/opt/t-head/entrypoint.sh"]
cmd:        ["sleep", "infinity"]
network:    host
ipc:        host
privileged: true
shm-size:   512 GiB
```

挂载：

```text
/dev                  -> /dev
/usr/local/PPU_SDK    -> /usr/local/PPU_SDK
/mnt/workspace/models -> /models
```

## Step 1：启动 vLLM 服务

实际启动命令：

```bash
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

当前服务检查：

```bash
curl http://127.0.0.1:18082/health
curl http://127.0.0.1:18082/v1/models
```

结果：健康检查 HTTP `200`，模型名为 `Phi-3-vision-128k-instruct`。

### 环境变量

```bash
export CUDA_VISIBLE_DEVICES=4
export HIP_VISIBLE_DEVICES=4
export XPU_VISIBLE_DEVICES=4

export VLLM_PLUGINS=fl
export USE_FLAGGEMS=1
export VLLM_FL_PREFER_ENABLED=true

export VLLM_FL_FLAGOS_WHITELIST=add,addmm,arange_start,argmax,cat,copy_,cos,embedding,eq_scalar,exponential_,fill_scalar_,flash_attention_forward,floor_divide,full,gelu,index,layer_norm,lt_scalar,mm,mm_out,mul,normal_,ones,pow_scalar,rand_like,randn,reciprocal,remainder,sigmoid,sin,softmax,softmax_out,sub,to_copy,true_divide,true_divide_,uniform_,where_self,where_self_out,zero_,zeros,attention_backend,rms_norm,silu_and_mul,rotary_embedding

export PPU_HOME=/usr/local/PPU_SDK
export CUDA_HOME=/usr/local/PPU_SDK/CUDA_SDK
export HF_ENDPOINT=https://hf-mirror.com
```

当前实际接管的主要路径包括 `flash_attention_forward`、`attention_backend`、`rms_norm`、`rotary_embedding`、`silu_and_mul`。没有修改 vLLM、plugin-FL 或 FlagGems 源码。

## Step 2：模型文件和容器变更

模型文件位于：

```text
/mnt/workspace/models/Phi-3-vision-128k-instruct
```

没有重新构建或修改 Harbor 中的原始镜像。容器可写层变化主要是：

- 安装 ModelScope 及其依赖；
- 产生 ModelScope、pip、vLLM model-info 和 remote-code 缓存；
- 产生 FlagGems/Triton 运行时临时文件；
- 通过 `/models` 绑定共享目录写入模型、日志和缓存。

未修改 `/workspace/vllm`、`/workspace/vllm-plugin-FL` 或 `/workspace/FlagGems` 的源码和算子实现。

服务日志：

```text
/models/_serve_logs/Phi-3-vision-128k-instruct-20260915_160253.log
```

## Step 3：评测

文本 GPQA 评测服务地址：

```text
http://127.0.0.1:18082/v1
```

评测配置：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.5.1` |
| 题数 | 50 |
| `eval_batch_size` | 4 |
| `max_model_len` | 32768 |
| `max_tokens` | 4096 |
| 截断检测 | 未检测到截断 |
| 评测耗时 | 1349.65 秒 |

结果文件：

```text
/mnt/workspace/models/_eval_results/20260915_accuracy/formal_20260915_164849/Phi-3-vision-128k-instruct_retry_20260915_183542/Phi-3-vision-128k-instruct_gpqa_result.json
```

结果摘要：

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

这里以答案提取审计后的 `score=32.0%` 作为当前正式分数；`evalscope_score=34.0%` 保留作原始评测器记录。

## 现象

- 服务正常启动，50 题评测完整结束；
- EvalScope 原始分为 `34.0%`；
- 逐题答案提取审计后为 `32.0%`，存在 1 道 parser mismatch；
- 审计分仍高于 NV 参考基线 `25.0%`；
- 没有发现输出截断。

## 定位

本次没有发现服务启动故障或精度退化。当前 GPQA 结果验证的是文本推理路径；视觉输入链路尚未通过图像数据集或真实图文请求验证。

## 处置

1. 使用统一 PPU 镜像启动 Phi-3 vision；
2. 使用 GPU4、端口 `18082`、TP=1；
3. 保留当前 FlagOS 算子白名单；
4. 使用独立评测容器执行 GPQA；
5. 对 EvalScope 原始分进行答案提取审计，采用校正后的正式分数；
6. 将视觉能力验证与文本 GPQA 结果分开记录。

## 当前结果

- 服务：正常，端口 `18082`，GPU4
- 文本 GPQA Diamond：`32.0%`（审计后）
- EvalScope 原始分：`34.0%`
- NV 参考基线：`25.0%`
- 相对退化：`-28.0%`，实际为提升
- 文本精度判定：✅ 通过
- 图像输入/视觉链路：本次未评测
- 本次完整性能验收：未重测

## 可复用规则

视觉语言模型的 GPQA 通过只能证明文本路径基本可用，不能代替多模态验收。后续应在服务稳定后增加 `mm_star` 或等价图文数据集，并单独保存图像输入格式、processor、chat template 和逐题结果。
