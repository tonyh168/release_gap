# hygon/Phi-3-medium-128k-instruct 修复日志

- **失败报告**：flagrelease_fail_reports/Hygon/FAILED_Hygon_Phi-3-medium-128k-instruct_202607300330.md
- **原始失败类型**：精度不达标
- **日期**：2026-09-17

## 现象

- 本轮为 `10.232.2.21` 上 6 个模型的批量部署与 50 题精度补测之一，使用统一 Hygon 新镜像 + `TRITON_ATTN` + BF16 路径，权重先落共享盘再挂载进推理容器。
- 初始服务启动阶段容器内默认 clang 路径不匹配，触发 Triton/FlagGems 编译报错（`HSACOError`），服务起不来。
- 显式指定 DTK 26.04 的 AILLVM clang 后服务正常：端口 `8000` 返回 HTTP `200`，`/v1/models` 返回服务名 `Phi-3-medium-128k-instruct`、`max_model_len=131072`。
- 精度评测（GPQA Diamond 50 题）结果 `36.00%`，相对 NV `37.00%` 下降 `2.70%`；本轮检测到 `2/50` 题 runaway，服务指标中可见部分请求以 `length` 结束。评测耗时 `8899.06s`（约 2h 28m 19.1s）。

## 定位

- **部署侧根因是编译器路径，不是权重或端口**：Hygon 栈下必须显式指定 `TRITON_HIP_CLANG_PATH=/opt/dtk-26.04-DCC2602-0317/aillvm/bin/clang-18`，FlagGems/Triton 编译路径才能正常工作，服务才能稳定启动。
- **必须只用 `HIP_VISIBLE_DEVICES` 控卡**：设置 `ROCR_VISIBLE_DEVICES` 会让容器内 `torch.cuda.is_available()` 变为 `False`，本轮最终未设置该变量。
- **精度侧的主要风险不是正确率而是输出形态**：`max_model_len=131072` 使标准评测自动推导 `max_tokens=32768`。GPQA 是短答案选择题，这个生成窗口过大，少数题出现长输出/复读（runaway 2 题、部分请求 `finish_reason=length`），拉长耗时并污染结果。本轮分数仍在 5% 相对退化门限内，但 runaway 必须作为质量风险保留。
- 本轮截断检测通过 `--skip-truncation-check` 显式跳过，**不能据此声明已排除截断**。

## 处置

宿主机 `bm-srwl-nj-zone3-d-bw1000-64g-2-21`（`10.232.2.21`），推理容器 `flagrelease-phi3-medium-128k`，评测容器 `flagrelease-model-download-20260917`，端口 `8000`，`HIP_VISIBLE_DEVICES=0,1`，TP=2，bf16。模型 `/public-flash/models/flagrelease/fixes_models/Phi-3-medium-128k-instruct` → 容器内 `/models/flagrelease/fixes_models/Phi-3-medium-128k-instruct`。本轮未重新构建/推送镜像，也未修改 vLLM、`vllm-plugin-FL`、FlagGems 源码。

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
2. 使用 `HIP_VISIBLE_DEVICES=0,1`，不设置 `ROCR_VISIBLE_DEVICES`；
3. 固定 `TRITON_ATTN`、BF16、TP=2 和 eager 模式；
4. 显式设置 `TRITON_HIP_CLANG_PATH=/opt/dtk-26.04-DCC2602-0317/aillvm/bin/clang-18`（失败尝试：不设置时触发 `HSACOError`，服务无法启动）；
5. 使用独立 Triton 缓存目录与 FlagGems 实际启用算子记录文件（`enabled_ops_retry-clang18-20260917.txt`）；
6. 使用 EvalScope `1.5.1`、固定并发 4，执行 GPQA Diamond 50 题；
7. 使用 `accuracy_compare.py` 与 NV 记录值按 5% 相对退化门限比较。

关键日志：

```text
/public-flash/models/release_run_logs/Phi-3-medium-128k-instruct/serve_retry-clang18-20260917.log
/public-flash/models/release_run_logs/Phi-3-medium-128k-instruct/enabled_ops_retry-clang18-20260917.txt
```

健康检查：`curl http://127.0.0.1:8000/health`、`curl http://127.0.0.1:8000/v1/models`。

评测配置与命令：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.5.1` |
| 题数 | 50 |
| `eval_batch_size` | 4 |
| `temperature` | 0 |
| `max_model_len` | 131072 |
| `max_tokens` | 32768（由标准模型自动推导） |
| 截断检测 | `--skip-truncation-check` 显式跳过 |
| 评测耗时 | `8899.06s` |

```bash
python3 fast_gpqa.py \
  --model-name Phi-3-medium-128k-instruct \
  --api-base http://127.0.0.1:8000/v1 \
  --dataset gpqa_diamond \
  --limit 50 \
  --eval-batch-size 4 \
  --skip-truncation-check \
  --dataset-dir /models/day0_eval/cache/datasets \
  --output /models/release_run_logs/accuracy/gpqa50_nv_20260917_1310/phi3-medium-128k/gpqa50.json
