# T-Head/Qwen2.5-7B-Instruct 适配与评测记录

- **日期**：`2026-09-17`
- **远端机器**：`244-pm-aliyun-wlcb-zoned-d-810e-96G`（`8.130.132.221`）
- **主机名**：`dsw-879515-f5bf65bfd-jd7bj`
- **模型来源**：`Qwen/Qwen2.5-7B-Instruct`
- **本次处理结论**：当前 PPU 机器上的新镜像服务正常，50 题 GPQA 精度通过；本文件仅记录本次 50 题结果，不展开根因分析

---

## 背景

本次使用统一 PPU 镜像，在共享目录下载模型权重，并在长驻推理容器中单卡启动 vLLM 服务。评测使用独立评测容器访问 OpenAI API 接口，固定 GPQA Diamond 50 题作为当前记录口径。

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
| 模型路径 | `/models/Qwen2.5-7B-Instruct` |
| 宿主机共享路径 | `/mnt/workspace/models/Qwen2.5-7B-Instruct` |
| GPU | `CUDA_VISIBLE_DEVICES=1` |
| 服务端口 | `18083` |

## Step 0：容器运行配置

推理容器为长驻容器，PID 1 用于保持容器存活，vLLM 服务通过 `docker exec` 在容器内启动：

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

宿主机上的实际容器配置经 `docker inspect` 核对。以下命令可在同名容器不存在时重建等价的长驻推理容器：

```bash
set -euo pipefail
test -d /dev
test -d /usr/local/PPU_SDK
test -d /mnt/workspace/models/Qwen2.5-7B-Instruct

docker run -d \
  --name flagrelease_thead_model_dl_20260915 \
  --network host \
  --ipc host \
  --privileged \
  --shm-size=512g \
  -v /dev:/dev \
  -v /usr/local/PPU_SDK:/usr/local/PPU_SDK \
  -v /mnt/workspace/models:/models \
  harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100 \
  sleep infinity
```

评测容器只挂载 `/mnt/workspace/models:/models`，不执行 PPU 推理，因而没有挂载 `/dev` 和 `/usr/local/PPU_SDK`。

## Step 1：启动 vLLM 服务

实际启动命令：

```bash
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

健康检查：

```bash
curl http://127.0.0.1:18083/health
curl http://127.0.0.1:18083/v1/models
```

结果：健康检查 HTTP `200`，模型名为 `Qwen2.5-7B-Instruct`。

### 环境变量

```bash
export CUDA_VISIBLE_DEVICES=1
export HIP_VISIBLE_DEVICES=1
export XPU_VISIBLE_DEVICES=1

export VLLM_PLUGINS=fl
export USE_FLAGGEMS=1
export VLLM_FL_PREFER_ENABLED=true

export VLLM_FL_FLAGOS_WHITELIST=lift_fresh,empty,zero_,zeros,arange_start,true_divide,pow_scalar,reciprocal,mul,unsqueeze,cos,sin,cat,to_copy,ones,fill_scalar_,narrow,copy_,randn,addmm_out,broadcast_to,mm_out,index,rand_like,linear,alias,full,argmax,lt_scalar,scalar_tensor,where_self,where_self_out,true_divide_,softmax,softmax_out,exponential_,unbind,add,sub,expand,eq_scalar,masked_fill_,ones_like,scatter_add_0,gt_scalar,repeat,bitwise_or_tensor,mul_,sub_,sort,sort_stable,cumsum,rsub_scalar,gather,lt,cumsum_out,le,scatter_,attention_backend,rms_norm,silu_and_mul,rotary_embedding

export VLLM_CACHE_ROOT=/models/_vllm_cache/qwen2.5-7b-gpu1
export TORCHINDUCTOR_CACHE_DIR=/models/_vllm_cache/qwen2.5-7b-gpu1/torchinductor
export TRITON_CACHE_DIR=/models/_vllm_cache/qwen2.5-7b-gpu1/triton
export VLLM_FL_TRITON_CACHE_ROOT=/models/_vllm_cache/qwen2.5-7b-gpu1/triton

export PPU_HOME=/usr/local/PPU_SDK
export CUDA_HOME=/usr/local/PPU_SDK/CUDA_SDK
export HF_ENDPOINT=https://hf-mirror.com
```

当前实际使用的主要 FlagOS 路径包括 `attention_backend`、`rms_norm`、`rotary_embedding`、`silu_and_mul`。没有修改 vLLM、plugin-FL 或 FlagGems 源码。

服务日志：

```text
/models/_serve_logs/Qwen2.5-7B-Instruct-20260916-gpu1.log
```

## Step 2：模型文件和容器变更

模型文件位于：

```text
/mnt/workspace/models/Qwen2.5-7B-Instruct
```

镜像本身没有重新构建、重新打 tag 或 push。容器可写层变化主要来自：

- 安装 `modelscope==1.40.0`、`modelscope-hub==0.4.2`；
- 产生 ModelScope、pip、vLLM model-info 等缓存；
- 产生 FlagGems/Triton 运行时临时文件；
- `/models` 绑定共享目录中的模型、日志和缓存。

未修改 `/workspace/vllm`、`/workspace/vllm-plugin-FL` 或 `/workspace/FlagGems` 的源码和算子实现。

## Step 3：评测

评测服务地址：

```text
http://127.0.0.1:18083/v1
```

评测配置：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.5.1` |
| 题数 | 50 |
| `eval_batch_size` | 4 |
| `max_model_len` | 32768 |
| `max_tokens` | 24576 |
| 截断检测 | 未检测到截断 |
| 评测耗时 | 1513.43 秒 |

结果文件：

```text
/mnt/workspace/models/_eval_results/20260916_new_models/50/Qwen2.5-7B-Instruct/Qwen2.5-7B-Instruct_gpqa_result.json
```

结果摘要：

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

## 当前结果

- 服务：正常，端口 `18083`，GPU1
- GPQA Diamond：`38.0%`（19/50）
- NV 参考值：`39.0%`
- 相对退化：`2.56%`
- 精度判定：✅ 通过
- 性能验收：未重测

## 可复用规则

50 题 GPQA 记录必须同时保存原始 EvalScope 分数、答案提取审计结果、截断检测结果和 NV 对齐判定。若模型服务使用独立 GPU 和独立缓存目录，应在记录中固定写清，便于复现实验环境。
