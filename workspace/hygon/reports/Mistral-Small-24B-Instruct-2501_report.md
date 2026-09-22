# hygon/Mistral-Small-24B-Instruct-2501 修复日志

- **失败报告**：flagrelease_fail_reports/Hygon/FAILED_Hygon_Mistral-Small-24B-Instruct-2501_202607290628.md
- **原始失败类型**：精度不达标
- **日期**：2026-09-17

## 现象

- 历史 Hygon 自动化报告（旧栈：vLLM `0.20.2` / plugin-FL `0.2.0` / FlagGems `5.4.0dev` / Flagtree `0.6.1`）在本模型上 V2/V3 的 GPQA Diamond 50 题分别只有 `44.0%` / `46.0%`，低于 NV `54.0%`，判精度不达标（同时提交了 plugin-FL error issue）。
- 本轮换用 Hygon 新镜像（`xingcgen4-blacklist`，vLLM `0.24.0+empty` / torch `2.10.0+das.opt1.dtk2604.20260325.g6b060a`），TP4 服务本身正常（`/health` HTTP `200`），但首轮 GPQA Diamond 50 题只有 `40.00%`（20/50），相对 NV `54.00%` 退化 `25.93%`；该轮无 parser mismatch、无 runaway，评测耗时 `1237.14s`。
- 首轮低分的服务日志：`/public-flash/models/release_run_logs/Mistral-Small-24B-Instruct-2501/serve-whitelist-noprefix-nochunk-genconfig-20260917-150118.log`。

## 定位

问题不在部署链路（权重、端口、健康检查全部正常），而在**推理 prefill/cache 路径 + 评测采样参数口径**，与 FlagGems 算子替换无直接因果：

1. **prefix cache / chunked prefill 路径污染**：保持 26 算子白名单不变，仅加 `--no-enable-prefix-caching --no-enable-chunked-prefill`，同 50 题即从 `40.00%` 升到 `46.00%`（相对 NV 退化 `14.81%`）。说明当前 Hygon 新镜像下这两条路径会改变本模型输出。
2. **评测静默退回贪心**：`fast_gpqa.py` 只拿到 `--model-name` 时定位不到容器内模型目录，读不到模型 `generation_config.json`，于是退回默认 `temperature=0.0`；而本模型 `generation_config.json` 声明 `{"temperature": 0.15, "do_sample": true}`。补齐目录定位后同题再升到 `52.00%`。
3. **不是“全关 FlagGems 就能恢复”**：单独验证 `USE_FLAGGEMS=false`，结果仍为 `40.00%`，与初始轮一致。因此本次首轮达标不能归因于关闭算子，核心修复点是 prefill/cache 开关 + 评测生成参数对齐。

## 处置

宿主机 `10.1.15.95`（`bm-baai-dx-zone2-d-BW1000-64G-15-95`），推理容器 `Mistral-Small-24B-Instruct-2501_flagos`，端口 `8005`，GPU `HIP_VISIBLE_DEVICES=2,3,4,7`，TP=4，bf16。模型权重 `/public-flash/models/Mistral-Small-24B-Instruct-2501` → 容器内 `/models/Mistral-Small-24B-Instruct-2501`。本轮未修改模型权重、tokenizer、config、vLLM 源码、`vllm-plugin-FL` 源码或 FlagGems 算子实现。

**迭代过程（均为 GPQA Diamond 50 题）**

| 轮次 | 配置 | 温度 | 分数 | 相对 NV | 判定 |
|------|------|-----:|-----:|--------:|------|
| v1 初始 | 26 算子白名单，prefix cache / chunked prefill 默认开启 | 0.0 | `40.00%` | `25.93%` | 不达标 |
| v2 | 同上 + `--no-enable-prefix-caching --no-enable-chunked-prefill` | 0.0 | `46.00%` | `14.81%` | 不达标 |
| 失败尝试 | v2 配置 + `USE_FLAGGEMS=false`（全关 FlagGems） | 0.0 | `40.00%` | `25.93%` | 未恢复，排除“全关算子”路线 |
| v3 最终 | v2 配置 + 补 `context.yaml` 让评测读取模型 `generation_config.json` | 0.15 | `52.00%` | `3.70%` | 达标 |

**最终服务参数**

- 镜像：`harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist`（image id `sha256:4b2a93440c3c8bc9230d6774c417e46e85211229696cb73b2141b1cd682758e4`）
- 启动脚本会先检查并加载镜像内实际存在的 DTK `env.sh`；找不到时直接报错，不会继续启动服务。
- 沿用历史失败报告的 26 项算子白名单：

```text
add,arange_start,argmax,copy_,cos,expand,full,index,linear,lt_scalar,mm_out,ones,rand_like,randn,reciprocal,sin,softmax,softmax_out,sub,to_copy,true_divide,true_divide_,where_self,where_self_out,zero_,zeros
```

**评测采样参数修正（本轮关键改动）**

容器内 `/flagos-workspace/shared/context.yaml` 增加模型目录定位：

```yaml
model:
  container_path: /models/Mistral-Small-24B-Instruct-2501
```

