# Iluvatar 模型修复状态总览

> 更新：2026-09-21 22:26（**Qwen2.5-72B-Instruct 达标 —— 计数 10 → 11 通过**）| 机器：iluvatar-139 + iluvatar-147 | 镜像：`xingchen4-0907`

## 当前计数

**11 通过 / 6 跳过 / 2 待继续修复 = 19**

- **✅ 已通过（11）**、**⏭️ 跳过无需修复（6）**：见状态表，**均以机器上 `verdict_*.json` 的 `aligned` 字段核对过**
- **✅ Qwen2.5-72B-Instruct 已达标**（2026-09-21 新增对象，当轮完成）：
  **GPQA 56.0% vs 基线 56.0%，相对退化 0.00%，`aligned=true`**（exit=0）。50 题全量，
  **runaway 0/50、truncation=False**，是一次**干净达标**。
  配置：TP=8 / `TRITON_ATTN` / mlen=32768 / **graph 模式**（未回退 eager）/ 采样取模型自带
  `generation_config.json`。中途修掉 **5 个无人值守脚本 bug**（v2 空跑 + v3 评测阶段三个），
  详见下方专节与 `fixes/Qwen2.5-72B-Instruct.md`。
- **🔧 待继续修复（2）** —— 两者都在排除法上走到尽头，剩余差距无法归因：
  - ❌ **OpenReasoning-Nemotron-1.5B** — math_500 **76.0%** vs 84.0%（↓9.52%）。
    **iter4 抬 `max_tokens` 到 65536 → 无效（76.5%→76.0%）**，**截断假设被证伪**。
    **五项假设（权重/上下文/并发/采样/截断）已全部排除**
  - ❌ **Phi-4-mini-reasoning** — math_500 **62.0%** vs 88.2%（↓29.71%）。
    **iter4 按 README 改采样 → 复读 31→2（−94%）但分数只 +2.5pt**，**采样假设被证伪**（非主因）。
    截断与采样两项修复均已实测，剩余差距同样无法归因
- **⚠️ QwQ-32B 未受本次 bug 影响**：名字含 `qwq` 命中 thinking 判定，
  日志实测 `thinking (temperature=0.6)`，采样配置正确。

> 🟢 **2026-09-19 晚重大进展：`--enforce-eager` 是元凶，两个"废案"模型双双达标**
>
> 用户指示用 **TP=8 + graph 模式**（去掉 `--enforce-eager`）重启 Fathom 与 MiroThinker，双双成功：
>
> | 模型 | 旧配置（eager） | **graph（并发1）** | **graph（并发8聚合）** | 精度 | 判定 |
> |------|:---:|:---:|:---:|:---:|:---:|
> | **Fathom-R1-14B** | 3.49 tok/s | **18.97**（5.4×） | **108.3** | **68.0%** vs 60.0（↑13.33%） | ✅ **达标** |
> | **MiroThinker-v1.5-30B** | 3.65 tok/s | **31.61**（8.7×） | **72.3** | **30.0%** vs 25.0（↑20.00%） | ✅ **达标** |
>
> **Fathom 此前被判"❌ 放弃"（固有性能瓶颈 + 精度不达标），两条理由今天全被推翻** ——
> 真因只有两个：**去 `--enforce-eager`** + **按 README 改采样**（它也是 `detect_thinking` 误判受害者）。
> 50 题评测从"ETA 50h"变成 **30 分钟**。
>
> ⚠️ **但两者的"达标"成色不同，判读时必须区分**：
> - **Fathom 干净**：runaway **0/50**，单变量清晰（graph + 采样各自效果可分离）。
> - **MiroThinker 勉强**：**runaway 仍 35/50（70%）**，达标完全由"能收尾的 16 题"贡献；
>   且 iter1→iter5 **同时变了 5 个变量**，**说不清哪个起作用**（唯一没有干净归因的模型）。

> ⚠️ **4 个复评全部命中 `detect_runaway` 的 list-content 崩溃**（`fast_gpqa.py:370`
> `AttributeError: 'list' object has no attribute 'strip'`），`score` 未写出，分数是从 evalscope 报告
> `outputs/<ds>/<ts>/reports/<model>/<ds>.json` 的 `metrics[0].score` 恢复的。
> **TinyR1 / OpenReasoning / Phi-4-mini 的 verdict 均已重建**（TinyR1 exit=0，另两个 exit=1）。
> iter4 的两个评测（2026-09-19 晚）**同样命中该崩溃**，分数同样从报告恢复。

## 本次 session 新发现（重要，影响判读）

0. 🔴 **`--enforce-eager` 是隐蔽的性能杀手，且极易被误判成硬件瓶颈**（**本轮最重要结论**）。
   两个模型在 eager 下都被判"固有性能瓶颈"，去掉后分别提速 **5.4× / 8.7×**：
   - `--enforce-eager` **同时禁用 torch.compile 与 CUDAGraph**（serve 日志原话：
     `Enforce eager set, disabling torch.compile and CUDAGraphs`）。
   - **Fathom-R1-14B 因此被冤枉了一整轮并判"❌ 放弃"**，今天 graph 模式一跑就达标（68.0%）。
   - ⚠️ **"换机复现"不能证明平台问题** —— 两台机器用同一套错误配置，结论就会一样错。
   - 📌 **排查吞吐问题时，去掉 `--enforce-eager` 应作为第一优先级，而不是最后手段。**

1. **`detect_thinking()` 误判**（见下方专节）：多个推理模型被按贪心解码评测。
   **0919/0920 实测结论：影响是 per-model 的，且"修正采样"往往不是解药**：
   - **TinyR1**：✅ **成立**（58.0%→62.0%，达标）→ ✅ 已通过
   - **Fathom**：✅ **成立且幅度最大**（贪心 54.0% → 0.6/0.95 **68.0%，+14pt**，runaway 0/50）
     → ✅ 已通过。**此前那个"修正采样也不改变处置"的判断是错的**（它依赖了错误的性能瓶颈结论）
   - **OpenReasoning**：❌ **不成立**（76.5%→73.5%，反而更低）。后续 iter4 又证伪了"截断"，
     → **既非采样也非截断**，剩余 9.52% 无法归因
   - **Phi-4-mini**：⚠️ **行为成立、分数不成立** —— 应用 README 的 0.8/0.95 后复读 31→2（−94%）、
     撞顶 32→9（−72%），**但分数只 +2.5pt**（59.5%→62.0%）→ **复读在掩盖错误，不是制造错误**
   - **MiroThinker**：iter3 **采样已与模型推荐完全一致**（含服务端补的 `top_k=20`），
     撞顶 77%→74%、解码 3.39→3.65 tok/s **均未改善** → **采样不是原因**
   - 📌 **共同教训**：**"采样配置不对"是一个容易成立、但很少是根因的假设。**
     5 个模型里 2 个（TinyR1 / Fathom）靠它达标，3 个不是。**改动前必须实跑对照，不能靠推理。**

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
   ✅ **2026-09-21 客户端那条路已打通**：新增 `fast_gpqa.py --model-dir`（见下方专节），
   现在可以显式指定模型权重目录，采样参数按 `generation_config.json` 走。**Qwen2.5-72B 已实测生效。**

