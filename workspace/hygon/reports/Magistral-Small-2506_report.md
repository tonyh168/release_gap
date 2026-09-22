# hygon/Magistral-Small-2506 修复日志

- **失败报告**：flagrelease_fail_reports/Hygon/FAILED_Hygon_Magistral-Small-2506_202607311737.md
- **原始失败类型**：精度不达标（长输出与 runaway）
- **日期**：2026-09-18

## 现象

- 本模型是 reasoning 模型，模型卡推荐采样解码而不是普通模型贪心解码。初始按普通模型处理、使用 `temperature=0.0`，结果显著偏低并出现多道长重复输出：
  - 普通模型贪心口径：约 `48.00%`
  - 服务侧优化后普通口径：约 `54.00%`
  - 初始异常：`7/50` 题高重复并撞 `max_tokens`
  - NV 参考值：`62.00%`

- 旧栈失败报告同样记录精度不达标（V2 50 题 `48.0%`、V3 198 题 `46.97%`，NV 基线 `62.0%`，rel_drop 均超 5%），并提交了 plugin-FL error issue。
- 本轮 TP2 服务本身正常：端口 `8001` 返回 HTTP `200`；修复后 GPQA Diamond 50 题首轮 `62.00%`，与 NV `62.00%` 持平，评测耗时 `4469.97s`（约 74m 30.0s）。

## 定位

- **评测模式错配是主因**：reasoning 模型按普通贪心口径评测会系统性低估结果，本模型在 Hygon 上已实测证明这一点（约 48% vs 62%）。模型目录 `generation_config.json` 只提供 token 配置，**没有** `temperature` / `top_p` / `top_k`；不能把“配置缺 temperature”解释成“应该用 `temperature=0.0`”，而应按模型卡推荐参数评测。
- **服务侧还有可修的数值路径因素**：关闭 prefix cache / chunked prefill，并让核心 Mistral 算子（`silu_and_mul` / `rms_norm` / `rotary_embedding`）避开普通 FlagGems 替换路径后，普通贪心口径也能从约 `48.00%` 抬到约 `54.00%`。
- **生成窗口必须收窄**：`max_model_len=40960` 会让异常复读吃满 2 万～3 万 token；GPQA 只需要选择题答案，因此显式设 `max_tokens=4096`，既限制复读成本又给正常 reasoning 链留足输出空间。
- **本模型不能用“全关算子”或统一白名单解释**：普通 FlagGems 白名单保持历史 26 项，但核心 Mistral/Qwen 类算子不在其中；该选择是 Magistral 的消融结果，不应直接套用到 Qwen 等其他模型。

## 处置

宿主机 `bm-srwl-nj-zone3-d-bw1000-64g-2-21`（`10.232.2.21`），推理容器 `flagrelease-magistral-small-2506`，评测容器 `flagrelease-model-download-20260917`，端口 `8001`，`HIP_VISIBLE_DEVICES=2,3`，TP=2，bf16。模型 `/public-flash/models/flagrelease/fixes_models/Magistral-Small-2506` → 容器内 `/models/flagrelease/fixes_models/Magistral-Small-2506`。本轮未重新构建/推送镜像，也未修改 vLLM、`vllm-plugin-FL`、FlagGems 源码。

模型配置核验：

```json
{
  "torch_dtype": "bfloat16",
  "max_position_embeddings": 40960,
  "model_type": "mistral"
}
```

`generation_config.json` 主要只有 token 配置，未明确提供 `temperature` / `top_p` / `top_k`，因此采用模型卡推荐的 reasoning 生成参数 `temperature=0.7`、`top_p=0.95`。

**服务侧与生成模式消融**

| 配置 | 结果 |
|------|-----:|
| 普通模型、`temperature=0.0` | 约 `48.00%` |
| 服务侧优化后、普通贪心口径 | 约 `54.00%` |
| thinking 模式、`temperature=0.7`、核心算子避开 FlagGems | 10 题约 `70.00%` |
| thinking 模式、完整 50 题 | `62.00%`（最终采用） |

