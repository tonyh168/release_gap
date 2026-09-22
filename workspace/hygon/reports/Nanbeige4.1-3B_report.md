# hygon/Nanbeige4.1-3B 修复日志

- **失败报告**：flagrelease_fail_reports/Hygon/FAILED_Hygon_Nanbeige4.1-3B_202607150245.md
- **原始失败类型**：精度不达标
- **日期**：2026-09-17

## 现象

- 本轮为 `10.232.2.21` 上 6 个模型的批量部署与 50 题精度补测之一，使用统一 Hygon 新镜像 + `TRITON_ATTN` + BF16 路径。
- 同批模型初始服务曾因容器内默认 clang 路径不匹配触发 Triton/FlagGems 编译问题，本模型沿用统一修复后单卡服务正常：端口 `8003` 返回 HTTP `200`，`/v1/models` 返回服务名 `Nanbeige4.1-3B`、`max_model_len=32768`。
- GPQA Diamond 50 题格式校正后得分 `84.00%`，高于 NV `81.00%`；但 **EvalScope 原始分只有 `78.00%`**，两者相差 6 个百分点。
- 本轮未检测到 runaway，但 vLLM 指标显示累计 `generation_tokens_total=680265`，且有 6 个请求以 `length` 结束，评测耗时长达 `16349.65s`（约 4h 32m 29.7s）。

## 定位

- **部署侧与同批模型一致**：需要显式指定 DTK 26.04 AILLVM `clang-18`，并只使用 `HIP_VISIBLE_DEVICES` 控卡（设置 `ROCR_VISIBLE_DEVICES` 会让 `torch.cuda.is_available()` 变 `False`）。该配置下服务稳定运行，评测期间 vLLM `error/abort/repetition` 指标均为 0。
- **精度侧主要风险在输出形态而非正确率**：本模型在 GPQA 上生成大量 reasoning/长文本，导致评测耗时极长，并出现多个 `finish_reason=length`。
- **答案抽取审计是必需项**：审计把分数从 EvalScope 原始 `78.00%` 校正到 `84.00%`，说明该模型输出格式对 EvalScope 原始解析影响明显；记录里不能只引用 EvalScope 原始分，否则会低估 6 个百分点。

## 处置

宿主机 `bm-srwl-nj-zone3-d-bw1000-64g-2-21`（`10.232.2.21`），推理容器 `flagrelease-nanbeige4p1-3b`，评测容器 `flagrelease-model-download-20260917`，端口 `8003`，`HIP_VISIBLE_DEVICES=7`，TP=1，bf16。模型 `/public-flash/models/flagrelease/fixes_models/Nanbeige4.1-3B` → 容器内 `/models/flagrelease/fixes_models/Nanbeige4.1-3B`。本轮未重新构建/推送镜像，也未修改 vLLM、`vllm-plugin-FL`、FlagGems 源码。

容器运行配置（长驻容器 + `docker exec` 起服务）：

```text
cmd:      ["bash", "-lc", "sleep infinity"]
network:  host
ipc:      host
shm-size: 64 GiB
```

设备与权限：`/dev/kfd`、`/dev/dri`、`seccomp=unconfined`、`group-add=video`、`group-add=render`；挂载 `/public-flash/models -> /models`（读写）、`/opt/hyhal -> /opt/hyhal`（只读）。

处置步骤：

1. 使用统一 Hygon 新镜像；
2. 使用 `HIP_VISIBLE_DEVICES=7`，不设置 `ROCR_VISIBLE_DEVICES`；
3. 固定 `TRITON_ATTN`、BF16、TP=1 和 eager 模式；
4. 显式设置 `TRITON_HIP_CLANG_PATH=/opt/dtk-26.04-DCC2602-0317/aillvm/bin/clang-18`（失败尝试：不设置时同批服务触发 Triton/FlagGems 编译问题）；
5. 使用独立 Triton 缓存与算子记录文件（`enabled_ops_retry-clang18-20260917.txt`）；
6. 使用 EvalScope `1.5.1`、固定并发 4，执行 GPQA Diamond 50 题；
7. 使用 `accuracy_compare.py` 与 NV 记录值比较，并保留答案抽取审计结果。

关键日志：

```text
/public-flash/models/release_run_logs/Nanbeige4.1-3B/serve_retry-clang18-20260917.log
/public-flash/models/release_run_logs/Nanbeige4.1-3B/enabled_ops_retry-clang18-20260917.txt
```

评测配置与命令：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.5.1` |
| 题数 | 50 |
| `eval_batch_size` | 4 |
| `temperature` | 0 |
| `max_model_len` | 32768 |
| `max_tokens` | 24576 |
| 截断检测 | `--skip-truncation-check` 显式跳过 |
| 评测耗时 | `16349.65s` |

```bash
python3 fast_gpqa.py \
  --model-name Nanbeige4.1-3B \
  --api-base http://127.0.0.1:8003/v1 \
  --dataset gpqa_diamond \
  --limit 50 \
  --eval-batch-size 4 \
  --skip-truncation-check \
  --dataset-dir /models/day0_eval/cache/datasets \
  --output /models/release_run_logs/accuracy/gpqa50_nv_20260917_1310/nanbeige4p1-3b/gpqa50.json