9. 🔴 **无人值守 driver 的失败会伪装成"还在进行中"**（2026-09-21，Qwen2.5-72B 一轮踩了 5 个）。
   5 个 bug 形状完全一致：**重定向失败=静默不执行 / pgrep 自匹配=永远活着 / 僵尸进程=永远活着 /
   `docker exec` 缺 `-i`=静默无输出 / `_split_datasets` 缺 None 守卫=静默走错分支**。
   后果分别是「服务看起来起不来」（实际从未启动）和「评测看起来卡住」（实际早已失败）。
   **对策：凡等待，都要校验一个能证伪的独立正向证据**（进程在 + 日志非空 + 输出文件写出），
   而不是只信单一返回值。详见「复盘：无人值守 driver 的 5 个脚本 bug」节与 `_shared/KNOWLEDGE.md` 第七节。

> **0918 ~ 0920 状态收敛**：达标者标 ✅ 已通过，未达标者标 ⏭️ 跳过（无需修复），不再投入。
> 所有判定均以机器上 `verdict_*.json`（`aligned` 字段）为证据核对过。
> **剩余 2 个模型转入"继续修复"，可执行下一步见「待继续修复的 2 个模型」节。**
>
> ⚠️ **注意 `--enforce-eager` 这个坑**（见「新发现 0」）：本环境长期把 `--enforce-eager` 当作
> 规避算子崩溃的"安全默认"，**它却是两个模型"性能瓶颈"的真因**，并直接导致 Fathom 被误判为
> "固有瓶颈 → 放弃"。**新一轮评测起服务前，先确认是否真的需要 eager。**

## 图例

