# Hygon/MiniCPM4-8B 适配与评测记录

- **日期**：`2026-09-18`
- **远端机器**：`10.232.2.33`
- **主机名**：`bm-srwl-nj-zone3-d-bw1000-64g-2-33`
- **模型来源**：`openbmb/MiniCPM4-8B`
- **本次处理结论**：使用 Hygon 新镜像单卡部署，评测侧固定采用模型 `generation_config.json` 中的 `temperature=0.8`、`top_p=0.8`；GPQA Diamond 50 题得分 `36.00%（18/50）`，与 NV 基线 `36.00%` 持平，精度损失为 `0`，按当前精度门限通过

---

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `bm-srwl-nj-zone3-d-bw1000-64g-2-33` / `10.232.2.33` |
| 芯片 | Hygon DCU BW1000，8 × 64GB |
| 推理容器 | `day0-minicpm4-8b` |
| 评测容器 | `day0-eval-standard` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4` |
| 镜像 ID | `sha256:b4dd95d30aa8213e0721856672ee544e773c51216b3737c12069b32ad71d07a0` |
| vLLM / PyTorch | `vLLM 0.24.0` / `PyTorch 2.10.0` |
| EvalScope | `1.5.1` |
| 模型宿主机路径 | `/public-flash/models/MiniCPM4-8B` |
| 模型容器路径 | `/models/MiniCPM4-8B` |
| GPU | `HIP_VISIBLE_DEVICES=6` |
| Tensor Parallel | `1` |
| 服务端口 | `8010` |
| dtype | `bfloat16` |

## Step 0：模型配置核验

模型配置文件：

```text
/public-flash/models/MiniCPM4-8B/generation_config.json
```

与本轮评测相关的配置：

```json
{
  "do_sample": true,
  "temperature": 0.8,
  "top_p": 0.8,
  "top_k": null,
  "repetition_penalty": null,
  "max_new_tokens": null,
  "max_length": null
}
```

本轮评测固定使用：

```text
temperature=0.8
top_p=0.8
```

`max_tokens` 由评测脚本根据服务端 `max_model_len=32768` 自动计算：

```text
max_tokens = max_model_len - 8192
           = 32768 - 8192
           = 24576
```

## Step 1：容器运行配置

推理容器由常驻进程保持运行，vLLM 通过 `docker exec` 在容器内启动：

```text
cmd:      ["bash", "-lc", "sleep infinity"]
network:  host
ipc:      host
shm-size: 64 GiB
```

设备与权限：

```text
/dev/kfd
/dev/dri
seccomp=unconfined
group-add=video
```

挂载：

```text
/public-flash/models -> /models      读写
/opt/hyhal           -> /opt/hyhal  只读
```

评测容器使用 host 网络，并挂载：

```text
/public-flash/models/day0_eval -> /models/day0_eval
/public-flash/models/day0_logs -> /models/day0_logs
```

## Step 2：启动 vLLM 服务

实际 vLLM 进程命令：

```bash
/usr/bin/python3 /usr/local/bin/vllm serve /models/MiniCPM4-8B \
  --served-model-name MiniCPM4-8B \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.90 \
  --port 8010 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code
```

关键环境变量：

```bash
export DTK_HOME=/opt/dtk
export ROCM_PATH=/opt/dtk
export HIP_PATH=/opt/dtk/hip
export HSA_PATH=/opt/dtk/hsa
export DEVICE_LIB_PATH=/opt/dtk/amdgcn/bitcode
export TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18

export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export HIP_VISIBLE_DEVICES=6
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200

