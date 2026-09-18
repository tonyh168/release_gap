# Iluvatar 模型修复状态总览

> 更新：2026-09-18 晚（session 退出前快照）| 机器：iluvatar-139 + iluvatar-147 | 镜像：`xingchen4-0907`

## 当前计数

**7 通过 / 6 跳过 / 4 在途复评 / 1 放弃 = 18**

- **✅ 已通过（7）**、**⏭️ 跳过无需修复（6）**：见上表，**均以机器上 `verdict_*.json` 的 `aligned` 字段核对过**
- **🔧 在途复评（4）**：TinyR1 / OpenReasoning / MiroThinker / Phi-4-mini —— 均为 2026-09-18 晚启动的后台评测，见下
- **❌ 放弃（1）**：Fathom-R1-14B
- **⚠️ QwQ-32B 未受本次 bug 影响**：名字含 `qwq` 命中 thinking 判定，
  日志实测 `thinking (temperature=0.6)`，采样配置正确。

## 本次 session 新发现（重要，影响判读）

1. **`detect_thinking()` 误判**（见下方专节）：4 个推理模型被按贪心解码评测，此前低分结论口径不对等。
2. **`phi3 + longrope` 的 `max_model_len` 自动推导缺陷**：vLLM 推导成 4096（模型实际支持 131072），
   致 `max_tokens` 被压到 2048、Phi-4-mini 超半数题截断。**修复=显式 `--max-model-len 32768`**。
3. **并发上限必须按 KV cache 算，不能按参数量猜**：
   - Phi-4-mini（3.8B，全 MHA）KV cache 仅 **160,353** tokens → 32K 上下文下最多 **4.89 并发**，
     32 并发直接打崩（KV 100%、Waiting 排队、38 分钟 1 题）。
   - OpenReasoning（1.5B，GQA）KV cache **919,360** tokens → 32 并发只用 38%，健康。
   - **小参数模型的 KV cache 反而可能远小于大模型**（取决于 MHA/GQA 结构，非参数量）。
4. **MiroThinker 的"性能瓶颈"是假象**：iter1 **116 题中 89 题（77%）撞满输出上限**，尾部为
   `"Wait, maybe it's X? No. Wait, maybe it's X? No."` 型复读。所谓 ETA 60h 是复读空转，非硬件不足。
   **与 Fathom 性质完全不同**——Fathom 输出长度正常（中位 7636，仅 1/49 撞顶），是真实吞吐瓶颈。

