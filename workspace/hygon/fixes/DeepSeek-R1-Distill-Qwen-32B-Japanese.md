# Hygon/DeepSeek-R1-Distill-Qwen-32B-Japanese 适配与评测记录

- **日期**：`2026-09-18`
- **远端机器**：`10.232.2.33`
- **主机名**：`bm-srwl-nj-zone3-d-bw1000-64g-2-33`
- **模型来源**：`cyberagent/DeepSeek-R1-Distill-Qwen-32B-Japanese`
- **历史问题类型**：按普通模型使用贪心解码和较短生成上限时精度不达标，并出现重复输出撞 `max_tokens`
- **本次处理结论**：使用 Hygon 新镜像、4 卡 TP 部署，服务侧关闭 prefix cache、chunked prefill、FlagGems attention 和 OOT；评测侧按模型 `generation_config.json` 使用 thinking 采样参数 `temperature=0.6`、`top_p=0.95`，并固定 `max_tokens=16384`。GPQA Diamond 50 题得分 `66.00%（33/50）`，高于 NV 基线 `62.00%`，绝对提升 `4` 个百分点，相对提升约 `6.45%`，按 NV 相对退化不超过 5% 的门限通过

- **2026-09-20 追加验证**：恢复上述同一服务配置后，仅将评测并发由 2 调到 8，50 题得到 `72.00%（36/50）`，耗时 `7464.34s`（约 2h 04m 24s），相对原 `24982.68s` 加速 `3.35×`；比 NV `62%` 高 10 个百分点，仍通过。采样解码的单轮分数波动不能解释为并发提升模型精度，详见下方独立复测记录。

---

## 背景分析

该模型是 DeepSeek-R1 蒸馏得到的 reasoning 模型，模型自身 `generation_config.json` 明确声明：

```json
{
  "do_sample": true,
  "temperature": 0.6,
  "top_p": 0.95
}
```

初始评测按普通模型口径使用 `temperature=0.0`、`max_tokens=4096`，GPQA Diamond 50 题只有 `38.00%`。逐题输出扫描发现 5 道题出现高重复、强可压缩输出，并以 `finish_reason=max_tokens` 结束，因此该结果被生成参数和 runaway 污染，不能代表模型正常 reasoning 精度。

修正后的评测同时固定三类变量：

1. 按 thinking 模型处理，保留思维链生成并在判分前按 `</think>` 过滤；
2. 使用模型声明的 `temperature=0.6`、`top_p=0.95`；
3. 将生成上限提高到 `16384`，避免正常思维链被 `4096` 截断，同时限制极端 runaway 成本。

最终 50 题得分 `66.00%`，未检测到 runaway，50 题均提取到显式答案，EvalScope 原始得分与答案审计得分一致。

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `bm-srwl-nj-zone3-d-bw1000-64g-2-33` / `10.232.2.33` |
| 芯片 | Hygon DCU BW1000，8 × 64GB |
| 推理容器 | `day0-deepseek-r1-distill-qwen-32b-japanese` |
| 评测容器 | `day0-eval-standard` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4` |
| 镜像 ID | `sha256:b4dd95d30aa8213e0721856672ee544e773c51216b3737c12069b32ad71d07a0` |
| vLLM | `0.24.0`（服务初始化日志确认） |
| EvalScope | `1.5.1` |
| 模型宿主机路径 | `/public-flash/models/DeepSeek-R1-Distill-Qwen-32B-Japanese` |
| 模型容器路径 | `/models/DeepSeek-R1-Distill-Qwen-32B-Japanese` |
| GPU | `HIP_VISIBLE_DEVICES=0,1,2,3` |
| Tensor Parallel | `4` |
| 服务端口 | `8005` |
| dtype | `bfloat16` |

## Step 0：模型配置核验

模型 `config.json` 中与本轮相关的字段：

```json
{
  "model_type": "qwen2",
  "torch_dtype": "bfloat16",
  "max_position_embeddings": 131072
}
```

模型 `generation_config.json`：

```json
{
  "_from_model_config": true,
  "bos_token_id": 151646,
  "do_sample": true,
  "eos_token_id": 151643,
  "temperature": 0.6,
  "top_p": 0.95,
  "transformers_version": "4.47.0"
}
```

模型配置支持 131072 位置长度，但本轮 vLLM 服务显式限制为 `max_model_len=32768`。因此本记录只证明 32K 服务配置下的 GPQA 精度通过，不代表 128K 长上下文能力已经验证。

## Step 1：容器运行配置

推理容器使用常驻进程保持运行，vLLM 通过 `docker exec` 在容器内启动：

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
label=disable
group-add=video
```

