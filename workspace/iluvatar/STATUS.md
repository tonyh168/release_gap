# Iluvatar 模型修复状态总览

> 更新：2026-09-16 | 机器：iluvatar-139 + iluvatar-147 | 镜像：`xingchen4-0907`（corex4.5.0 / flagtree0.6.0 / triton3.6.0 / vllm_fl0.24.0）

## 图例

| 标识 | 含义 |
|------|------|
| 🟢 服务运行中 | vLLM 服务已启动，smoke test 通过，待评测 |
| 🟡 评测进行中 | 评测脚本已跑，等待结果 |
| ✅ 已通过 | accuracy_compare 退出码 0 |
| ❌ 精度不达标 | accuracy_compare 退出码 1 |
| ⏭️ 因失败跳过 | 镜像内依赖链缺陷，非模型问题，暂时搁置 |
| 🔵 待开始 | 修复日志已建，尚未动手 |

---

## 状态表

| 模型 | 阶段 | 原始失败类型 | 评测指标 | NV基线 | 当前得分 | 容器 / 端口 | 下一步 |
|------|------|------------|---------|:------:|:-------:|------------|--------|
| LFM2.5-1.2B-Thinking | ✅ 已通过 | 精度不达标（V2 GPQA=2.4%）+ plugin dispatch 报错 | gpqa_diamond | 29.0 | **32.0**（↑3pt，反超基线） | `flagrelease-fix-lfm2.5-1.2b-thinking` / :8000 | 完成，达标（分数取自 evalscope 报告，详见下方 fast_gpqa bug） |
| LFM2.5-1.2B-Instruct | ✅ 已通过 | 精度完全崩溃（V2 GPQA=0.0%） | gpqa_diamond | 29.0 | **40.0**（↑11pt，反超基线） | `flagrelease-fix-lfm2.5-1.2b-instruct` / :8001 | 完成，达标 |
| gemma-1.1-7b-it | ❌ 精度不达标 | 全部数据为空（服务疑似未起） | gpqa_diamond | 37.0 | **22.0**（↓40.5%，差7.5题） | `flagrelease-fix-gemma-1.1-7b-it` / :8002 | 真实退化非噪声；查 chat_template/采样参数/算子精度 |
| OpenThinker-7B | ✅ 已通过 | 评测中断（mmlu 145/1140） | mmlu / math_500 | 77.0 / 88.0 | **75.0 / 86.5**（mmlu↓2.6%，math↓1.7%，均达标） | `flagrelease-fix-openthinker-7b` / :8003 | 完成，达标 |
| AgentCPM-Explore | 🟡 评测进行中 | 服务启动失败（`silu_and_mul` 算子缺失） | gpqa_diamond | 36.0 | — | `flagrelease-fix-agentcpm-explore` / :8008 | 服务重启中（EngineDeadError 崩后重新 detach 启动），待评测 |
| AgentCPM-Report | ❌ 精度不达标 | 精度不达标（V2 GPQA=2.0% vs NV=46.0%，↓95.7%） | gpqa_diamond | 46.0 | **40.0**（↓13.04%，差3题） | `flagrelease-fix-agentcpm-report` / :8004 | 真实退化；需算子级精度排查 |
| Fathom-R1-14B | ❌ 精度不达标 | 精度数据为空 + 性能严重不达标（V1 TTFT=244727ms） | gpqa_diamond | 60.0 | **54.0**（↓10.0%，差3题） | `flagrelease-fix-fathom-r1-14b` / :8002 (u147) | 超容差；需排查（50题小样本可扩样本确认或算子排查） |
| Marco-o1 | ✅ 已通过 | 服务启动失败（Operator crash）+ 精度存疑（V2 GPQA=32.83%） | gpqa_diamond | 32.0 | **28.0**（差2题，噪声容忍达标） | `flagrelease-fix-marco-o1` / :8005 | 完成，达标（小样本噪声区，可扩样本复核） |
| Ministral-8B-Instruct-2410 | ⏭️ 因失败跳过 | 精度不达标（V2/V3 GPQA=28.0% vs NV=30.0%，↓6.7%） | gpqa_diamond | 30.0 | — | — | **镜像 transformers+mistral_common 依赖链缺陷**：`is_vision_available()`=False → `is_mistral_common_available()`=False → mistral tokenizer 模块级 `SpecialTokens` NameError；非模型问题，待换镜像 |
| MiroThinker-v1.5-30B | ❌ 精度不达标 | Operator crash + 全部评测数据为空 | gpqa_diamond | 25.0 | **18.0**（↓28.0%，差3.5题） | `flagrelease-fix-mirothinker-v1.5-30b` / :8001 (u147) | 退化显著；需算子排查 |
| NeuralDaredevil-8B-abliterated | ❌ 精度不达标 | 服务启动失败（Operator crash，原用 FlagGems 5.3.0rc2） | gpqa_diamond | 37.0 | **30.0**（↓18.9%） | `flagrelease-fix-neuraldaredevil-8b-abliterated` / :8006 | 服务已修好，但精度退化>5%；需算子级排查（50题小样本，可复评/扩样本确认） |
| QwQ-32B | ❌ 精度不达标 | 服务启动失败（流程仅 37min，全部数据为空） | gpqa_diamond | 63.0 | **56.0**（↓11.11%，差3.5题） | `flagrelease-fix-qwq-32b` / :8000 (u147) | 超容差；50题小样本（差3.5题），可扩样本复核或算子排查 |
| TinyR1-32B-Preview | 🔵 待开始 | 服务启动失败（无镜像产出，全部数据为空） | gpqa_diamond | 64.0 | — | — | ModelScope 404；HF 网络不通；待确认正确 repo id |

