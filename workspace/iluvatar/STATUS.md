# Iluvatar 模型修复状态总览

> 更新：2026-09-19 14:20（收完 4 个后台复评，转入「剩余 4 个模型」的继续修复）| 机器：iluvatar-139 + iluvatar-147 | 镜像：`xingchen4-0907`

## 当前计数

**8 通过 / 6 跳过 / 4 待继续修复（其中 1 个复评仍在途）= 18**

- **✅ 已通过（8）**、**⏭️ 跳过无需修复（6）**：见状态表，**均以机器上 `verdict_*.json` 的 `aligned` 字段核对过**
- **🔧 剩余 4 个、待继续修复**（3 个已有 `verdict_*.json` 且 exit=1，1 个复评进行中；**每个都有明确的下一步**）：
  - ⏸️ **MiroThinker-v1.5-30B** — iter3 **已人工中止**（31/50）。部分口径 **29.0%（9/31）**；
    拆分后**撞顶 23 题只对 1 题（4.3%）/ 正常收尾 8 题全对（100%）** → 瓶颈在输出预算，不在模型能力
  - ❌ **OpenReasoning-Nemotron-1.5B** — math_500 **76.0%** vs 84.0%（↓9.52%）。
    **iter4 抬 `max_tokens` 到 65536 → 无效（76.5%→76.0%）**，**截断假设被证伪**。
    **五项假设（权重/上下文/并发/采样/截断）已全部排除**，剩余差距无法归因
  - ❌ **Phi-4-mini-reasoning** — math_500 **62.0%** vs 88.2%（↓29.71%）。
    **iter4 按 README 改采样 → 复读 31→2（−94%）但分数只 +2.5pt**，**采样假设被证伪**（非主因）。
    截断与采样两项修复均已实测，剩余差距同样无法归因
  - ❌ **Fathom-R1-14B** — GPQA **54.0%** vs 60.0%（↓10.0%）+ 解码仅 **3.49 tok/s**（198 题 ETA 50h）
- **⚠️ QwQ-32B 未受本次 bug 影响**：名字含 `qwq` 命中 thinking 判定，
  日志实测 `thinking (temperature=0.6)`，采样配置正确。

> 🔴 **iter4 的结论（2026-09-19 晚，重要）**：两个模型的"最可疑根因"**都被实测推翻了** ——
> OpenReasoning 不是截断，Phi-4-mini 不是采样。**两者都在排除法上走到了尽头**
> （各自 4~5 项假设全部排除），剩余差距 **9.52% / 29.71% 目前无法归因**，
> 嫌疑指向**算子精度**，但**无直接证据**。详见两份 fix log 的「定位」节。

> ⚠️ **4 个复评全部命中 `detect_runaway` 的 list-content 崩溃**（`fast_gpqa.py:370`
> `AttributeError: 'list' object has no attribute 'strip'`），`score` 未写出，分数是从 evalscope 报告
> `outputs/<ds>/<ts>/reports/<model>/<ds>.json` 的 `metrics[0].score` 恢复的。
> **TinyR1 / OpenReasoning / Phi-4-mini 的 verdict 均已重建**（TinyR1 exit=0，另两个 exit=1）。
> iter4 的两个评测（2026-09-19 晚）**同样命中该崩溃**，分数同样从报告恢复。

## 本次 session 新发现（重要，影响判读）

1. **`detect_thinking()` 误判**（见下方专节）：多个推理模型被按贪心解码评测。
   **0919 实测结论：影响是 per-model 的，且"修正采样"往往不是解药**：
   - **TinyR1**：✅ **成立**（58.0%→62.0%，达标）→ ✅ 已通过
   - **OpenReasoning**：❌ **不成立**（76.5%→73.5%，反而更低）。后续 iter4 又证伪了"截断"，
     → **既非采样也非截断**，剩余 9.52% 无法归因
   - **Phi-4-mini**：⚠️ **行为成立、分数不成立** —— 应用 README 的 0.8/0.95 后复读 31→2（−94%）、
     撞顶 32→9（−72%），**但分数只 +2.5pt**（59.5%→62.0%）→ **复读在掩盖错误，不是制造错误**
   - **Fathom**：**也中招**（名字不命中 `deepseek-r1`，README 推荐 0.6/0.95 却用 0.0），
     但它的性能瓶颈是决定性的，修正采样也不改变处置，见 `fixes/Fathom-R1-14B.md`
   - **MiroThinker**：iter3 **采样已与模型推荐完全一致**（含服务端补的 `top_k=20`），
     但撞顶 77%→74%、解码 3.39→3.65 tok/s **均未改善** → **采样不是原因**
   - 📌 **共同教训**：**"采样配置不对"是一个容易成立、但很少是根因的假设。**
     5 个模型里只有 TinyR1 靠它达标。**改动前必须实跑对照，不能靠推理。**
2. **`phi3 + longrope` 的 `max_model_len` 自动推导缺陷**：vLLM 推导成 4096（模型实际支持 131072），
   致 `max_tokens` 被压到 2048、Phi-4-mini 超半数题截断。**修复=显式 `--max-model-len 32768`**。
   **0919 验证有效**：math_500 41.0% → 59.5%（+18.5pt）。
   ⚠️ **iter1 的 mmlu 58.07% / math_500 41.0% 两个数字都受 2048 截断污染**（撞顶 26% / 56%），
   引用时必须带此前提。
3. **并发上限必须按 KV cache 算，不能按参数量猜**：
   - Phi-4-mini（3.8B，全 MHA）KV cache 仅 **160,353** tokens → 32K 上下文下最多 **4.89 并发**，
     32 并发直接打崩（KV 100%、Waiting 排队、38 分钟 1 题）。
   - OpenReasoning（1.5B，GQA）KV cache **919,360** tokens → 32 并发只用 38%，健康。
   - **小参数模型的 KV cache 反而可能远小于大模型**（取决于 MHA/GQA 结构，非参数量）。
