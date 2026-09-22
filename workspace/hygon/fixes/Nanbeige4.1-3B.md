# Hygon/Nanbeige4.1-3B 适配与评测记录

- **日期**：`2026-09-17`
- **远端机器**：`10.232.2.21`
- **主机名**：`bm-srwl-nj-zone3-d-bw1000-64g-2-21`
- **历史失败报告**：暂无，本轮为新增批量部署与 50 题精度补测
- **历史问题类型**：无历史失败报告；本轮重点验证新镜像、Hygon DCU 部署链路和 GPQA 50 题相对 NV 精度
- **模型来源**：`Nanbeige/Nanbeige4.1-3B`
- **本次处理结论**：当前 Hygon 新镜像下单卡服务正常；GPQA Diamond 50 题格式校正后得分 `84.00%`，高于 NV `81.00%`，按 5% 相对退化门限通过

---

## 背景分析

本轮在 `10.232.2.21` 上批量下载并部署 6 个模型，其中 `Nanbeige4.1-3B` 使用统一 Hygon 新镜像、`TRITON_ATTN` 注意力后端和 BF16 推理路径。模型文件先下载到共享盘，再挂载到推理容器内。

同批模型初始服务曾因容器内默认 clang 路径不匹配触发 Triton/FlagGems 编译问题，最终统一显式指定：

```bash
export TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18
```

同时确认不能设置 `ROCR_VISIBLE_DEVICES`，否则容器内 `torch.cuda.is_available()` 会变为 `False`；最终只使用 `HIP_VISIBLE_DEVICES` 控制 GPU。

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `bm-srwl-nj-zone3-d-bw1000-64g-2-21` / `10.232.2.21` |
| 芯片 | Hygon DCU BW1000，8 × 64GB |
| 推理容器 | `flagrelease-nanbeige4p1-3b` |
| 评测容器 | `flagrelease-model-download-20260917` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist` |
| 镜像 ID | `sha256:4b2a93440c3c8bc9230d6774c417e46e85211229696cb73b2141b1cd682758e4` |
| vLLM / PyTorch | `vllm 0.24.0+empty` / `torch 2.10.0+das.opt1.dtk2604.20260325.g6b060a` |
| EvalScope | `1.5.1` |
| 模型宿主机路径 | `/public-flash/models/flagrelease/fixes_models/Nanbeige4.1-3B` |
| 模型容器路径 | `/models/flagrelease/fixes_models/Nanbeige4.1-3B` |
| GPU | `HIP_VISIBLE_DEVICES=7` |
| Tensor Parallel | `1` |
| 服务端口 | `8003` |
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
/usr/bin/python3 /usr/local/bin/vllm serve /models/flagrelease/fixes_models/Nanbeige4.1-3B \
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

关键环境变量：

```bash
export HIP_VISIBLE_DEVICES=7
export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
export FLAGGEMS_DB_URL=sqlite:///:memory:
export VLLM_FL_TRITON_CACHE_ROOT=/models/triton_cache/Nanbeige4.1-3B
mkdir -p "$VLLM_FL_TRITON_CACHE_ROOT"
```

健康检查：

```bash
curl http://127.0.0.1:8003/health
curl http://127.0.0.1:8003/v1/models
```

只读核验结果：`/v1/models` 返回 HTTP `200`，服务模型名为 `Nanbeige4.1-3B`，`max_model_len=32768`。

## Step 2：模型文件和容器变更

模型文件位于：

```text
/public-flash/models/flagrelease/fixes_models/Nanbeige4.1-3B
```

本次没有重新构建、重新打 tag 或推送镜像，也没有修改 vLLM、`vllm-plugin-FL` 或 FlagGems 源码。运行时新增内容主要包括：

- 独立 Triton 缓存目录；
- 服务日志；
- EvalScope 预测、报告、汇总 JSON 和 NV 对比 JSON。

关键日志：

```text
/public-flash/models/release_run_logs/Nanbeige4.1-3B/serve_retry-clang18-20260917.log
```

## Step 3：评测

评测服务地址：

```text
http://127.0.0.1:8003/v1
```

评测配置：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.5.1` |
| 题数 | 50 |
| `eval_batch_size` | 4 |
| `temperature` | 0 |
| `max_model_len` | 32768 |
| `max_tokens` | 24576 |
| 截断检测 | 通过 `--skip-truncation-check` 显式跳过，不能据此声明已排除截断 |
| 评测耗时 | `16349.65s`，约 4h 32m 29.7s |

