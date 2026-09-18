# Iluvatar 模型修复状态总览

> 更新：2026-09-18 15:20 | 机器：iluvatar-139 + iluvatar-147 | 镜像：`xingchen4-0907`（corex4.5.0 / flagtree0.6.0 / triton3.6.0 / vllm_fl0.24.0）
>
> **0918 状态收敛**：除 6 个在途/待决模型外，其余 12 个模型已定论——达标者标 ✅ 已通过，未达标者标 ⏭️ 跳过（无需修复），不再投入。所有判定均以机器上 `verdict_*.json`（`aligned` 字段）为证据核对过。

## 图例

| 标识 | 含义 |
|------|------|
| 🟢 服务运行中 | vLLM 服务已启动，smoke test 通过，待评测 |
| 🟡 评测进行中 | 评测脚本已跑，等待结果 |
| ✅ 已通过 | accuracy_compare 退出码 0 |
| ❌ 精度不达标 | accuracy_compare 退出码 1 |
| ⏭️ 跳过（无需修复） | 已尝试但未达标，或因环境/范围原因不再投入；0918 决策，结论已定 |
| 🔵 待开始 | 修复日志已建，尚未动手 |
| 🔧 修复中 | 正在进行算子排查 / 评测迭代，结果待定 |

---

## 状态表