4. **切 `thinking` 模式不只是改采样温度**：`max_tokens` 会被 thinking 公式压到 **20000**（从 32768 收紧），
   并给 evalscope 加 `remove_until='</think>'` 过滤器。做对照实验时必须把这 2 个连带变化计入变量，
   否则会把"输出上限收紧"的负面影响误记到采样改动上。TinyR1 iter3 因此有 9/50 撞顶（比 iter1/iter2 的 8 题更多）。
   ⚠️ **对 chat_template 不含 `<think>` 的模型（如 Phi-4-mini）不能照抄这个修法**，
   应只覆写采样参数、保持 standard 分支。
5. **"排除撞 max_tokens 的题再看分数" —— 这个指标只能诊断，不能估计能力（`iter4` 修正）**。
   它曾让我们以为 OpenReasoning"只差输出预算"（排除撞顶后 90.0% > 基线）；
   但 iter4 把上限翻倍后**分数纹丝不动（76.5%→76.0%）**，且 30 道撞顶题里有 **20 题给了 2 倍预算仍撞顶**。
   **那些题是死循环，不是"差一点就写完" —— 排除它们得到的是幸存者偏差。**
   （反例对照：该指标在 TinyR1 上成立，因为那里复读题在正确采样下确实收敛了。**要分模型判断。**）
   `fast_gpqa` 自己封顶（standard `clamp(max_model_len-8192, 4096, 32768)`、
   thinking `clamp(…, 8192, 20000)`），与服务端 `max_model_len` 无关；**但放开它不一定有用**。
6. **"修好了明显的问题"≠"分数会上来"**：Phi-4-mini 的复读从 **31 降到 2（−94%）**、撞顶 **32→9（−72%）**，
   行为上极其成功，**但分数只 +2.5pt**，且"排除撞顶后"的分数**反而从 69.6% 降到 64.9%**。
   **复读只是在掩盖错误，不是在制造错误。** 只看"复读消失了"就宣布修好，会得出完全错误的结论。
7. **MiroThinker 的"假瓶颈"旧结论已修正**：iter1 有 77~90% 的题撞满输出上限、尾部为复读，
   当时判为"复读空转造成的假瓶颈"。**iter3 换成正确采样（0.6/0.95）后撞顶率 77%→74%、
   解码速率 3.39→3.65 tok/s，都没有改善** → **复读真实存在，但慢是独立的第二个问题。**
   - **"是否复读"与"解码快不快"是两个独立指标**：复读看撞顶占比/runaway 检测，
     吞吐看 `1/tpot`（与输出长度无关）。**Fathom 是"慢但不复读"，MiroThinker 是"又慢又复读"。**
   - **14B dense（`qwen2`）与 30B MoE（`qwen3_moe`）两种架构都落在 ~3.5 tok/s**
     → 先怀疑平台/算子层（MoE 算子在本镜像走 `default.flagos` 通用回退），
     **不要逐个模型怀疑模型本身**。本轮未定位到具体算子，不下结论。

8. **判读实际采样要同时看两处**：evalscope 请求参数 **+ 服务端 `model.py:1477` 警告**。
   `top_k` 这类参数 evalscope 可能根本不发，由 vLLM 从模型 `generation_config.json` 补齐
   （MiroThinker 的 `top_k=20` 即如此）。**只看请求 payload 会漏判。**
   ⚠️ 由此需修正早先的说法：**"`generation_config.json` 覆盖机制失效"只对 `fast_gpqa` 的客户端路径成立**
   （`_resolve_model_dir()` 两条路径不通）；**服务端 vLLM 那条路是通的**。

> **0918/0919 状态收敛**：达标者标 ✅ 已通过，未达标者标 ⏭️ 跳过（无需修复），不再投入。
> 所有判定均以机器上 `verdict_*.json`（`aligned` 字段）为证据核对过。
> **剩余 4 个模型转入"继续修复"，各自的可执行下一步见「剩余 4 个模型（继续修复）」节。**

## 图例