| 标识 | 含义 |
|------|------|
| 🟢 服务运行中 | vLLM 服务已启动，smoke test 通过，待评测 |
| 🟡 评测进行中 | 评测脚本已跑，等待结果 |
| ✅ 已通过 | accuracy_compare 退出码 0 |
| ❌ 精度不达标 | accuracy_compare 退出码 1 |
| ⏭️ 跳过（无需修复） | 已尝试但未达标，或因环境/范围原因不再投入；0918 决策，结论已定 |
| 🔧 待继续修复（verdict exit=1） | 复评/verdict 已完成且不达标，**排除法已走到尽头**（见「待继续修复的 2 个模型」节），不判"跳过" |
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
| Fathom-R1-14B | ✅ 已通过 | 精度数据为空 + 性能严重不达标（V1 TTFT=244727ms） | gpqa_diamond | 60.0 | iter1: 54.0%（贪心，口径不对等）→ **iter5: 68.0%（thinking + 0.6/0.95，↑13.33%）** | `flagrelease-fix-fathom-r1-14b` GPU 0-7 / :8002 (u139) | **完成，达标**。`verdict_gpqa_graph.json` 实测 exit=0 / aligned=true。**此前"❌ 放弃"的两条理由（性能瓶颈、精度退化）均被推翻**：真因是 `--enforce-eager`（graph 模式 108.3 tok/s，31×）+ `detect_thinking` 误判致贪心评测。50 题 30m05s 跑完，**runaway 0/50**。graph 模式需黑名单加 **`broadcast_to`**。详见 fix log |
| Marco-o1 | ✅ 已通过 | 服务启动失败（Operator crash）+ 精度存疑（V2 GPQA=32.83%） | gpqa_diamond | 32.0 | **28.0**（差2题，噪声容忍达标） | `flagrelease-fix-marco-o1` / :8005 | 完成，达标（小样本噪声区，可扩样本复核） |
| Ministral-8B-Instruct-2410 | ⏭️ 跳过（无需修复） | 精度不达标（V2/V3 GPQA=28.0% vs NV=30.0%，↓6.7%） | gpqa_diamond | 30.0 | — | — | **镜像 transformers+mistral_common 依赖链缺陷**：serve.log 报 `name 'SpecialTokens' is not defined` → 服务根本未起，无 verdict。非模型问题，0918 决策不再修复 |
| MiroThinker-v1.5-30B | ✅ 已通过（**勉强**） | Operator crash + 全部评测数据为空 | gpqa_diamond | 25.0 | iter1: 18.0%（50题，贪心）→ iter3 部分 29.0%（31/50）→ **iter5: 30.0%（50题全量，thinking 0.6/0.95，↑20.00%）** | `flagrelease-fix-mirothinker-v1.5-30b` GPU 8-15 / :8001 (u139) | ✅ **达标**（`verdict_gpqa_graph.json` exit=0）。**但属"勉强达标"**：⚠️ **runaway 仍 35/50（70%）**，34 道撞顶题只对 2 道，**达标完全由"能收尾的 16 题"贡献**。性能真因同样是 `--enforce-eager`（graph 72.3 tok/s，20×），但**提速没有改善复读**（74%→68%）。⚠️ **本模型是唯一没有干净归因的**（iter1→iter5 同时变了 5 个变量）。下一步可试**抬 max_tokens 到 65536** 看能否救回撞顶题。详见 fix log「定位 4/5」 |
| NeuralDaredevil-8B-abliterated | ⏭️ 跳过（无需修复） | 服务启动失败（Operator crash，原用 FlagGems 5.3.0rc2） | gpqa_diamond | 37.0 | iter1: **30.0%**（↓18.92%）；iter2: **22.0%**（↓40.54%） | `flagrelease-fix-neuraldaredevil-8b-abliterated` GPU 1 / :8006 (u139) | 两轮 verdict 均 `aligned=false`。iter2 结论：mm/addmm 不可黑名单化；`sort,sort_stable` 必需但精度差距根因未定位。0918 决策不再修复 |
| QwQ-32B | ⏭️ 跳过（无需修复） | 服务启动失败（流程仅 37min，全部数据为空） | gpqa_diamond | 63.0 | **56.0%**（50题，↓11.11%） | `flagrelease-fix-qwq-32b` 已停 (u147) | 已实测，verdict 判定 `aligned=false`（2026-09-15）；数量已够，0918 决策不再修复；容器已停 |
| TinyR1-32B-Preview | ✅ 已通过 | 服务启动失败（无镜像产出，全部数据为空） | gpqa_diamond | 64.0 | iter1: 58.0%（贪心）→ iter2（+mm,addmm）: 58.0%（与 iter1 完全相同）→ **iter3（thinking + 0.6/0.95）: 62.0%**（↓3.12%，runaway 6→2） | `flagrelease-fix-tinyr1-32b-preview` GPU 3,4,7,8 / :8001 (u139) | iter2 证明 `mm,addmm` 黑名单**无效**；根因确认为**采样配置错误**（`detect_thinking` 误判为 standard → 贪心解码 → 复读）→ iter3 thinking + 0.6/0.95 复评完成，`verdict_gpqa_iter3.json` 实测 exit=0 / aligned=true。详见 fix log「评测参数的影响」节 |
| Phi-3-medium-128k-instruct | ⏭️ 跳过（无需修复） | 服务启动失败（原 vLLM 0.20.2 Operator crash，全部数据为空） | gpqa_diamond | 37.0 | **24.0%**（↓35.14%） | `flagrelease-fix-phi3-medium` GPU 0 / :8009 (u139) | iter3（17算子黑名单）得分仍 24.0%，三次完全相同，verdict 判定 `aligned=false`；算子黑名单路径彻底排查完毕。0918 决策不再修复（如需重启：chat_template / dtype） |
| Qwen3-30B-A3B-Thinking-2507 | ✅ 已通过 | Operator crash: mm on unknown platform（V2/V3 全空） | gpqa_diamond | 75.0 | **76.0**（↑1.33%，反超基线） | `flagrelease-fix-qwen3-30b-a3b-thinking` GPU 4-7 / :8010 (u139) | 完成，达标（score=null 从 evalscope 报告恢复；blacklist=sort,sort_stable,mm，TP=4） |
| OpenReasoning-Nemotron-1.5B | 🔧 待继续修复 | 无原始失败报告（后补评测对象） | mmlu / math_500 | 52.21 / 84.0 | mmlu 35.0%（iter1）; math_500 76.5%（iter2）→ 73.5%（iter3 thinking）→ **76.0%（iter4 抬 mt=65536，↓9.52%）** | `flagrelease-fix-openreasoning-nemotron-1.5b` GPU 0 / :8011 (u139) | **五项假设全部排除**（权重 sha256 一致 / 上下文 131072 / 并发 / 采样 iter3 反降 / **截断 iter4 抬上限无效**）。`verdict_math500_iter4.json` exit=1。**下一步：查算子精度（逐组开关黑名单做对照）；mmlu 需干净重测**。⚠️ 别再调 max_tokens/采样 |
| Phi-4-mini-reasoning | 🔧 待继续修复 | 无原始失败报告（后补评测对象） | mmlu / math_500 | 72.83 / 88.2 | mmlu 58.07%（iter1，**受 2048 截断污染**）/ math_500 41.0%（同污染）→ 59.5%（iter3，`--max-model-len 32768` + c8）→ **62.0%（iter4，T=0.8/0.95，↓29.71%）** | `flagrelease-fix-phi4-mini-reasoning` GPU 9 / :8012 (u139) | **截断已修**（+18.5pt）；**采样已修但只 +2.5pt** —— 复读 31→2（−94%）、撞顶 32→9（−72%），**行为改善巨大但分数没上来** → **采样不是主因**。`verdict_math500_iter4.json` exit=1。**下一步：查算子精度；mmlu 需干净重测**。⚠️ 别再调采样/max_model_len |
| Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled | ✅ 已通过 | 未开始 | gpqa_diamond | 75.0 | iter1: **70.0**（↓6.67%）→ iter2: **80.0**（↑6.67%，反超基线）| `flagrelease-fix-qwen3.5-27b` GPU 5,6 / :8014 (u139) | 完成，达标。iter2 配置：sort,sort_stable,mm,addmm，TRITON_ATTN，TP=2，`--max-model-len 65536`（iter1 为 8192，把 max_tokens 压到 4096）。verdict 为 2026-09-18 实跑重建（`verdict_gpqa_iter2.json`，exit=0） |
| Qwen2.5-72B-Instruct | ✅ 已通过 | 未开始（2026-09-21 新增对象） | gpqa_diamond | 56.0 | **56.0**（相对退化 **0.00%**，`aligned=true`，exit=0） | `flagrelease-fix-qwen2.5-72b-instruct` GPU 0-7 / :8015 (u139) | **完成，达标（干净：runaway 0/50、truncation=False）**。Qwen2 dense GQA（80层/hidden 8192/8 KV heads），bf16 **136 GB** → **TP=8**；`TRITON_ATTN`（非 MLA）；**standard 分支（非推理模型，不套 thinking wrapper）**；mlen=32768；**graph 模式成功（未回退 eager）**，单请求解码 **~18 tok/s**；**采样取模型自带 `generation_config.json`**（temp 0.7 / top_p 0.8 / top_k 20 / rp 1.05，靠新加的 `--model-dir` 生效，已三层验证）。50 题 **9.7 分钟**（并发 8）。**原定 117，当日 117 被占用 → 改用 139** |

---

## 已完成：Qwen2.5-72B-Instruct（2026-09-21，新对象 → 当轮达标）

**结果**：GPQA Diamond **56.0% vs NV 基线 56.0%**，相对退化 **0.00%**，`aligned=true`（exit=0）。
50 题全量、**runaway 0/50**、**truncation=False** —— **一次干净达标**，没有任何"勉强"成分
（对比 MiroThinker 那种 runaway 70% 仍判达标的成色）。

| 项 | 值 |
|----|----|
| 服务模式 | **`SERVE_MODE=graph`**（未回退 eager） |
| 启动耗时 | **5 分 10 秒**（加载 37 分片 ~2min + compile 37s + 图捕获 22s） |
| KV cache | 222,352 tokens（32768/请求下最大并发 6.79×） |
| 解码吞吐 | 单请求 **~18 tok/s**（graph；GPU util ~71%、功耗 237W）；并发 8 时聚合到 ~49 tok/s |
| 评测耗时 | **579 秒（9.7 分钟）**，并发 8，探测 15.6s |
| 采样 | `temperature=0.7, top_p=0.8, top_k=20, repetition_penalty=1.05`（模型自带 gen config） |
| max_tokens | 24576（`clamp(32768-8192, 4096, 32768)`） |

**⭐ 结论价值（对后续 dense 模型）**：72B dense 在 graph 模式 + 扩黑名单
（`sort,sort_stable,mm,addmm,broadcast_to`）下**能顺利图捕获并按 5 分钟级启动**，
且**单请求吞吐比 14B（Fathom 18.97 tok/s）只慢 7%** —— 说明「去掉 `--enforce-eager`」
这条经验**对更大的 dense 模型同样成立**，不是小模型专属。
若当初回退 eager（按 5.4~8.7× 损失估），单请求约 2 tok/s，50 题要跑好几天。