---

## 当前进度快照

- **精度已通过**：4 / 13（LFM2.5-1.2B-Thinking 32.0；LFM2.5-1.2B-Instruct 40.0；Marco-o1 28.0 噪声容忍；OpenThinker-7B mmlu 75.0/math 86.5）
- **精度不达标**：6 / 13（gemma-1.1-7b-it 22.0% vs 37.0；NeuralDaredevil-8B 30.0% vs 37.0；AgentCPM-Report 40.0% vs 46.0；Fathom-R1-14B 54.0% vs 60.0；QwQ-32B 56.0% vs 63.0；MiroThinker-v1.5-30B 18.0% vs 25.0）
- **评测进行中**：1 / 13（AgentCPM-Explore — 服务重启中，待评测）
- **因失败跳过**：1 / 13（Ministral-8B-Instruct-2410）
- **尚未开始**：1 / 13（TinyR1-32B-Preview — ModelScope 404，HF 不通，待确认 repo）

### 🟡 当前评测中的服务

**iluvatar-139**

| 模型 | GPU | 端口 | 数据集 | attention-backend |
|------|:---:|:----:|:------:|:-----------------:|
| LFM2.5-1.2B-Thinking | 0 | 8000 | gpqa_diamond | TRITON_ATTN |
| LFM2.5-1.2B-Instruct | 1 | 8001 | gpqa_diamond | TRITON_ATTN |
| gemma-1.1-7b-it | 2 | 8002 | gpqa_diamond | TRITON_ATTN |
| OpenThinker-7B | 3 | 8003 | mmlu + math_500 | TRITON_ATTN |
| AgentCPM-Report | 4 | 8004 | gpqa_diamond | TRITON_ATTN |
| Marco-o1 | 5 | 8005 | gpqa_diamond | TRITON_ATTN |
| NeuralDaredevil-8B-abliterated | 6 | 8006 | gpqa_diamond | TRITON_ATTN |
| AgentCPM-Explore | 7 | 8008 | gpqa_diamond | TRITON_ATTN |

**iluvatar-147**

| 模型 | GPU | 端口 | 数据集 | attention-backend |
|------|:---:|:----:|:------:|:-----------------:|
| QwQ-32B | 0-3 | 8000 | gpqa_diamond | TRITON_ATTN |
| MiroThinker-v1.5-30B | 4-7 | 8001 | gpqa_diamond | TRITON_ATTN |
| Fathom-R1-14B | 8-9 | 8002 | gpqa_diamond | TRITON_ATTN |

跟踪进度：

```bash
# iluvatar-139 汇总 verdict
ssh iluvatar-139 'for m in LFM2.5-1.2B-Thinking LFM2.5-1.2B-Instruct gemma-1.1-7b-it OpenThinker-7B AgentCPM-Report Marco-o1 NeuralDaredevil-8B-abliterated AgentCPM-Explore; do echo "== $m =="; cat /mnt/share/models/release_run_logs/$m/verdict_*.json 2>/dev/null || tail -3 /mnt/share/models/release_run_logs/$m/eval.log 2>/dev/null || echo "(评测中)"; done'
# iluvatar-147 汇总 verdict
ssh iluvatar-147 'for m in QwQ-32B MiroThinker-v1.5-30B Fathom-R1-14B; do echo "== $m =="; cat /mnt/share/models/release_run_logs/$m/verdict_*.json 2>/dev/null || tail -3 /mnt/share/models/release_run_logs/$m/eval.log 2>/dev/null || echo "(评测中)"; done'
```

评测驱动脚本（本地）：`/tmp/iluvatar_eval_bg.sh`（139）、`/tmp/iluvatar147_eval.sh`（147）

---

## 待修复模型优先级建议

难度从低到高：

1. **Ministral-8B-Instruct-2410** — 差距仅 6.7%，新镜像最可能直接过
2. **Marco-o1** — Operator crash，新镜像 vLLM 0.24.0 升级后可能已修复
3. **NeuralDaredevil-8B-abliterated** — 原用 RC 版 FlagGems，换 5.3.4.post1 后值得重试
4. **AgentCPM-Explore** — `silu_and_mul` 算子，可快速加黑名单隔离
5. **MiroThinker-v1.5-30B** — Operator crash，排查算子后应可起服务
6. **AgentCPM-Report** — 精度崩溃严重（↓95.7%），需逐算子排查
7. **Fathom-R1-14B** — 性能异常（TTFT=244s），需先确认 TP 够用
8. **QwQ-32B** — MLA 架构 32B，`TRITON_MLA` + TP=4，链路复杂
9. **TinyR1-32B-Preview** — 同上，MLA 架构 32B

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