| 标识 | 含义 |
|------|------|
| 🟢 服务运行中 | vLLM 服务已启动，smoke test 通过，待评测 |
| 🟡 评测进行中 | 评测脚本已跑，等待结果 |
| ✅ 已通过 | accuracy_compare 退出码 0 |
| ❌ 精度不达标 | accuracy_compare 退出码 1 |
| ⏭️ 跳过（无需修复） | 已尝试但未达标，或因环境/范围原因不再投入；0918 决策，结论已定 |
| 🔧 待继续修复（verdict exit=1） | 复评/verdict 已完成且不达标，**但有明确的下一步**（见「剩余 4 个模型」节），不判"跳过" |
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
| Fathom-R1-14B | 🔧 待继续修复 | 精度数据为空 + 性能严重不达标（V1 TTFT=244727ms） | gpqa_diamond | 60.0 | iter1: **54.0%**（↓10.0%，**贪心解码，口径不对等**）；iter2/iter3 均因 3.49 tok/s 中止 | `flagrelease-fix-fathom-r1-14b` / :8002 (u147) → :8003 (u139) | 已放弃，但若继续修复：**(a)** 按 README 的 0.6/0.95 重测精度（`Fathom-R1-14B` 也命中 `detect_thinking` 误判）；**(b)** 吞吐排查顺序 = `--max-model-len` 降到 32768 → 去 `--enforce-eager` → 查 MoE/算子后端。**已验证与黑名单无关**（换机复现）。详见 fix log |
| Marco-o1 | ✅ 已通过 | 服务启动失败（Operator crash）+ 精度存疑（V2 GPQA=32.83%） | gpqa_diamond | 32.0 | **28.0**（差2题，噪声容忍达标） | `flagrelease-fix-marco-o1` / :8005 | 完成，达标（小样本噪声区，可扩样本复核） |
| Ministral-8B-Instruct-2410 | ⏭️ 跳过（无需修复） | 精度不达标（V2/V3 GPQA=28.0% vs NV=30.0%，↓6.7%） | gpqa_diamond | 30.0 | — | — | **镜像 transformers+mistral_common 依赖链缺陷**：serve.log 报 `name 'SpecialTokens' is not defined` → 服务根本未起，无 verdict。非模型问题，0918 决策不再修复 |
| MiroThinker-v1.5-30B | ⏸️ 已中止（待重跑） | Operator crash + 全部评测数据为空 | gpqa_diamond | 25.0 | iter1: **18.0%**（50题全量）；iter3 **部分 29.0%（9/31，口径不完整）** | `flagrelease-fix-mirothinker-v1.5-30b` GPU 4-7 / :8001 (u147) | iter3 **已人工中止**（31/50，14:2x，数据已存档）。**三个已确认结论**：① 采样**已与模型推荐完全一致**（0.6/0.95 + 服务端补的 top_k=20），74% 照样撞顶 → **采样不是原因**；② 解码仅 **3.65 tok/s**，是独立于复读的第二个问题；③ **撞顶 23 题只对 1 题 / 正常收尾 8 题全对** → 瓶颈在输出预算。**重跑方向：抬 `max_tokens` 到 65536 优先，其次按序试 `--max-model-len` 降 32768 → 去 `--enforce-eager` → 查 MoE 后端** |
| NeuralDaredevil-8B-abliterated | ⏭️ 跳过（无需修复） | 服务启动失败（Operator crash，原用 FlagGems 5.3.0rc2） | gpqa_diamond | 37.0 | iter1: **30.0%**（↓18.92%）；iter2: **22.0%**（↓40.54%） | `flagrelease-fix-neuraldaredevil-8b-abliterated` GPU 1 / :8006 (u139) | 两轮 verdict 均 `aligned=false`。iter2 结论：mm/addmm 不可黑名单化；`sort,sort_stable` 必需但精度差距根因未定位。0918 决策不再修复 |
| QwQ-32B | ⏭️ 跳过（无需修复） | 服务启动失败（流程仅 37min，全部数据为空） | gpqa_diamond | 63.0 | **56.0%**（50题，↓11.11%） | `flagrelease-fix-qwq-32b` 已停 (u147) | 已实测，verdict 判定 `aligned=false`（2026-09-15）；数量已够，0918 决策不再修复；容器已停 |
| TinyR1-32B-Preview | ✅ 已通过 | 服务启动失败（无镜像产出，全部数据为空） | gpqa_diamond | 64.0 | iter1: 58.0%（贪心）→ iter2（+mm,addmm）: 58.0%（与 iter1 完全相同）→ **iter3（thinking + 0.6/0.95）: 62.0%**（↓3.12%，runaway 6→2） | `flagrelease-fix-tinyr1-32b-preview` GPU 3,4,7,8 / :8001 (u139) | iter2 证明 `mm,addmm` 黑名单**无效**；根因确认为**采样配置错误**（`detect_thinking` 误判为 standard → 贪心解码 → 复读）→ iter3 thinking + 0.6/0.95 复评完成，`verdict_gpqa_iter3.json` 实测 exit=0 / aligned=true。详见 fix log「评测参数的影响」节 |
| Phi-3-medium-128k-instruct | ⏭️ 跳过（无需修复） | 服务启动失败（原 vLLM 0.20.2 Operator crash，全部数据为空） | gpqa_diamond | 37.0 | **24.0%**（↓35.14%） | `flagrelease-fix-phi3-medium` GPU 0 / :8009 (u139) | iter3（17算子黑名单）得分仍 24.0%，三次完全相同，verdict 判定 `aligned=false`；算子黑名单路径彻底排查完毕。0918 决策不再修复（如需重启：chat_template / dtype） |
| Qwen3-30B-A3B-Thinking-2507 | ✅ 已通过 | Operator crash: mm on unknown platform（V2/V3 全空） | gpqa_diamond | 75.0 | **76.0**（↑1.33%，反超基线） | `flagrelease-fix-qwen3-30b-a3b-thinking` GPU 4-7 / :8010 (u139) | 完成，达标（score=null 从 evalscope 报告恢复；blacklist=sort,sort_stable,mm，TP=4） |
| OpenReasoning-Nemotron-1.5B | 🔧 待继续修复 | 无原始失败报告（后补评测对象） | mmlu / math_500 | 52.21 / 84.0 | mmlu 35.0%（iter1）; math_500 76.5%（iter2）→ 73.5%（iter3 thinking）→ **76.0%（iter4 抬 mt=65536，↓9.52%）** | `flagrelease-fix-openreasoning-nemotron-1.5b` GPU 0 / :8011 (u139) | **五项假设全部排除**（权重 sha256 一致 / 上下文 131072 / 并发 / 采样 iter3 反降 / **截断 iter4 抬上限无效**）。`verdict_math500_iter4.json` exit=1。**下一步：查算子精度（逐组开关黑名单做对照）；mmlu 需干净重测**。⚠️ 别再调 max_tokens/采样 |
| Phi-4-mini-reasoning | 🔧 待继续修复 | 无原始失败报告（后补评测对象） | mmlu / math_500 | 72.83 / 88.2 | mmlu 58.07%（iter1，**受 2048 截断污染**）/ math_500 41.0%（同污染）→ 59.5%（iter3，`--max-model-len 32768` + c8）→ **62.0%（iter4，T=0.8/0.95，↓29.71%）** | `flagrelease-fix-phi4-mini-reasoning` GPU 9 / :8012 (u139) | **截断已修**（+18.5pt）；**采样已修但只 +2.5pt** —— 复读 31→2（−94%）、撞顶 32→9（−72%），**行为改善巨大但分数没上来** → **采样不是主因**。`verdict_math500_iter4.json` exit=1。**下一步：查算子精度；mmlu 需干净重测**。⚠️ 别再调采样/max_model_len |
| Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled | ✅ 已通过 | 未开始 | gpqa_diamond | 75.0 | iter1: **70.0**（↓6.67%）→ iter2: **80.0**（↑6.67%，反超基线）| `flagrelease-fix-qwen3.5-27b` GPU 5,6 / :8014 (u139) | 完成，达标。iter2 配置：sort,sort_stable,mm,addmm，TRITON_ATTN，TP=2，`--max-model-len 65536`（iter1 为 8192，把 max_tokens 压到 4096）。verdict 为 2026-09-18 实跑重建（`verdict_gpqa_iter2.json`，exit=0） |