**⚠️ 一个观察点（留待后续）**：`--cudagraph-capture-sizes 16` 只捕获了 **1/1** 个尺寸
（预期 1,2,4,8,16 一组）。本次并发 8 仍跑出 49 tok/s 聚合、评测 9.7 分钟完成，
**未构成瓶颈**；但若后续遇到并发上不去的情况，这是第一个该查的点。

**本轮修掉的 5 个无人值守脚本 bug**（全部与模型/平台无关，详见下方两节）：
v2 的「宿主机路径当容器路径用」+「pgrep 自匹配」→ vLLM 从未启动（空跑两轮 30 分钟）；
v3 评测阶段的「`kill -0` 测不出僵尸进程」+「`docker exec` 缺 `-i` 吞 heredoc」+
「`_split_datasets()` 缺 None 守卫 → `未知数据集 ['None']`」。
**5 个 bug 同一形状：失败被伪装成"还在进行中"。** 教训已进 `_shared/KNOWLEDGE.md` 第七节。

---

## 复盘：无人值守 driver 的 5 个脚本 bug（**已全部修复，对象已达标**）

> **同一形状：失败被伪装成"还在进行中"。** 5 个 bug 全部与模型/算子/平台无关，
> 却先后把流程拖成「看起来服务起不来」（v2）和「评测卡住不结束」（v3）。
> 最终 v4 跑通，Qwen2.5-72B-Instruct **56.0% 达标（退化 0.00%）**。

### v2：两个 bug 让 vLLM **从未启动**（空跑两轮 30 分钟）

- **现象（2026-09-21 19:26~20:27）**：v2 driver 报 graph 超时 → 回退 eager → 又超时 →
  `driver end (FAILED)`。看上去"两种模式都起不来"。
- **实际**：**vLLM 一次都没被启动过**。8 张卡全程空闲（`ixsmi` 68MiB/卡），
  容器里没有任何 `vllm serve` 进程，serve 日志从未生成。权重完好（37/37 分片，136 GB）。
- **根因 1（致命）**：**宿主机路径当容器路径用**。v2 用 `$RUNLOG=/mnt/share/models/release_run_logs/...`
  做重定向 `> $RUNLOG/serve_graph.log`，但修复容器只挂了 `/mnt/share/models -> /models`，
  容器内**没有 `/mnt/share`** → bash 打开重定向失败 → **整条 `nohup vllm serve` 根本没执行**。
  driver 自己的 `tail -30 serve_graph.log` 报 `No such file or directory` 就是铁证。
- **根因 2**：存活检查 `docker exec $CT bash -c 'pgrep -f "vllm serve"'` **自匹配**
  （父 `bash -c` 的 cmdline 里就含 `vllm serve`，pgrep 不排除它）→ 恒为真 →
  "进程消失"永远测不出来，两轮各空等 30 分钟。
- **修复（v3，`/root/qwen25-72b-driver.sh`，NFS 副本 `driver_v3.sh`）**：
  ① 容器内一律用 `/models/...` 写日志；② 存活检查改 `pgrep -f "[v]llm serve"`；
  ③ **启动后 90 秒硬校验**（进程在 + 日志非空），不合格立刻失败，不再空等；
  ④ 评测加 `--model-dir`。**实测 5 秒即通过硬校验**，服务真起来了。
- **提炼**：已进 `_shared/KNOWLEDGE.md` 第七节。**教训："超时未就绪"必须先分清"在加载"还是"根本没起来"**
  —— 用 pgrep 确认进程、`ls` 确认日志文件，再谈模型/算子问题。

### v3：服务起来了（`SERVE_MODE=graph`），但评测阶段又栽 3 个 bug

| # | 现象 | 根因 | 修复 |
|:-:|------|------|------|
| B1 | 评测算死了，轮询却一直以为在跑（4a 本会空等 40min、4b 空等 12h） | `kill -0 $EPID` 对**僵尸进程**（`STAT=Z`）**仍返回 0**；实测 `1852 Z [python3] <defunct> PPID=1` | 判活改 `pgrep -f "[f]ast_gpqa"`，并**用"输出文件是否写出"区分"跑完"与"崩了"** |
| B2 | "单请求吞吐实测"永远不打印 | `docker exec` 不带 `-i` → **heredoc 的 stdin 被静默吞掉**（还被 `\|\| true` 掩盖） | 改 `docker exec -i`（实测对照：带 `-i` 打印，不带则零输出） |
| B3 | 评测 1 秒退出：`[ERROR] 未知数据集: ['None']` | 部署版 `_split_datasets()` 缺 `if raw is None: return []`，`str(None)="None"` 非空 → 返回 `['None']`（真值）→ `or config.get('dataset','gpqa_diamond')` 兜底**永不触发** | 脚本补回 None 守卫（NFS + eval-scope + 仓库三处同步）；driver 侧同时**显式传 `--dataset gpqa_diamond`** 双保险 |

> ⚠️ **B3 影响面最大**：**SOP 第 4 节的评测命令模板本身就没写 `--dataset`**，照抄 SOP 即踩。
> 已在 fix log 与 KNOWLEDGE 标注，后续脚本模板建议一律显式写数据集名。

**附带发现**：评测日志重定向到文件时 python 是**块缓冲**，运行中 `tail` 看不到内容
（也是"进度看起来不动"的假象之一）。要实时进度得给 `python3` 加 `-u`。

### v4：复用 v3 已起的 graph 服务，只重跑评测 —— 一次通过

- **不重启服务**（省 5 分钟 + 保住 graph 结论），从冒烟 + 4a 小样本接着跑
- 新增「启动宽限 60s」+「进程消失即判定结果」，任何失败在 1 分钟内暴露
- 新增 **4a 小样本（`--limit 2`）先验**：先确认链路与 `[gen]` 采样行，再跑 50 题全量
- **4a 3 分钟通过 → 4b 9.7 分钟出分 → verdict exit=0，达标**

**通用教训（已进 KNOWLEDGE 第七之二节）**：无人值守脚本里**每一个"等待/判断"都必须有
"失败了会怎样"的快速路径**。这 5 个 bug 的共同形状是 **失败被伪装成"还在进行中"**
（重定向失败=静默不执行、自匹配=永远活着、僵尸=永远活着、空 stdin=静默无输出、
`['None']`=静默走错分支）。对策：凡等待，都要同时校验**一个独立的、能证伪的正向证据**
（进程存在 + 日志非空 + 输出文件写出），而不是只信单一返回值。