挂载：

```text
/public-flash/models -> /models      读写
/opt/hyhal           -> /opt/hyhal  只读
```

评测容器使用同一镜像和 host 网络，挂载：

```text
/public-flash/models/day0_eval -> /models/day0_eval
/public-flash/models/day0_logs -> /models/day0_logs
```

## Step 2：启动 vLLM 服务

实际 vLLM 进程命令：

```bash
/usr/bin/python3 /usr/local/bin/vllm serve /models/DeepSeek-R1-Distill-Qwen-32B-Japanese \
  --served-model-name DeepSeek-R1-Distill-Qwen-32B-Japanese \
  --dtype bfloat16 \
  --tensor-parallel-size 4 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.90 \
  --port 8005 \
  --attention-backend TRITON_ATTN \
  --no-enable-prefix-caching \
  --no-enable-chunked-prefill \
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
export HIP_VISIBLE_DEVICES=0,1,2,3
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200

export FLAGGEMS_DB_URL=sqlite:///:memory:
export VLLM_FL_TRITON_CACHE_ROOT=/models/day0_logs/triton_cache/DeepSeek-R1-Distill-Qwen-32B-Japanese
export VLLM_FL_FLAGOS_WHITELIST=attention_backend
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_FL_OOT_ENABLED=0
export VLLM_FL_OOT_BLACKLIST=addmm,broadcast_to,copy
```

与精度和稳定性直接相关的开关：

```text
prefix caching：关闭
chunked prefill：关闭
FlagGems attention：关闭
OOT：关闭
attention backend：TRITON_ATTN
执行模式：eager
```

虽然设置了 `VLLM_FL_OOT_BLACKLIST`，但本轮同时设置 `VLLM_FL_OOT_ENABLED=0`，所以 OOT 整体未启用；不能把本轮结果解释为只禁用了 blacklist 中的三个算子。

EngineCore 初始化日志确认：

```text
vLLM=0.24.0
dtype=torch.bfloat16
max_seq_len=32768
tensor_parallel_size=4
enforce_eager=True
enable_prefix_caching=False
enable_chunked_prefill=False
served_model_name=DeepSeek-R1-Distill-Qwen-32B-Japanese
GPU KV cache size=621440 tokens
32K 请求理论最大并发=18.96x
```

服务日志：

```text
/public-flash/models/day0_logs/DeepSeek-R1-Distill-Qwen-32B-Japanese-serve-20260917-gpu0-3.log
```

健康检查：

```bash
curl http://127.0.0.1:8005/health
curl http://127.0.0.1:8005/v1/models
```

## Step 3：评测脚本和生成参数修复

本轮实际使用的评测脚本：

```text
/models/day0_eval/fast_gpqa_genconfig_fixed.py
```

从远端评测容器只读导出的完整脚本已嵌入 [file_fixes/DeepSeek-R1-Distill-Qwen-32B-Japanese.md](file_fixes/DeepSeek-R1-Distill-Qwen-32B-Japanese.md)。该文档保留完整评测流程代码，不是仅含修改片段。

该脚本基于统一评测脚本 `/models/day0_eval/fast_gpqa.py`。专用脚本通过模型名映射固定本模型参数：

```python
_GEN_OVERRIDES = {
    "DeepSeek-R1-Distill-Qwen-32B-Japanese": {
        "temperature": 0.6,
        "top_p": 0.95,
        "max_tokens": 16384,
    },
}
```

