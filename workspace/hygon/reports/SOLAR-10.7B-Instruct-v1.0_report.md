# hygon/SOLAR-10.7B-Instruct-v1.0 修复日志

- **失败报告**：flagrelease_fail_reports/Hygon/FAILED_Hygon_SOLAR-10.7B-Instruct-v1.0_202607252026.md
- **原始失败类型**：精度不达标
- **日期**：2026-09-17

## 现象

- 本轮为 `10.232.2.21` 上 6 个模型的批量部署与 50 题精度补测之一，使用统一 Hygon 新镜像 + `TRITON_ATTN` + BF16 路径。
- 同批模型均遇到过 Triton/FlagGems 编译器路径问题，本模型沿用统一修复后单卡服务正常：端口 `8002` 返回 HTTP `200`，`/v1/models` 返回服务名 `SOLAR-10.7B-Instruct-v1.0`、`max_model_len=4096`。
- GPQA Diamond 50 题得分 `30.00%`，相对 NV `34.00%` 下降 `11.76%`；本轮未检测到 runaway，评测耗时 `703.90s`（约 11m 43.9s）。
- 与主要失败的 `gemma-1.1-7b-it` / `sarvam-m` / `SuperNova-Medius` 不同，本模型分数正好落在小样本容忍边界内（绝对差恰为 2 题）。

## 定位

- **部署侧根因是同批统一的编译器路径**：必须显式设置 `TRITON_HIP_CLANG_PATH=/opt/dtk-26.04-DCC2602-0317/aillvm/bin/clang-18`；只用 `HIP_VISIBLE_DEVICES` 控卡，不设置 `ROCR_VISIBLE_DEVICES`（后者会让 `torch.cuda.is_available()` 变 `False`）。
- **不存在 Phi 128K 那样的超大生成窗口问题**：本模型 `max_model_len=4096`，标准评测自动得到 `max_tokens=2048`，耗时与输出形态正常。
- **主要风险是 50 题样本量过小导致的统计方差**：相对退化 `11.76%` 超过 5% 门限，但绝对差 `-4.00` 个百分点 = `2.00` 题，正好等于 50 题噪声阈值上限，因此按小样本容忍规则判达标。
- **不能宣称逐题严格对齐**：仓库只有 NV 记录分数，没有 NV 原始逐题预测、prompt 和评测产物，只能确认相对记录值在小样本容忍规则下达标。

## 处置

宿主机 `bm-srwl-nj-zone3-d-bw1000-64g-2-21`（`10.232.2.21`），推理容器 `flagrelease-solar-10p7b`，评测容器 `flagrelease-model-download-20260917`，端口 `8002`，`HIP_VISIBLE_DEVICES=4`，TP=1，bf16。模型 `/public-flash/models/flagrelease/fixes_models/SOLAR-10.7B-Instruct-v1.0` → 容器内 `/models/flagrelease/fixes_models/SOLAR-10.7B-Instruct-v1.0`。本轮未重新构建/推送镜像，也未修改 vLLM、`vllm-plugin-FL`、FlagGems 源码。

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
2. 使用 `HIP_VISIBLE_DEVICES=4`，不设置 `ROCR_VISIBLE_DEVICES`；
3. 固定 `TRITON_ATTN`、BF16、TP=1 和 eager 模式；
4. 显式设置 `TRITON_HIP_CLANG_PATH=/opt/dtk-26.04-DCC2602-0317/aillvm/bin/clang-18`（失败尝试：不设置时同批服务触发 Triton/FlagGems 编译问题）；
5. 使用独立 Triton 缓存与算子记录文件（`enabled_ops_retry-clang18-20260917.txt`）；
6. 使用 EvalScope `1.5.1`、固定并发 4，执行 GPQA Diamond 50 题；
7. 使用 `accuracy_compare.py` 与 NV 记录值比较，并按 50 题小样本噪声规则判定。

关键日志：

```text
/public-flash/models/release_run_logs/SOLAR-10.7B-Instruct-v1.0/serve_retry-clang18-20260917.log
/public-flash/models/release_run_logs/SOLAR-10.7B-Instruct-v1.0/enabled_ops_retry-clang18-20260917.txt
```

评测配置与命令：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.5.1` |
| 题数 | 50 |
| `eval_batch_size` | 4 |
| `temperature` | 0 |
| `max_model_len` | 4096 |
| `max_tokens` | 2048 |
| 截断检测 | `--skip-truncation-check` 显式跳过 |
| 评测耗时 | `703.90s` |

```bash
python3 fast_gpqa.py \
  --model-name SOLAR-10.7B-Instruct-v1.0 \
  --api-base http://127.0.0.1:8002/v1 \
  --dataset gpqa_diamond \
  --limit 50 \
  --eval-batch-size 4 \
  --skip-truncation-check \
  --dataset-dir /models/day0_eval/cache/datasets \
  --output /models/release_run_logs/accuracy/gpqa50_nv_20260917_1310/solar-10p7b/gpqa50.json
