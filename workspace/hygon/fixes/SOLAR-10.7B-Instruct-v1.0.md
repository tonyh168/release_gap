# Hygon/SOLAR-10.7B-Instruct-v1.0 适配与评测记录

- **日期**：`2026-09-17`
- **远端机器**：`10.232.2.21`
- **主机名**：`bm-srwl-nj-zone3-d-bw1000-64g-2-21`
- **历史失败报告**：暂无，本轮为新增批量部署与 50 题精度补测
- **历史问题类型**：无历史失败报告；本轮重点验证新镜像、Hygon DCU 部署链路和 GPQA 50 题相对 NV 精度
- **模型来源**：`upstage/SOLAR-10.7B-Instruct-v1.0`
- **本次处理结论**：当前 Hygon 新镜像下单卡服务正常；GPQA Diamond 50 题得分 `30.00%`，相对 NV `34.00%` 退化 `11.76%`，虽然超过 5% 相对退化门限，但 50 题下绝对差异为 2 题，按小样本噪声容忍规则通过

---

## 背景分析

本轮在 `10.232.2.21` 上批量下载并部署 6 个模型，其中 `SOLAR-10.7B-Instruct-v1.0` 使用统一 Hygon 新镜像、`TRITON_ATTN` 注意力后端和 BF16 推理路径。模型文件先下载到共享盘，再挂载到推理容器内。

同批模型均遇到过 Triton/FlagGems 编译器路径问题，最终统一显式指定：

```bash
export TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18
```

最终服务仅通过 `HIP_VISIBLE_DEVICES` 指定 GPU，不设置 `ROCR_VISIBLE_DEVICES`。

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `bm-srwl-nj-zone3-d-bw1000-64g-2-21` / `10.232.2.21` |
| 芯片 | Hygon DCU BW1000，8 × 64GB |
| 推理容器 | `flagrelease-solar-10p7b` |
| 评测容器 | `flagrelease-model-download-20260917` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist` |
| 镜像 ID | `sha256:4b2a93440c3c8bc9230d6774c417e46e85211229696cb73b2141b1cd682758e4` |
| vLLM / PyTorch | `vllm 0.24.0+empty` / `torch 2.10.0+das.opt1.dtk2604.20260325.g6b060a` |
| EvalScope | `1.5.1` |
| 模型宿主机路径 | `/public-flash/models/flagrelease/fixes_models/SOLAR-10.7B-Instruct-v1.0` |
| 模型容器路径 | `/models/flagrelease/fixes_models/SOLAR-10.7B-Instruct-v1.0` |
| GPU | `HIP_VISIBLE_DEVICES=4` |
| Tensor Parallel | `1` |
| 服务端口 | `8002` |
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
/usr/bin/python3 /usr/local/bin/vllm serve /models/flagrelease/fixes_models/SOLAR-10.7B-Instruct-v1.0 \
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

关键环境变量：

```bash
export HIP_VISIBLE_DEVICES=4
export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
export FLAGGEMS_DB_URL=sqlite:///:memory:
```

健康检查：

```bash
curl http://127.0.0.1:8002/health
curl http://127.0.0.1:8002/v1/models
```

只读核验结果：`/v1/models` 返回 HTTP `200`，服务模型名为 `SOLAR-10.7B-Instruct-v1.0`，`max_model_len=4096`。

## Step 2：模型文件和容器变更

模型文件位于：

```text
/public-flash/models/flagrelease/fixes_models/SOLAR-10.7B-Instruct-v1.0
```

本次没有重新构建、重新打 tag 或推送镜像，也没有修改 vLLM、`vllm-plugin-FL` 或 FlagGems 源码。运行时新增内容主要包括：

- Triton 默认缓存；
- 服务日志；
- EvalScope 预测、报告、汇总 JSON 和 NV 对比 JSON。

关键日志：

```text
/public-flash/models/release_run_logs/SOLAR-10.7B-Instruct-v1.0/serve_retry-clang18-20260917.log
```

## Step 3：评测

评测服务地址：

```text
http://127.0.0.1:8002/v1
```

评测配置：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.5.1` |
| 题数 | 50 |
| `eval_batch_size` | 4 |
| `temperature` | 0 |
| `max_model_len` | 4096 |
| `max_tokens` | 2048 |
| 截断检测 | 通过 `--skip-truncation-check` 显式跳过，不能据此声明已排除截断 |
| 评测耗时 | `703.90s`，约 11m 43.9s |