服务侧最终采用：`--no-enable-prefix-caching`、`--no-enable-chunked-prefill`、核心算子不加入普通 FlagGems 白名单（走 reference/native 路径）。

评测侧最终采用：`thinking` 模式、`temperature=0.7`、`top_p=0.95`、`max_tokens=4096`、`eval_batch_size=4`。本轮评测使用了 thinking 模式的数据过滤与回答提取逻辑，不能与普通贪心评测结果混为同一口径。

**环境备注**

本模型容器与同批模型同宿主机、同镜像，`TRITON_HIP_CLANG_PATH` / `VLLM_WORKER_MULTIPROC_METHOD=spawn` / 两个超时变量在源日志的启动参数块中未单列，按同批同镜像的统一配置补齐（同批其他模型日志记录：不指定 clang 路径会触发 Triton/FlagGems 编译问题；只用 `HIP_VISIBLE_DEVICES` 控卡，不设置 `ROCR_VISIBLE_DEVICES`）。

**评测配置与命令**

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.6.1` |
| 题数 | 50 |
| `eval_batch_size` | 4 |
| 模式 | `thinking` |
| `temperature` / `top_p` | `0.7` / `0.95` |
| `max_model_len` | 40960 |
| `max_tokens` | 4096 |
| prefix cache / chunked prefill | 均关闭 |
| 截断检测 | 显式指定生成上限，跳过会改写上限的截断探测 |
| 评测耗时 | `4469.97s` |

```bash
python3 fast_gpqa.py \
  --model-name Magistral-Small-2506 \
  --api-base http://127.0.0.1:8001/v1 \
  --api-key EMPTY \
  --dataset gpqa_diamond \
  --limit 50 \
  --eval-batch-size 4 \
  --max-tokens 4096 \
  --dataset-dir /models/day0_eval/cache/datasets \
  --output /models/release_run_logs/accuracy/fix_magistral_thinking_temp07_full50_20260918_0055/magistral_temp07_thinking_cap4096_batch4/gpqa50.json