命令：

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

结果文件：

```text
/public-flash/models/release_run_logs/accuracy/gpqa50_nv_20260917_1310/nanbeige4p1-3b/gpqa50.json
```

判定文件：

```text
/public-flash/models/release_run_logs/accuracy/gpqa50_nv_20260917_1310/nanbeige4p1-3b/verdict.json
```

结果摘要：

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

NV 基线：

```yaml
Nanbeige4.1-3B:
  metrics:
    gpqa_diamond: 81
```

对比结果：

| 项目 | 值 |
|------|---:|
| Hygon 当前结果 | `84.00%` |
| EvalScope 原始分 | `78.00%` |
| NV 基线 | `81.00%` |
| 绝对差 | `+3.00` 个百分点 |
| 相对退化 | `-3.70%` |
| 5% 相对退化口径 | 通过 |
| 小样本噪声容忍 | 未触发，当前分数高于 NV |

`accuracy_compare.py` 判定：

```json
{
  "aligned": true,
  "noise_zone": false,
  "rel_drop_pct": -3.7,
  "abs_diff": 3.0,
  "message": "精度达标: 当前=84.00%, NV=81.00%, 相对退化=-3.70% (容差 5.0%)"
}
```

## 现象

- 新镜像下单卡服务正常启动，端口 `8003` 返回 HTTP `200`；
- 50 题格式校正后结果为 `84.00%`，高于 NV `81.00%`；
- EvalScope 原始分为 `78.00%`，答案抽取审计校正后为 `84.00%`，说明该模型输出格式对 EvalScope 原始解析有明显影响；
- 本轮未检测到 runaway；
- vLLM 指标显示本轮累计 `generation_tokens_total=680265`，且有 6 个请求以 `length` 结束，评测耗时达到约 4.5 小时。

## 定位

部署侧问题与同批模型一致：需要显式指定 DTK 26.04 AILLVM `clang-18`，并只使用 `HIP_VISIBLE_DEVICES` 控制可见 GPU。该配置下服务稳定运行，评测期间 vLLM `error/abort/repetition` 指标均为 0。

精度侧主要风险不在正确率，而在输出形态。`Nanbeige4.1-3B` 在 GPQA 上生成了大量 reasoning/长文本，导致评测耗时极长，并出现多个 `finish_reason=length`。同时，答案提取审计将分数从 EvalScope 原始 `78.00%` 校正到 `84.00%`，说明记录中必须保留 parser audit，不能只引用 EvalScope 原始分。

## 处置

1. 使用统一 Hygon 新镜像；
2. 使用 `HIP_VISIBLE_DEVICES=7`，不设置 `ROCR_VISIBLE_DEVICES`；
3. 固定 `TRITON_ATTN`、BF16、TP=1 和 eager 模式；
4. 显式设置 `TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18`；
5. 使用独立 Triton 缓存目录；
6. 使用 EvalScope `1.5.1`、固定并发 4，执行 GPQA Diamond 50 题；
7. 使用 `accuracy_compare.py` 与 NV 记录值比较，并保留答案抽取审计结果。

## 当前结果

- 服务：正常，GPU `7`，端口 `8003`
- GPQA Diamond 50 题：`84.00%`
- EvalScope 原始分：`78.00%`
- NV 参考值：`81.00%`
- 相对退化：`-3.70%`，当前分数高于 NV
- 精度判定：通过
- Runaway：0 题
- 长输出风险：累计生成 token 很高，6 个请求以 `length` 结束
- 性能验收：本次未重测

## 可复用规则

对会输出 reasoning 或长答案的模型，自动化评测必须记录 EvalScope 原始分、格式校正分、`answer_extraction_audit`、`finish_reason=length` 和总生成 token。若原始分与校正分差异明显，应以格式校正分进行 NV 对比，同时把解析差异作为结果质量风险保留；GPQA 这类 MCQ 任务后续应考虑增加 MCQ 专用 `max_tokens` 上限，避免长输出拖慢验收。
