# Hygon/Light-R1-7B-DS 适配与评测记录

- **日期**：`2026-09-18`
- **远端机器**：`10.232.2.33`
- **主机名**：`bm-srwl-nj-zone3-d-bw1000-64g-2-33`
- **模型来源**：`qihoo360/Light-R1-7B-DS`
- **本次处理结论**：使用 Hygon 新镜像单卡部署，服务侧固定 native `TRITON_ATTN`、关闭 FlagGems attention 和 FL OOT，评测侧按模型 `generation_config.json` 使用 thinking 参数 `temperature=0.6`、`top_p=0.95`、`max_tokens=20000`。MATH-500 50 题得分 `92.00%（46/50）`，相对 NV 记录值 `94.00%`下降 `2.13%`，满足相对精度损失低于 5% 的门限，本轮评测通过。

---

## 背景分析

Light-R1-7B-DS 是基于 Qwen2 架构的 reasoning 模型，模型 `generation_config.json` 明确声明：

```json
{
  "do_sample": true,
  "temperature": 0.6,
  "top_p": 0.95,
  "eos_token_id": 151643
}
```

本轮从服务和评测两侧固定变量：

1. 服务使用 BF16、TP1、eager 和 `TRITON_ATTN`；
2. `VLLM_FL_FLAGOS_WHITELIST=attention_backend` 只保留 plugin-FL 路由入口；
3. `VLLM_FL_USE_FLAGGEMS_ATTN=0`，attention 实际走 vLLM native Triton 路径；
4. `VLLM_FL_OOT_ENABLED=0`，关闭 FL OOT 注册；
5. 评测脚本按模型名固定 `temperature=0.6`、`top_p=0.95`、`max_tokens=20000`；
6. 固定并发 4，MATH-500 每个难度 Level 取 10 题，共 50 题。

本记录只描述上述通过轮次，不将其他题数、其他服务配置或其他评测轮次混入结论。

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `bm-srwl-nj-zone3-d-bw1000-64g-2-33` / `10.232.2.33` |
| 芯片 | Hygon DCU BW1000，8 × 64GB |
| 推理容器 | `day0-light-r1-7b-ds` |
| 评测容器 | `day0-eval-standard` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4` |
| 镜像 ID | `sha256:b4dd95d30aa8213e0721856672ee544e773c51216b3737c12069b32ad71d07a0` |
| vLLM / EvalScope | `0.24.0` / `1.5.1` |
| 模型宿主机路径 | `/public-flash/models/Light-R1-7B-DS` |
| 模型容器路径 | `/models/Light-R1-7B-DS` |
| GPU | `HIP_VISIBLE_DEVICES=5` |
| Tensor Parallel / dtype | `1` / `bfloat16` |
| 服务端口 | `8003` |
| 注意力后端 | `TRITON_ATTN` |

## Step 0：模型配置核验

模型 `config.json`：

```json
{
  "architectures": ["Qwen2ForCausalLM"],
  "model_type": "qwen2",
  "torch_dtype": "bfloat16",
  "max_position_embeddings": 131072,
  "eos_token_id": 151643
}
```

模型 `generation_config.json`：

```json
{
  "do_sample": true,
  "temperature": 0.6,
  "top_p": 0.95,
  "eos_token_id": 151643
}
```

本轮评测参数与模型声明一致：

```text
mode=thinking
temperature=0.6
top_p=0.95
max_tokens=20000
```

`max_tokens=20000` 是本轮评测脚本显式固定的生成窗口，不是模型文件中的字段。服务端 `max_model_len=131072`，因此该窗口不会使请求的 prompt + output 超过服务上下文限制。

## Step 1：容器运行配置

实际推理容器配置：

```text
name: day0-light-r1-7b-ds
cmd: bash -lc 'sleep infinity'
network: host
ipc: host
shm-size: 64 GiB
devices: /dev/kfd, /dev/dri
security: seccomp=unconfined, label=disable
group: video
```

挂载：

```text
/public-flash/models -> /models      读写
/opt/hyhal           -> /opt/hyhal  只读
```

容器使用统一 Hygon 镜像；模型权重、tokenizer 和配置均来自 `/models/Light-R1-7B-DS`。

## Step 2：启动 vLLM 服务

实际 vLLM 进程命令：

```bash
/usr/bin/python3 /usr/local/bin/vllm serve /models/Light-R1-7B-DS \
  --served-model-name Light-R1-7B-DS \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 131072 \
  --gpu-memory-utilization 0.90 \
  --port 8003 \
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