```

- 结果文件：`/public-flash/models/release_run_logs/accuracy/fix_magistral_thinking_temp07_full50_20260918_0055/magistral_temp07_thinking_cap4096_batch4/gpqa50.json`
- 判定文件：`/public-flash/models/release_run_logs/accuracy/fix_magistral_thinking_temp07_full50_20260918_0055/magistral_temp07_thinking_cap4096_batch4/verdict.json`

结果摘要（逐题审计部分）：

```json
{
  "score": 62.0,
  "evalscope_score": 62.0,
  "total_questions": 50,
  "eval_batch_size": 4,
  "max_tokens": 4096,
  "max_model_len": 40960,
  "temperature": 0.7,
  "runaway_detection": {
    "checked": 50,
    "runaway_count": 0
  },
  "answer_extraction_audit": {
    "checked": 50,
    "explicit_answer_found": 44,
    "fallback_to_evalscope": 3,
    "format_corrected_score": 62.0,
    "parser_mismatch_count": 0,
    "invalid_evalscope_extract_count": 3
  }
}
```

**稳定性复测**

| 轮次 | 得分 | runaway | 结论 |
|------|-----:|--------:|------|
| 首轮通过轮次（记录口径） | `62.00%` | `0/50` | 与 NV 持平 |
| 稳定性复测 | `52.00%` | `1/50` | 低于 NV `10` 个百分点，不通过 |

因此本模型的结论必须写成：**该配置存在首轮与 NV 持平的通过证据，但在 `temperature=0.7` 的随机采样口径下，50 题重复评测尚未证明精度稳定通过。**

## 结果

- 修复后分 / NV 基线：`62.00%`（首轮）/ NV `62.00%`
- 达标判定（accuracy_compare 退出码）：`aligned=true`（源日志只记录 verdict 的 `aligned` 字段，未记录退出码数值；按 SOP 约定 0=达标）—— 相对退化 `0.00%`，**严格达标**（不涉及小样本噪声容忍）
- 该轮判定文件（verdict.json）原文：

```json
{
  "aligned": true,
  "noise_zone": false,
  "rel_drop_pct": 0.0,
  "abs_diff": 0.0,
  "message": "精度达标: 当前=62.00%, NV=62.00%, 相对退化=0.00%"
}
```

- 计数对照：Hygon `62.00%`（31/50）vs NV `62.00%`，绝对差 `0` 个百分点，折算 `0` 题，相对退化 `0.00%`。
- **NV 基线来源**：仓库 `nv_baseline.yaml` 中 `Magistral-Small-2506.metrics.gpqa_diamond: 62`，即本次判定实际采用值（与旧失败报告记录的 NV 62.0% 一致，不存在被推翻的口径）。
- **可比性判读**：`nv_baseline.yaml` 只记录 NV 分数，缺少 NV 原始题目 ID、样本量、prompt、EvalScope 版本与逐题预测，只能确认相对仓库 NV 记录值达标；另外 NV 的评测口径（是否 thinking 模式、是否采样）未知，因此**不能宣称与 NV 逐题同源**。
- 解析口径：`explicit_answer_found=44`、`fallback_to_evalscope=3`、`parser_mismatch_count=0`，格式校正分与 EvalScope 原始分一致（均 `62.00%`）。
- 稳定性风险：同参数复测 `52.00%`（runaway 1/50），明确不通过；发布验收应补多轮或全量数据集评测。
- 截断检测被显式跳过，不能据此声明已排除截断。
- **性能验收：本次未单独重测**。

## 提炼到 KNOWLEDGE 的条目

1. reasoning/thinking 模型不能按普通模型默认 `temperature=0.0` 评测；模型卡与模型行为必须纳入评测模式判断。
2. `generation_config.json` 缺少采样字段时，不能静默把模型当贪心模型，应使用模型卡推荐参数并显式记录在结果中。
3. prefix cache / chunked prefill 与核心算子路径的取舍必须用固定并发、固定 prompt、固定生成参数做受控 A/B，不能凭一次分数归因。
4. `max_tokens` 是评测窗口控制而非通用服务上限；本模型用 `4096` 限制复读成本，同时必须审计截断、runaway 与答案提取。
5. `temperature=0.7` 下单轮 50 题波动大（本轮 62% → 复测 52%），发布验收必须补多轮或全量。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: mistralai/Magistral-Small-2506
# IMAGE: harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist
# HARBOR_VER: V3
# GPU: Hygon DCU BW1000, 2 × 64GB
# TP: 2
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 62
# SCORE_FLAGOS: 62.0
# CONTAINER_DEVS: --device=/dev/kfd --device=/dev/dri --security-opt seccomp=unconfined --group-add video --group-add render --shm-size=64g
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -d --net=host --ipc=host \
  --security-opt seccomp=unconfined --security-opt label=disable --group-add video --group-add render \
  --device=/dev/kfd --device=/dev/dri --shm-size=64g \
  -v /public-flash/models:/models \
  -v /opt/hyhal:/opt/hyhal:ro \
  --name flagrelease-magistral-small-2506 \
  harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist \
  bash -lc 'sleep infinity'
```

### 三、启动服务（容器内执行）

```bash
source /opt/dtk/env.sh
export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
export FLAGGEMS_DB_URL=sqlite:///:memory:
export VLLM_FL_FLAGOS_WHITELIST=add,arange_start,argmax,copy_,cos,expand,full,index,linear,lt_scalar,mm_out,ones,rand_like,randn,reciprocal,sin,softmax,softmax_out,sub,to_copy,true_divide,true_divide_,where_self,where_self_out,zero_,zeros
vllm serve /models/flagrelease/fixes_models/Magistral-Small-2506 \
  --served-model-name Magistral-Small-2506 \
  --host 0.0.0.0 \
  --port 8001 \
  --tensor-parallel-size 2 \
  --max-model-len 40960 \
  --dtype bfloat16 \
  --gpu-memory-utilization 0.90 \
  --trust-remote-code \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --block-size 64 \
  --no-enable-prefix-caching \
  --no-enable-chunked-prefill
```
