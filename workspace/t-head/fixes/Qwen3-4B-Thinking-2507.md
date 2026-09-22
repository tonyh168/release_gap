# T-Head/Qwen3-4B-Thinking-2507 适配与评测记录

- **日期**：`2026-09-16`
- **远端机器**：`244-pm-aliyun-wlcb-zoned-d-810e-96G`（`8.130.132.221`）
- **主机名**：`dsw-879515-f5bf65bfd-jd7bj`
- **历史失败报告**：`flagrelease_fail_reports/T-Head/FAILED_T-Head_Qwen3-4B-Thinking-2507_202608281759.md`
- **历史问题类型**：服务/精度/性能流程未完整达标；历史报告中的 V2 GPQA 仅 30 题、`63.33%`，且没有 V1 基线
- **本次处理结论**：当前 PPU 机器上的新镜像服务正常，50 题 GPQA 精度通过；性能和完整 V1-V3 对比本次未重测

---

## 背景分析

历史 T-Head 自动化报告使用的是较早的 vLLM 0.20.2 / plugin-FL 0.2.0 组合，V2 只有 30 题精度结果，不能直接作为本次新镜像的最终结论。

本次使用已经下载完成的统一 PPU 镜像，在共享目录中的模型权重上重新启动服务，并使用独立评测容器执行 50 题 GPQA Diamond。Qwen3-4B-Thinking-2507 为 thinking 模型，正式评测采用 `eval_batch_size=1`，避免长思考输出和并发访问导致服务端 SQLite 锁冲突。

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
| 模型来源 | `Qwen/Qwen3-4B-Thinking-2507` |
| 模型路径 | `/models/Qwen3-4B-Thinking-2507` |
| 宿主机共享路径 | `/mnt/workspace/models/Qwen3-4B-Thinking-2507` |
| GPU | `CUDA_VISIBLE_DEVICES=6` |
| 服务端口 | `18080` |

`/models` 是宿主机 `/mnt/workspace/models` 的读写挂载。三个模型共用同一个推理容器，分别通过不同 GPU 和端口启动 vLLM 进程。

## Step 0：容器运行配置

当前容器 PID 1 不是 vLLM，而是保持容器存活：

```text
entrypoint: ["bash", "/opt/t-head/entrypoint.sh"]
cmd:        ["sleep", "infinity"]
```

容器关键配置：

```text
network:    host
ipc:        host
privileged: true
shm-size:   512 GiB
```

挂载：

```text
/dev                 -> /dev
/usr/local/PPU_SDK   -> /usr/local/PPU_SDK
/mnt/workspace/models -> /models
```

宿主机上的实际容器配置经 `docker inspect` 核对。以下命令可在同名容器不存在时重建等价的长驻推理容器：

```bash
set -euo pipefail
test -d /dev
test -d /usr/local/PPU_SDK
test -d /mnt/workspace/models/Qwen3-4B-Thinking-2507

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

评测容器只挂载 `/mnt/workspace/models:/models`；它不执行 PPU 推理，所以无需挂载 `/dev` 和 `/usr/local/PPU_SDK`。

## Step 1：启动 vLLM 服务

服务通过 `docker exec` 在长驻容器内手动启动，实际命令为：

```bash
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

当前服务检查：

```bash
curl http://127.0.0.1:18080/health
curl http://127.0.0.1:18080/v1/models
```

结果：健康检查 HTTP `200`，模型名为 `Qwen3-4B-Thinking-2507`。

### 环境变量

```bash
export CUDA_VISIBLE_DEVICES=6
export HIP_VISIBLE_DEVICES=6
export XPU_VISIBLE_DEVICES=6

export VLLM_PLUGINS=fl
export USE_FLAGGEMS=1
export VLLM_FL_PREFER_ENABLED=true

export VLLM_FL_FLAGOS_WHITELIST=add,arange_start,argmax,cat,copy_,cos,cumsum,cumsum_out,true_divide,true_divide_,exponential_,fill_scalar_,full,gather,index,le,lt,lt_scalar,masked_fill_,mm,mm_out,mul,ones,pow_scalar,rand_like,randn,reciprocal,rsub_scalar,scatter_,sin,softmax,softmax_out,sort,sort_stable,sub,to_copy,where_self,where_self_out,zero_,zeros,attention_backend,rms_norm,silu_and_mul,rotary_embedding

export VLLM_CACHE_ROOT=/models/_vllm_cache/qwen3-4b-gpu6
export TORCHINDUCTOR_CACHE_DIR=/models/_vllm_cache/qwen3-4b-gpu6/torchinductor
export TRITON_CACHE_DIR=/models/_vllm_cache/qwen3-4b-gpu6/triton
export VLLM_FL_TRITON_CACHE_ROOT=/models/_vllm_cache/qwen3-4b-gpu6/triton
```