| 模型 | 阶段 | 原始失败类型 | 评测指标 | NV基线 | 当前得分 | 容器 / 端口 | 下一步 |
|------|------|------------|---------|:------:|:-------:|------------|--------|
| LFM2.5-1.2B-Thinking | ✅ 已通过 | 精度不达标（V2 GPQA=2.4%）+ plugin dispatch 报错 | gpqa_diamond | 29.0 | **32.0**（↑3pt，反超基线） | `flagrelease-fix-lfm2.5-1.2b-thinking` / :8000 | 完成，达标（分数取自 evalscope 报告，详见下方 fast_gpqa bug） |
| LFM2.5-1.2B-Instruct | ✅ 已通过 | 精度完全崩溃（V2 GPQA=0.0%） | gpqa_diamond | 29.0 | **40.0**（↑11pt，反超基线） | `flagrelease-fix-lfm2.5-1.2b-instruct` / :8001 | 完成，达标 |
| gemma-1.1-7b-it | ⏭️ 跳过（无需修复） | 全部数据为空（服务疑似未起） | gpqa_diamond | 37.0 | **22.0**（↓40.54%） | `flagrelease-fix-gemma-1.1-7b-it` / :8002 | 已实测，`verdict_gpqa_diamond.json` 判定 `aligned=false`（2026-09-15）；真实退化非噪声。0918 决策不再修复（如需重启：chat_template / 采样参数 / 算子精度） |
| OpenThinker-7B | ✅ 已通过 | 评测中断（mmlu 145/1140） | mmlu / math_500 | 77.0 / 88.0 | **75.0 / 86.5**（mmlu↓2.6%，math↓1.7%，均达标） | `flagrelease-fix-openthinker-7b` / :8003 | 完成，达标 |
| AgentCPM-Explore | ⏭️ 跳过（无需修复） | 服务启动失败（`silu_and_mul` 算子缺失） | gpqa_diamond | 36.0 | — | `flagrelease-fix-agentcpm-explore` / :8008 | 无 verdict。2026-09-16 serve.log 持续 `EngineDeadError`，eval 以 `APIConnectionError` 失败，服务始终未起。0918 决策不再修复 |
| AgentCPM-Report | ✅ 已通过 | 精度不达标（V2 GPQA=2.0% vs NV=46.0%，↓95.7%） | gpqa_diamond | 46.0 | iter1: **40.0%**（↓13.04%）→ iter2: **49.49%**（↑7.59%，198题全量，✅ 反超基线） | `flagrelease-fix-agentcpm-report` / :8002 (u139) | 完成，达标（iter2 TRITON_ATTN，sort,sort_stable；fast_gpqa detect_runaway bug crash，分数从 evalscope 报告 `outputs/gpqa_diamond/20260917_034638` 恢复）。**2026-09-18 已实跑 accuracy_compare 重建 verdict**：exit=0，`aligned=true`；iter1 旧产物保留为 `*_iter1.json` |
| Fathom-R1-14B | ❌ 精度不达标 + 放弃 | 精度数据为空 + 性能严重不达标（V1 TTFT=244727ms） | gpqa_diamond | 60.0 | iter1: **54.0%**（↓10.0%）；iter2/iter3 均因 3.5 tok/s 性能瓶颈中止 | — | 最终结论：放弃。BI-V150 对该 14B reasoning 模型存在固有性能瓶颈（3.5 tok/s，正常应 100+ tok/s），198题 ETA 50h 不可接受 |
| Marco-o1 | ✅ 已通过 | 服务启动失败（Operator crash）+ 精度存疑（V2 GPQA=32.83%） | gpqa_diamond | 32.0 | **28.0**（差2题，噪声容忍达标） | `flagrelease-fix-marco-o1` / :8005 | 完成，达标（小样本噪声区，可扩样本复核） |
| Ministral-8B-Instruct-2410 | ⏭️ 跳过（无需修复） | 精度不达标（V2/V3 GPQA=28.0% vs NV=30.0%，↓6.7%） | gpqa_diamond | 30.0 | — | — | **镜像 transformers+mistral_common 依赖链缺陷**：serve.log 报 `name 'SpecialTokens' is not defined` → 服务根本未起，无 verdict。非模型问题，0918 决策不再修复 |
| MiroThinker-v1.5-30B | 🟡 评测进行中 | Operator crash + 全部评测数据为空 | gpqa_diamond | 25.0 | **18.0**（iter1，↓28.0%，差3.5题）；iter2 进行中 | `flagrelease-fix-mirothinker-v1.5-30b` GPU 4-7 / :8001 (u147) | iter1 退化显著；2026-09-18 12:01 重启（TRITON_ATTN，sort,sort_stable，TP=4）；iter2 GPQA eval 运行中（pid 1282）。**吞吐异常**：3/50 耗时 2h42m（~41min/题，ETA 32h），疑似 Fathom 同类性能瓶颈 |
| NeuralDaredevil-8B-abliterated | ⏭️ 跳过（无需修复） | 服务启动失败（Operator crash，原用 FlagGems 5.3.0rc2） | gpqa_diamond | 37.0 | iter1: **30.0%**（↓18.92%）；iter2: **22.0%**（↓40.54%） | `flagrelease-fix-neuraldaredevil-8b-abliterated` GPU 1 / :8006 (u139) | 两轮 verdict 均 `aligned=false`。iter2 结论：mm/addmm 不可黑名单化；`sort,sort_stable` 必需但精度差距根因未定位。0918 决策不再修复 |
| QwQ-32B | ⏭️ 跳过（无需修复） | 服务启动失败（流程仅 37min，全部数据为空） | gpqa_diamond | 63.0 | **56.0%**（50题，↓11.11%） | `flagrelease-fix-qwq-32b` 已停 (u147) | 已实测，verdict 判定 `aligned=false`（2026-09-15）；数量已够，0918 决策不再修复；容器已停 |
| TinyR1-32B-Preview | 🔧 修复中 | 服务启动失败（无镜像产出，全部数据为空） | gpqa_diamond | 64.0 | iter1: **58.0%**（50题，↓9.38%） | `flagrelease-fix-tinyr1-32b-preview` GPU 3,4,7,8 / :8001 (u139) | iter2 评测中（sort,sort_stable,mm,addmm，TRITON_ATTN，TP=4）；2026-09-18 15:00 进度 32/50 |
| Phi-3-medium-128k-instruct | ⏭️ 跳过（无需修复） | 服务启动失败（原 vLLM 0.20.2 Operator crash，全部数据为空） | gpqa_diamond | 37.0 | **24.0%**（↓35.14%） | `flagrelease-fix-phi3-medium` GPU 0 / :8009 (u139) | iter3（17算子黑名单）得分仍 24.0%，三次完全相同，verdict 判定 `aligned=false`；算子黑名单路径彻底排查完毕。0918 决策不再修复（如需重启：chat_template / dtype） |
| Qwen3-30B-A3B-Thinking-2507 | ✅ 已通过 | Operator crash: mm on unknown platform（V2/V3 全空） | gpqa_diamond | 75.0 | **76.0**（↑1.33%，反超基线） | `flagrelease-fix-qwen3-30b-a3b-thinking` GPU 4-7 / :8010 (u139) | 完成，达标（score=null 从 evalscope 报告恢复；blacklist=sort,sort_stable,mm，TP=4） |
| OpenReasoning-Nemotron-1.5B | ❌ 精度不达标 + 放弃 | 权重下载中 | mmlu / math_500 | 52.21 / 84.0 | mmlu **35.0%**（↓32.9%）；math_500 已中止 | — | **放弃**：mmlu 差距 17.21 分（↓32.9%），远超 5% 容差；graph 模式亦 OOM（9/51 graphs 后 VRAM 耗尽）；容器已停 |
| Phi-4-mini-reasoning | ❌ 精度不达标 | 未开始 | mmlu / math_500 | 72.83 / 88.2 | mmlu **58.07%**（↓20.3%）/ math_500 **41.0%**（↓53.5%） | `flagrelease-fix-phi4-mini-reasoning` GPU 2 / :8012 (u139) | iter1：sort,sort_stable 黑名单，TRITON_ATTN，TP=1；双指标严重不达标；分数从 evalscope 报告恢复（mmlu: `outputs/mmlu/20260917_033152`，math_500: `outputs/math_500/20260917_102103`） |
| Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled | 🔧 修复中 | 未开始 | gpqa_diamond | 75.0 | iter1: **70.0**（↓6.67%，差2.5题）| `flagrelease-fix-qwen3.5-27b` GPU 5,6 / :8014 (u139) | iter2 评测中（sort,sort_stable,mm,addmm，TRITON_ATTN，TP=2）；2026-09-18 15:00 进度 33/50 |