---

## 当前进度快照

> 更新：2026-09-19 21:05（OpenReasoning / Phi-4-mini 的 iter4 已出结果，**两项假设均被证伪**）

- **✅ 精度已通过：8 / 18** — LFM2.5-1.2B-Thinking（32.0 vs 29.0）、LFM2.5-1.2B-Instruct（40.0 vs 29.0）、OpenThinker-7B（mmlu 75.0/77.0 + math 86.5/88.0）、Marco-o1（28.0 vs 32.0，小样本噪声容忍）、Qwen3-30B-A3B-Thinking-2507（76.0 vs 75.0）、AgentCPM-Report（49.49 vs 46.0，198题全量）、Qwen3.5-27B-Distilled（80.0 vs 75.0，iter2 反超）、**TinyR1-32B-Preview（62.0 vs 64.0，iter3 thinking+0.6/0.95 达标）**
- **⏭️ 跳过（无需修复）：6 / 18** — gemma-1.1-7b-it（22.0 vs 37.0）、NeuralDaredevil-8B-abliterated（30.0→22.0 vs 37.0）、Phi-3-medium-128k-instruct（24.0 vs 37.0）、QwQ-32B（56.0 vs 63.0）、AgentCPM-Explore（服务未起）、Ministral-8B-Instruct-2410（镜像依赖链缺陷）
- **🔧 剩余 4 个、待继续修复：4 / 18** — 见下节

### 🔧 剩余 4 个模型（继续修复）—— 状态与可执行下一步

> 4 个都已有 `verdict_*.json`（或原始 verdict），**均 exit=1**；但每一个都有**明确的下一步**，
> 因此不判「跳过」。详细记录见各自的 fix log。

| 模型 | 最新分数 | NV | 已确认的根因 | **下一步（可执行）** |
|------|:-------:|:--:|------------|---------------------|
| **OpenReasoning-Nemotron-1.5B** | math_500 **76.0%**（iter4） | 84.0 | ⚠️ **截断假设被 iter4 证伪**（抬上限 65536 无效）；**五项假设全部排除** | ⬜ **查算子精度**（逐组开关黑名单做对照）；⬜ mmlu 需干净重测。**不要再调 max_tokens / 采样** |
| **Phi-4-mini-reasoning** | math_500 **62.0%**（iter4） | 88.2 | ⚠️ **采样假设被 iter4 证伪**（复读 31→2 但只 +2.5pt）；截断已修 | ⬜ **查算子精度**；⬜ mmlu 需干净重测。**不要再调采样 / max_model_len** |
| **MiroThinker-v1.5-30B** | iter1 **18.0%**；iter3 部分 29.0%（9/31） | 25.0 | ① 反复读（74~90% 撞顶）② **解码仅 3.65 tok/s**（独立问题） | ⏸️ iter3 已人工中止（数据已存档）。重跑方向：**抬 `max_tokens`** + 吞吐三实验（`--max-model-len` 降 32768 → 去 `--enforce-eager` → 查 MoE 后端） |
| **Fathom-R1-14B** | GPQA **54.0%** | 60.0 | **解码仅 3.49 tok/s**（与黑名单无关，换机复现）；精度口径不对等 | **(a)** 按 README 的 0.6/0.95 重测精度；**(b)** 与 MiroThinker 共用同一套吞吐实验 |

> **2026-09-19 14:30 全部容器已按要求停止**（139 + 147 所有项目容器 `docker stop`，未删除，文件系统保留）。
> 随后为两个 iter4 评测重启了 139 上的 3 个容器（`openreasoning` GPU 0:8011 / `phi4-mini` GPU 9:8012 / `eval-scope`），
> **147 上所有容器保持停止**。
> **iter4 已于 2026-09-19 20:45 前后跑完**（两个都 200/200 完成，收尾同样命中 `detect_runaway` 崩溃，
> 分数已从 evalscope 报告恢复、verdict 已重建）。
> ⚠️ **当前这三个容器仍在运行**，待用户指示是否停止。
>
> iter4 的 wrapper 在容器内 `/tmp/`（`openreason_maxtok.py` / `phi4mini_sampling.py`），
> 已同步备份到 NFS `release_run_logs/_wrappers_backup/`。

**为什么这 4 个放一起看**：`Fathom` 与 `MiroThinker` 是**同一类吞吐问题**
（14B dense `qwen2` 与 30B MoE `qwen3_moe` 都落在 ~3.5 tok/s → 先怀疑平台/算子层），
`OpenReasoning` 与 `Phi-4-mini` 是**同一类输出预算问题**（都被 `fast_gpqa` 的 max_tokens 封顶卡住）。
建议按「同类合并排查」而不是逐个模型试。

### 🟡 4 个复评的最终结果（0919 收）

| 模型 | 采样配置 | 结果 | NV | 说明 |
|------|---------|:----:|:--:|------|
| TinyR1-32B-Preview | **thinking + 0.6/0.95** | **62.0%（达标）** | 64.0 | u139 GPU 3,4,7,8:8001；iter1/iter2 贪心 58.0% → **62.0%**，runaway 6→2，耗时 125m15s（150 s/题）。**采样假设成立**。`verdict_gpqa_iter3.json` exit=0 |
| OpenReasoning-Nemotron-1.5B | **standard 贪心，mt=65536**（c16） | math **76.0%（不达标）** | 84.0 | u139 GPU 0:8011；iter2 76.5% → **76.0%**，抬上限**无提升**。撞顶 30→29、平均输出 +49% → **多烧一半算力零收益**。`verdict_math500_iter4.json` exit=1 |
| Phi-4-mini-reasoning | **standard，T=0.8/top_p=0.95**（c16） | math **62.0%（不达标）** | 88.2 | u139 GPU 9:8012；iter3 59.5% → **62.0%（+2.5pt）**，但复读 31→2、撞顶 32→9。`verdict_math500_iter4.json` exit=1 |
| MiroThinker-v1.5-30B | thinking + 0.6/0.95 + **top_k=20**（并发 2） | **部分 29.0%（9/31）** | 25.0 | u147 GPU 4-7:8001；人工中止于 31/50。**采样与模型推荐完全一致却无改善**（撞顶 77%→74%、解码 3.39→3.65 tok/s）。拆分：**撞顶 23 题对 1 题（4.3%）/ 正常收尾 8 题全对（100%）** → 瓶颈在输出预算 |
| Fathom-R1-14B | standard **贪心**（未修正） | 54.0% | 60.0 | **真实吞吐瓶颈**（3.49 tok/s），且输出长度正常（1/49 撞顶）→ **与 MiroThinker 机制不同**；精度口径亦不对等 |

