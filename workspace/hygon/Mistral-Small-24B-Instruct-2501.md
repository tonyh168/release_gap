# Mistral-Small-24B-Instruct-2501 on Hygon

## 2026-09-17 部署

- 机器：`10.1.15.95`
- 容器：`Mistral-Small-24B-Instruct-2501_flagos`
- 镜像：`harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist`
- 模型路径：`/public-flash/models/Mistral-Small-24B-Instruct-2501`，容器内 `/models/Mistral-Small-24B-Instruct-2501`
- GPU：`HIP_VISIBLE_DEVICES=2,3,4,7`
- 并行：tensor parallel 4
- 服务：`http://10.1.15.95:8005/v1`
- 后端：`TRITON_ATTN`，`--enforce-eager`
- 关键环境：`VLLM_PLUGINS=fl`，`FLAGGEMS_DB_URL=sqlite:///:memory:`
- 关键修复：通过 `source /opt/dtk/env.sh` 注入 Hygon 动态库路径，否则 `torch` 找不到 `libgalaxyhip.so.5`

Hygon 白名单沿用失败报告中的 26 个算子：

```text
add,arange_start,argmax,copy_,cos,expand,full,index,linear,lt_scalar,mm_out,ones,rand_like,randn,reciprocal,sin,softmax,softmax_out,sub,to_copy,true_divide,true_divide_,where_self,where_self_out,zero_,zeros
```

服务验收：`/health` 返回 HTTP 200；最小 chat completion 返回 `OK`。

## 2026-09-17 GPQA 50 题

评测参数：

```bash
python3 fast_gpqa.py \
  --model-name Mistral-Small-24B-Instruct-2501 \
  --api-base http://127.0.0.1:8005/v1 \
  --api-key EMPTY \
  --dataset gpqa_diamond \
  --limit 50 \
  --eval-batch-size 4 \
  --max-tokens 4096 \
  --dataset-dir /models/eval_datasets
```

结果：

- 正确率：`40.00%`，`20/50`
- EvalScope 原始分：`40.00%`
- NV 基线：`54.00%`
- 相对退化：`25.93%`
- 判定：不达标
- runaway：`0/50`
- 答案解析误扣：`0`
- 服务：评测后仍为 HTTP 200
- 评测耗时：`1237.14s`，约 20 分 37 秒

结果文件：

- `/public-flash/models/release_run_logs/Mistral-Small-24B-Instruct-2501/mistral-small-24b-instruct-2501-gpqa50-cap4096-20260917-130145.json`
- `/public-flash/models/release_run_logs/Mistral-Small-24B-Instruct-2501/mistral-small-24b-instruct-2501-gpqa50-cap4096-20260917-130145.verdict.json`
- `/public-flash/models/release_run_logs/Mistral-Small-24B-Instruct-2501/mistral-small-24b-instruct-2501-gpqa50-cap4096-20260917-130145.log`

注意：本轮远端评测环境为 `evalscope 1.6.1`，项目统一口径要求 `1.5.1`。因此本轮可作为当前服务实测结果；严格发布对比前应在锁定 `1.5.1` 的独立评测环境中复跑。

## 2026-09-17 精度修复

问题：初始 50 题只有 `40.00%`，相对 NV `54.00%` 退化 `25.93%`，不达标。

排查结论：

- `--enable-prefix-caching`/chunked prefill 会污染本模型结果；禁用 prefix cache 和 chunked prefill 后，50 题从 `40.00%` 提升到 `46.00%`。
- 直接 `USE_FLAGGEMS=false` 并没有恢复精度，同样只有 `40.00%`，说明本轮不是简单的“全部 FlagGems 替换导致退化”。
- `fast_gpqa.py` 如果只传 `--model-name Mistral-Small-24B-Instruct-2501`，但没有 `/flagos-workspace/shared/context.yaml` 指向模型目录，就读不到模型 `generation_config.json`，会退回默认 `temperature=0.0`。
- 模型自身 `generation_config.json` 指定 `temperature=0.15`、`do_sample=true`。补充 context 后，评测日志确认采用 `temperature=0.15`，50 题恢复到 `52.00%`。

当前候选服务配置：