命令：

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

结果文件：

```text
/public-flash/models/release_run_logs/accuracy/gpqa50_nv_20260917_1310/solar-10p7b/gpqa50.json
```

判定文件：

```text
/public-flash/models/release_run_logs/accuracy/gpqa50_nv_20260917_1310/solar-10p7b/verdict.json
```

结果摘要：

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

NV 基线：

```yaml
SOLAR-10.7B-Instruct-v1.0:
  metrics:
    gpqa_diamond: 34
```

对比结果：

| 项目 | 值 |
|------|---:|
| Hygon 当前结果 | `30.00%` |
| NV 基线 | `34.00%` |
| 绝对差 | `-4.00` 个百分点 |
| 50 题折算差异 | `2.00` 题 |
| 相对退化 | `11.76%` |
| 5% 相对退化口径 | 超过 |
| 小样本噪声容忍 | 通过 |

`accuracy_compare.py` 判定：

```json
{
  "aligned": true,
  "noise_zone": true,
  "rel_drop_pct": 11.76,
  "abs_diff": -4.0,
  "message": "精度达标(小样本噪声容忍): 当前=30.00%, NV=34.00%, 相对退化=11.76% 虽超容差 5.0%，但 绝对差异 4.00% = 2.00 题 (每题 2.00%, 共 50 题), ≤ 2 题噪声阈值，属小样本评测方差，判定达标"
}
```

## 现象

- 新镜像下单卡服务正常启动，端口 `8002` 返回 HTTP `200`；
- 50 题评测结果为 `30.00%`，相对 NV `34.00%` 下降 `11.76%`；
- 本轮未检测到 runaway；
- 分数相对退化超过 5%，但绝对差异正好为 2 题，落入 50 题小样本噪声容忍区间。

## 定位

SOLAR 的 `max_model_len=4096`，标准评测自动得到 `max_tokens=2048`，不存在 Phi 128K 模型那样的超大生成窗口问题。本轮耗时和输出形态相对正常，主要风险来自 50 题样本量过小导致的统计方差。

当前只能确认相对仓库 NV 记录值在小样本容忍规则下达标；由于没有 NV 原始逐题预测、prompt 和评测产物，不能宣称逐题严格对齐。

## 处置

1. 使用统一 Hygon 新镜像；
2. 使用 `HIP_VISIBLE_DEVICES=4`，不设置 `ROCR_VISIBLE_DEVICES`；
3. 固定 `TRITON_ATTN`、BF16、TP=1 和 eager 模式；
4. 显式设置 `TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18`；
5. 沿用 Triton 默认缓存目录；
6. 使用 EvalScope `1.5.1`、固定并发 4，执行 GPQA Diamond 50 题；
7. 使用 `accuracy_compare.py` 与 NV 记录值比较，并按 50 题小样本噪声规则判定。

## 当前结果

- 服务：正常，GPU `4`，端口 `8002`
- GPQA Diamond 50 题：`30.00%`
- NV 参考值：`34.00%`
- 相对退化：`11.76%`
- 精度判定：通过，小样本噪声容忍
- Runaway：0 题
- 性能验收：本次未重测

## 可复用规则

对 50 题 GPQA 快速验收，必须同时输出原始相对退化和小样本折算题数。若通过原因是小样本噪声容忍，应在记录中显式写清，不得等同于严格 5% 相对退化通过；发布前建议补充全量或多轮重复评测确认稳定性。