```

结果摘要（逐题审计部分）：

```json
{
  "score": 84.0,
  "evalscope_score": 78.0,
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
    "explicit_answer_found": 45,
    "fallback_to_evalscope": 1,
    "format_corrected_score": 84.0,
    "parser_mismatch_count": 3,
    "invalid_evalscope_extract_count": 7
  }
}
```

- 结果文件：`/public-flash/models/release_run_logs/accuracy/gpqa50_nv_20260917_1310/nanbeige4p1-3b/gpqa50.json`
- 判定文件：`/public-flash/models/release_run_logs/accuracy/gpqa50_nv_20260917_1310/nanbeige4p1-3b/verdict.json`

## 结果

- 修复后分 / NV 基线：`84.00%`（格式校正分，EvalScope 原始分 `78.00%`）/ NV `81.00%`
- 达标判定（accuracy_compare 退出码）：`aligned=true`（源日志只记录 verdict 的 `aligned` 字段，未记录退出码数值；按 SOP 约定 0=达标）—— 当前分数高于 NV（相对退化 `-3.70%`），**未触发小样本噪声容忍**
- 该轮判定文件（verdict.json）原文：

```json
{
  "aligned": true,
  "noise_zone": false,
  "rel_drop_pct": -3.7,
  "abs_diff": 3.0,
  "message": "精度达标: 当前=84.00%, NV=81.00%, 相对退化=-3.70% (容差 5.0%)"
}
```

- 计数对照：Hygon `84.00%`（42/50）vs NV `81.00%`，绝对差 `+3.00` 个百分点，相对退化 `-3.70%`；EvalScope 原始分 `78.00%` 仅作参考，判定采用格式校正分。
- **NV 基线来源**：仓库 `nv_baseline.yaml` 中 `Nanbeige4.1-3B.metrics.gpqa_diamond: 81`，即本次判定实际采用值（不存在被推翻的口径）。
- **可比性判读**：`nv_baseline.yaml` 只记录 NV 分数，没有 NV 原始题目 ID、样本量、prompt、EvalScope 版本与逐题预测，因此只能确认**相对仓库 NV 记录值达标**，不能宣称与 NV 逐题同源。
- **两种分数口径必须并存**：EvalScope 原始 `78.00%` 与格式校正 `84.00%` 差 6 个百分点（`parser_mismatch_count=3`、`invalid_evalscope_extract_count=7`）。若只引用原始分，本模型会被误判为低于 NV。
- 长输出风险：0 runaway，但累计 `generation_tokens_total=680265`、6 个请求以 `length` 结束、评测耗时约 4.5 小时；截断检测被显式跳过，不能据此声明已排除截断。
- **性能验收：本次未重测**。

## 提炼到 KNOWLEDGE 的条目

1. 对会输出 reasoning/长答案的模型，自动评测必须同时记录 EvalScope 原始分、格式校正分、`answer_extraction_audit`、`finish_reason=length` 和总生成 token；原始分与校正分差异明显时，应以格式校正分做 NV 对比，同时保留解析差异作为质量风险。
2. GPQA 这类 MCQ 任务的 `max_tokens` 由 `max_model_len` 自动推导，长输出模型会被拖到数小时量级，应引入 MCQ 专用生成上限。
3. Hygon 栈下 `ROCR_VISIBLE_DEVICES` 与 `HIP_VISIBLE_DEVICES` 不能同时使用，只能用后者控卡。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: Nanbeige/Nanbeige4.1-3B
# IMAGE: harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist
# HARBOR_VER: V3
# GPU: Hygon DCU BW1000, 1 × 64GB
# TP: 1
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 81
# SCORE_FLAGOS: 84.0
# CONTAINER_DEVS: --device=/dev/kfd --device=/dev/dri --security-opt seccomp=unconfined --group-add video --group-add render --shm-size=64g
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --net=host --ipc=host \
  --security-opt seccomp=unconfined --group-add video --group-add render \
  --device=/dev/kfd --device=/dev/dri --shm-size=64g \
  -v /public-flash/models:/models \
  -v /opt/hyhal:/opt/hyhal:ro \
  --name flagrelease-nanbeige4p1-3b \
  harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist \
  /bin/bash
```

### 三、启动服务（容器内执行）

```bash
source /opt/dtk-26.04-DCC2602-0317/env.sh
export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export TRITON_HIP_CLANG_PATH=/opt/dtk-26.04-DCC2602-0317/aillvm/bin/clang-18
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
export FLAGGEMS_DB_URL=sqlite:///:memory:
export VLLM_FL_TRITON_CACHE_ROOT=/models/release_run_logs/triton_cache/Nanbeige4.1-3B
export FLAGGEMS_ENABLE_OPLIST_PATH=/models/release_run_logs/Nanbeige4.1-3B/enabled_ops_retry-clang18-20260917.txt
vllm serve /models/flagrelease/fixes_models/Nanbeige4.1-3B \
  --served-model-name Nanbeige4.1-3B \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.90 \
  --port 8003 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code
```