- 容器：`Mistral-Small-24B-Instruct-2501_flagos`
- GPU：`2,3,4,7`
- 端口：`8005`
- vLLM 参数：`--tensor-parallel-size 4 --gpu-memory-utilization 0.9 --trust-remote-code --served-model-name Mistral-Small-24B-Instruct-2501 --max-model-len 32768 --block-size 64 --swap-space 16 --enforce-eager --no-enable-prefix-caching --no-enable-chunked-prefill`
- 环境：`VLLM_PLUGINS=fl`，`VLLM_FL_BACKEND=TRITON_ATTN`，`FLAGGEMS_DB_URL=sqlite:///:memory:`，26 算子白名单保持开启。
- 评测 context：`/flagos-workspace/shared/context.yaml`

```yaml
model:
  container_path: /models/Mistral-Small-24B-Instruct-2501
```

关键结果：

| 变量 | 温度 | GPQA 50 题 | 相对 NV 退化 | 判定 |
| --- | --- | ---: | ---: | --- |
| 初始服务，prefix/chunk 默认开启 | 0.0 | 40.00% | 25.93% | 不达标 |
| 禁用 prefix cache + chunked prefill，26 算子白名单 | 0.0 | 46.00% | 14.81% | 不达标 |
| 禁用 prefix cache + chunked prefill，`USE_FLAGGEMS=false` | 0.0 | 40.00% | 25.93% | 不达标 |
| 禁用 prefix cache + chunked prefill，26 算子白名单，读取模型 `generation_config` | 0.15 | 52.00% | 3.70% | 达标 |

首轮达标结果文件：

- `/public-flash/models/release_run_logs/Mistral-Small-24B-Instruct-2501/mistral-small-24b-instruct-2501-gpqa50-cap4096-whitelist-noprefix-nochunk-genconfig-20260917-150908.json`
- `/public-flash/models/release_run_logs/Mistral-Small-24B-Instruct-2501/mistral-small-24b-instruct-2501-gpqa50-cap4096-whitelist-noprefix-nochunk-genconfig-20260917-150908.verdict.json`
- `/public-flash/models/release_run_logs/Mistral-Small-24B-Instruct-2501/mistral-small-24b-instruct-2501-gpqa50-cap4096-whitelist-noprefix-nochunk-genconfig-20260917-150908.log`

注意事项：

- 达标轮仍有 `2/50` 题 runaway 复读，题号 `[16, 23]`；分数已达标，但做全量 198 题前需要继续保留 runaway 审计。
- 本轮 `evalscope=1.6.1`；若用于严格发布对比，建议在项目锁定版本 `1.5.1` 下复跑。
- 50 题 `temperature=0.15` 带采样，存在小样本波动；若全量 198 题要复现同一口径，必须保留 context.yaml 和相同生成参数。

## 2026-09-17 稳定性复测

同一服务、同一 50 题、同一 `temperature=0.15` 参数复跑一轮：

- 首轮：`52.00%`，`26/50`，相对 NV 退化 `3.70%`，达标；runaway `2/50`，题号 `[16, 23]`。
- 复跑：`48.00%`，`24/50`，相对 NV 退化 `11.11%`，不达标；runaway `1/50`，题号 `[16]`。
- 两轮均无 parser mismatch；复跑分低不是解析器误扣。
- 两轮共有 `15/50` 题抽取答案发生变化；正确性翻转 `10` 题，其中 `6` 题从对到错、`4` 题从错到对，净少 `2` 题。

复跑结果文件：

- `/public-flash/models/release_run_logs/Mistral-Small-24B-Instruct-2501/mistral-small-24b-instruct-2501-gpqa50-cap4096-stability2-whitelist-noprefix-nochunk-genconfig-20260917-160823.json`
- `/public-flash/models/release_run_logs/Mistral-Small-24B-Instruct-2501/mistral-small-24b-instruct-2501-gpqa50-cap4096-stability2-whitelist-noprefix-nochunk-genconfig-20260917-160823.verdict.json`
- `/public-flash/models/release_run_logs/Mistral-Small-24B-Instruct-2501/mistral-small-24b-instruct-2501-gpqa50-cap4096-stability2-whitelist-noprefix-nochunk-genconfig-20260917-160823.log`

结论：`--no-enable-prefix-caching --no-enable-chunked-prefill` 与 `context.yaml` 可以修正明显低分问题，但 `temperature=0.15` 的 50 题小样本不稳定；不能用单轮 52% 作为稳定通过结论。严格结论应跑全量 198 题，或在支持时固定 seed/改为确定性口径后再比较。
