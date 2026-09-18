# T-Head/Nanbeige4.1-3B 适配与评测记录

- **日期**：`2026-09-17`
- **远端机器**：`244-pm-aliyun-wlcb-zoned-d-810e-96G`（`8.130.132.221`）
- **主机名**：`dsw-879515-f5bf65bfd-jd7bj`
- **历史容器**：`Nanbeige4.1-3B_flagos`，旧镜像，`Exited (255) 3 weeks ago`
- **历史失败报告**：`flagrelease_fail_reports/T-Head/FAILED_T-Head_Nanbeige4.1-3B_202608221700.md`
- **海光参考记录**：`workspace/hygon/fixes/Nanbeige4.1-3B.md`
- **模型来源**：`nanbeige/Nanbeige4.1-3B`
- **本次处理结论**：新镜像单卡服务正常，模型下载容器已清理；GPQA Diamond 50 题格式校正分 `76.00%`，低于 NV `81.00%`，相对退化 `6.17%`，超过 5% 门限，当前精度不达标

---

## 背景分析

用户要求使用统一 T-Head 新镜像部署 `Nanbeige4.1-3B`，模型下载必须在临时容器内完成并在下载后清理容器；启动后按照海光记录同口径跑 GPQA Diamond 50 题，并与 NV 精度对比。

本机曾部署过同模型旧容器：

```text
Nanbeige4.1-3B_flagos
image: harbor.baai.ac.cn/flagrelease-public/flagrelease_ppu_vllm020plugin_base:0807
status: Exited (255) 3 weeks ago
old mounts:
  /data/models/Nanbeige4.1-3B
  /data/flagos-workspace/Nanbeige/Nanbeige4.1-3B
```

本轮不复用旧容器，新建独立推理容器并使用空闲 GPU14、端口 `18087`。算子白名单参考历史 T-Head 失败报告中的 Nanbeige 记录，并补充当前 vLLM 0.24 常用融合路径。

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `244-pm-aliyun-wlcb-zoned-d-810e-96G` / `8.130.132.221` |
| 芯片 | PPU-ZW810E，16 x 96GB |
| 推理容器 | `flagrelease_thead_nanbeige4p1_3b_20260917` |
| 评测容器 | `flagrelease_thead_eval_20260915` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100` |
| 镜像 ID | `sha256:a54dcb164e0d9aad003884e6b0691400f6c8db1e56d513b03dc1c65d30f830ce` |
| vLLM / PyTorch | `vllm 0.24.0+empty` / `torch 2.10.0` |
| EvalScope | `1.5.1` |
| 模型宿主机路径 | `/mnt/workspace/models/Nanbeige4.1-3B` |
| 模型容器路径 | `/models/Nanbeige4.1-3B` |
| GPU | `CUDA_VISIBLE_DEVICES=14` |
| 服务端口 | `18087` |
| dtype | `bfloat16` |
| max_model_len | `32768` |

## Step 0：模型下载

模型下载在临时容器内完成，下载后容器由 `--rm` 清理：

```text
container: flagrelease_nanbeige4p1_3b_download_20260917
mount:     /mnt/workspace/models -> /models
target:    /models/Nanbeige4.1-3B
```

下载后核验 `docker ps -a` 中不存在该下载容器，模型文件保留在共享目录：

```text
/mnt/workspace/models/Nanbeige4.1-3B
```

主要权重文件包括：

```text
model-00001-of-00002.safetensors
model-00002-of-00002.safetensors
model.safetensors.index.json
config.json
tokenizer.model
tokenizer.json
```

## Step 1：启动 vLLM 服务

推理容器为长驻容器，vLLM 服务通过 `docker exec` 在容器内启动：

```text
network:    host
ipc:        host
privileged: true
shm-size:   512 GiB
mounts:
  /mnt/workspace/models -> /models
  /dev                  -> /dev
  /usr/local/PPU_SDK    -> /usr/local/PPU_SDK
