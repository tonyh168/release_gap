# Hygon/Phi-3-medium-128k-instruct 适配与评测记录

- **日期**：`2026-09-17`
- **远端机器**：`10.232.2.21`
- **主机名**：`bm-srwl-nj-zone3-d-bw1000-64g-2-21`
- **历史失败报告**：暂无，本轮为新增批量部署与 50 题精度补测
- **历史问题类型**：无历史失败报告；本轮重点验证新镜像、Hygon DCU 部署链路和 GPQA 50 题相对 NV 精度
- **模型来源**：`microsoft/Phi-3-medium-128k-instruct`
- **本次处理结论**：当前 Hygon 新镜像下 TP2 服务正常；GPQA Diamond 50 题得分 `36.00%`，相对 NV `37.00%` 退化 `2.70%`，按 5% 相对退化门限通过

---

## 背景分析

本轮在 `10.232.2.21` 上批量下载并部署 6 个模型，其中 `Phi-3-medium-128k-instruct` 使用统一 Hygon 新镜像、`TRITON_ATTN` 注意力后端和 BF16 推理路径。模型文件先下载到共享盘，再挂载到推理容器内。

初始服务曾因容器内默认 clang 路径不匹配触发 `HSACOError`，后显式指定：

```bash
export TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18
```

同时确认不能设置 `ROCR_VISIBLE_DEVICES`，否则容器内 `torch.cuda.is_available()` 会变为 `False`；最终只使用 `HIP_VISIBLE_DEVICES` 控制 GPU。

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `bm-srwl-nj-zone3-d-bw1000-64g-2-21` / `10.232.2.21` |
| 芯片 | Hygon DCU BW1000，8 × 64GB |
| 推理容器 | `flagrelease-phi3-medium-128k` |
| 评测容器 | `flagrelease-model-download-20260917` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist` |
| 镜像 ID | `sha256:4b2a93440c3c8bc9230d6774c417e46e85211229696cb73b2141b1cd682758e4` |
| vLLM / PyTorch | `vllm 0.24.0+empty` / `torch 2.10.0+das.opt1.dtk2604.20260325.g6b060a` |
| EvalScope | `1.5.1` |
| 模型宿主机路径 | `/public-flash/models/flagrelease/fixes_models/Phi-3-medium-128k-instruct` |
| 模型容器路径 | `/models/flagrelease/fixes_models/Phi-3-medium-128k-instruct` |
| GPU | `HIP_VISIBLE_DEVICES=0,1` |
| Tensor Parallel | `2` |
| 服务端口 | `8000` |
| dtype | `bfloat16` |

## Step 0：容器运行配置

推理容器为长驻容器，vLLM 服务通过 `docker exec` 在容器内启动。关键配置：

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
group-add=render
```

挂载：

```text
/public-flash/models -> /models      读写
/opt/hyhal           -> /opt/hyhal  只读
```

## Step 1：启动 vLLM 服务

实际 vLLM 进程命令：

```bash
/usr/bin/python3 /usr/local/bin/vllm serve /models/flagrelease/fixes_models/Phi-3-medium-128k-instruct \
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

关键环境变量：

```bash
export HIP_VISIBLE_DEVICES=0,1
export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
export FLAGGEMS_DB_URL=sqlite:///:memory:
export VLLM_FL_TRITON_CACHE_ROOT=/models/triton_cache/Phi-3-medium-128k-instruct
mkdir -p "$VLLM_FL_TRITON_CACHE_ROOT"
```

健康检查：

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/v1/models
```

只读核验结果：`/v1/models` 返回 HTTP `200`，服务模型名为 `Phi-3-medium-128k-instruct`，`max_model_len=131072`。

## Step 2：模型文件和容器变更

模型文件位于：

```text
/public-flash/models/flagrelease/fixes_models/Phi-3-medium-128k-instruct
```

本次没有重新构建、重新打 tag 或推送镜像，也没有修改 vLLM、`vllm-plugin-FL` 或 FlagGems 源码。运行时新增内容主要包括：

- 独立 Triton 缓存目录；
- 服务日志；
- EvalScope 预测、报告、汇总 JSON 和 NV 对比 JSON。