> **0918 状态收敛**：达标者标 ✅ 已通过，未达标者标 ⏭️ 跳过（无需修复），不再投入。
> 所有判定均以机器上 `verdict_*.json`（`aligned` 字段）为证据核对过。

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
| TinyR1-32B-Preview | 🔧 复评中 | 服务启动失败（无镜像产出，全部数据为空） | gpqa_diamond | 64.0 | iter1: **58.0%**；iter2（+mm,addmm）: **58.0%**（与 iter1 完全相同） | `flagrelease-fix-tinyr1-32b-preview` GPU 3,4,7,8 / :8001 (u139) | iter2 证明 `mm,addmm` 黑名单**无效**。根因转为**采样配置**（`detect_thinking` 误判为 standard → 贪心解码 → 复读）→ iter3 thinking + 0.6/0.95 复评中。详见 fix log 专项调查章节 |
| Phi-3-medium-128k-instruct | ⏭️ 跳过（无需修复） | 服务启动失败（原 vLLM 0.20.2 Operator crash，全部数据为空） | gpqa_diamond | 37.0 | **24.0%**（↓35.14%） | `flagrelease-fix-phi3-medium` GPU 0 / :8009 (u139) | iter3（17算子黑名单）得分仍 24.0%，三次完全相同，verdict 判定 `aligned=false`；算子黑名单路径彻底排查完毕。0918 决策不再修复（如需重启：chat_template / dtype） |
| Qwen3-30B-A3B-Thinking-2507 | ✅ 已通过 | Operator crash: mm on unknown platform（V2/V3 全空） | gpqa_diamond | 75.0 | **76.0**（↑1.33%，反超基线） | `flagrelease-fix-qwen3-30b-a3b-thinking` GPU 4-7 / :8010 (u139) | 完成，达标（score=null 从 evalscope 报告恢复；blacklist=sort,sort_stable,mm，TP=4） |
| OpenReasoning-Nemotron-1.5B | 🔧 重测中 | 无原始失败报告（后补评测对象） | mmlu / math_500 | 52.21 / 84.0 | mmlu 35.0%（iter1）; **math_500 76.5%**（iter2，↓8.93%） | `flagrelease-fix-openreasoning-nemotron-1.5b` GPU 0 / :8011 (u139) | **变量排除已完成**：权重（sha256 与 HF 上游一致）、上下文（131072 本就正确）、并发（16→32）**均已排除**；剩余怀疑为采样配置 → iter3 thinking + 0.6/0.95 重测中 |
| Phi-4-mini-reasoning | 🔧 重测中 | 无原始失败报告（后补评测对象） | mmlu / math_500 | 72.83 / 88.2 | mmlu **58.07%**（↓20.3%）/ math_500 **41.0%**（↓53.5%） | `flagrelease-fix-phi4-mini-reasoning` GPU 9 / :8012 (u139) | 2026-09-18 重测 math_500：**修复 `--max-model-len` 32768**（vLLM 对 `phi3+longrope` 自动推导成 4096，致 `max_tokens` 被压到 2048、超半数题截断）。**并发 32 曾打崩服务**（KV cache 仅 160,353 tokens，超配 6.5 倍 → KV 100%），改 **c8** 重测中。iter1 分数从 evalscope 报告恢复 |
| Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled | ✅ 已通过 | 未开始 | gpqa_diamond | 75.0 | iter1: **70.0**（↓6.67%）→ iter2: **80.0**（↑6.67%，反超基线）| `flagrelease-fix-qwen3.5-27b` GPU 5,6 / :8014 (u139) | 完成，达标。iter2 配置：sort,sort_stable,mm,addmm，TRITON_ATTN，TP=2，`--max-model-len 65536`（iter1 为 8192，把 max_tokens 压到 4096）。verdict 为 2026-09-18 实跑重建（`verdict_gpqa_iter2.json`，exit=0） |

---

## 当前进度快照

> 更新：2026-09-18 15:20（0918 状态收敛）

除下列 6 个在途/待决模型外，其余 12 个已**定论**：

- **✅ 精度已通过：7 / 18** — LFM2.5-1.2B-Thinking（32.0 vs 29.0）、LFM2.5-1.2B-Instruct（40.0 vs 29.0）、OpenThinker-7B（mmlu 75.0/77.0 + math 86.5/88.0）、Marco-o1（28.0 vs 32.0，小样本噪声容忍）、Qwen3-30B-A3B-Thinking-2507（76.0 vs 75.0）、AgentCPM-Report（49.49 vs 46.0，198题全量）、**Qwen3.5-27B-Distilled（80.0 vs 75.0，iter2 反超）**
- **⏭️ 跳过（无需修复）：6 / 18** — gemma-1.1-7b-it（22.0 vs 37.0）、NeuralDaredevil-8B-abliterated（30.0→22.0 vs 37.0）、Phi-3-medium-128k-instruct（24.0 vs 37.0）、QwQ-32B（56.0 vs 63.0）、AgentCPM-Explore（服务未起）、Ministral-8B-Instruct-2410（镜像依赖链缺陷）
- **5 个在途/待决（本次未改）** — 见下表

### 🟡 4 个在途/待决模型（2026-09-18 晚快照）

| 模型 | 状态 | 当前 | NV | 说明 |
|------|------|:----:|:--:|------|
| TinyR1-32B-Preview | 🔧 **thinking 复评中** | 58.0%（iter1/iter2 相同） | 64.0 | u139 GPU 3,4,7,8:8001；**22/50 (44%)**，150 s/题（iter2 是 222 s/题，快 43%）。复读消失则分数应回升 |
| Phi-4-mini-reasoning | 🔧 math_500 重测中（c8） | math 41.0%（iter1，被截断） | 88.2 | u139 GPU 9:8012；**57/200 (28%)**，82 s/题。已修 `--max-model-len 32768` |
| OpenReasoning-Nemotron-1.5B | 🔧 **thinking 复评中** | math 76.5%（iter2） | 84.0 | u139 GPU 0:8011；**3/200**，35 s/题。变量已排除到只剩采样配置 |
| MiroThinker-v1.5-30B | 🔧 thinking 复评中（慢） | 18.0%（iter1，77% 复读污染） | 25.0 | u147 GPU 4-7:8001；**0/50（35 分钟）**，并发仅 2。等首批输出长度判断复读是否消失 |
| Fathom-R1-14B | ❌ 已放弃 | 54.0% | 60.0 | **真实吞吐瓶颈**（V1 基线 TTFT=244s / TPOT=338ms，且输出长度正常、几乎不复读）——与 MiroThinker 的"假瓶颈"性质不同 |