---

## 新增能力：`fast_gpqa.py --model-dir`（采样参数取模型自带 generation_config.json）

- **背景**：`resolve_gen_params()` 早有"采纳模型 `generation_config.json` 采样字段"的逻辑
  （`_GEN_PARAM_WHITELIST = temperature/top_p/top_k/repetition_penalty`），但 `_resolve_model_dir()`
  只在 `--model-name` 是**本地目录路径**或存在 `/flagos-workspace/shared/context.yaml` 时才生效。
  流水线里 `--model-name` 是 NV key（如 `Qwen2.5-72B-Instruct`）→ **永远定位不到模型目录 → 静默回退默认**。
- **改动（2026-09-21）**：新增 `--model-dir` 选项，显式指定模型权重目录（容器内路径），
  优先级高于 `--model-name`。**纯增量，不传时行为与改动前完全一致**（不动其它模型已出分数的可比性）。
- **文件**：NFS 规范副本 `/mnt/share/models/flagrelease/eval_methods/fast_gpqa.py`
  （旧版备份 `fast_gpqa.py.bak-v0930-2155`），已 `docker cp` 到 139 的 `eval-scope:/workspace/eval_scripts/`；
  仓库副本 `flagrelease_eval_methods/fast_gpqa.py` 同步打了同样的补丁。
- **实测验证**（容器内）：
  ```
  不传 --model-dir: temperature=0.0, top_p=1.0            ← 贪心（旧行为）
  传   --model-dir: temperature=0.7, top_p=0.8, top_k=20, repetition_penalty=1.05   ← 模型自带配置
  ```
- **用法**：`python3 fast_gpqa.py --model-name <NV key> --api-base ... \
  --model-dir /models/flagrelease/fixes_models/<模型名> --output ...`
- ⚠️ **注意可比性**：以后凡是传了 `--model-dir` 的评测，采样口径就变成"模型自带配置"，
  与 0919~0920 那批（手写 0.6/0.95 或贪心）**不是同一口径**，跨轮对比时要注明。

---

## 当前进度快照

> 更新：2026-09-21 22:26（**Qwen2.5-72B-Instruct 达标**，计数 10 → 11；graph 模式结论已确认）

- **✅ 精度已通过：11 / 19** — LFM2.5-1.2B-Thinking（32.0 vs 29.0）、LFM2.5-1.2B-Instruct（40.0 vs 29.0）、OpenThinker-7B（mmlu 75.0/77.0 + math 86.5/88.0）、Marco-o1（28.0 vs 32.0，小样本噪声容忍）、Qwen3-30B-A3B-Thinking-2507（76.0 vs 75.0）、AgentCPM-Report（49.49 vs 46.0，198题全量）、Qwen3.5-27B-Distilled（80.0 vs 75.0）、TinyR1-32B-Preview（62.0 vs 64.0）、**Fathom-R1-14B（68.0 vs 60.0，↑13.33%）**、**MiroThinker-v1.5-30B（30.0 vs 25.0，↑20.00%，但 runaway 70% 未解决）**、**Qwen2.5-72B-Instruct（56.0 vs 56.0，退化 0.00%，runaway 0/50，干净达标）**
- **⏭️ 跳过（无需修复）：6 / 19** — gemma-1.1-7b-it（22.0 vs 37.0）、NeuralDaredevil-8B-abliterated（30.0→22.0 vs 37.0）、Phi-3-medium-128k-instruct（24.0 vs 37.0）、QwQ-32B（56.0 vs 63.0）、AgentCPM-Explore（服务未起）、Ministral-8B-Instruct-2410（镜像依赖链缺陷）
- **🔧 待继续修复：2 / 19** — 见下节

### 🔧 待继续修复的 2 个模型 —— 状态与可执行下一步

> 两者都已有 `verdict_*.json` 且 **exit=1**，**排除法已走到尽头**（各自 4~5 项假设全部排除），
> 剩余差距**无法归因**。详细记录见各自的 fix log。

| 模型 | 最新分数 | NV | 已排除的假设 | **下一步（可执行）** |
|------|:-------:|:--:|------------|---------------------|
| **OpenReasoning-Nemotron-1.5B** | math_500 **76.0%**（iter4） | 84.0 | 权重(sha256) / 上下文(131072) / 并发 / 采样(iter3 反降) / **截断(iter4 抬上限无效)** | ⬜ **查算子精度**（逐组开关黑名单做对照）；⬜ mmlu 需干净重测。**不要再调 max_tokens / 采样** |
| **Phi-4-mini-reasoning** | math_500 **62.0%**（iter4） | 88.2 | 权重(sha256) / **max_model_len 截断(已修 +18.5pt)** / 采样(iter4 仅 +2.5pt) / 并发 | ⬜ **查算子精度**；⬜ mmlu 需干净重测。**不要再调采样 / max_model_len** |

**这 2 个的共同点**：都被 `fast_gpqa` 的 max_tokens 封顶影响过，但**抬上限/改采样都已实测无效**；
排除法剩下的唯一方向是**算子精度**，**无直接证据**，需单独设计对比实验。

> **容器状态时间线（2026-09-19 ~ 09-20）**：
> - **14:30** 全部项目容器按要求 `docker stop`（139 + 147，**未删除，文件系统保留**）。
> - **14:33** 为两个 iter4 评测重启 139 上 3 个容器；**20:45** iter4 跑完；**21:5x** 两个模型容器也停。
> - **22:00 起** 按用户指示，用 **TP=8 + graph 模式**重启 **Fathom（GPU 0-7 / :8002）** 与
>   **MiroThinker（GPU 8-15 / :8001）**，双双启动成功。
> - 评测：**Fathom 30m05s 跑完**（22:28 起）、**MiroThinker 114m20s 跑完**（22:30 起，00:22 结束）。
> - **01:00** 两个 graph 服务也按要求停止 → **139 的 16 张卡全部释放**。
> - ⚠️ **147 上全部容器仍为停止状态**（MiroThinker 已在 139 新建容器）。
>
> 两个评测的 wrapper 在容器内 `/tmp/`（`fathom_graph_eval.py` / `miro_graph_eval.py`），
> 已同步备份到 NFS `release_run_logs/_wrappers_backup/`。
> ✅ **`fast_gpqa.py`（NFS 已修补版）已拷入 eval-scope**，所以本轮两个评测**收尾没有再崩**。

### 🟢 graph 模式的两个结果（2026-09-19 晚，本轮最重要）