---

## 当前进度快照

> 更新：2026-09-18 15:20（0918 状态收敛）

除下列 6 个在途/待决模型外，其余 12 个已**定论**：

- **✅ 精度已通过：6 / 18** — LFM2.5-1.2B-Thinking（32.0 vs 29.0）、LFM2.5-1.2B-Instruct（40.0 vs 29.0）、OpenThinker-7B（mmlu 75.0/77.0 + math 86.5/88.0）、Marco-o1（28.0 vs 32.0，小样本噪声容忍）、Qwen3-30B-A3B-Thinking-2507（76.0 vs 75.0）、AgentCPM-Report（49.49 vs 46.0，198题全量）
- **⏭️ 跳过（无需修复）：6 / 18** — gemma-1.1-7b-it（22.0 vs 37.0）、NeuralDaredevil-8B-abliterated（30.0→22.0 vs 37.0）、Phi-3-medium-128k-instruct（24.0 vs 37.0）、QwQ-32B（56.0 vs 63.0）、AgentCPM-Explore（服务未起）、Ministral-8B-Instruct-2410（镜像依赖链缺陷）
- **6 个在途/待决（本次未改）** — 见下表

### 🟡 6 个在途/待决模型

| 模型 | 状态 | 当前 | NV | 说明 |
|------|------|:----:|:--:|------|
| TinyR1-32B-Preview | 🔧 iter2 评测中 | iter1 58.0% | 64.0 | u139，32/50 进度 |
| Qwen3.5-27B-Distilled | 🔧 iter2 评测中 | iter1 70.0% | 75.0 | u139，33/50 进度 |
| MiroThinker-v1.5-30B | 🔧 iter2 评测中（异常慢） | iter1 18.0% | 25.0 | u147，3/50，~41min/题，ETA 32h |
| Phi-4-mini-reasoning | ❌ 待决 | mmlu 58.07% / math 41.0% | 72.83 / 88.2 | 双指标严重不达标 |
| Fathom-R1-14B | ❌ 已放弃 | 54.0% | 60.0 | BI-V150 固有性能瓶颈 3.5 tok/s |
| OpenReasoning-Nemotron-1.5B | ❌ 已放弃 | mmlu 35.0% | 52.21 | 差距 17.21 分远超容差；graph 模式 OOM |