```

结果摘要（逐题审计部分）：

```json
{
  "score": 36.0,
  "evalscope_score": 36.0,
  "total_questions": 50,
  "eval_batch_size": 4,
  "temperature": 0.0,
  "max_tokens": 32768,
  "max_model_len": 131072,
  "truncation_check_skipped": true,
  "runaway_detection": {
    "checked": 50,
    "runaway_count": 2
  },
  "answer_extraction_audit": {
    "checked": 50,
    "explicit_answer_found": 46,
    "fallback_to_evalscope": 2,
    "format_corrected_score": 36.0,
    "parser_mismatch_count": 0,
    "invalid_evalscope_extract_count": 2
  }
}
```

- 结果文件：`/public-flash/models/release_run_logs/accuracy/gpqa50_nv_20260917_1310/phi3-medium-128k/gpqa50.json`
- 判定文件：`/public-flash/models/release_run_logs/accuracy/gpqa50_nv_20260917_1310/phi3-medium-128k/verdict.json`

## 结果

- 修复后分 / NV 基线：`36.00%` / NV `37.00%`
- 达标判定（accuracy_compare 退出码）：`aligned=true`（源日志只记录 verdict 的 `aligned` 字段，未记录退出码数值；按 SOP 约定 0=达标）—— 相对退化 `2.70%`，绝对差 `-1.00` 个百分点，**未触发小样本噪声容忍，直接通过**
- 该轮判定文件（verdict.json）原文：

```json
{
  "aligned": true,
  "noise_zone": false,
  "rel_drop_pct": 2.7,
  "abs_diff": -1.0,
  "message": "精度达标: 当前=36.00%, NV=37.00%, 相对退化=2.70% (容差 5.0%)"
}
```

- **NV 基线来源**：仓库 `nv_baseline.yaml` 中 `Phi-3-medium-128k-instruct.metrics.gpqa_diamond: 37`，即本次判定实际采用值（与旧失败报告记录的 NV 37.0% 一致，不存在被推翻的口径）。
- **可比性判读**：`nv_baseline.yaml` 只记录 NV 分数，缺少 NV 原始题目 ID、样本量、prompt、EvalScope 版本和逐题预测，因此只能确认**相对仓库 NV 记录值达标**，不能宣称与 NV 逐题同源。
- 结果质量风险：runaway `2/50`，且有请求以 `finish_reason=length` 结束；截断检测被显式跳过，不能据此声明已排除截断。
- **性能验收：本次未重测**。

## 提炼到 KNOWLEDGE 的条目

1. 长上下文模型（128K）在 GPQA 这类短答案 MCQ 上，`max_model_len` 会自动放大 `max_tokens`（131072 → 32768），必须把 runaway 数、`finish_reason=length` 和答案抽取审计与 accuracy 一起记录，否则分数不可信。
2. Hygon 栈下 Triton/FlagGems 编译失败的典型触发点是容器内默认 clang 路径，显式指向 DTK 的 AILLVM `clang-18` 即可恢复；这与模型权重、端口无关。
3. 海光控卡只能用 `HIP_VISIBLE_DEVICES`，加 `ROCR_VISIBLE_DEVICES` 会让容器内 `torch.cuda.is_available()` 变 `False`。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: microsoft/Phi-3-medium-128k-instruct
# IMAGE: harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist
# HARBOR_VER: V3
# GPU: Hygon DCU BW1000, 2 × 64GB
# TP: 2
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 37
# SCORE_FLAGOS: 36.0
# CONTAINER_DEVS: --device=/dev/kfd --device=/dev/dri --security-opt seccomp=unconfined --group-add video --group-add render --shm-size=64g
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --net=host --ipc=host \
  --security-opt seccomp=unconfined --group-add video --group-add render \
  --device=/dev/kfd --device=/dev/dri --shm-size=64g \
  -v /public-flash/models:/models \
  -v /opt/hyhal:/opt/hyhal:ro \
  --name flagrelease-phi3-medium-128k \
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
export VLLM_FL_TRITON_CACHE_ROOT=/models/release_run_logs/triton_cache/Phi-3-medium-128k-instruct
export FLAGGEMS_ENABLE_OPLIST_PATH=/models/release_run_logs/Phi-3-medium-128k-instruct/enabled_ops_retry-clang18-20260917.txt
vllm serve /models/flagrelease/fixes_models/Phi-3-medium-128k-instruct \
  --served-model-name Phi-3-medium-128k-instruct \
  --dtype bfloat16 \
  --tensor-parallel-size 2 \
  --max-model-len 131072 \
  --gpu-memory-utilization 0.90 \
  --port 8000 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code
```