只读比对远端 `day0-eval-standard` 中 `/models/day0_eval/fast_gpqa.py` 与 `fast_gpqa_genconfig_fixed.py` 后确认：修改插在 `run_eval` 构建 `gen_config = resolve_gen_params(is_thinking, max_tokens, model_path=model_name)` 之后、构建 `dataset_args` 之前。专用脚本实际包含如下逻辑（映射表还包含 MiniCPM4.1 和 Light-R1；此处保留全部键，以免复现时误认为只改了本模型）：

```python
_model_key = str(model_name).split('/')[-1]
_GEN_OVERRIDES = {
    'MiniCPM4-8B': {'temperature': 0.8, 'top_p': 0.8},
    'MiniCPM4.1-8B': {'temperature': 0.8, 'top_p': 0.8},
    'DeepSeek-R1-Distill-Qwen-32B-Japanese': {'temperature': 0.6, 'top_p': 0.95, 'max_tokens': 16384},
    'Light-R1-7B-DS': {'temperature': 0.6, 'top_p': 0.95, 'max_tokens': 20000},
}
if _model_key in _GEN_OVERRIDES:
    for _k, _v in _GEN_OVERRIDES[_model_key].items():
        if _k == 'max_tokens':
            max_tokens = int(_v)
        gen_config[_k] = _v
    print(f"  [gen] applied embedded model config for {_model_key}: temperature={gen_config.get('temperature')}, top_p={gen_config.get('top_p')}, max_tokens={gen_config.get('max_tokens')}")
```

`max_tokens` 同时更新局部变量和 `gen_config`；只改字典或只改 CLI 参数都不能复现该脚本行为。远端 `diff -u` 显示专用脚本相对原脚本仅增加这一段；`remove_until: </think>` 属于原脚本已有的 thinking 模式逻辑，不是这次新增的代码。

thinking 模型同时应用 EvalScope 过滤：

```python
dataset_args[dataset]["filters"] = {
    "remove_until": "</think>",
}
```

评测日志确认最终生效配置：

```text
mode=thinking
temperature=0.6
top_p=0.95
max_tokens=16384
stream=true
timeout=120000
eval_batch_size=2
```

模型目录本身未被修改，vLLM、vllm-plugin-FL 和 FlagGems 源码也未被修改；生成参数修复位于专用评测脚本中。

## Step 4：执行评测

评测服务地址：`http://127.0.0.1:8005/v1`

实际命令的等价形式：

```bash
python3 /models/day0_eval/fast_gpqa_genconfig_fixed.py \
  --model-name DeepSeek-R1-Distill-Qwen-32B-Japanese \
  --api-base http://127.0.0.1:8005/v1 \
  --api-key EMPTY \
  --dataset gpqa_diamond \
  --limit 50 \
  --eval-batch-size 2 \
  --skip-truncation-check \
  --output /models/day0_logs/accuracy/DeepSeek-R1-Distill-Qwen-32B-Japanese-gpqa50-genconfig-fixed-20260918-0002.json
```

说明：脚本没有 `--max-tokens` CLI 参数，`16384` 来自脚本中的模型专用 `_GEN_OVERRIDES`，不能在复现命令中虚构 `--max-tokens 16384` 参数。

评测配置：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.5.1` |
| 题数 | 50 |
| few-shot | 0 |
| 模式 | `thinking` |
| `eval_batch_size` | 2 |
| `temperature` | 0.6 |
| `top_p` | 0.95 |
| `max_tokens` | 16384 |
| `max_model_len` | 32768 |
| seed | 42 |
| 截断检测 | 通过 `--skip-truncation-check` 显式跳过 |
| 评测耗时 | `24982.68s`，约 6h 56m 22.7s |

结果文件：

```text
/public-flash/models/day0_logs/accuracy/DeepSeek-R1-Distill-Qwen-32B-Japanese-gpqa50-genconfig-fixed-20260918-0002.json
```

EvalScope 原始输出：

```text
/public-flash/models/day0_eval/outputs/gpqa_diamond/20260918_041948
```

结果摘要：

```json
{
  "model": "DeepSeek-R1-Distill-Qwen-32B-Japanese",
  "benchmark": "gpqa_diamond",
  "mode": "thinking",
  "score": 66.0,
  "evalscope_score": 66.0,
  "total_questions": 50,
  "eval_batch_size": 2,
  "max_tokens": 16384,
  "max_model_len": 32768,
  "temperature": 0.6,
  "eval_duration_seconds": 24982.68,
  "runaway_detection": {
    "checked": 50,
    "runaway_count": 0
  },
  "answer_extraction_audit": {
    "checked": 50,
    "explicit_answer_found": 50,
    "fallback_to_evalscope": 0,
    "format_corrected_score": 66.0,
    "parser_mismatch_count": 0,
    "invalid_evalscope_extract_count": 0
  }
}
```

## Step 5：NVIDIA 基线对比和通过判定

NV 基线文件：`/public-flash/models/day0_eval/nv_baseline.yaml`

```yaml
DeepSeek-R1-Distill-Qwen-32B-Japanese:
  aliases:
    - cyberagent/DeepSeek-R1-Distill-Qwen-32B-Japanese
    - deepseek-r1-distill-qwen-32b-japanese
    - deepseek_r1_distill_qwen_32b_japanese
  metrics:
    gpqa_diamond: 62
  source: "NV 实测"
  updated_at: "2026-08-05"