### 🟡 当前服务运行状态

**iluvatar-139**

| 模型 | GPU | 端口 | 数据集 | attention-backend | 状态 |
|------|:---:|:----:|:------:|:-----------------:|------|
| LFM2.5-1.2B-Thinking | 0 | 8000 | gpqa_diamond | TRITON_ATTN | ✅ 完成 |
| LFM2.5-1.2B-Instruct | 1 | 8001 | gpqa_diamond | TRITON_ATTN | ✅ 完成 |
| gemma-1.1-7b-it | 2 | 8002 | gpqa_diamond | TRITON_ATTN | ⏭️ 跳过（22.0%，不达标，不再修复） |
| OpenThinker-7B | 3 | 8003 | mmlu + math_500 | TRITON_ATTN | ✅ 完成 |
| AgentCPM-Report | 4 | 8004 | gpqa_diamond | TRITON_ATTN | ✅ 完成（iter2 49.49%，达标） |
| Marco-o1 | 5 | 8005 | gpqa_diamond | TRITON_ATTN | ✅ 完成 |
| NeuralDaredevil-8B-abliterated | 6 | 8006 | gpqa_diamond | TRITON_ATTN | ⏭️ 跳过（iter1 30.0% / iter2 22.0%，不达标，不再修复） |
| OpenReasoning-Nemotron-1.5B | 1 | 8011 | mmlu + math_500 | TRITON_ATTN | ❌ **放弃**（mmlu 35.0%，↓32.9%；graph 模式 OOM；容器已停，GPU 1 空闲） |
| Phi-3-medium-128k-instruct | 0 | 8009 | gpqa_diamond | TRITON_ATTN | ⏭️ 跳过（iter3 24.0%，三次相同，不再修复） |
| Qwen3-30B-A3B-Thinking-2507 | 4-7 | 8010 | gpqa_diamond | TRITON_ATTN | ✅ 完成（GPQA 76.0%，NV 75.0%，↑1.33%） |
| Phi-4-mini-reasoning | 2 | 8012 | mmlu + math_500 | TRITON_ATTN | ❌ 完成（mmlu 58.07% / math_500 41.0%，双指标严重不达标） |
| TinyR1-32B-Preview | 3,4,7,8 | 8001 | gpqa_diamond | TRITON_ATTN | 🔧 iter2 评测中（iter1 58.0%，NV 64.0%） |
| Qwen3.5-27B-Distilled | 5,6 | 8014 | gpqa_diamond | TRITON_ATTN | 🔧 iter2 评测中（iter1 70.0%，NV 75.0%） |

**iluvatar-147**

| 模型 | GPU | 端口 | 数据集 | attention-backend | 状态 |
|------|:---:|:----:|:------:|:-----------------:|------|
| QwQ-32B | 0-3 | 8000 | gpqa_diamond | TRITON_ATTN | ⏭️ 跳过（无需修复；56.0% vs 63.0） |
| MiroThinker-v1.5-30B | 4-7 | 8001 | gpqa_diamond | TRITON_ATTN | 🟡 iter2 GPQA eval 运行中（pid 1282），**3/50 已耗时 2h42m（~41min/题，ETA 32h）** |

跟踪进度：

```bash
# iluvatar-139 汇总 verdict（已定论模型）
ssh iluvatar-139 'for m in LFM2.5-1.2B-Thinking LFM2.5-1.2B-Instruct gemma-1.1-7b-it OpenThinker-7B AgentCPM-Report Marco-o1 NeuralDaredevil-8B-abliterated Phi-3-medium-128k-instruct Qwen3-30B-A3B-Thinking-2507; do echo "== $m =="; for v in /mnt/share/models/release_run_logs/$m/verdict*.json; do [ -f "$v" ] && python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(\" \",sys.argv[1].split(\"/\")[-1],d[\"current\"].get(\"score\"),\"aligned=\",d.get(\"aligned\"))" "$v"; done; done'
# 在途模型单独看
ssh iluvatar-139 'for m in TinyR1-32B-Preview Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled; do echo "== $m =="; grep -aoE "Evaluating\[gpqa_diamond\]:[ ]+[0-9]+%[^A]*" /mnt/share/models/release_run_logs/$m/eval_gpqa_iter2.log | tail -1; done'
# iluvatar-147（MiroThinker 真实进度在 evalscope 目录，不在 release_run_logs）
ssh iluvatar-147 'docker exec eval-scope bash -c "ls -t /workspace/eval_scripts/outputs/gpqa_diamond/ | head -1"'
```