### 🔴 重大发现：`detect_thinking()` 误判导致推理模型被按贪心解码评测（**已复评闭环，结论 per-model**）

详见 `fixes/TinyR1-32B-Preview.md` 的「专项调查」+「评测参数的影响」两节。要点：

- `fast_gpqa.detect_thinking()` 靠**模型名子串**匹配 `['qwen3','qwq','deepseek-r1','deepseek-r2','mimo','hunyuan']`；
  名字不含关键词的推理模型 **TinyR1 / MiroThinker / OpenReasoning / Phi-4-mini / Fathom**
  全部被判成 standard → `temperature=0.0` 贪心解码 → R1 系模型显著复读。
- `resolve_gen_params()` 本应读模型自带的 `generation_config.json` 覆盖采样，但
  `_resolve_model_dir()` 的两条路径在本环境**都不通**（`--model-name` 传的是名字不是路径；`context.yaml` 不存在）。
  **反例验证**：OpenThinker-7B / Marco-o1 配置写 0.7、日志实际 0.0。
  ⚠️ **限定范围（0919 修正）**：这条**只对 `fast_gpqa` 的客户端路径成立**；
  **服务端 vLLM 是通的** —— vLLM 默认 `--generation-config auto`，启动时会把模型目录的
  `generation_config.json` 读成服务端默认采样参数（MiroThinker 的 `top_k=20` 就是这么来的，
  serve 日志有 `model.py:1477` 警告）。**判读实际采样必须同时看 evalscope 请求和服务端这条警告。**
- **复评结果（0919 收）——影响是 per-model 的，不能一概而论**：

| 模型 | 贪心（旧口径） | 正确采样 | 结论 |
|------|:---:|:---:|------|
| **TinyR1-32B-Preview** | 58.0%（runaway 6/50） | **62.0%**（runaway 2/50） | ✅ 假设成立，差异主要是复读造成 → **达标** |
| OpenReasoning-Nemotron-1.5B | 76.5% | **73.5%（thinking）/ 76.0%（抬 mt）** | ❌ 两次都不升，真因**既非采样也非截断** |
| Phi-4-mini-reasoning | 41.0%（54% 题被截断） | **62.0%（T=0.8/0.95）** | ⚠️ 复读 31→2 但分数只 +2.5pt → **采样不是主因** |
| MiroThinker-v1.5-30B | 18.0%（77% 撞顶） | **0.6/0.95 + top_k=20（与服务端一致）** → 74% 撞顶 | ⚠️ 采样全中却无改善 → **采样不是原因** |
| Fathom-R1-14B | 54.0% | **未测** | ⬜ 待检验（README 要求 0.6/0.95） |

- **切 thinking 模式会连带改 2 个别的参数**（做对照实验时务必计入变量）：
  `max_tokens` 走 thinking 公式被压到 **20000**（从 32768 收紧）、评分前加 `remove_until='</think>'` 过滤器。
  TinyR1 iter3 因此有 **9/50 题撞 20000 上限**（比 iter1/iter2 的 8 题更多）→ 62.0% 是**保守下界**。
  ⚠️ **对 chat_template 不含 `<think>` 的模型（Phi-4-mini）不能照抄这个修法**，应只覆写采样参数。
- **判读提醒**：TinyR1 的低分结论**已修正**；OpenReasoning 的 73.5% **不是**采样问题（是截断）；
  MiroThinker / Fathom 的 18.0% / 54.0% **口径仍不对等**，引用时须带前提。
- ⚠️ **`fast_gpqa.py` 本体仍未修**（本轮用 wrapper 绕过）。根治要改三处：
  `detect_thinking()` 的模式表、`_resolve_model_dir()` 的路径解析、
  以及 **max_tokens 封顶过紧**（截断了正常的思考链）。**注意副作用**：`_resolve_model_dir()` 一旦生效
  会同时改变**所有**模型的采样（OpenThinker-7B / Marco-o1 的 0.0→0.7），需连带复核这两个模型的"达标"结论。


### 🟡 当前服务运行状态（2026-09-19 14:33 起）

> **除下表列出的两个 iter4 评测外，139 与 147 上的项目容器均已 `docker stop`（未删除）。**
> 下面 139 表里标「已停」的行是历史服务位记录，**当前并未运行**。

**iluvatar-139**