关键日志：

```text
/public-flash/models/release_run_logs/Phi-3-medium-128k-instruct/serve_retry-clang18-20260917.log
```

## Step 3：评测

评测服务地址：

```text
http://127.0.0.1:8000/v1
```

评测配置：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.5.1` |
| 题数 | 50 |
| `eval_batch_size` | 4 |
| `temperature` | 0 |
| `max_model_len` | 131072 |
| `max_tokens` | 32768 |
| 截断检测 | 通过 `--skip-truncation-check` 显式跳过，不能据此声明已排除截断 |
| 评测耗时 | `8899.06s`，约 2h 28m 19.1s |

命令：

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

结果文件：

```text
/public-flash/models/release_run_logs/accuracy/gpqa50_nv_20260917_1310/phi3-medium-128k/gpqa50.json
```

判定文件：

```text
/public-flash/models/release_run_logs/accuracy/gpqa50_nv_20260917_1310/phi3-medium-128k/verdict.json
```

结果摘要：

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

NV 基线：

```yaml
Phi-3-medium-128k-instruct:
  metrics:
    gpqa_diamond: 37
```

对比结果：

| 项目 | 值 |
|------|---:|
| Hygon 当前结果 | `36.00%` |
| NV 基线 | `37.00%` |
| 绝对差 | `-1.00` 个百分点 |
| 相对退化 | `2.70%` |
| 5% 相对退化口径 | 通过 |
| 小样本噪声容忍 | 未触发，直接通过 |

`accuracy_compare.py` 判定：

```json
{
  "aligned": true,
  "noise_zone": false,
  "rel_drop_pct": 2.7,
  "abs_diff": -1.0,
  "message": "精度达标: 当前=36.00%, NV=37.00%, 相对退化=2.70% (容差 5.0%)"
}
```

## 现象

- 新镜像下 TP2 服务正常启动，端口 `8000` 返回 HTTP `200`；
- 50 题评测结果为 `36.00%`，相对 NV `37.00%` 下降 `2.70%`；
- 本轮检测到 2 题 runaway，且服务指标中可见部分请求以 `length` 结束，说明长上下文模型在 MCQ 任务上存在长输出污染风险；
- 尽管存在 runaway，本轮分数仍在 5% 相对退化门限内。

## 定位

本轮部署问题的关键点不是模型权重或服务端口，而是 Hygon 栈下 Triton 编译器路径。显式使用 DTK 26.04 的 AILLVM `clang-18` 后，FlagGems/Triton 编译路径可正常工作，服务稳定。

精度层面，`max_model_len=131072` 导致标准模型自动 `max_tokens=32768`。GPQA 是短答案选择题，这个生成窗口过大，少数题会出现长输出或复读，进而拉长耗时并污染结果。因此本轮虽然通过，仍应把 runaway 作为质量风险记录。

## 处置

1. 使用统一 Hygon 新镜像；
2. 使用 `HIP_VISIBLE_DEVICES=0,1`，不设置 `ROCR_VISIBLE_DEVICES`；
3. 固定 `TRITON_ATTN`、BF16、TP=2 和 eager 模式；
4. 显式设置 `TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18`；
5. 使用独立 Triton 缓存目录；
6. 使用 EvalScope `1.5.1`、固定并发 4，执行 GPQA Diamond 50 题；
7. 使用 `accuracy_compare.py` 与 NV 记录值按 5% 相对退化门限比较。

## 当前结果

- 服务：正常，GPU `0,1`，端口 `8000`
- GPQA Diamond 50 题：`36.00%`
- NV 参考值：`37.00%`
- 相对退化：`2.70%`
- 精度判定：通过
- Runaway：2 题，需保留为结果质量风险
- 性能验收：本次未重测

## 可复用规则

长上下文模型在 GPQA 这类短答案 MCQ 任务中，不能只看服务是否可用和最终 accuracy。自动化流程应同时记录 `max_model_len`、自动推导的 `max_tokens`、`finish_reason=length`、runaway 数量和答案抽取审计。若 `max_tokens` 过大导致长输出，应在后续协议中增加 MCQ 专用生成上限或显式读取模型目录中的 `generation_config.json`。