基础运行环境还包括：

```bash
export PPU_HOME=/usr/local/PPU_SDK
export CUDA_HOME=/usr/local/PPU_SDK/CUDA_SDK
export HF_ENDPOINT=https://hf-mirror.com
```

FlagOS 当前实际接管了 `attention_backend`、`rms_norm`、`rotary_embedding`、`silu_and_mul` 等路径。未修改 `/workspace/vllm`、`/workspace/vllm-plugin-FL` 或 `/workspace/FlagGems` 中的源码。

## Step 2：模型文件和容器变更

模型文件位于共享目录：

```text
/mnt/workspace/models/Qwen3-4B-Thinking-2507
```

镜像仓库中的原始镜像没有重构、重新打 tag 或 push 新镜像。运行容器的可写层有以下运行时变化：

- 安装了 `modelscope==1.40.0` 和 `modelscope-hub==0.4.2`；
- 产生 ModelScope、pip、vLLM model-info、HuggingFace remote-code 缓存；
- 产生 FlagGems/Triton 临时文件；
- 模型、日志和 vLLM/Triton 缓存写入绑定挂载的 `/models`。

没有修改 vLLM、plugin-FL、FlagGems 算子实现文件。

服务日志：

```text
/models/_serve_logs/Qwen3-4B-Thinking-2507-20260915_191800-gpu6.log
```

## Step 3：评测

评测使用独立容器 `flagrelease_thead_eval_20260915`，访问：

```text
http://127.0.0.1:18080/v1
```

评测配置：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.5.1` |
| 题数 | 50 |
| `eval_batch_size` | 1 |
| `max_model_len` | 32768 |
| `max_tokens` | 20000 |
| 截断检测 | 未检测到截断 |
| 评测耗时 | 27042.81 秒 |

结果文件：

```text
/mnt/workspace/models/_eval_results/20260915_accuracy/qwen_retry_20260915_192500/Qwen3-4B-Thinking-2507_gpqa_result.json
```

结果摘要：

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

## 现象

- 首轮高并发评测曾因 SQLite `database is locked` 中断；
- GPU2 当时已被其他模型服务占用，不能强行回收；
- 将 Qwen 服务切换到 GPU6，并将评测并发降为 1 后完成 50 题评测；
- 最终未出现截断，答案格式校正前后分数一致。

## 定位

本次主要问题是评测并发与服务端运行状态冲突，不是当前模型服务启动失败。GPU2 的占用来自其他独立服务，不能作为本模型资源使用。

## 处置

1. 保留统一 PPU 镜像和当前 FlagOS 算子白名单；
2. 将 Qwen 服务固定到空闲 GPU6；
3. 使用独立的 `/models/_vllm_cache/qwen3-4b-gpu6` 缓存目录；
4. 将正式 GPQA 评测并发固定为 1；
5. 对结果执行答案提取审计和截断检查。

## 当前结果

- 服务：正常，端口 `18080`，GPU6
- GPQA Diamond：`72.0%`（36/50）
- NV 参考基线：`68.0%`
- 相对退化：`-5.88%`，实际为提升
- 精度判定：✅ 通过
- 本次完整性能验收：未重测，不能据此宣称 V1-V3 全部通过

## 可复用规则

Thinking 模型在 PPU 上正式精度评测应优先使用 `eval_batch_size=1`，并为每次重启隔离 `VLLM_CACHE_ROOT`、TorchInductor 和 Triton 缓存目录。服务健康、评测完整结束、答案提取审计和截断检查必须同时满足，才能把分数作为正式结果。