首轮达标日志中确认生效：`[gen]` 行打印“采用模型 generation_config.json 采样参数: {'temperature': 0.15}”，即评测确实按 `temperature=0.15` 采样，而不是退回 `0.0`。

**评测命令与产物**

```bash
python3 fast_gpqa.py \
  --model-name Mistral-Small-24B-Instruct-2501 \
  --api-base http://127.0.0.1:8005/v1 \
  --api-key EMPTY \
  --dataset gpqa_diamond \
  --limit 50 \
  --eval-batch-size 4 \
  --max-tokens 4096 \
  --dataset-dir /models/eval_datasets \
  --output /models/release_run_logs/Mistral-Small-24B-Instruct-2501/mistral-small-24b-instruct-2501-gpqa50-cap4096-whitelist-noprefix-nochunk-genconfig-20260917-150908.json
```

- 结果文件：`/public-flash/models/release_run_logs/Mistral-Small-24B-Instruct-2501/mistral-small-24b-instruct-2501-gpqa50-cap4096-whitelist-noprefix-nochunk-genconfig-20260917-150908.json`
- 判定文件：`/public-flash/models/release_run_logs/Mistral-Small-24B-Instruct-2501/mistral-small-24b-instruct-2501-gpqa50-cap4096-whitelist-noprefix-nochunk-genconfig-20260917-150908.verdict.json`
- 评测配置：EvalScope `1.6.1`、题数 50、`eval_batch_size=4`、`max_model_len=32768`、`max_tokens=4096`、`temperature=0.15`、prefix cache 关闭、chunked prefill 关闭，耗时 `1932.07s`（约 32m 12.1s）。

结果摘要：

```json
{
  "score": 52.0,
  "evalscope_score": 52.0,
  "total_questions": 50,
  "temperature": 0.15,
  "max_tokens": 4096,
  "runaway_detection": {
    "checked": 50,
    "runaway_count": 2,
    "runaway_indices": [16, 23]
  },
  "answer_extraction_audit": {
    "checked": 50,
    "explicit_answer_found": 45,
    "format_corrected_score": 52.0,
    "parser_mismatch_count": 0,
    "invalid_evalscope_extract_count": 5
  }
}
```

**稳定性复测（同服务、同 50 题、同 `temperature=0.15`）**

| 轮次 | 分数 | 折算 | 相对 NV | runaway | 判定 |
|------|-----:|-----:|--------:|--------:|------|
| 首轮（记录口径） | `52.00%` | 26/50 | `3.70%` | 2/50，题号 `[16, 23]` | 达标 |
| 复跑 | `48.00%` | 24/50 | `11.11%` | 1/50，题号 `[16]` | 不达标 |

两轮均无 parser mismatch（复跑低分不是解析器误扣）；两轮共 15/50 题抽取答案发生变化，正确性翻转 10 题（6 题对→错、4 题错→对，净少 2 题）。本报告按约定采用首轮 `52.00%` 作为记录口径，但 `temperature=0.15` 的 50 题采样存在波动，严格发布结论应补全量 198 题或固定 seed。

> 来源说明：本节（稳定性复测）的逐轮数据 —— 复跑 `48.00%` / 相对退化 `11.11%` / `runaway 1/50`（题号 `[16]`）/ `15/50` 题抽取答案变化、正确性翻转 `10` 题 / 首轮耗时 `1237.14s` 等 —— **取自同目录旧原始日志 `workspace/hygon/Mistral-Small-24B-Instruct-2501.md`，不是 `fixes/Mistral-Small-24B-Instruct-2501.md`**；`fixes/` 版日志对该复跑只写了「复跑曾出现 `48.00%`」这一句。数据非编造，此处仅标明来源。

## 结果

- 修复后分 / NV 基线：`52.00%`（26/50）/ NV `54.00%`
- 达标判定（accuracy_compare 退出码）：`aligned=true`（源日志只记录 verdict 的 `aligned` 字段，未记录退出码数值；按 SOP 约定 0=达标）—— 相对退化 `3.70%`，未超 5% 门限，判定 `精度达标`
- 该轮判定文件（verdict.json）原文：

```json
{
  "aligned": true,
  "noise_zone": false,
  "rel_drop_pct": 3.7,
  "abs_diff": -2.0,
  "message": "精度达标: 当前=52.00%, NV=54.00%, 相对退化=3.70% (容差 5.0%)"
}
```

- **NV 基线来源**：仓库 `nv_baseline.yaml` 中 `Mistral-Small-24B-Instruct-2501.metrics.gpqa_diamond: 54`，即本次判定实际采用值。
- **可比性判读**：`nv_baseline.yaml` 只记录 NV 分数，没有 NV 原始题目 ID、样本量、prompt、EvalScope 版本和逐题预测，因此当前只能确认**相对仓库 NV 记录值达标**，不能宣称与 NV 逐题严格同源；若需严格对齐，应在 NV 环境用同一条命令重测。
- 答案解析审计：parser mismatch `0`；runaway `2/50`（题号 16、23），作为结果质量风险保留。
- **性能验收：本次未重测**，不能据此宣称 V1–V4 性能门控通过。
- 评测器版本说明：本轮远端 EvalScope 为 `1.6.1`，项目统一口径为 `1.5.1`；用于严格发布对比前建议在 `1.5.1` 环境复跑。