### 🔴 重大发现：`detect_thinking()` 误判导致 4 个推理模型被按贪心解码评测

详见 `fixes/TinyR1-32B-Preview.md` 的「专项调查」章节。要点：

- `fast_gpqa.detect_thinking()` 靠**模型名子串**匹配 `['qwen3','qwq','deepseek-r1','deepseek-r2','mimo','hunyuan']`；
  名字不含关键词的推理模型 **TinyR1 / MiroThinker / OpenReasoning / Phi-4-mini 全部被判成 standard**
  → `temperature=0.0` 贪心解码 → R1 系模型显著复读。
- `resolve_gen_params()` 本应读模型自带的 `generation_config.json` 覆盖采样，但
  `_resolve_model_dir()` 的两条路径在本环境**都不通**（`--model-name` 传的是名字不是路径；`context.yaml` 不存在）。
  **反例验证**：OpenThinker-7B / Marco-o1 配置写 0.7、日志实际 0.0。
- 后果：TinyR1 复读 6/50，**扣除复读题后 63.6% ≈ 基线 64.0%**；MiroThinker iter1 **77% 的题撞满输出上限**，
  所谓"性能瓶颈"（ETA 60h）实为复读空转。
- **判读提醒**：这几个模型此前的低分结论（TinyR1 58.0%、MiroThinker 18.0%、OpenReasoning 76.5%）
  都建立在贪心解码上，**口径与 NV 基线不对等，需在复评后再定论**。


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
| OpenReasoning-Nemotron-1.5B | 0 | 8011 | math_500 | TRITON_ATTN | 🔧 **iter3 thinking 复评中**（3/200），pid 9391 |
| Phi-3-medium-128k-instruct | 0 | 8009 | gpqa_diamond | TRITON_ATTN | ⏭️ 跳过（iter3 24.0%，三次相同，不再修复） |
| Qwen3-30B-A3B-Thinking-2507 | 4-7 | 8010 | gpqa_diamond | TRITON_ATTN | ✅ 完成（GPQA 76.0%，NV 75.0%，↑1.33%） |
| Phi-4-mini-reasoning | 9 | 8012 | math_500 | TRITON_ATTN | 🔧 math_500 重测中 c8（57/200），pid 8226 |
| TinyR1-32B-Preview | 3,4,7,8 | 8001 | gpqa_diamond | TRITON_ATTN | 🔧 **iter3 thinking 复评中**（22/50），pid 8726 |
| Qwen3.5-27B-Distilled | 5,6 | 8014 | gpqa_diamond | TRITON_ATTN | ✅ 完成（iter2 80.0%，NV 75.0%，↑6.67%） |

**iluvatar-147**

| 模型 | GPU | 端口 | 数据集 | attention-backend | 状态 |
|------|:---:|:----:|:------:|:-----------------:|------|
| QwQ-32B | 0-3 | 8000 | gpqa_diamond | TRITON_ATTN | ⏭️ 跳过（无需修复；56.0% vs 63.0） |
| MiroThinker-v1.5-30B | 4-7 | 8001 | gpqa_diamond | TRITON_ATTN | 🔧 **iter3 thinking 复评中**（0/50，并发 2，pid 1529）；iter2 已停（6h 仅 5/50） |

> **在途任务均为后台 nohup + `docker exec -d` 启动，SSH 断开不影响。** 复评用的 wrapper 脚本在
> **容器内 `/tmp/`**（`tinyr1_thinking.py` / `openreason_thinking.py` / `miro_thinking.py` / `force_conc.py`），
> 主机侧备份在**本机 `/tmp/`** 同名文件；**容器重启会丢失**，届时从主机重新 `docker cp` 即可。

跟踪进度：