```

结果摘要（逐题审计部分）：

```json
{
  "score": 30.0,
  "evalscope_score": 30.0,
  "total_questions": 50,
  "eval_batch_size": 4,
  "temperature": 0.0,
  "max_tokens": 2048,
  "max_model_len": 4096,
  "truncation_check_skipped": true,
  "runaway_detection": {
    "checked": 50,
    "runaway_count": 0
  },
  "answer_extraction_audit": {
    "checked": 50,
    "explicit_answer_found": 40,
    "fallback_to_evalscope": 5,
    "format_corrected_score": 30.0,
    "parser_mismatch_count": 0,
    "invalid_evalscope_extract_count": 5
  }
}
```

- 结果文件：`/public-flash/models/release_run_logs/accuracy/gpqa50_nv_20260917_1310/solar-10p7b/gpqa50.json`
- 判定文件：`/public-flash/models/release_run_logs/accuracy/gpqa50_nv_20260917_1310/solar-10p7b/verdict.json`

## 结果

- 修复后分 / NV 基线：`30.00%` / NV `34.00%`
- 达标判定（accuracy_compare 退出码）：`aligned=true`（源日志只记录 verdict 的 `aligned` 字段，未记录退出码数值；按 SOP 约定 0=达标）—— **相对退化 `11.76%` 超过 5% 门限，但绝对差 `-4.00` 个百分点 = `2.00` 题，正好不超过 2 题噪声阈值，按小样本噪声容忍规则通过**；不是严格 5% 相对退化通过
- 该轮判定文件（verdict.json）原文：

```json
{
  "aligned": true,
  "noise_zone": true,
  "rel_drop_pct": 11.76,
  "abs_diff": -4.0,
  "message": "精度达标(小样本噪声容忍): 当前=30.00%, NV=34.00%, 相对退化=11.76% 虽超容差 5.0%，但 绝对差异 4.00% = 2.00 题 (每题 2.00%, 共 50 题), ≤ 2 题噪声阈值，属小样本评测方差，判定达标"
}
```

- 计数对照：Hygon `30.00%`（15/50）vs NV `34.00%`，绝对差 `-4.00` 个百分点，折算 `2.00` 题，相对退化 `11.76%`。
- **NV 基线来源**：仓库 `nv_baseline.yaml` 中 `SOLAR-10.7B-Instruct-v1.0.metrics.gpqa_diamond: 34`，即本次判定实际采用值。
- **可比性判读**：`nv_baseline.yaml` 只记录 NV 分数，缺少 NV 原始题目 ID、样本量、prompt、EvalScope 版本与逐题预测，因此只能确认相对仓库 NV 记录值达标，**不能宣称与 NV 逐题严格对齐**。
- 解析口径：`explicit_answer_found=40`、`fallback_to_evalscope=5`、`parser_mismatch_count=0`，格式校正分与 EvalScope 原始分一致（均 `30.00%`），低分不是解析器误扣。
- 结果质量：runaway `0/50`；截断检测被显式跳过，不能据此声明已排除截断。
- **性能验收：本次未重测**。

## 提炼到 KNOWLEDGE 的条目

1. 50 题 GPQA 快速验收必须同时输出原始相对退化和小样本折算题数；通过原因若是小样本噪声容忍，必须在记录中显式写清，不得等同于严格 5% 相对退化通过。
2. 小样本容忍判定前要先确认答案抽取审计干净（本模型 parser mismatch=0），否则容忍的对象可能是评测器误差。
3. 达标边界值（绝对差正好 2 题）最容易在后续复核中被翻案，发布前应补全量或多轮重复评测确认稳定性。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: upstage/SOLAR-10.7B-Instruct-v1.0
# IMAGE: harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist
# HARBOR_VER: V3
# GPU: Hygon DCU BW1000, 1 × 64GB
# TP: 1
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 34
# SCORE_FLAGOS: 30.0
# CONTAINER_DEVS: --device=/dev/kfd --device=/dev/dri --security-opt seccomp=unconfined --group-add video --group-add render --shm-size=64g
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --net=host --ipc=host \
  --security-opt seccomp=unconfined --group-add video --group-add render \
  --device=/dev/kfd --device=/dev/dri --shm-size=64g \
  -v /public-flash/models:/models \
  -v /opt/hyhal:/opt/hyhal:ro \
  --name flagrelease-solar-10p7b \
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
export VLLM_FL_TRITON_CACHE_ROOT=/models/release_run_logs/triton_cache/SOLAR-10.7B-Instruct-v1.0
export FLAGGEMS_ENABLE_OPLIST_PATH=/models/release_run_logs/SOLAR-10.7B-Instruct-v1.0/enabled_ops_retry-clang18-20260917.txt
vllm serve /models/flagrelease/fixes_models/SOLAR-10.7B-Instruct-v1.0 \
  --served-model-name SOLAR-10.7B-Instruct-v1.0 \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 4096 \
  --gpu-memory-utilization 0.90 \
  --port 8002 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code
```