| 模型 | GPU | 端口 | 数据集 | attention-backend | 状态 |
|------|:---:|:----:|:------:|:-----------------:|------|
| **OpenReasoning-Nemotron-1.5B** | **0** | **8011** | **math_500 (200题)** | TRITON_ATTN | ✅ **iter4 已完成**（76.0%，↓9.52%，verdict exit=1）。服务仍在运行 |
| **Phi-4-mini-reasoning** | **9** | **8012** | **math_500 (200题)** | TRITON_ATTN | ✅ **iter4 已完成**（62.0%，↓29.71%，verdict exit=1）。服务仍在运行 |
| LFM2.5-1.2B-Thinking | 0 | 8000 | gpqa_diamond | TRITON_ATTN | ✅ 完成（已停） |
| LFM2.5-1.2B-Instruct | 1 | 8001 | gpqa_diamond | TRITON_ATTN | ✅ 完成（已停） |
| gemma-1.1-7b-it | 2 | 8002 | gpqa_diamond | TRITON_ATTN | ⏭️ 跳过（22.0%，不达标）（已停） |
| OpenThinker-7B | 3 | 8003 | mmlu + math_500 | TRITON_ATTN | ✅ 完成（已停） |
| AgentCPM-Report | 4 | 8004 | gpqa_diamond | TRITON_ATTN | ✅ 完成（iter2 49.49%，达标）（已停） |
| Marco-o1 | 5 | 8005 | gpqa_diamond | TRITON_ATTN | ✅ 完成（已停） |
| NeuralDaredevil-8B-abliterated | 6 | 8006 | gpqa_diamond | TRITON_ATTN | ⏭️ 跳过（iter1 30.0% / iter2 22.0%）（已停） |
| Phi-3-medium-128k-instruct | 0 | 8009 | gpqa_diamond | TRITON_ATTN | ⏭️ 跳过（iter3 24.0%，三次相同）（已停） |
| Qwen3-30B-A3B-Thinking-2507 | 4-7 | 8010 | gpqa_diamond | TRITON_ATTN | ✅ 完成（GPQA 76.0%）（已停） |
| TinyR1-32B-Preview | 3,4,7,8 | 8001 | gpqa_diamond | TRITON_ATTN | ✅ **完成，达标**（iter3 62.0%）（已停） |
| Qwen3.5-27B-Distilled | 5,6 | 8014 | gpqa_diamond | TRITON_ATTN | ✅ 完成（iter2 80.0%）（已停） |

**iluvatar-147**（**全部已停**）

| 模型 | GPU | 端口 | 数据集 | attention-backend | 状态 |
|------|:---:|:----:|:------:|:-----------------:|------|
| QwQ-32B | 0-3 | 8000 | gpqa_diamond | TRITON_ATTN | ⏭️ 跳过（56.0% vs 63.0）（已停） |
| MiroThinker-v1.5-30B | 4-7 | 8001 | gpqa_diamond | TRITON_ATTN | ⏸️ iter3 **已人工中止**（31/50，14:2x），partial 结果已存档（已停） |

> **iter4 任务是后台 nohup + `docker exec -d` 启动，SSH 断开不影响。**
> wrapper 在容器内 `/tmp/`（`openreason_maxtok.py` / `phi4mini_sampling.py`），
> **已备份到 NFS `release_run_logs/_wrappers_backup/`**（与历次复评的 wrapper 一起）——**不再只依赖容器 `/tmp`**。
> TinyR1 的 wrapper 全文已抄进 `fixes/TinyR1-32B-Preview.md`（防止 `/tmp` 丢失）；
> **`openreason_thinking.py` / `miro_thinking.py` / `force_conc.py` 尚未抄进文档，建议下次一并备份。**
> **139 的三个复评进程均已退出，只剩 147 的 MiroThinker 在跑。**

跟踪进度：

```bash
# iluvatar-139 汇总 verdict（已定论模型 + TinyR1 iter3 + OpenReasoning/Phi-4-mini iter3）
ssh iluvatar-139 'for m in LFM2.5-1.2B-Thinking LFM2.5-1.2B-Instruct gemma-1.1-7b-it OpenThinker-7B AgentCPM-Report Marco-o1 NeuralDaredevil-8B-abliterated Phi-3-medium-128k-instruct Qwen3-30B-A3B-Thinking-2507 Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled TinyR1-32B-Preview OpenReasoning-Nemotron-1.5B Phi-4-mini-reasoning; do echo "== $m =="; for v in /mnt/share/models/release_run_logs/$m/verdict*.json; do [ -f "$v" ] && python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(\" \",sys.argv[1].split(\"/\")[-1],d[\"current\"].get(\"score\"),\"aligned=\",d.get(\"aligned\"))" "$v"; done; done'

# --- 在途任务进度（2026-09-19：139 上的两个 iter4 评测）---
for p in "OpenReasoning-Nemotron-1.5B:eval_iter4_maxtok.log" "Phi-4-mini-reasoning:eval_iter4_sampling.log"; do
  m=${p%%:*}; f=${p##*:}
  echo "== $m"
  ssh iluvatar-139 "tr '\r' '\n' < /mnt/share/models/release_run_logs/$m/$f | grep -aoE 'Evaluating\[math_500\]:[ ]+[0-9]+%[^]]*\]' | tail -1"
done

# 评测进程是否还活着
ssh iluvatar-139 'docker exec eval-scope ps -eo pid,etime,cmd | grep -E "openreason_maxtok|phi4mini_sampling" | grep -v grep'
```

> ⚠️ **verdict 生成注意**：thinking 模型常触发 `fast_gpqa` 的 `detect_runaway` list-content bug
> 导致 `score=null`，需从 evalscope 报告重建（见下方「已知问题」节）。
> **TinyR1 / OpenReasoning / Phi-4-mini 三者的 iter3 verdict 已于 2026-09-19 重建完毕**
> （`verdict_gpqa_iter3.json` / `verdict_math500_iter3.json` ×2）。
> ⚠️ **iter4 这两个评测虽然都是 standard 模式，但仍可能命中崩溃**（`detect_runaway` 对
> list content 的假设与模式无关）——若 `score=null`，同样从 evalscope 报告恢复。

---

## 剩余 4 个模型的继续修复：推进状态（0919）

现状：**8 通过 / 6 跳过 / 4 待继续修复**。各模型的分数与已确认根因见上方
「🔧 剩余 4 个模型（继续修复）」表。

| 顺序 | 模型 | 状态 | 本轮结果 |
|:---:|------|------|---------|
| 1 | **OpenReasoning-Nemotron-1.5B** | ❌ **iter4 完成，假设证伪** | `max_tokens` 32768 → **65536**，采样不变 → **76.0%**（iter2 76.5%，**无提升**）。**截断假设被证伪** |
| 2 | **Phi-4-mini-reasoning** | ❌ **iter4 完成，假设证伪** | **T=0.8 / top_p=0.95** → **62.0%**（iter3 59.5%，**+2.5pt**）。复读 31→2 但分数没上来 → **采样不是主因** |
| 3 | **MiroThinker-v1.5-30B + Fathom-R1-14B** | ⏸️ 待办（待重跑） | MiroThinker iter3 已中止；重跑方向：**抬 `max_tokens`** + 吞吐三实验（`--max-model-len` 降 32768 → 去 `--enforce-eager` → 查 MoE 后端）。Fathom 精度需按 0.6/0.95 重测 |