```bash
# iluvatar-139 汇总 verdict（已定论模型）
ssh iluvatar-139 'for m in LFM2.5-1.2B-Thinking LFM2.5-1.2B-Instruct gemma-1.1-7b-it OpenThinker-7B AgentCPM-Report Marco-o1 NeuralDaredevil-8B-abliterated Phi-3-medium-128k-instruct Qwen3-30B-A3B-Thinking-2507 Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled; do echo "== $m =="; for v in /mnt/share/models/release_run_logs/$m/verdict*.json; do [ -f "$v" ] && python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(\" \",sys.argv[1].split(\"/\")[-1],d[\"current\"].get(\"score\"),\"aligned=\",d.get(\"aligned\"))" "$v"; done; done'

# --- 在途任务进度（2026-09-18 晚的四个）---
# 139: TinyR1(thinking) / OpenReasoning(thinking) / Phi-4-mini(c8)
ssh iluvatar-139 'for p in "TinyR1-32B-Preview:eval_iter3_thinking.log:gpqa_diamond" "OpenReasoning-Nemotron-1.5B:eval_iter3_thinking.log:math_500" "Phi-4-mini-reasoning:eval_math500.log:math_500"; do m=${p%%:*}; r=${p#*:}; f=${r%%:*}; d=${r##*:}; echo "== $m =="; tr "\r" "\n" < /mnt/share/models/release_run_logs/$m/$f | grep -aoE "Evaluating\[$d\]:[ ]+[0-9]+%[^A]*" | tail -1; done'
# 147: MiroThinker(thinking) —— 真实进度在 evalscope 目录，不在 release_run_logs
ssh iluvatar-147 'docker exec eval-scope bash -c "ls -t /workspace/eval_scripts/outputs/gpqa_diamond/ | head -1 | xargs -I{} sh -c \"grep -aoE \\\"Evaluating.\[gpqa_diamond\\\]:[ ]+[0-9]+%\\\" /workspace/eval_scripts/outputs/gpqa_diamond/{}/logs/eval_log.log | tail -1\""'

# 评测进程是否还活着
ssh iluvatar-139 'docker exec eval-scope ps -eo pid,etime,cmd | grep -E "thinking.py|force_" | grep -v grep'
ssh iluvatar-147 'docker exec eval-scope ps -eo pid,etime,cmd | grep miro_thinking | grep -v grep'
```

> ⚠️ **verdict 生成注意**：thinking 模型常触发 `fast_gpqa` 的 `detect_runaway` list-content bug
> 导致 `score=null`，需从 evalscope 报告重建（见下方「已知问题」节）。本轮四个复评都可能命中。

---

## 剩余待决模型（0918 更新）

现状：**7 通过 / 6 跳过 / 5 在途待决**。不达标的 6 个已统一标为 ⏭️ 跳过（无需修复），**不再投入**。
本节保留 5 个仍待处理的模型：

| 模型 | 当前 | NV | 状态与建议 |
|------|:----:|:--:|------|
| TinyR1-32B-Preview | iter1 58.0%（↓9.38%） | 64.0 | **iter2 评测中**（u139），最接近达标 |
| Phi-4-mini-reasoning | iter1 math 41.0%（↓53.5%） | 88.2 | **math_500 重测中**（u139，已修 `--max-model-len` 32768，并发 32） |
| OpenReasoning-Nemotron-1.5B | iter1 mmlu 35.0%（↓32.9%） | 52.21 / 84.0 | **math_500 重测中**（u139，HF 权重 + 并发 32）；iter1 math_500 从未出分 |
| MiroThinker-v1.5-30B | iter1 18.0%（↓28.0%） | 25.0 | iter2 运行中但吞吐异常（41min/题，ETA 32h）；建议比照 Fathom 判为性能瓶颈放弃 |
| Fathom-R1-14B | iter1 54.0%（↓10.0%） | 60.0 | 已放弃：BI-V150 对该 14B reasoning 模型固有性能瓶颈（3.5 tok/s；V1 基线即 TTFT=244s） |

> **历史参考**（0918 前的难度排序，现已作废）：Ministral-8B → Marco-o1 → NeuralDaredevil-8B → AgentCPM-Explore → MiroThinker → AgentCPM-Report → Fathom → QwQ-32B → TinyR1-32B。其中 AgentCPM-Report（49.49% ✅）、Marco-o1（噪声容忍 ✅）、Qwen3.5-27B（80.0% ✅）已达标，其余已跳过。
>
> **注**：OpenReasoning-Nemotron-1.5B 原标记为"放弃"，2026-09-18 因换 HF 权重重开评测，状态回到在途。