export VLLM_FL_TRITON_CACHE_ROOT=/models/day0_logs/triton_cache/MiniCPM4-8B
export VLLM_FL_FLAGOS_WHITELIST=add,arange_start,argmax,broadcast_to,copy_,cos,cumsum,cumsum_out,expand,full,index,le,linear,lt_scalar,masked_fill_,mm_out,ones,rand_like,reciprocal,rsub_scalar,scatter_,sin,softmax,softmax_out,sub,sum_dim,to_copy,true_divide,true_divide_,where_self,where_self_out,zero_,zeros
```

环境变量说明：

- `TRITON_HIP_CLANG_PATH` 显式使用 DTK clang-18；
- `VLLM_FL_TRITON_CACHE_ROOT` 使用 MiniCPM4-8B 独立 Triton 缓存；
- `VLLM_FL_FLAGOS_WHITELIST` 固定本轮普通 FlagGems 算子集合；
- 当前服务进程没有显式设置 `VLLM_FL_OOT_ENABLED`、`VLLM_FL_OOT_BLACKLIST` 或 `VLLM_FL_USE_FLAGGEMS_ATTN`。

vLLM EngineCore 初始化日志确认：

```text
dtype=torch.bfloat16
max_seq_len=32768
tensor_parallel_size=1
enforce_eager=True
enable_prefix_caching=True
enable_chunked_prefill=True
served_model_name=MiniCPM4-8B
```

服务日志：

```text
/public-flash/models/day0_logs/MiniCPM4-8B-serve-20260916-161804-gpu6.log
```

健康检查：

```bash
curl http://127.0.0.1:8010/health
curl http://127.0.0.1:8010/v1/models
```

核验结果：

```text
/health: HTTP 200
model: MiniCPM4-8B
max_model_len: 32768
```

## Step 3：评测脚本

本轮实际使用的评测脚本：

```text
/models/day0_eval/fast_gpqa_genconfig_fixed.py
```

该脚本以统一评测脚本为基础：

```text
/models/day0_eval/fast_gpqa.py
```

新增模型采样参数映射：

```python
_model_key = str(model_name).split("/")[-1]
_GEN_OVERRIDES = {
    "MiniCPM4-8B": {
        "temperature": 0.8,
        "top_p": 0.8,
    },
}

if _model_key in _GEN_OVERRIDES:
    for _k, _v in _GEN_OVERRIDES[_model_key].items():
        gen_config[_k] = _v
```

评测日志确认最终生效参数：

```text
[gen] applied embedded model config for MiniCPM4-8B:
temperature=0.8, top_p=0.8, max_tokens=24576
```

该改动只存在于评测容器的专用评测脚本中。推理容器中的 vLLM、vllm-plugin-FL、FlagGems 和模型文件均未修改。

## Step 4：执行评测

评测服务地址：

```text
http://127.0.0.1:8010/v1
```

实际命令的等价形式：

```bash
python3 /models/day0_eval/fast_gpqa_genconfig_fixed.py \
  --model-name MiniCPM4-8B \
  --api-base http://127.0.0.1:8010/v1 \
  --api-key EMPTY \
  --dataset gpqa_diamond \
  --limit 50 \
  --eval-batch-size 4 \
  --skip-truncation-check \
  --output /models/day0_logs/accuracy/MiniCPM4-8B-gpqa50-genconfig-fixed-20260918-0002.json