## 提炼到 KNOWLEDGE 的条目

1. 对 Mistral 类模型，服务健康不等于评测口径正确：必须确认评测脚本是否真正读到容器内模型目录和 `generation_config.json`，否则会静默退回 `temperature=0.0` 并系统性低估分数。
2. Hygon 新镜像上遇到“无解析错误但精度显著偏低”时，应优先排查 prefix cache / chunked prefill，再排查算子白名单。
3. `USE_FLAGGEMS=false` 不一定能恢复精度：全关仍低时，要继续检查评测生成参数、attention/prefill 路径与缓存状态，而不是停在算子归因。
4. 带采样的 50 题评测必须同时保留原始分、NV 基线、相对退化、折算题数、runaway 审计和 parser mismatch；单轮通过不能写成稳定达标结论。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: mistralai/Mistral-Small-24B-Instruct-2501
# IMAGE: harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist
# HARBOR_VER: V3
# GPU: Hygon DCU BW1000, 4 × 64GB
# TP: 4
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 54
# SCORE_FLAGOS: 52.0
# CONTAINER_DEVS: --device=/dev/kfd --device=/dev/dri --security-opt seccomp=unconfined --group-add video --shm-size=64g --mount type=bind,src=/public-flash/models,dst=/models --mount type=bind,src=/opt/hyhal,dst=/opt/hyhal,readonly
```

### 二、容器创建（宿主机执行）

```bash
set -euo pipefail

MODEL_ROOT="${MODEL_ROOT:-/public-flash/models}"
HYHAL_ROOT="${HYHAL_ROOT:-/opt/hyhal}"
[[ -d "$MODEL_ROOT" ]] || { echo "ERROR: model root not found: $MODEL_ROOT" >&2; exit 1; }
[[ -d "$HYHAL_ROOT/lib" ]] || { echo "ERROR: Hygon driver library not found: $HYHAL_ROOT/lib" >&2; exit 1; }
[[ -d "$HYHAL_ROOT/lib/cmake/rocm_smi" ]] || echo "WARNING: rocm_smi CMake directory not found under $HYHAL_ROOT; verify the host driver version" >&2

docker run --init -d --net=host --ipc=host \
  --security-opt seccomp=unconfined --security-opt label=disable --group-add video \
  --device=/dev/kfd --device=/dev/dri --shm-size=64g \
  --mount type=bind,src="$MODEL_ROOT",dst=/models \
  --mount type=bind,src="$HYHAL_ROOT",dst=/opt/hyhal,readonly \
  --name Mistral-Small-24B-Instruct-2501_flagos \
  harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist \
  bash -lc 'sleep infinity'
```

### 三、启动服务（容器内执行）

```bash
set -euo pipefail

MODEL_DIR="${MODEL_DIR:-/models/Mistral-Small-24B-Instruct-2501}"
DTK_ENV="${DTK_ENV:-/opt/dtk/env.sh}"
if [[ ! -r "$DTK_ENV" ]]; then
  DTK_ENV="$(find /opt -maxdepth 4 -type f -path '*/dtk*/env.sh' -print -quit 2>/dev/null || true)"
fi
[[ -r "$DTK_ENV" ]] || { echo "ERROR: DTK env.sh not found; check the selected image" >&2; exit 1; }
source "$DTK_ENV"

if [[ -z "${TRITON_HIP_CLANG_PATH:-}" ]]; then
  if [[ -x /opt/dtk/aillvm/bin/clang-18 ]]; then
    TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18
  else
    TRITON_HIP_CLANG_PATH="$(find /opt -maxdepth 6 -type f -path '*/aillvm/bin/clang-18' -perm -111 -print -quit 2>/dev/null || true)"
  fi
fi
[[ -x "${TRITON_HIP_CLANG_PATH:-}" ]] || { echo "ERROR: clang-18 not found in the container" >&2; exit 1; }
export TRITON_HIP_CLANG_PATH
[[ -d "$MODEL_DIR" ]] || { echo "ERROR: model directory not found: $MODEL_DIR" >&2; exit 1; }
export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
export FLAGGEMS_DB_URL=sqlite:///:memory:
export VLLM_FL_FLAGOS_WHITELIST=add,arange_start,argmax,copy_,cos,expand,full,index,linear,lt_scalar,mm_out,ones,rand_like,randn,reciprocal,sin,softmax,softmax_out,sub,to_copy,true_divide,true_divide_,where_self,where_self_out,zero_,zeros
vllm serve "$MODEL_DIR" \
  --host 0.0.0.0 \
  --served-model-name Mistral-Small-24B-Instruct-2501 \
  --dtype bfloat16 \
  --tensor-parallel-size 4 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.90 \
  --port 8005 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code \
  --no-enable-prefix-caching \
  --no-enable-chunked-prefill
```