```

实际 vLLM 命令：

```bash
/usr/local/bin/vllm serve /models/Nanbeige4.1-3B \
  --served-model-name Nanbeige4.1-3B \
  --host 0.0.0.0 \
  --port 18087 \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.85 \
  --trust-remote-code \
  --enforce-eager
```

关键环境变量：

```bash
export CUDA_VISIBLE_DEVICES=14
export HIP_VISIBLE_DEVICES=14
export XPU_VISIBLE_DEVICES=14

export VLLM_PLUGINS=fl
export USE_FLAGGEMS=1
export VLLM_FL_PREFER_ENABLED=true
export FLAGGEMS_DB_URL=sqlite:///:memory:

export VLLM_FL_FLAGOS_WHITELIST=add,arange_start,argmax,cat,copy_,cos,exponential_,fill_scalar_,index,lt_scalar,mul,pow_scalar,rand_like,reciprocal,scatter_,sin,softmax,softmax_out,sub,true_divide,true_divide_,where_self,where_self_out,zero_,zeros,attention_backend,rms_norm,silu_and_mul,rotary_embedding

export VLLM_CACHE_ROOT=/models/_vllm_cache/nanbeige4p1-3b-gpu14
export TORCHINDUCTOR_CACHE_DIR=/models/_vllm_cache/nanbeige4p1-3b-gpu14/torchinductor
export TRITON_CACHE_DIR=/models/_vllm_cache/nanbeige4p1-3b-gpu14/triton
export VLLM_FL_TRITON_CACHE_ROOT=/models/_vllm_cache/nanbeige4p1-3b-gpu14/triton

export PPU_HOME=/usr/local/PPU_SDK
export CUDA_HOME=/usr/local/PPU_SDK/CUDA_SDK
export HF_ENDPOINT=https://hf-mirror.com
```

服务日志：

```text
/mnt/workspace/models/_serve_logs/Nanbeige4.1-3B-20260917-gpu14-port18087.log
```

健康检查：

```bash
curl http://127.0.0.1:18087/health
curl http://127.0.0.1:18087/v1/models
```

结果：HTTP `200`，`/v1/models` 返回模型名 `Nanbeige4.1-3B`，`max_model_len=32768`。日志确认实际进入 FlagOS 路径的主要算子包括 `attention_backend`、`rms_norm`、`rotary_embedding`、`silu_and_mul`。

## Step 2：评测

评测服务地址：

```text
http://127.0.0.1:18087/v1
```

评测配置与海光记录保持同口径：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.5.1` |
| 题数 | 50 |
| `eval_batch_size` | 4 |
| `temperature` | 0.0 |
| `max_model_len` | 32768 |
| `max_tokens` | 24576 |
| 截断检测 | 通过 `--skip-truncation-check` 显式跳过，不能据此声明已排除截断 |
| 评测耗时 | `124m 29.4s` |

评测命令：

```bash
python3 fast_gpqa.py \
  --model-name Nanbeige4.1-3B \
  --api-base http://127.0.0.1:18087/v1 \
  --dataset gpqa_diamond \
  --limit 50 \
  --eval-batch-size 4 \
  --skip-truncation-check \
  --max-tokens 24576 \
  --dataset-dir /models/evalscope-datasets \
  --output /models/_eval_results/20260917_nanbeige4p1_3b_thead_gpqa50/Nanbeige4.1-3B_gpqa_result.json
```

结果文件：

```text
/mnt/workspace/models/_eval_results/20260917_nanbeige4p1_3b_thead_gpqa50/Nanbeige4.1-3B_gpqa_result.json
/mnt/workspace/models/_eval_results/20260917_nanbeige4p1_3b_thead_gpqa50/verdict.json
/mnt/workspace/models/_eval_results/20260917_nanbeige4p1_3b_thead_gpqa50/eval.log
```

EvalScope 原始输出目录：

```text
/mnt/workspace/models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods/outputs/gpqa_diamond/20260917_184414
```

