# Hygon/MiniCPM4.1-8B 适配与评测记录

- **日期**：`2026-09-20`
- **远端机器**：`10.232.2.33`
- **主机名**：`bm-srwl-nj-zone3-d-bw1000-64g-2-33`
- **模型来源**：`openbmb/MiniCPM4.1-8B`
- **本次处理结论**：沿用原有 Hygon 单卡服务，不修改权重或推理源码；在评测客户端显式补入特殊 token、固定 thinking 模式并将输出上限设置为 `32768`。独立生成的 GPQA Diamond 50 题得分 `68.00%（34/50）`，高于仓库 NV 基线 `54.00%`，本轮精度门限通过；其中 2 题达到输出上限，应继续保留逐题终止原因审计。

---

## 背景分析

MiniCPM4.1-8B 是混合推理模型；模型 `README.md` 在 vLLM Chat API 部分明确提醒：Chat API 默认不自动补特殊 token，客户端应传 `add_special_tokens=True`；其 vLLM 示例使用 `temperature=0.6`、`top_p=0.95`、`max_tokens=32768`。模型的 `generation_config.json` 则提供通用采样值 `temperature=0.8`、`top_p=0.8`，两者不能混为同一套评测口径。

统一评测脚本把 MiniCPM4.1 识别为 thinking 模型，并使用通用保护值 `THINKING_MAX_TOKENS_CAP=20000`。此前同一 50 题、`temperature=0.6`、`top_p=0.95` 的一轮结果为 `48.00%（24/50）`：其中 11 题达到 20000 token 上限，11 题均判错。这个模型的长推理行为说明通用 20000 上限会截断部分正常回答。

本轮只修改评测请求和评测进程环境，保持服务侧不变：

1. 在 `extra_body` 中传 `add_special_tokens=True`，补入模型所需的特殊 token；
2. 显式传 `chat_template_kwargs={"enable_thinking": True}`，锁定推理模式；旧轮也依赖模板默认 thinking，此项不能单独解释提分；
3. 保留原有较好的 `temperature=0.6`、`top_p=0.95`；
4. 将本模型单次生成上限从统一 cap `20000` 覆盖为 `32768`；
5. 评测进程临时补齐 DTK 动态库搜索路径，使 PyTorch/EvalScope 能导入。

两轮 50 题的题干和标准答案逐题一致；新轮 14 题由错变对、4 题由对变错，净增 10 题。其中旧轮 11 道截断题在新轮有 10 题自然停止、8 题答对。本轮同时更改输入 token 和输出上限，不能将全部提升归因于单一参数。

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `bm-srwl-nj-zone3-d-bw1000-64g-2-33` / `10.232.2.33` |
| 芯片 | Hygon DCU BW1000，8 × 64GB |
| 推理容器 | `day0-minicpm4-1-8b` |
| 评测容器 | `day0-eval-standard` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4` |
| 镜像 ID | `sha256:b4dd95d30aa8213e0721856672ee544e773c51216b3737c12069b32ad71d07a0` |
| vLLM / EvalScope | `0.24.0` / `1.5.1` |
| 模型宿主机路径 | `/public-flash/models/MiniCPM4.1-8B` |
| 模型容器路径 | `/models/MiniCPM4.1-8B` |
| 设备 | `HIP_VISIBLE_DEVICES=4` |
| Tensor Parallel / dtype | `1` / `bfloat16` |
| 服务端口 | `8002` |
| 注意力后端 | `TRITON_ATTN` |

## Step 0：模型配置核验

模型 `config.json`：

```json
{
  "architectures": ["MiniCPMForCausalLM"],
  "model_type": "minicpm",
  "torch_dtype": "bfloat16",
  "max_position_embeddings": 65536
}
```

模型 `generation_config.json` 的相关字段：

```json
{
  "do_sample": true,
  "temperature": 0.8,
  "top_p": 0.8,
  "eos_token_id": [2, 73440]
}
```

本轮不是照搬 `0.8/0.8`：`temperature=0.6`、`top_p=0.95` 来自此前较好的 thinking 评测口径，也与本模型 README 中的 vLLM 示例一致。`32768` 是本轮对评测客户端的显式模型专用覆盖，不是 `generation_config.json` 中的 `max_tokens`。

tokenizer 的 chat template 在没有 `/no_think` 或 `enable_thinking=False` 时默认进入思考模式。本轮显式传 `enable_thinking=True` 固定模式；服务端 reasoning parser 仍为空，没有修改模型模板。

## Step 1：容器运行配置

实际推理容器为常驻 `sleep infinity`，使用 `host` 网络、`host` IPC、64 GiB 共享内存：

```text
/public-flash/models -> /models      读写
/opt/hyhal           -> /opt/hyhal  只读
```

评测结果 JSON 和日志位于共享挂载 `/public-flash/models/day0_logs`；EvalScope 的完整逐题输出却位于评测容器的 `/root/outputs`（见后文），两者保存周期不同。

## Step 2：启动 vLLM 服务

本轮复用的实际服务进程命令：

```bash
/usr/bin/python3 /usr/local/bin/vllm serve /models/MiniCPM4.1-8B \
  --served-model-name MiniCPM4.1-8B \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 65536 \
  --gpu-memory-utilization 0.90 \
  --port 8002 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code