| 模型 | 配置 | 精度 | NV | 判定 | runaway |
|------|------|:----:|:--:|:----:|:-------:|
| **Fathom-R1-14B** | thinking 0.6/0.95，并发 8，graph | **68.0%** | 60.0 | ✅ **达标**（↑13.33%） | **0/50** |
| **MiroThinker-v1.5-30B** | thinking 0.6/0.95/top_k=20，并发 8，graph | **30.0%** | 25.0 | ✅ **达标**（↑20.00%） | ⚠️ **35/50** |

**Fathom 是干净的结果**（runaway 0、单变量清晰）；**MiroThinker 是勉强达标**（见下方拆分）。

### 🟡 4 个复评的最终结果（0919 收）

| 模型 | 采样配置 | 结果 | NV | 说明 |
|------|---------|:----:|:--:|------|
| TinyR1-32B-Preview | **thinking + 0.6/0.95** | **62.0%（达标）** | 64.0 | u139 GPU 3,4,7,8:8001；iter1/iter2 贪心 58.0% → **62.0%**，runaway 6→2，耗时 125m15s（150 s/题）。**采样假设成立**。`verdict_gpqa_iter3.json` exit=0 |
| OpenReasoning-Nemotron-1.5B | **standard 贪心，mt=65536**（c16） | math **76.0%（不达标）** | 84.0 | u139 GPU 0:8011；iter2 76.5% → **76.0%**，抬上限**无提升**。撞顶 30→29、平均输出 +49% → **多烧一半算力零收益**。`verdict_math500_iter4.json` exit=1 |
| Phi-4-mini-reasoning | **standard，T=0.8/top_p=0.95**（c16） | math **62.0%（不达标）** | 88.2 | u139 GPU 9:8012；iter3 59.5% → **62.0%（+2.5pt）**，但复读 31→2、撞顶 32→9。`verdict_math500_iter4.json` exit=1 |
| **Fathom-R1-14B** | **thinking 0.6/0.95 + graph，并发 8** | **68.0%（✅ 达标）** | 60.0 | u139 GPU 0-7:8002；贪心 54.0% → **68.0%（+14pt）**，30m05s 跑完，**runaway 0/50**。**两项修复（去 eager + 改采样）各自效果可分离** |
| **MiroThinker-v1.5-30B** | **thinking 0.6/0.95 + graph，并发 8** | **30.0%（✅ 达标但勉强）** | 25.0 | u139 GPU 8-15:8001；114m20s 跑完。⚠️ **runaway 仍 35/50**，34 道撞顶题只对 2 道 —— **达标由"能收尾的 16 题"贡献**。**5 个变量同变，无干净归因** |

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


### 🟡 服务运行状态（**截至 2026-09-21 22:26：Qwen2.5-72B 评测已完成，服务仍在运行**）

> **139 上除 Qwen2.5-72B 外的项目容器均已 `docker stop`（未删除，文件系统保留，`docker start` 可恢复）。**
> **147 全停。** `eval-scope` 在运行（不占 GPU）。
>
> ⚠️ **2026-09-21 22:26 起新增占用**：`flagrelease-fix-qwen2.5-72b-instruct` 仍在运行，
> **占 GPU 0-7、端口 8015**（graph 模式，TP=8，KV cache 222,352 tokens）——
> **评测已完成（56.0% 达标），服务按流程未自动停**。GPU 8-15 空闲。
> 如需释放全部 16 张卡，`docker stop flagrelease-fix-qwen2.5-72b-instruct` 即可（可 `docker start` 恢复）。

**iluvatar-139**

| 模型 | GPU | 端口 | 数据集 | attention-backend | 状态 |
|------|:---:|:----:|:------:|:-----------------:|------|
| **Qwen2.5-72B-Instruct** | **0-7** | **8015** | gpqa_diamond | TRITON_ATTN | 🟢 **运行中**（graph 模式 TP=8，2026-09-21 22:03 起）—— ✅ **已完成：56.0%，退化 0.00%，达标**，runaway 0/50 |
| **Fathom-R1-14B** | **0-7** | **8002** | gpqa_diamond | TRITON_ATTN | ⏹️ **已停**（graph 模式 TP=8）—— ✅ iter5 完成：**68.0%，达标**，runaway 0/50 |
| **MiroThinker-v1.5-30B** | **8-15** | **8001** | gpqa_diamond | TRITON_ATTN | ⏹️ **已停**（graph 模式 TP=8）—— ✅ iter5 完成：**30.0%，达标（勉强）**，⚠️ runaway 35/50 |
| **OpenReasoning-Nemotron-1.5B** | **0** | **8011** | math_500 (200题) | TRITON_ATTN | ⏹️ **已停**（iter4 完成：76.0%，↓9.52%，verdict exit=1） |
| **Phi-4-mini-reasoning** | **9** | **8012** | math_500 (200题) | TRITON_ATTN | ⏹️ **已停**（iter4 完成：62.0%，↓29.71%，verdict exit=1） |
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
| MiroThinker-v1.5-30B | 4-7 | 8001 | gpqa_diamond | TRITON_ATTN | ⏸️ 旧容器，iter3 中止后已停；**本轮改在 139 上重建容器运行** |

> ✅ **139 上两个 graph 服务已于 2026-09-20 01:00 停止，16 张卡全部释放**（均为 68MiB 基线）。
> ⚠️ 重启时注意：**它们的图只捕获了 batch=8**（`--max-num-seqs 8 --cudagraph-capture-sizes 8`），
> **并发超过 8 会退回 eager**，白费提速 —— 后续评测务必锁 8。
>
> **iter4/iter5 的 wrapper 都在 NFS `release_run_logs/_wrappers_backup/`**
> （`openreason_maxtok.py` / `phi4mini_sampling.py` / `fathom_graph_eval.py` / `miro_graph_eval.py` 等）——
> **不再只依赖容器 `/tmp`**。
> ✅ **`fast_gpqa.py`（NFS 已修补版）已拷入 139 的 eval-scope**，所以 iter5 两个评测**收尾没有再崩**
> （此前 4 次复评全部崩在 `detect_runaway`，分数得从报告里捞）。
> ⚠️ **147 的 eval-scope 尚未做这一步**，若在 147 起评测需先补。
> `phi4mini_sampling.py` / `fathom_graph_eval.py` / `miro_graph_eval.py` / `force_conc.py` 等）
> **已在 NFS `_wrappers_backup/` 备份，无需再抄进文档**。
> **所有评测进程、以及全部模型服务均已停止**（139 只剩 `eval-scope`，不占 GPU）。

跟踪进度：