```

项目判据：

```text
(current_score - nv_score) / nv_score >= -0.05
```

| 项目 | 值 |
|------|---:|
| Hygon 当前结果 | `66.00%` |
| NV 基线 | `62.00%` |
| 绝对差 | `+4.00` 个百分点 |
| 50 题折算差异 | `+2` 题 |
| 相对变化 | `+6.45%` |
| 允许的最大相对退化 | `-5.00%` |
| 判定 | **通过** |

> DeepSeek-R1-Distill-Qwen-32B-Japanese 在 FlagOS/Hygon 上的 thinking 模式 GPQA-Diamond 评测通过 NVIDIA 基线，精度没有退化，反而高于 NV 基线。

当前为 50 题抽样结果。NV 基线文件记录了分数和来源，但没有保存完整 NV 运行参数；如果用于严格发布验收，仍应确认 NV 侧题目子集、prompt、采样参数和 EvalScope 版本与本轮完全一致。

## 现象

- 服务在 4 张 Hygon DCU 上以 TP4 正常启动；
- 普通贪心评测为 `38.00%`，明显低于 NV `62.00%`；
- 普通评测中 5/50 道题出现高重复并撞 `max_tokens=4096`；
- 改为模型声明的 thinking 采样参数后得分升至 `66.00%`；
- 最终评测 50/50 道题均输出显式答案，无 parser mismatch，无 invalid extract；
- 最终评测未检测到 runaway；
- 单轮 50 题耗时接近 7 小时，reasoning 输出成本较高。

## 定位

本轮主要不是模型权重、vLLM kernel 或答案解析错误，而是评测生成口径错误：reasoning 模型被按普通模型使用贪心解码和 4096 token 上限，导致思维链重复、撞生成上限并损失精度。

服务侧同时使用了一组保守配置：关闭 prefix cache、chunked prefill、FlagGems attention 和 OOT，并采用 eager 模式。当前结果证明的是这组完整配置能够通过，不能在没有消融测试的情况下声称其中任一开关单独决定了精度提升。

## 处置

1. 保持模型权重和服务框架源码不变；
2. 使用 4 卡 TP、BF16、`TRITON_ATTN` 和 eager 模式启动服务；
3. 关闭 prefix cache 和 chunked prefill；
4. 设置 `VLLM_FL_USE_FLAGGEMS_ATTN=0`、`VLLM_FL_OOT_ENABLED=0`；
5. 评测脚本按模型名固定 `temperature=0.6`、`top_p=0.95`、`max_tokens=16384`；
6. thinking 输出在判分前使用 `remove_until: </think>`；
7. 固定并发为 2，执行 GPQA Diamond 50 题；
8. 保存 EvalScope 原始报告、答案抽取审计和 runaway 扫描结果；
9. 与 NV `62.00%` 基线按 5% 相对退化门限比较，最终判定通过。

## 追加复测：旧最优服务 + eval_batch_size=8（2026-09-20）

先试验的另一套配置（prefix cache 开启、去掉 `--enforce-eager`、`gpu-memory-utilization=0.75`）虽在 `3858.66s` 完成 50 题，但仅得 `54%`，低于 NV 基线；`0.90/0.85` 在非 eager 图捕获阶段发生 HIP OOM。这是**不同服务配置**，不得将其速度或分数归因于评测并发。随后停止该服务并恢复本文件 Step 2 的已通过配置：TP4、GPU 0–3、`gpu-memory-utilization=0.90`、`--enforce-eager`、`--no-enable-prefix-caching`、`--no-enable-chunked-prefill`，其余环境变量不变。服务日志确认 `enforce_eager=True`、`enable_prefix_caching=False`、`enable_chunked_prefill=False`，KV cache 为 621440 tokens。

仅将 Step 4 的评测命令改为 `--eval-batch-size 8`，继续使用同一 `fast_gpqa_genconfig_fixed.py`、`temperature=0.6`、`top_p=0.95`、`max_tokens=16384`、GPQA Diamond 50 题及 `--skip-truncation-check`。本轮未修改模型、vLLM、插件或评测脚本源码；新日志与结果独立保存：

```bash
python3 /models/day0_eval/fast_gpqa_genconfig_fixed.py \
  --model-name DeepSeek-R1-Distill-Qwen-32B-Japanese \
  --api-base http://127.0.0.1:8005/v1 --api-key EMPTY \
  --dataset gpqa_diamond --limit 50 --eval-batch-size 8 \
  --skip-truncation-check \
  --output /models/day0_logs/accuracy/DeepSeek-R1-Distill-Qwen-32B-Japanese-gpqa50-best-batch8-20260920-04.json