```

关键运行环境（从服务进程读取）：

```bash
export DTK_HOME=/opt/dtk
export ROCM_PATH=/opt/dtk
export HIP_PATH=/opt/dtk/hip
export HSA_PATH=/opt/dtk/hsa
export DEVICE_LIB_PATH=/opt/dtk/amdgcn/bitcode
export TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18
export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export HIP_VISIBLE_DEVICES=4
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
export VLLM_FL_TRITON_CACHE_ROOT=/models/triton_cache/MiniCPM4.1-8B
mkdir -p "$VLLM_FL_TRITON_CACHE_ROOT"
export VLLM_FL_FLAGOS_WHITELIST=add,arange,argmax,broadcast_to,copy,cos,cumsum,div,expand,index,le,lt,masked_fill,rand_like,randn,reciprocal,rsub,scatter,sin,softmax,sub,sum,to,where
```

服务进程没有显式设置 `VLLM_FL_OOT_ENABLED` 等 OOT 开关，不能在复现时擅自把它们当作本轮固定值。EngineCore 初始化日志确认 `enable_prefix_caching=True`、`enable_chunked_prefill=True`、`enforce_eager=True`、`max_seq_len=65536`。

服务日志：

```text
/public-flash/models/day0_logs/MiniCPM4.1-8B-serve-20260914-174041-exact-md-final.log
```

本轮未重启该服务，未修改镜像、vLLM/plugin-FL/FlagGems 源码或模型文件。

## Step 3：评测入口与运行环境

本轮从本机 `/tmp/minicpm41_full50_fixed.py` 经标准输入执行，导入评测容器已有的 `/models/day0_eval/fast_gpqa.py`；完整评测入口和文件影响范围见 [file_fixes/MiniCPM4.1-8B.md](file_fixes/MiniCPM4.1-8B.md)。

模型专用覆盖内容：

```python
# 仅对 MiniCPM4.1-8B：
max_tokens = 32768
generation_config = {
    "max_tokens": 32768,
    "temperature": 0.6,
    "top_p": 0.95,
    "extra_body": {
        "add_special_tokens": True,
        "chat_template_kwargs": {"enable_thinking": True},
    },
}
```

此处是关键参数摘要，不是可直接替换统一脚本的完整补丁；实际入口只更新原脚本构建的配置，其余生成与判分逻辑保持原样。

评测容器的默认 `LD_LIBRARY_PATH` 不含 DTK 运行库，导入 EvalScope 会牵连 PyTorch 依赖失败。本轮只在评测进程临时加入 DTK 的 `hip/lib`、`lib`、`.hyhal/hsa/lib`、`.hyhal/rocm_smi/lib` 等路径；验证可导入 `torch 2.10.0`、`evalscope 1.5.1`，未安装包或修改镜像。

## Step 4：GPQA Diamond 50 题评测

评测服务地址：`http://127.0.0.1:8002/v1`。评测参数：

| 项目 | 值 |
|------|---|
| 数据集 / hub | `gpqa_diamond` / ModelScope |
| 题数 / split | `50` / `train`（`default` subset） |
| few-shot | `0` |
| EvalScope | `1.5.1`，OpenAI API / Native |
| 模式 | `thinking`，保留 `</think>` 过滤 |
| `eval_batch_size` | `4`（固定并发） |
| `temperature` / `top_p` | `0.6` / `0.95` |
| `max_model_len` / `max_tokens` | `65536` / `32768` |
| `extra_body` | `add_special_tokens=True`，`chat_template_kwargs.enable_thinking=True` |
| `stream` / timeout / retries | `true` / `120000 ms` / `5` |
| seed | `42` |
| 截断探测 | 显式 `--skip-truncation-check`；事后逐题审计结束原因 |
| 实际耗时 | `22627.56s`，约 6 小时 17 分 8 秒 |

当时的评测入口参数（入口源码见 file_fixes；没有 `--max-tokens` CLI 选项）：

```bash
/usr/bin/python3 - \
  --model-name MiniCPM4.1-8B \
  --api-base http://127.0.0.1:8002/v1 \
  --api-key EMPTY \
  --dataset gpqa_diamond \
  --limit 50 \
  --eval-batch-size 4 \
  --skip-truncation-check \
  --output /models/day0_logs/accuracy/MiniCPM4.1-8B-gpqa50-fixed-thinking-20260920-env.json
```