```bash
# iluvatar-139 汇总 verdict（全量 18 个模型）
ssh iluvatar-139 'for m in LFM2.5-1.2B-Thinking LFM2.5-1.2B-Instruct gemma-1.1-7b-it OpenThinker-7B AgentCPM-Report Marco-o1 NeuralDaredevil-8B-abliterated Phi-3-medium-128k-instruct Qwen3-30B-A3B-Thinking-2507 Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled TinyR1-32B-Preview OpenReasoning-Nemotron-1.5B Phi-4-mini-reasoning Fathom-R1-14B MiroThinker-v1.5-30B; do echo "== $m =="; for v in /mnt/share/models/release_run_logs/$m/verdict*.json; do [ -f "$v" ] && python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(\" \",sys.argv[1].split(\"/\")[-1],d[\"current\"].get(\"score\"),\"aligned=\",d.get(\"aligned\"))" "$v"; done; done'

# --- 当前无在途评测；如需重跑，参考 fix log 里的 graph 模式启动命令 ---
# 检查 139 上两个 graph 服务是否还在
ssh iluvatar-139 'for c in flagrelease-fix-fathom-r1-14b flagrelease-fix-mirothinker-v1.5-30b; do printf "%-40s " $c; docker exec $c bash -c "pgrep -f \"vllm serve\" >/dev/null && echo UP || echo DOWN"; done'
```

> ⚠️ **verdict 生成注意**：thinking 模型常触发 `fast_gpqa` 的 `detect_runaway` list-content bug
> 导致 `score=null`，需从 evalscope 报告重建（见下方「已知问题」节）。
> ✅ **但该 bug 已在 iter5 前修好**（NFS 修补版 `fast_gpqa.py` 已拷入 eval-scope），
> **iter5 两个评测收尾没有再崩**，分数直接写出。
> **TinyR1 / OpenReasoning / Phi-4-mini 三者的 iter3 verdict 已于 2026-09-19 重建完毕**
> （`verdict_gpqa_iter3.json` / `verdict_math500_iter3.json` ×2）。
> ⚠️ **iter4 这两个评测虽然都是 standard 模式，但仍可能命中崩溃**（`detect_runaway` 对
> list content 的假设与模式无关）——若 `score=null`，同样从 evalscope 报告恢复。

---

## 待继续修复的 2 个模型：推进状态（0919 ~ 0920）

现状：**11 通过 / 6 跳过 / 2 待继续修复**。各模型的分数与已排除的假设见上方
「🔧 待继续修复的 2 个模型」表。

| 顺序 | 模型 | 状态 | 本轮结果 |
|:---:|------|------|---------|
| 1 | **OpenReasoning-Nemotron-1.5B** | ❌ **iter4 完成，假设证伪** | `max_tokens` 32768 → **65536**，采样不变 → **76.0%**（iter2 76.5%，**无提升**）。**截断假设被证伪** |
| 2 | **Phi-4-mini-reasoning** | ❌ **iter4 完成，假设证伪** | **T=0.8 / top_p=0.95** → **62.0%**（iter3 59.5%，**+2.5pt**）。复读 31→2 但分数没上来 → **采样不是主因** |
| 3 | **MiroThinker-v1.5-30B + Fathom-R1-14B** | ✅ **双双达标（已完成）** | **去 `--enforce-eager` + graph 模式 + 按 README 改采样** → Fathom **68.0%**（runaway 0/50）、MiroThinker **30.0%**（runaway 35/50）。**Fathom"放弃"结论被完全推翻** |

**iter4 的设计与结论（务必按此判读）**：

- **两个评测各自只改一个变量**，因此结论是干净的：
  - OpenReasoning 只抬 `max_tokens`（采样不变）→ **无效** → **不是截断**。
  - Phi-4-mini 只改采样（上限不变）→ **只 +2.5pt** → **不是采样**。
- ⚠️ **三条判读教训**（均已写入各自 fix log 的 KNOWLEDGE 节）：
  1. **"排除撞 max_tokens 的题再看分数"可能是幸存者偏差**。OpenReasoning iter2 排除后达 **90.0%**（> 基线），
     看着像"只差输出预算"；但抬了上限后**纹丝不动**，且 iter2 的 30 道撞顶题里有 **20 题给了 2 倍预算仍然撞顶**。
     **那些题是死循环，不是"差一点就写完"。该指标只能用于诊断，不能估计能力。**
  2. **"修好了明显的问题"≠"分数会上来"**。Phi-4-mini 的复读从 **31 降到 2（−94%）**、撞顶 **32→9（−72%）**，
     行为上极其成功，但**分数只 +2.5pt**，且"排除撞顶后"的分数**反而从 69.6% 降到 64.9%**。
     **复读只是在掩盖错误，不是在制造错误。**
  3. 🔴 **`--enforce-eager` 被当作"安全默认"会掩盖真实性能，且极易误判成硬件瓶颈**。
     Fathom 因此被判"固有性能瓶颈 → 放弃"，实际去掉后 **3.49 → 108.3 tok/s（31×）**。
     **"换机复现"不能证明是平台问题** —— 两台机器用同一套错误配置，结论就会一样错。
- **待继续修复的 2 个模型都在排除法上走到了尽头**
  （OpenReasoning 5 项、Phi-4-mini 4 项假设全部排除），剩余差距 **9.52% / 29.71% 无法归因**，
  嫌疑指向**算子精度**，但**无直接证据**。
  ⚠️ **不要把"最后剩下那个嫌疑"写成"根因"** —— 只能说"其余已排除"。

> **注（范围）**：`flagrelease_fail_reports/Iluvatar/` 有 25 份失败报告，STATUS.md 只跟踪 18 个。
> **9 个模型有 iluvatar 失败报告却无跟踪记录**（AceReason-Nemotron-7B、Apodex-1.0-4B-SFT、GLM-4.7-Flash、
> gpt-oss-20b、LFM2-2.6B-Exp、Ministral-3-14B-Instruct-2512、Moonlight-16B-A3B-Instruct、rnj-1-instruct、
> SOLAR-10.7B-Instruct-v1.0）。用户尚未答复是划归其他厂商还是漏了 —— **若这 9 个也要做，范围会扩大**。

> **历史参考**（0918 前的难度排序，现已作废）：Ministral-8B → Marco-o1 → NeuralDaredevil-8B → AgentCPM-Explore → MiroThinker → AgentCPM-Report → Fathom → QwQ-32B → TinyR1-32B。其中 AgentCPM-Report（49.49% ✅）、Marco-o1（噪声容忍 ✅）、Qwen3.5-27B（80.0% ✅）、**TinyR1-32B（62.0% ✅，0919）**、**Fathom-R1-14B（68.0% ✅，0919）**、**MiroThinker（30.0% ✅，0920）** 已达标，其余已跳过。
>
> ⚠️ **Fathom 与 MiroThinker 曾在本排序里被列为"最难的"，且 Fathom 已被判"放弃"** ——
> 两个最后都靠**常规手段**（去 eager + 改采样）达标。**"难"的判断本身可能建立在错误基线上。**
>
> **注**：OpenReasoning-Nemotron-1.5B 原标记为"放弃"，2026-09-18 因换 HF 权重重开评测；
> 2026-09-19 iter3（采样）与 iter4（截断）**两个假设都被证伪**，转入「待继续修复」。