```

| 指标 | 原 batch=2 | 本轮 batch=8 |
|------|---:|---:|
| GPQA Diamond | 66%（33/50） | **72%（36/50）** |
| NV 基线 | 62% | 62% |
| 用时 | 24982.68s | 7464.34s（约 2h 04m） |
| 相对原轮加速 | — | **3.35×** |
| runaway | 0 | 0 |
| 显式答案 / 解析差异 | 50/50、0 | 50/50、0 |
| 截断探测 | 跳过 | 跳过 |

本轮 `exit=0`，EvalScope 原始分与答案审计分均为 `72%`；运行中曾观测到 8 个请求同时执行、0 排队，没有容量错误。结果和日志分别为同名 `.json`、`.log`、`.exit`，宿主机目录 `/public-flash/models/day0_logs/accuracy/`；EvalScope 原始工作目录为 `outputs/gpqa_diamond/20260920_102140`。**72% 是本轮抽样观测值，不是并发提高带来的确定性精度增益**；NV 基线未附同口径逐题记录，尚不能断言严格逐题对齐。

## 通用经验

### 1. reasoning 模型不能默认套用普通模型贪心参数

模型适配流程必须优先读取 `generation_config.json` 中的 `do_sample`、`temperature`、`top_p`、`top_k` 和 `repetition_penalty`。如果模型明确声明 `do_sample=true`，评测脚本不应无依据地强制 `temperature=0.0`。

### 2. 精度异常必须同时审计输出形态

仅看最终正确率无法区分模型能力退化和生成异常。统一评测流程至少应记录 `finish_reason`、输出 token 数、重复度/压缩率、显式答案提取率、parser mismatch 和 invalid extract。

### 3. 生成上限需要兼顾正常思维链和 runaway 成本

`4096` 对本模型过短，而直接放到接近上下文上限又会放大异常输出成本。本轮 `16384` 在 32K 服务窗口下获得了可用结果，但该值是本模型实测配置，不应直接复制给所有 reasoning 模型。

### 4. 通过结论必须绑定完整配置

本轮通过结论绑定以下组合：

```text
镜像 + 环境变量 + TP4 + 32K + eager
+ prefix cache off + chunked prefill off
+ FlagGems attention off + OOT off
+ thinking generation config + EvalScope 1.5.1
```

更改任一关键项后都应重新评测，不能沿用原通过结论。

### 5. 发布验收应区分抽样通过和全量通过

当前为固定 seed 下的 50 题抽样结果。若发布门禁要求更强统计可信度，应使用同口径完成 GPQA Diamond 全量 198 题，并保存 NV 与国产芯片两侧完全一致的运行配置。