**iter4 的设计与结论（务必按此判读）**：

- **两个评测各自只改一个变量**，因此结论是干净的：
  - OpenReasoning 只抬 `max_tokens`（采样不变）→ **无效** → **不是截断**。
  - Phi-4-mini 只改采样（上限不变）→ **只 +2.5pt** → **不是采样**。
- ⚠️ **两条判读教训**（本轮最重要的产出，均已写入各自 fix log 的 KNOWLEDGE 节）：
  1. **"排除撞 max_tokens 的题再看分数"可能是幸存者偏差**。OpenReasoning iter2 排除后达 **90.0%**（> 基线），
     看着像"只差输出预算"；但抬了上限后**纹丝不动**，且 iter2 的 30 道撞顶题里有 **20 题给了 2 倍预算仍然撞顶**。
     **那些题是死循环，不是"差一点就写完"。该指标只能用于诊断，不能估计能力。**
  2. **"修好了明显的问题"≠"分数会上来"**。Phi-4-mini 的复读从 **31 降到 2（−94%）**、撞顶 **32→9（−72%）**，
     行为上极其成功，但**分数只 +2.5pt**，且"排除撞顶后"的分数**反而从 69.6% 降到 64.9%**。
     **复读只是在掩盖错误，不是在制造错误。**
- **两个模型都在排除法上走到了尽头**（OpenReasoning 5 项、Phi-4-mini 4 项假设全部排除），
  剩余差距 **9.52% / 29.71% 无法归因**，嫌疑指向**算子精度**，但**无直接证据**。
  ⚠️ **不要把"最后剩下那个嫌疑"写成"根因"** —— 只能说"其余已排除"。
- **两者的共同现象**：都有 5% 左右"无法收敛"的题（撞顶题几乎全错），
  且**抬上限救不回来**。与 MiroThinker 的"74% 撞顶"可能同源，值得一起查。

> **注（范围）**：`flagrelease_fail_reports/Iluvatar/` 有 25 份失败报告，STATUS.md 只跟踪 18 个。
> **9 个模型有 iluvatar 失败报告却无跟踪记录**（AceReason-Nemotron-7B、Apodex-1.0-4B-SFT、GLM-4.7-Flash、
> gpt-oss-20b、LFM2-2.6B-Exp、Ministral-3-14B-Instruct-2512、Moonlight-16B-A3B-Instruct、rnj-1-instruct、
> SOLAR-10.7B-Instruct-v1.0）。用户尚未答复是划归其他厂商还是漏了 —— **若这 9 个也要做，范围会扩大**。

> **历史参考**（0918 前的难度排序，现已作废）：Ministral-8B → Marco-o1 → NeuralDaredevil-8B → AgentCPM-Explore → MiroThinker → AgentCPM-Report → Fathom → QwQ-32B → TinyR1-32B。其中 AgentCPM-Report（49.49% ✅）、Marco-o1（噪声容忍 ✅）、Qwen3.5-27B（80.0% ✅）、**TinyR1-32B（62.0% ✅，0919）** 已达标，其余已跳过。
>
> **注**：OpenReasoning-Nemotron-1.5B 原标记为"放弃"，2026-09-18 因换 HF 权重重开评测；
> 2026-09-19 采样复评完成、**采样假设被证伪**，根因改判为**输出截断**（排除撞顶后达 90.0% ≥ 基线），
> 故**不归入跳过**，转入「继续修复」。

---

## 已知问题：fast_gpqa.py detect_runaway 崩溃（**NFS 已修，但容器内未生效！**）

- **现象**：thinking 模型评测跑完、evalscope 已算出分数，但 `fast_gpqa.py` 在收尾的 `analyze_predictions_runaway → detect_runaway` 报 `AttributeError: 'list' object has no attribute 'strip'`（line 370），导致 result JSON 未写出、compare 未跑。
- **根因**：thinking 模型 `message.content` 是多段结构（list），`detect_runaway` 直接 `(text or "").strip()` 假设是 str。
- **修复**：`detect_runaway` 开头加 list→str 归一（本地 + NFS `eval_methods/fast_gpqa.py` 已更新）。
- ⚠️ **2026-09-19 实测发现：该修复只落在了 NFS 副本，容器内的评测实际用的是另一份未打补丁的副本**：

  | 路径 | 大小 | 时间 | 含 `isinstance(text, list)` 修复 |
  |------|:----:|:----:|:---:|
  | `/models/flagrelease/eval_methods/fast_gpqa.py`（NFS） | 56996 | 09-15 07:13 | ✅ 有 |
  | `/workspace/eval_scripts/fast_gpqa.py`（**评测实际运行的**） | 54559 | 09-14 06:49 | ❌ **无** |

  评测是从 `/workspace/eval_scripts` 跑的，所以**每一个 thinking 模型评测到现在都还会在收尾崩溃**
  —— 这正是 0918 晚那 4 个复评（TinyR1 / OpenReasoning / Phi-4-mini / MiroThinker）**全部**没写出 `score` 的原因。
  **建议动作**（两台机器都做）：
  ```bash
  ssh iluvatar-139 'docker cp /models/flagrelease/eval_methods/fast_gpqa.py eval-scope:/workspace/eval_scripts/fast_gpqa.py'
  ssh iluvatar-147 'docker cp /models/flagrelease/eval_methods/fast_gpqa.py eval-scope:/workspace/eval_scripts/fast_gpqa.py'
  ```
  ⚠️ 但**正在跑的 MiroThinker iter3 不要动**（它已加载旧代码进内存，重新 cp 不影响已启动的进程，
  只是别顺手重启它）。这一 cp 只对**之后新起**的评测生效。