结果摘要：

```json
{
  "score": 76.0,
  "evalscope_score": 70.0,
  "total_questions": 50,
  "eval_batch_size": 4,
  "temperature": 0.0,
  "max_tokens": 24576,
  "max_model_len": 32768,
  "truncation_check_skipped": true,
  "runaway_detection": {
    "checked": 50,
    "runaway_count": 0
  },
  "answer_extraction_audit": {
    "checked": 50,
    "explicit_answer_found": 40,
    "fallback_to_evalscope": 2,
    "format_corrected_score": 76.0,
    "parser_mismatch_count": 4,
    "parser_false_negative_count": 3,
    "parser_false_positive_count": 0,
    "invalid_evalscope_extract_count": 12
  }
}
```

NV 对比：

```json
{
  "baseline_mode": "nv_reference",
  "model": "Nanbeige4.1-3B",
  "metric": "gpqa_diamond",
  "nv": {
    "score": 81.0,
    "source": "NV 实测"
  },
  "current": {
    "score": 76.0,
    "mode": "standard"
  },
  "tolerance": 0.05,
  "rel_drop_pct": 6.17,
  "abs_diff": -5.0,
  "aligned": false,
  "noise_zone": false,
  "message": "精度不达标: 当前=76.00%, NV=81.00%, 相对退化=6.17% > 容差 5.0%"
}
```

## 现象

- 服务启动稳定，`18087` 健康检查 HTTP `200`；
- 50 题 EvalScope 原始分为 `70.00%`；
- 答案抽取审计后格式校正分为 `76.00%`，比原始分高 6 个百分点；
- NV 基线为 `81.00%`，当前格式校正分仍相对退化 `6.17%`，超过 5% 门限；
- `runaway_count=0`；
- `/metrics` 显示本轮 50 个请求累计 `request_generation_tokens_sum=699766`，长输出风险明显；
- `answer_extraction_audit.invalid_evalscope_extract_count=12`，说明该模型输出格式对 EvalScope 原始解析仍不友好。

## 定位

部署链路已打通，当前主要问题不是服务可用性，而是精度口径下未达标。与海光同模型同口径结果相比：

| 环境 | 格式校正分 | EvalScope 原始分 | NV 基线 | 结论 |
|------|-----------:|-----------------:|--------:|------|
| Hygon | `84.00%` | `78.00%` | `81.00%` | 通过 |
| T-Head 本轮 | `76.00%` | `70.00%` | `81.00%` | 未通过 |

历史 T-Head 失败报告中同模型曾记录 `78.00%` 对 NV `81.00%`，处于 5% 容差内；本轮新镜像、新服务、同 50 题口径下为 `76.00%`，低于历史记录，不能按达标交付。

## 后续定位方向

1. 保留当前服务作为复现场景：`flagrelease_thead_nanbeige4p1_3b_20260917`，GPU14，端口 `18087`；
2. 先复核采样与 prompt 口径是否与历史 T-Head 报告完全一致；
3. 对比本轮预测与海光/NV/历史 T-Head 的逐题答案，优先看 5 个百分点差距来自哪些题；
4. 尝试收缩白名单到 `attention_backend,rms_norm,silu_and_mul,rotary_embedding`，或按历史报告只保留实际必要算子，观察 50 题是否回到 `78%+`；
5. 对 GPQA 这类 MCQ 任务保留 `evalscope_score`、`score`、`answer_extraction_audit`、`runaway_detection` 和生成 token 汇总，避免只看 EvalScope 原始分误判。

## 当前结果

- 部署：完成
- 临时下载容器：已清理
- 服务：正常，端口 `18087`，GPU14
- GPQA Diamond 50 题：`76.00%`
- EvalScope 原始分：`70.00%`
- NV 参考值：`81.00%`
- 相对退化：`6.17%`
- 精度判定：未通过
- 长输出：明显，50 请求累计生成约 `699766` tokens