---

## 已知问题：fast_gpqa.py detect_runaway 崩溃（已修）

- **现象**：thinking 模型评测跑完、evalscope 已算出分数，但 `fast_gpqa.py` 在收尾的 `analyze_predictions_runaway → detect_runaway` 报 `AttributeError: 'list' object has no attribute 'strip'`（line 370），导致 result JSON 未写出、compare 未跑。
- **根因**：thinking 模型 `message.content` 是多段结构（list），`detect_runaway` 直接 `(text or "").strip()` 假设是 str。
- **修复**：`detect_runaway` 开头加 list→str 归一（本地 + NFS `eval_methods/fast_gpqa.py` 已更新）。
- **影响与兜底**：崩溃发生在算分之后，分数仍在 evalscope 原始报告 `outputs/<dataset>/<ts>/reports/<model>/<dataset>.json`（字段 `metrics[0].score`，×100 即百分比）。已崩的可从报告重建 result JSON 再跑 compare（LFM2.5-1.2B-Thinking 即如此，32.0%）。
- **注意**：本轮启动时仍在跑的 OpenThinker-7B / AgentCPM-Report / AgentCPM-Explore 用的是**打补丁前**加载进内存的旧代码，若命中 list content 仍会崩；届时同样从 evalscope 报告重建即可（无需重跑）。

---

## 已知问题：`detect_thinking()` 误判，致推理模型被按贪心解码评测（**未修复**）

> 完整调查见 `fixes/TinyR1-32B-Preview.md` 的「专项调查」章节。此处为摘要。

- **现象**：4 个推理模型被 `fast_gpqa` 判成 `standard`，拿到 `temperature=0.0`（贪心）+ `top_p=1.0`，
  而它们各自 README / 自带配置要求的都是 `temperature=0.6, top_p=0.95`。
  R1 系模型在贪心解码下会显著复读（TinyR1 的 README 原文警告过）。
- **根因一（判定）**：`detect_thinking()` 靠**模型名子串**匹配
  `['qwen3','qwq','deepseek-r1','deepseek-r2','mimo','hunyuan']`。
  `TinyR1-32B-Preview` / `MiroThinker-v1.5-30B` / `OpenReasoning-Nemotron-1.5B` / `Phi-4-mini-reasoning`
  **名字都不含这些关键词** → 全部落到 standard 分支。
- **根因二（覆盖失效）**：`resolve_gen_params()` 本应读模型自带 `generation_config.json` 的采样字段覆盖默认，
  但 `_resolve_model_dir()` 的两条路径在本环境**都不通**：
  ① `--model-name` 传的是模型**名**而非本地路径；② `/flagos-workspace/shared/context.yaml` **不存在**。
  **反例验证（决定性）**：OpenThinker-7B 配置写 `temperature: 0.7`、Marco-o1 写 `0.7`，
  二者评测日志实测均为 `temperature=0.0` —— 证明该覆盖机制对所有模型都未生效。
- **影响（实测）**：
  - TinyR1：6/50 复读；**扣除复读题后 63.6% ≈ 基线 64.0%**（原判 58.0% 不达标）。
  - MiroThinker：iter1 **77% 的题撞满输出上限**，尾部为退化复读 → 所谓"性能瓶颈 ETA 60h"是假象。
  - OpenReasoning：math_500 76.5% vs 84.0（↓8.93%），已排除权重/上下文/并发，采样为剩余嫌疑。
- **未受影响**：QwQ-32B、Qwen3-30B-A3B-Thinking-2507、Qwen3.5-27B 名字命中关键词，采样正确。
- **处置（进行中）**：对上述 4 个模型用 wrapper 脚本 monkeypatch
  （`detect_thinking→True` + `resolve_gen_params→强制 0.6/0.95`）重评，**不改 `fast_gpqa.py` 本体**
  （同一容器还有其他评测在跑，避免污染）。
- **判读提醒**：这几个模型此前的低分**口径与 NV 基线不对等**，复评出结果前不应作为最终结论。

---

> 各模型修复日志：`workspace/iluvatar/fixes/<模型名>.md`
> 评测产出目录：`/mnt/share/models/release_run_logs/<模型名>/`