export LD_LIBRARY_PATH=/opt/dtk/dcc/gcvm/lib:/opt/dtk/hip/lib:/opt/dtk/llvm/lib:/opt/dtk/lib:/opt/dtk/lib64:/opt/hyhal/lib:/opt/hyhal/lib64:/opt/dtk/dushmem/lib:/opt/dtk/opencl/lib:/opt/dtk/.hyhal/rocm_smi/lib:/usr/local/lib:/usr/local/lib64:/opt/mpi/lib

export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export HIP_VISIBLE_DEVICES=5
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
export FLAGGEMS_DB_URL=sqlite:///:memory:

export VLLM_FL_FLAGOS_WHITELIST=attention_backend
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_FL_OOT_ENABLED=0
```

配置含义：

```text
attention backend：vLLM native TRITON_ATTN
FlagGems attention：关闭
FL OOT：关闭
普通 FlagGems 算子白名单：不启用，仅保留 attention_backend 路由标识
prefix caching：开启（vLLM 默认，EngineCore 日志确认）
chunked prefill：开启（vLLM 默认，EngineCore 日志确认）
```

服务日志：

```text
/public-flash/models/day0_logs/Light-R1-7B-DS-serve-fix-whitelist-attn-oot-off-20260918-0048.log
```

健康检查：

```bash
curl http://127.0.0.1:8003/health
curl http://127.0.0.1:8003/v1/models
```

服务返回 HTTP `200`，模型名为 `Light-R1-7B-DS`，`max_model_len=131072`。

## Step 3：评测脚本和文件变更

本轮实际使用：

```text
/models/day0_eval/fast_gpqa_genconfig_fixed.py
```

该文件基于：

```text
/models/day0_eval/fast_gpqa.py
```

在构建 `generation_config` 后增加模型名映射。本模型对应项：

```python
"Light-R1-7B-DS": {
    "temperature": 0.6,
    "top_p": 0.95,
    "max_tokens": 20000,
}
```

完整差异、文件校验值、复现命令和运行时文件影响范围见：

[Light-R1-7B-DS 文件修改留档](file_fixes/Light-R1-7B-DS.md)

本轮未修改模型权重、模型配置、tokenizer、vLLM、vllm-plugin-FL 或 FlagGems 源码；服务行为通过环境变量和启动参数配置。

## Step 4：MATH-500 50 题评测

评测服务地址：

```text
http://127.0.0.1:8003/v1
```

等价评测命令：

```bash
/usr/bin/python3 /models/day0_eval/fast_gpqa_genconfig_fixed.py \
  --model-name Light-R1-7B-DS \
  --api-base http://127.0.0.1:8003/v1 \
  --api-key EMPTY \
  --dataset math_500 \
  --limit 10 \
  --eval-batch-size 4 \
  --skip-truncation-check \
  --output /models/day0_logs/accuracy/Light-R1-7B-DS-math500-50-fix-whitelist-attn-oot-off-b4-20260918-0051.json