---

## 已知问题：fast_gpqa.py detect_runaway 崩溃（**已修复并生效**）

- **现象**：thinking 模型评测跑完、evalscope 已算出分数，但 `fast_gpqa.py` 在收尾的 `analyze_predictions_runaway → detect_runaway` 报 `AttributeError: 'list' object has no attribute 'strip'`（line 370），导致 result JSON 未写出、compare 未跑。
- **根因**：thinking 模型 `message.content` 是多段结构（list），`detect_runaway` 直接 `(text or "").strip()` 假设是 str。
- **修复**：`detect_runaway` 开头加 list→str 归一（本地 + NFS `eval_methods/fast_gpqa.py` 已更新）。
- ⚠️ **2026-09-19 发现：该修复一度只落在 NFS 副本，容器内评测实际用的是另一份未打补丁的副本**：

  | 路径 | 大小 | 时间 | 含 `isinstance(text, list)` 修复 |
  |------|:----:|:----:|:---:|
  | `/models/flagrelease/eval_methods/fast_gpqa.py`（NFS） | 56996 | 09-15 07:13 | ✅ 有 |
  | `/workspace/eval_scripts/fast_gpqa.py`（**评测实际运行的**） | 54559 | 09-14 06:49 | ❌ **无** |

  这正是 0918 晚那 4 个复评（TinyR1 / OpenReasoning / Phi-4-mini / MiroThinker）**全部**没写出 `score` 的原因。
- ✅ **2026-09-19 已 cp 生效**：`docker cp /mnt/share/models/flagrelease/eval_methods/fast_gpqa.py eval-scope:/workspace/eval_scripts/fast_gpqa.py`
  （拷贝命令里必须用**宿主机路径** `/mnt/share/...`，容器内没有 `/models` 这个挂载点。）
  **效果已确认**：iter5 的 Fathom 与 MiroThinker 两个评测**收尾都没有再崩**，分数直接写出（`runaway_detection` 字段也正常）。
  ⚠️ **147 上的 eval-scope 尚未做这一步**，若在 147 起评测需先补。
- **影响与兜底**（历史，仍适用）：崩溃发生在算分之后，分数仍在 evalscope 原始报告
  `outputs/<dataset>/<ts>/reports/<model>/<dataset>.json`（字段 `metrics[0].score`，×100 即百分比）。
  已崩的可从报告重建 result JSON 再跑 compare。
- **注意**：从报告恢复时，`runaway_detection` 字段需要用**已修补**的 `fast_gpqa` 手动重算才能补上。

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
- **复评结果（0919/0920 收）—— 影响是 per-model 的，绝不能一概而论**：

  | 模型 | README/自带要求 | 贪心（旧口径） | 正确采样 | 结论 |
  |------|:---:|:---:|:---:|------|
  | **TinyR1-32B-Preview** | 0.6/0.95 | 58.0%（runaway 6/50） | **62.0%**（runaway 2/50） | ✅ **假设成立** → 达标 |
  | **Fathom-R1-14B** | 0.6/0.95 | 54.0% | **68.0%（+14pt，runaway 0/50）** | ✅ **成立，幅度最大** → 达标 |
  | OpenReasoning-Nemotron-1.5B | — | 76.5% | **73.5%** | ❌ 反而更低（后续证伪了"截断"，真因仍不明） |
  | Phi-4-mini-reasoning | **0.8**/0.95 | 41.0%（54% 题被截断） | **62.0%（仅 +2.5pt）** | ⚠️ 行为成立、分数不成立 |
  | MiroThinker-v1.5-30B | 0.6/0.95 | 18.0%（77% 撞顶） | **30.0%（达标）** | ⚠️ 分数上去了，但撞顶仍 68% |

  **教训：同一个 bug，5 个模型里 2 个靠修正采样达标（TinyR1 / Fathom）、3 个不是。
  修之前必须实跑对照，不能靠推理。**
  ⚠️ **对本模型的早期判读已修正**：Fathom 一节曾写"性能瓶颈是决定性的，修正采样也不改变处置"，
  该判断依赖了错误的性能瓶颈结论（真因是 `--enforce-eager`），**已作废**。
- **未受影响**：QwQ-32B、Qwen3-30B-A3B-Thinking-2507、Qwen3.5-27B 名字命中关键词，采样正确。
- **处置（已执行）**：用 wrapper 脚本 monkeypatch（`detect_thinking→True` + `resolve_gen_params→强制采样`）
  复评，**未改 `fast_gpqa.py` 本体**（同一容器还有其他评测在跑，避免污染）。
  **所有 wrapper 已备份到 NFS `release_run_logs/_wrappers_backup/`**（TinyR1 的另抄进了 fix log）。
- **⚠️ 修法不能照抄**：`is_thinking=True` 会连带把 `max_tokens` 收紧到 20000 并加 `remove_until='</think>'`。
  对 chat_template **不含 `<think>`** 的模型（如 **Phi-4-mini**），这是有害的（过滤器空转 + 上限收紧），
  **应只覆写采样参数、保持 standard 分支**。详见 `fixes/Phi-4-mini-reasoning.md`。
- **⚠️ 脚本本体仍未修，且修复有副作用**：根治需改
  ① `detect_thinking()` 的模式表、② `_resolve_model_dir()` 的路径解析、
  ③ **max_tokens 封顶过紧**（standard `clamp(max_model_len-8192, 4096, 32768)`、
  thinking `clamp(…, 8192, 20000)`，正在截断正常的思考链 —— OpenReasoning 的根因就是这个）。
  其中 ② 一旦生效会**同时改变所有模型**的采样（OpenThinker-7B / Marco-o1 的 0.0→0.7），
  会使已出分数的可比性被破坏，**需连带复核这两个模型的"达标"结论**。
- **判读提醒**：TinyR1（62.0%）、Fathom（68.0%）、MiroThinker（30.0%）的口径**均已修正为达标**；
  OpenReasoning 的 76.0% **不是**采样问题（是截断，且抬上限也救不回）；Phi-4-mini 的 62.0% 同理。

---

> 各模型修复日志：`workspace/iluvatar/fixes/<模型名>.md`
> 评测产出目录：`/mnt/share/models/release_run_logs/<模型名>/`