```

评测配置：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| 数据集来源 | `AI-ModelScope/gpqa_diamond` |
| subset | `default` |
| split | `train` |
| EvalScope | `1.5.1` |
| EvalScope backend | `Native` |
| 题数 | `50` |
| few-shot | `0` |
| 模式 | `standard` |
| `eval_batch_size` | `4` |
| `temperature` | `0.8` |
| `top_p` | `0.8` |
| `max_model_len` | `32768` |
| `max_tokens` | `24576` |
| `stream` | `true` |
| 请求超时 | `120000 ms` |
| retries | `5` |
| seed | `42` |
| 截断探测 | 通过 `--skip-truncation-check` 显式跳过 |
| 评测耗时 | `8405.55s`，约 140 分 5.5 秒 |

GPQA prompt：

```text
Answer the following multiple choice question.
The last line of your response should be of the following format:
'ANSWER: [LETTER]'
Think step by step before answering.
```

评测开始时日志记录：

```text
Unified pool: 50 items to process, 0 already fully cached
```

说明本轮 50 题均重新生成，没有复用历史答案。

## Step 5：结果文件

结果 JSON：

```text
/public-flash/models/day0_logs/accuracy/MiniCPM4-8B-gpqa50-genconfig-fixed-20260918-0002.json
```

评测日志：

```text
/public-flash/models/day0_logs/accuracy/MiniCPM4-8B-gpqa50-genconfig-fixed-20260918-0002.log
```

退出状态：

```text
/public-flash/models/day0_logs/accuracy/MiniCPM4-8B-gpqa50-genconfig-fixed-20260918-0002.exit
/public-flash/models/day0_logs/accuracy/MiniCPM4-8B-gpqa50-genconfig-fixed-20260918-0002.done
```

退出状态内容：

```text
exit=0
done=0
```

EvalScope 原始工作目录：

```text
/public-flash/models/day0_eval/outputs/gpqa_diamond/20260918_041951
```

TaskConfig：

```text
/public-flash/models/day0_eval/outputs/gpqa_diamond/20260918_041951/configs/task_config.yaml
```

结果摘要：

```json
{
  "model": "MiniCPM4-8B",
  "benchmark": "gpqa_diamond",
  "mode": "standard",
  "score": 36.0,
  "evalscope_score": 36.0,
  "total_questions": 50,
  "eval_batch_size": 4,
  "max_tokens": 24576,
  "max_model_len": 32768,
  "temperature": 0.8,
  "eval_duration_seconds": 8405.55,
  "total_duration_seconds": 8405.55,
  "runaway_detection": {
    "checked": 50,
    "runaway_count": 5,
    "runaway_indices": [6, 16, 17, 38, 47]
  },
  "answer_extraction_audit": {
    "checked": 50,
    "explicit_answer_found": 38,
    "fallback_to_evalscope": 8,
    "format_corrected_score": 36.0,
    "parser_mismatch_count": 0,
    "invalid_evalscope_extract_count": 4
  }
}
```

最终正确题数：

```text
18/50 = 36.00%
```

## Step 6：与 NV 基线对比

基线文件：

```text
/Users/baai3333/Desktop/flagos/release_gap/flagrelease_eval_methods/nv_baseline.yaml
```

NV 记录：

```yaml
MiniCPM4-8B:
  aliases:
    - openbmb/MiniCPM4-8B
    - minicpm4-8b
    - minicpm4_8b
  metrics:
    gpqa_diamond: 36
  source: "NV 实测"
  updated_at: "2026-07-17"
```

对比结果：

| 项目 | 值 |
|------|---:|
| Hygon 当前结果 | `36.00%（18/50）` |
| NV 基线 | `36.00%` |
| 绝对差 | `0` 个百分点 |
| 相对精度损失 | `0.00%` |
| 精度要求 | 相对 NV 精度损失低于 `5%` |
| 精度判定 | 通过 |

## 当前结果

- 部署：成功；
- 服务：正常；
- GPU：`6`；
- 端口：`8010`；
- Tensor Parallel：`1`；
- dtype：`bfloat16`；
- attention：`TRITON_ATTN`；
- prefix cache：开启；
- chunked prefill：开启；
- 评测采样参数：`temperature=0.8`、`top_p=0.8`；
- GPQA Diamond：`36.00%（18/50）`；
- NV 基线：`36.00%`；
- 相对精度损失：`0.00%`；
- 精度判定：通过。

## 可复用规则

1. 部署前读取模型 `generation_config.json`，固定记录 `do_sample`、`temperature`、`top_p`、`top_k` 和 `repetition_penalty`。
2. OpenAI API 客户端显式发送采样参数后，服务端不会再自动使用模型目录中的默认采样配置。
3. `served-model-name` 是 API 服务别名，不能直接当作评测容器中的本地模型路径。
4. 评测脚本应支持“服务模型名到采样配置”的明确映射，并在日志中打印最终生效值。
5. 结果 JSON 应保存生成参数、题数、缓存命中、答案提取审计、退出状态和 NV 对比结论。
6. 适配验收应同时记录镜像、环境变量、算子白名单、attention backend、prefix cache 和 chunked prefill 实际值。
