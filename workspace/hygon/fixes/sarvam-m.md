# sarvam-m on Hygon

## 2026-09-16 全量 GPQA 评测

- 机器：`10.1.15.95`
- 服务容器：`sarvam-m_flagos_20260915`
- 镜像：`harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist`
- 模型路径：`/public-flash/models/sarvam-m`，容器内 `/models/sarvam-m`
- 服务：`vllm serve /models/sarvam-m --served-model-name sarvam-m --dtype bfloat16 --tensor-parallel-size 2 --max-model-len 32768 --gpu-memory-utilization 0.9 --port 8100 --attention-backend TRITON_ATTN --no-enable-chunked-prefill --no-enable-prefix-caching --enforce-eager --trust-remote-code`
- GPU：`HIP_VISIBLE_DEVICES=4,7`
- 关键环境：`VLLM_PLUGINS=fl`，`VLLM_FL_FLAGOS_BLACKLIST=cat,slice`，`FLAGGEMS_DB_URL=sqlite:///:memory:`

评测参数：

```bash
python3 fast_gpqa.py \
  --model-name sarvam-m \
  --api-base http://127.0.0.1:8100/v1 \
  --api-key EMPTY \
  --dataset gpqa_diamond \
  --limit 0 \
  --eval-batch-size 4 \
  --max-tokens 4096 \
  --dataset-dir /models/eval_datasets \
  --output /models/release_run_logs/sarvam-m/sarvam-m-gpqa198-cap4096-20260916-r3.json
```

结果：

- 全量题数：`198`
- 得分：`29.80%`
- EvalScope 原始分：`29.80%`
- NV 基线：`48.00%`
- 相对退化：`37.92%`
- 判定：不达标，超过 `5%` 容差
- 耗时：`355m 53.6s`
- runaway：`40/198`
- 结果：`/public-flash/models/release_run_logs/sarvam-m/sarvam-m-gpqa198-cap4096-20260916-r3.json`
- verdict：`/public-flash/models/release_run_logs/sarvam-m/sarvam-m-gpqa198-cap4096-20260916-r3.verdict.json`
- EvalScope 输出：`/public-flash/models/eval_scripts/sarvam-m-20260915/outputs/gpqa_diamond/20260916_082155`

## 本轮踩坑

1. 首轮全量评测在 `53/198` 后服务崩掉，服务日志报 `sqlite3.OperationalError: database is locked`，栈在 FlagGems `index` autotune cache。结论是多 worker 共用 SQLite autotune DB 时会互相锁住；用 `FLAGGEMS_DB_URL=sqlite:///:memory:` 重启服务后规避。
2. 第二轮 `r2` 跑到 `24/198` 后评测临时容器被外部 `kill`，Docker 事件显示退出码 `137` 并被 destroy；服务仍健康。后续把评测挂到长驻 `sarvam-m_flagos_20260915` 容器内，避免临时下载容器被清理影响评测。
3. `accuracy_compare.py` 需要 `--v2` 参数；容器默认找 `/flagos-workspace/shared/nv_baseline.yaml`，本轮应显式传 `--nv-baseline-file /models/eval_scripts/sarvam-m-20260915/nv_baseline.yaml`。

## 结论

这轮服务稳定性问题已规避，但精度仍明显低于 NV 基线，并且 `40/198` 题出现 max_tokens 复读/runaway。当前只能判定 Hygon 新镜像下 `sarvam-m` 全量 GPQA 不达标；不能把 29.80% 全部归因给单个算子，下一步应做 `FlagGems 开/关 x OOT 开/关` 的 2x2 复现实验，并对 runaway 题做逐题输出审计。