评测日志核对：最终 `generation_config` 含 `max_tokens=32768`、`top_p=0.95`、`temperature=0.6` 和完整 `extra_body`；`Unified pool: 50 items to process, 0 already fully cached`，不是复用历史答案。

结果文件：

```text
/public-flash/models/day0_logs/accuracy/MiniCPM4.1-8B-gpqa50-fixed-thinking-20260920-env.json
/public-flash/models/day0_logs/accuracy/MiniCPM4.1-8B-gpqa50-fixed-thinking-20260920-env.log
/public-flash/models/day0_logs/accuracy/MiniCPM4.1-8B-gpqa50-fixed-thinking-20260920-env.exit
/public-flash/models/day0_logs/accuracy/MiniCPM4.1-8B-gpqa50-fixed-thinking-20260920-env.done
```

逐题预测、review、TaskConfig 和 HTML 报告：

```text
day0-eval-standard 容器内:
/root/outputs/gpqa_diamond/20260920_065338
```

注意：`/root/outputs` 位于容器可写层，**不是** `/public-flash/models/day0_eval/outputs`；删除评测容器前需另行导出逐题产物。本次没有搬运或改写该工作目录。

## Step 5：结果与质量审计

```json
{
  "model": "MiniCPM4.1-8B",
  "benchmark": "gpqa_diamond",
  "mode": "thinking",
  "score": 68.0,
  "evalscope_score": 68.0,
  "total_questions": 50,
  "eval_batch_size": 4,
  "max_model_len": 65536,
  "max_tokens": 32768,
  "temperature": 0.6,
  "eval_duration_seconds": 22627.56,
  "runaway_detection": {
    "checked": 50,
    "runaway_count": 0
  },
  "answer_extraction_audit": {
    "checked": 50,
    "explicit_answer_found": 48,
    "fallback_to_evalscope": 1,
    "format_corrected_score": 68.0,
    "parser_mismatch_count": 0,
    "invalid_evalscope_extract_count": 1
  }
}
```

- 评测退出码 `0`，`done` 标记 `run=0`；
- predictions 与 reviews 各 `50` 条，索引各 `50` 个且唯一；API error `0`；
- `stop_reason=stop` 为 `48` 题；索引 `12`、`22` 两题达到 `max_tokens=32768`，均判错；
- runaway 内容检测 `0/50`；该统计不等价于“没有长度截断”；
- EvalScope 原始分与答案提取校正分均为 `68.00%`，即 `34/50`。

## Step 6：NV 基线与判定

[项目 NV 基线](../../../flagrelease_eval_methods/nv_baseline.yaml)记录：

```yaml
MiniCPM4.1-8B:
  metrics:
    gpqa_diamond: 54
  source: "NV 实测"
  updated_at: "2026-07-17"
```

| 项目 | 值 |
|------|---:|
| Hygon 50 题 | `68.00%（34/50）` |
| NV 记录值 | `54.00%` |
| 绝对差 | `+14` 个百分点 |
| 相对差 | `(68-54)/54 = +25.93%` |
| 精度门限 | 相对 NV 损失 `<5%` |
| 本轮判定 | **精度通过** |

NV 基线文件未附原始 NV 题目、prompt、采样参数和逐题预测；这里是与仓库 NV **记录分数**的比较，不声称完成逐题同源复核。本次是新生成的单轮 50 题，不是将旧50题与局部重试结果拼接；性能与多轮精度稳定性本次未单独验收。

## 当前结果

- 服务：原有 Hygon GPU4 单卡、端口 `8002`，未重启；
- 评测：50 题完整、`34/50=68.00%`，NV 记录 `54.00%`；
- 质量：runaway `0`，API error `0`，仍有 2 题以长度上限结束；
- 判定：本轮 GPQA 50 题精度通过；
- 完整脚本：见 [评测入口与文件变更留档](file_fixes/MiniCPM4.1-8B.md)；
- 发布摘要：见 [评测结果报告](../reports/MiniCPM4.1-8B_report.md)。

## 可复用规则

1. 先分清 `generation_config.json` 的通用采样值、模型 README 的评测/推理建议和客户端最终发给 vLLM 的实际参数。
2. thinking 通用 `max_tokens` cap 只是成本保护；每个模型都要按逐题 `stop_reason` 证实是否截断了正常推理。
3. Chat API 的 `add_special_tokens` 依赖模型模板与 vLLM 默认值；通过 EvalScope `extra_body` 明确传入并在 TaskConfig 中核验。
4. 评测日志记录 `0 already cached`、采样参数来源、特殊 token 开关；报告同时给出逐题结束原因、错误数、正确题数和 NV 基线来源。
5. 对需要长期审计的任务，提前将 EvalScope `work_dir` 配到持久挂载，不要把容器 `/root/outputs` 误认作宿主机存储。
