# Hygon Day0 复测结论

远端机器：`10.232.2.33`

镜像：`harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4`

## Gemma-1.1-7B-IT

### 结论

初始诊断认为 Gemma 的低分由两部分组成：

1. 评测器对部分 Markdown 答案格式提取错误，导致部分历史原始分被低估。新增显式 `ANSWER: A/B/C/D` 审计后，通常可恢复约 1--2 个百分点。
2. Hygon 当前推理路径在批量并发下存在非确定性。同一配置、同一 `temperature=0`，两轮 198 题评测仍出现 70/198 题答案变化；同一题串行连续请求稳定，而并发 16 请求出现不同答案。因此不能将本次低分归因到单个白名单算子或单个 `silu_and_mul` 替换。

### 复测数据

| 配置 | 题数/并发 | EvalScope 原始分 | 格式校正分 |
|---|---:|---:|---:|
| 历史配置（FlagGems 开启，OOT `silu_and_mul` 黑名单） | 198/4 | 30.81% | 31.82% |
| FlagGems 关闭，OOT 开启，`silu_and_mul` 黑名单 | 198/16 | 31.31% | 34.34% |
| 同上，重复评测 | 198/4 | 28.79% | 30.30% |
| 同上，重复评测 | 198/16 | 27.78% | 30.30% |
| FlagGems 关闭，OOT 开启，关闭 prefix cache | 198/16 | 30.30% | 31.82% |
| 同上，第二轮 | 198/16 | 33.84% | 35.35% |
| 同上，串行独立诊断 | 50/1 | -- | 30.00%（15/50，4 题未提取到明确字母） |

NV GPQA 基线为 37%。因此 Gemma 当前结果区间为 30.00%--35.35%，无法视为稳定达标；最高一轮 35.35% 相对 NV 下降 4.46%，但重复性不足。

关键证据：

- `/public-flash/models/day0_logs/accuracy/gemma-1.1-7b-it-gpqa198-20260914-182013.json`
- `/public-flash/models/day0_logs/accuracy/gemma-no-prefix-gpqa198-b16-run1-20260914.json`
- `/public-flash/models/day0_logs/accuracy/gemma-no-prefix-gpqa198-b16-run2-20260914.json`
- `/public-flash/models/day0_logs/accuracy/gemma-no-prefix-gpqa50-sequential-20260915.json`

### 2026-09-15 新镜像复测结论

固定为 GPQA Diamond 50 题、`eval_batch_size=4`、`temperature=0` 后，修复前结果为 32%。格式校正分仍为 32%，因此本轮低分不是答案解析造成的。隔离实验在保留历史 FlagGems 白名单的前提下关闭 OOT，结果提升到 40%；正式服务采用同一修复后复测为 38%。

Gemma 当前设置 `VLLM_FL_OOT_ENABLED=0`，保留历史 FlagGems 白名单和 `VLLM_FL_OOT_BLACKLIST=silu_and_mul`。但 EvalScope 1.5.1 下同配置第二轮复测回落到 32%，相对 NV 37% 退化 13.51%，不达标。因此关闭 OOT 只能视为候选缓解措施，不能确认已经稳定修复。

两轮 1.5.1 评测的 50 道输入和目标答案完全相同，但 13 道最终选项、39 道完整输出发生变化，分数为 38% 和 32%。当前结论是服务部署成功，但批量推理非确定性仍导致精度不稳定。完整证据和复用规则见 `workspace/hygon/fixes/gemma-1.1-7b-it.md`。

随后执行 prefix cache 严格 A/B，两组均保持相同服务与评测配置：开启缓存冷/热两轮分别为 36%/32%，关闭缓存两轮分别为 42%/36%。开启热缓存轮新增 token 命中率为 96.81%，确认缓存实际生效；但关闭后两轮仍有 15/50 道最终选项变化。并且开启冷缓存轮与关闭缓存第 2 轮的 50 道完整生成文本完全一致。因此 prefix cache 不是波动的充分原因，关闭缓存不能作为稳定精度修复，正式服务保持默认配置，继续定位批处理、chunked prefill 或底层算子执行的非确定性。

关键证据：

- `/public-flash/models/day0_logs/accuracy/gemma-1.1-7b-it-gpqa50-oot-disabled-final-20260915.json`
- `/public-flash/models/day0_logs/accuracy/gemma-1.1-7b-it-gpqa50-oot-disabled-final-20260915-vs-nv.json`
- `/public-flash/models/day0_logs/accuracy/gemma-1.1-7b-it-gpqa50-oot-disabled-repeat-evalscope151-20260915.json`
- `/public-flash/models/day0_logs/accuracy/gemma-1.1-7b-it-gpqa50-oot-disabled-repeat-evalscope151-20260915-vs-nv.json`
- `/public-flash/models/day0_logs/accuracy/gemma-prefix-on-ab-20260915-cold.json`
- `/public-flash/models/day0_logs/accuracy/gemma-prefix-on-ab-20260915-warm.json`
- `/public-flash/models/day0_logs/accuracy/gemma-prefix-off-ab-20260915-run1.json`
- `/public-flash/models/day0_logs/accuracy/gemma-prefix-off-ab-20260915-run2.json`
- `/public-flash/models/day0_logs/gemma-1.1-7b-it-serve-20260915-oot-disabled-final-v2.log`

## Light-R1-7B-DS

采用 MATH-500 50 题快速评测（Level 1--5 各 10 题），因为 NV 表没有 Light-R1 的 GPQA 基线，现有基线为 MATH-500=94%。

| 难度 | 得分 |
|---|---:|
| Level 1 | 9/10 = 90% |
| Level 2 | 9/10 = 90% |
| Level 3 | 10/10 = 100% |
| Level 4 | 10/10 = 100% |
| Level 5 | 6/10 = 60% |
| Overall | 44/50 = 88% |

相对 NV：`88% - 94% = -6` 个百分点，按现有 `accuracy_compare.py` 的相对口径为 `6.38%` 退化；两种口径都超过 5%，不达标。

另有 1 题 Level 5 输出达到 `max_tokens=20000`，答案为空并判错。即使该题通过，最多达到 90%，仍需真实复测才能判断，不能直接修正分数。

关键证据：

- `/public-flash/models/day0_logs/accuracy/Light-R1-7B-DS-math500-50-b4-20260914-1832.json`
- `/public-flash/models/day0_logs/accuracy/Light-R1-7B-DS-math500-50-b4-20260914-1832-vs-nv.json`
- 原始 EvalScope 目录：`/models/day0_eval/outputs/math_500/20260914_103129/`

## 工具修复

`release_评测标准/fast_gpqa.py` 已增加：

- OpenAI 多分块 message 的统一文本提取，兼容 `reasoning`/`text` 分块；
- GPQA 显式答案审计，保留 EvalScope 原始分和格式校正分；
- 固定评测并发参数和跳过截断探测参数；
- 评测后 runaway 检测兼容 MATH-500 的分块输出。

本次标准评测环境为 EvalScope 1.5.1。`nv_baseline.yaml` 未保存 NV 原始题目 ID、样本量和预测结果，因此当前只能确认相对仓库中的 NV 记录值达标；若要证明逐题完全同源，还需补齐 NV 原始评测产物。