- **影响与兜底**：崩溃发生在算分之后，分数仍在 evalscope 原始报告 `outputs/<dataset>/<ts>/reports/<model>/<dataset>.json`（字段 `metrics[0].score`，×100 即百分比）。已崩的可从报告重建 result JSON 再跑 compare（LFM2.5-1.2B-Thinking 即如此，32.0%；TinyR1/OpenReasoning/Phi-4-mini 的 iter3 也是这么恢复的）。
- **注意**：从报告恢复时，`runaway_detection` 字段需要用 NFS 那份**已修补**的 `fast_gpqa` 手动重算才能补上。

---

## 已知问题：`detect_thinking()` 误判，致推理模型被按贪心解码评测（**wrapper 绕过，脚本本体未修**）

> 完整调查 + 量化对照见 `fixes/TinyR1-32B-Preview.md` 的「专项调查」与「评测参数的影响」两节。此处为摘要。

- **现象**：多个推理模型被 `fast_gpqa` 判成 `standard`，拿到 `temperature=0.0`（贪心）+ `top_p=1.0`，
  而它们各自 README / 自带配置要求的都是 `temperature=0.6~0.8, top_p=0.95`。
  R1 系模型在贪心解码下会显著复读（TinyR1 的 README 原文警告过）。
- **根因一（判定）**：`detect_thinking()` 靠**模型名子串**匹配
  `['qwen3','qwq','deepseek-r1','deepseek-r2','mimo','hunyuan']`。
  **5 个模型名字都不含这些关键词** → 全部落到 standard 分支：
  `TinyR1-32B-Preview`（`tinyr1` 不含 `deepseek-r1`）、`MiroThinker-v1.5-30B`、
  `OpenReasoning-Nemotron-1.5B`、`Phi-4-mini-reasoning`、**`Fathom-R1-14B`（0919 新发现，同样不命中）**。
- **根因二（覆盖失效）**：`resolve_gen_params()` 本应读模型自带 `generation_config.json` 的采样字段覆盖默认，
  但 `_resolve_model_dir()` 的两条路径在本环境**都不通**：
  ① `--model-name` 传的是模型**名**而非本地路径；② `/flagos-workspace/shared/context.yaml` **不存在**。
  **反例验证（决定性）**：OpenThinker-7B 配置写 `temperature: 0.7`、Marco-o1 写 `0.7`，
  二者评测日志实测均为 `temperature=0.0` —— 证明该覆盖机制对所有模型都未生效。
  （注意 Phi-4-mini 即便补上 `generation_config.json` 也没用 —— 它的该文件里根本没有 temperature 字段。）
- **复评结果（0919 收）—— 影响是 per-model 的，绝不能一概而论**：

  | 模型 | README/自带要求 | 贪心（旧口径） | 正确采样 | 结论 |
  |------|:---:|:---:|:---:|------|
  | **TinyR1-32B-Preview** | 0.6/0.95 | 58.0%（runaway 6/50） | **62.0%**（runaway 2/50） | ✅ **假设成立** → 达标（↓3.12%） |
  | OpenReasoning-Nemotron-1.5B | — | 76.5% | **73.5%** | ❌ **反而更低**，真因是**截断** |
  | Phi-4-mini-reasoning | **0.8**/0.95 | 41.0%（54% 题被截断） | **未测** | ⬜ 待检验 |
  | MiroThinker-v1.5-30B | 0.6/0.95 | 18.0%（77% 撞顶） | 74% 撞顶（进行中） | ⚠️ 复读**几乎没减少** |
  | Fathom-R1-14B | 0.6/0.95 | 54.0% | **未测** | ⬜ 待检验（但其吞吐瓶颈是决定性的） |

  **教训：同一个 bug，对 TinyR1 是根因、对 OpenReasoning 完全不是。修之前必须实跑对照，不能靠推理。**
- **未受影响**：QwQ-32B、Qwen3-30B-A3B-Thinking-2507、Qwen3.5-27B 名字命中关键词，采样正确。
- **处置（已执行）**：用 wrapper 脚本 monkeypatch（`detect_thinking→True` + `resolve_gen_params→强制采样`）
  复评，**未改 `fast_gpqa.py` 本体**（同一容器还有其他评测在跑，避免污染）。
  TinyR1 的 wrapper 全文已备份在 `fixes/TinyR1-32B-Preview.md`；
  ⚠️ **`MiroThinker` / `OpenReasoning` 的 wrapper 只在 `/tmp`（易失），尚未抄进文档。**
- **⚠️ 修法不能照抄**：`is_thinking=True` 会连带把 `max_tokens` 收紧到 20000 并加 `remove_until='</think>'`。
  对 chat_template **不含 `<think>`** 的模型（如 **Phi-4-mini**），这是有害的（过滤器空转 + 上限收紧），
  **应只覆写采样参数、保持 standard 分支**。详见 `fixes/Phi-4-mini-reasoning.md`。
- **⚠️ 脚本本体仍未修，且修复有副作用**：根治需改
  ① `detect_thinking()` 的模式表、② `_resolve_model_dir()` 的路径解析、
  ③ **max_tokens 封顶过紧**（standard `clamp(max_model_len-8192, 4096, 32768)`、
  thinking `clamp(…, 8192, 20000)`，正在截断正常的思考链 —— OpenReasoning 的根因就是这个）。
  其中 ② 一旦生效会**同时改变所有模型**的采样（OpenThinker-7B / Marco-o1 的 0.0→0.7），
  会使已出分数的可比性被破坏，**需连带复核这两个模型的"达标"结论**。
- **判读提醒**：TinyR1 已修正为达标；OpenReasoning 的 73.5% 是截断所致（非采样）；
  MiroThinker 18.0% / Fathom 54.0% **口径仍不对等**，引用时须带前提。

---

> 各模型修复日志：`workspace/iluvatar/fixes/<模型名>.md`
> 评测产出目录：`/mnt/share/models/release_run_logs/<模型名>/`