评测驱动脚本（本地）：`/tmp/iluvatar_eval_bg.sh`（139）、`/tmp/iluvatar147_eval.sh`（147）

---

## 剩余待决模型（0918 后）

0918 收敛后，不达标的 6 个模型已统一标为 ⏭️ 跳过（无需修复），**不再投入**。本节仅保留 6 个仍待处理的模型，按是否值得继续投入排序：

| 模型 | 差距 | 建议 |
|------|------|------|
| Qwen3.5-27B-Distilled | 70.0 vs 75.0（↓6.67%，差 2.5 题） | **iter2 评测中**，最接近达标，优先看结果 |
| TinyR1-32B-Preview | 58.0 vs 64.0（↓9.38%） | **iter2 评测中** |
| Phi-4-mini-reasoning | mmlu ↓20.3% / math ↓53.5% | 双指标严重不达标，需判断是否值得重开 |
| MiroThinker-v1.5-30B | 18.0 vs 25.0（↓28.0%） | iter2 运行中但吞吐异常（41min/题，ETA 32h）；建议比照 Fathom 判为性能瓶颈放弃 |
| Fathom-R1-14B | 54.0 vs 60.0 | 已放弃：BI-V150 对该 14B reasoning 模型固有性能瓶颈（3.5 tok/s） |
| OpenReasoning-Nemotron-1.5B | mmlu 35.0 vs 52.21 | 已放弃：差距远超容差，graph 模式 OOM |

> **历史参考**（0918 前的难度排序，现已作废）：Ministral-8B → Marco-o1 → NeuralDaredevil-8B → AgentCPM-Explore → MiroThinker → AgentCPM-Report → Fathom → QwQ-32B → TinyR1-32B。其中 AgentCPM-Report（49.49% ✅）、Marco-o1（噪声容忍 ✅）已达标，其余已跳过。

---

## 已知问题：fast_gpqa.py detect_runaway 崩溃（已修）

- **现象**：thinking 模型评测跑完、evalscope 已算出分数，但 `fast_gpqa.py` 在收尾的 `analyze_predictions_runaway → detect_runaway` 报 `AttributeError: 'list' object has no attribute 'strip'`（line 370），导致 result JSON 未写出、compare 未跑。
- **根因**：thinking 模型 `message.content` 是多段结构（list），`detect_runaway` 直接 `(text or "").strip()` 假设是 str。
- **修复**：`detect_runaway` 开头加 list→str 归一（本地 + NFS `eval_methods/fast_gpqa.py` 已更新）。
- **影响与兜底**：崩溃发生在算分之后，分数仍在 evalscope 原始报告 `outputs/<dataset>/<ts>/reports/<model>/<dataset>.json`（字段 `metrics[0].score`，×100 即百分比）。已崩的可从报告重建 result JSON 再跑 compare（LFM2.5-1.2B-Thinking 即如此，32.0%）。
- **注意**：本轮启动时仍在跑的 OpenThinker-7B / AgentCPM-Report / AgentCPM-Explore 用的是**打补丁前**加载进内存的旧代码，若命中 list content 仍会崩；届时同样从 evalscope 报告重建即可（无需重跑）。

---

> 各模型修复日志：`workspace/iluvatar/fixes/<模型名>.md`
> 评测产出目录：`/mnt/share/models/release_run_logs/<模型名>/`
> 评测脚本（本地）：`/tmp/iluvatar_eval4.sh`