```

MATH-500 的 `--limit 10` 按 subset 生效：

```text
Level 1--5 各 10 题，共 50 题
```

评测配置：

| 项目 | 值 |
|------|---|
| 数据集 / hub | `math_500` / ModelScope |
| subset | `Level 1` 至 `Level 5` |
| 题数 | `5 × 10 = 50` |
| few-shot | `0` |
| EvalScope | `1.5.1`，OpenAI API / Native |
| 模式 | `thinking` |
| `eval_batch_size` | `4` |
| `temperature` / `top_p` | `0.6` / `0.95` |
| `max_model_len` / `max_tokens` | `131072` / `20000` |
| `stream` / timeout / retries | `true` / `120000 ms` / `5` |
| seed | `42` |
| 截断探测 | `--skip-truncation-check`；结束后逐题审计 |
| 实际耗时 | `3120.36s`，约 52 分 0.4 秒 |

日志记录：

```text
Unified pool: 50 items to process, 0 already fully cached
```

说明 50 题全部重新生成，没有复用历史答案。

## Step 5：结果与质量审计

结果文件：

```text
/public-flash/models/day0_logs/accuracy/Light-R1-7B-DS-math500-50-fix-whitelist-attn-oot-off-b4-20260918-0051.json
/public-flash/models/day0_logs/accuracy/Light-R1-7B-DS-math500-50-fix-whitelist-attn-oot-off-b4-20260918-0051.log
/public-flash/models/day0_logs/accuracy/Light-R1-7B-DS-math500-50-fix-whitelist-attn-oot-off-b4-20260918-0051.exit
/public-flash/models/day0_logs/accuracy/Light-R1-7B-DS-math500-50-fix-whitelist-attn-oot-off-b4-20260918-0051.done
```

EvalScope 原始工作目录（宿主机持久挂载）：

```text
/public-flash/models/day0_eval/outputs/math_500/20260918_045356
```

分层结果：

| 难度 | 正确数 | 精度 |
|------|------:|-----:|
| Level 1 | `9/10` | `90%` |
| Level 2 | `9/10` | `90%` |
| Level 3 | `10/10` | `100%` |
| Level 4 | `9/10` | `90%` |
| Level 5 | `9/10` | `90%` |
| **总计** | **`46/50`** | **`92%`** |

结果摘要：

```json
{
  "model": "Light-R1-7B-DS",
  "benchmark": "math_500",
  "mode": "thinking",
  "score": 92.0,
  "evalscope_score": 92.0,
  "total_questions": 50,
  "eval_batch_size": 4,
  "max_tokens": 20000,
  "max_model_len": 131072,
  "temperature": 0.6,
  "eval_duration_seconds": 3120.36,
  "runaway_detection": {
    "checked": 50,
    "runaway_count": 0
  }
}
```

逐题审计：

- 5 个 Level 的 predictions 和 reviews 各 `10` 条，总计各 `50` 条；
- API error 为 `0`；
- 49 题以 `stop_reason=stop` 结束；
- Level 5 的 0-based 索引 `1` 达到 `max_tokens=20000`，其提取答案为 `4`、目标答案为 `4`，判分正确；
- runaway 内容检测为 `0/50`；
- 退出码 `0`，完成标记 `done=0`。

MATH-500 使用 EvalScope 数学答案等价判分，不适用 GPQA 的字母答案审计；JSON 中 `answer_extraction_audit.checked=0` 属正常行为。

## Step 6：NV 基线与判定

[项目 NV 基线](../../../flagrelease_eval_methods/nv_baseline.yaml)记录：

```yaml
Light-R1-7B-DS:
  metrics:
    mmlu: 69.95
    math_500: 94.0
  source: "NV 实测"
  updated_at: "2026-08-12"
```

| 项目 | 值 |
|------|---:|
| Hygon MATH-500 50 题 | `92.00%（46/50）` |
| NV MATH-500 记录值 | `94.00%` |
| 绝对差 | `-2` 个百分点 |
| 相对精度损失 | `(94-92)/94 = 2.13%` |
| 允许的最大相对精度损失 | `<5%` |
| 本轮判定 | **通过** |

NV 基线文件只提供记录分数，没有附 NV 侧逐题结果、抽样题目和完整推理参数。本结论是本轮 Hygon 50 题与仓库 NV 记录值的精度门限比较，不扩展到其他题数或性能指标。

## 当前结果

- 服务：GPU5、端口 `8003`、TP1、BF16，健康；
- 服务路径：native `TRITON_ATTN`，FlagGems attention 关闭，FL OOT 关闭；
- MATH-500 50 题：`46/50=92.00%`；
- NV 记录值：`94.00%`；
- 相对精度损失：`2.13%`；
- API error / runaway：`0 / 0`；
- 判定：本轮 50 题精度通过；
- 文件修改：见 [file_fixes/Light-R1-7B-DS.md](file_fixes/Light-R1-7B-DS.md)；
- 发布摘要：见 [reports/Light-R1-7B-DS_report.md](../reports/Light-R1-7B-DS_report.md)。

## 可复用规则

1. reasoning 模型先读取 `generation_config.json`，把采样参数来源和最终 API 参数同时落入日志。
2. 服务端算子路径与评测端采样参数分层固定；native attention、OOT、普通算子白名单不能用一个笼统的“FlagGems开关”描述。
3. MATH-500 的 `limit` 是 per-subset 语义，必须同时记录每个 Level 数量和总题数。
4. 即使 runaway 检测为 0，也要逐题扫描 `stop_reason`；达到输出上限但判对的题仍需保留事实记录。
5. 评测产物使用宿主机持久挂载目录，确保 predictions、reviews、TaskConfig 和报告可追溯。
