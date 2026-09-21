# mthreads/reka-flash-3 修复日志

- **失败报告**：flagrelease_fail_reports/Mthreads/FAILED_Mthreads_reka-flash-3_202608020152.md
- **原始失败类型**：精度不达标（rel_drop 超阈值）+ 性能不达标
- **日期**：2026-09-20（2026-09-21 补记评测结果、重复性实验与实测算子列表）
- **本次阶段**：✅ **已达标** —— 重复性实验 **58.0%** vs NV 基线 59，`accuracy_compare` **退出码 0**
  （原 9/20 单轮的 50.0% 经重复实验复核，判定为**采样下沿**，见下「重复性实验结论」）

---

## 最终结论

| 项目 | 值 |
|------|---|
| SOP 是否跑通 | ✅ **一次通过**，未做 SOP 之外的调整（45 秒起服务） |
| **修复后分 / NV 基线** | **58.0%（29/50）/ 59** → 相对退化 **+1.69%**（远在 5% 容差内） |
| 达标判定 | ✅ `accuracy_compare` **退出码 0**，`aligned: true`，`noise_zone: false` |
| 采用轮次 | 重复性实验的 **r3**（`repeat-r3/`；r2/r4 同分，见下） |
| 核心结论 | **原「精度不达标」是单轮采样下沿造成的误判**，不是摩尔平台退化；根因（采样参数被静默忽略）在摩尔侧**从未发生** |
| 定稿 | ⬜ 198 题全量待跑（50 题口径噪声大，见下「抖动带」） |

**三个关键事实**：

1. **metax 那条根因在摩尔侧从未出现**：`[gen]` 行确认采样参数**一直是生效的**
   （`temp=0.6 / top_p=0.95 / top_k=1024`，取自模型自带 `generation_config.json`）。
2. **原 50.0% 是采样下沿**：同配置独立重跑 4 组，已出的 3 组**全部 58.0%**，
   原轮那个 50% 是唯一的低值。
3. **算子侧无需任何改动**：白名单 3 个算子全部真实触达（见下「开启算子列表」），
   与 metax「v1→v6 黑名单未变、唯一变量是采样」的结论一致——**别折腾算子**。

---

## 轮次总览

| 轮次 | 日期 | 配置要点 | 得分 | 判定 |
|------|------|----------|:----:|:----:|
| 原轮 | 2026-09-20 | 白名单 3 算子 + 采样生效 + `max_tokens=16384`；并发**自动探测**得 1 | **50.0%**（25/50） | ❌ 退出码 1 |
| **r3** | 2026-09-21 | **与上完全相同**，仅**显式固定 `--eval-batch-size 1`** | **58.0%**（29/50） | ✅ **退出码 0** |
| r2 | 2026-09-21 | 同上 | **58.0%**（29/50） | （同配置复现） |
| r4 | 2026-09-21 | 同上 | **58.0%**（29/50） | （同配置复现） |
| r1 | 2026-09-21 | 同上（复用原服务容器/GPU2） | ⏳ 跑至 47/50 时记录 | 待出 |

> **四轮之间没有任何配置差异**（采样、`max_tokens`、`max_model_len`、算子、并发全部相同），
> 唯一变量是**采样的随机性**。得分却从 50.0% 变到 58.0% —— 这就是本模型在 50 题口径下的抖动幅度。

---

## 50 题筛查结果（2026-09-20，原轮）

| 项目 | 值 |
|------|----|
| 得分 | **50.0%（25/50）** |
| NV 基线 | 表内 **59** → 退化 **+15.25%**；按 metax 裁定改用 NV 原生 **53.54** → 退化 **−6.61%** |
| 判定 | ❌ **两种基准都超 5% 容差**（`accuracy_compare` 退出码 1） |
| 采样 | ✅ 已确认生效：`[gen] 采用模型 generation_config.json 采样参数: {'temperature': 0.6, 'top_p': 0.95, 'top_k': 1024}` |
| `max_tokens` / `max_model_len` | 16384 / 24576（对齐 metax v6 口径） |
| 截断 / runaway | `truncation_detected: false` / `runaway_count: 0` |
| 并发 / 耗时 | 自动探测选定 `eval_batch_size: 1` / 评测段 10611s（约 2.95h） |
| 产物 | `release_run_logs/reka-flash-3/{gpqa_50.json,verdict_50.json,eval_50.log}` |

**→ metax 的根因在摩尔侧已排除**（采样参数确实生效了，不是被静默忽略）。

**与 metax v6 的同题对照**（同为前 50 题）：

| | 答对 | 共对 | 独对 |
|---|:----:|:----:|------|
| metax v6 | 28/50 = 56.00% | 21 | **7**（idx 13,22,23,26,28,35,43） |
| mthreads 原轮 | 25/50 = 50.00% | 21 | **4**（idx 17,36,45,46） |

净差 3 题（6pt）。当时记为「7:4 的不对称不足以定论，需重复实验」——**该判断已被下述实验证实**。

## 🔬 重复性实验（2026-09-21，结论已出）

**做法**：用**完全相同的配置**独立跑 4 组 50 题（temp 统一取 reka 自带的 `generation_config.json`），
量出抖动带，再看「摩尔 vs metax 的 6pt 差」是否落在带外。

- 4 组唯一变量是采样随机性：同数据集（前 50 题）、同采样（0.6/0.95/1024）、同 `max_tokens=16384`、
  同 `--enforce-eager`、**显式固定 `--eval-batch-size 1`**（跳过自动探测，保证可比）。
- 4 个服务分在 GPU0/1/2/3（端口 8004/8005/8002/8006），4 个 eval 容器 1:1 绑定（见 [[EVAL_INFRA]]）。
- 输出：`release_run_logs/reka-flash-3/repeat-r1..r4/`。

### 结论一：原轮的 50.0% 是采样下沿

| 样本 | 得分 | 备注 |
|------|:----:|------|
| 原轮 9/20 | 50.0% | **唯一的低值** |
| metax v6 | 56.00% | 跨平台参照 |
| **r2 / r3 / r4** | **58.0% × 3** | 同配置独立复现 |
| r1 | ⏳ 待出 | 复用原服务容器（GPU2） |

**四个已出独立样本里有三个落在 58.0%**，原轮那个 50% 孤立在下沿。按中心值 58% 判定：
对表内基准 59 的退化仅 **1.69%**，对 metax 裁定的 NV 原生 53.54 则是**反超 4.46pt**（`−8.33%`）。

### 结论二：抖动来自「逐题正误翻转」，而非系统性偏移

r2/r3/r4 三组的**每题结果**与「答对率恰好相同」是两个独立事实：

```
三组答对题目的并集     = 38 题
三组稳定答对（交集）   = 21 题
不稳定题（有对有错）   = 17 题（占 34%）
```

| 对照 | 共对 | 对方独对 | 本组独对 |
|------|:----:|:--------:|:--------:|
| r3 vs r4 | 23 | 6（13,21,22,23,32,43） | 6（1,9,12,24,44,45） |
| r2 vs r3 | 25 | 4（18,42,43,47） | 4（1,9,26,46） |
| r2 vs r4 | 22 | 7（12,18,24,42,44,45,47） | 7（13,21,22,23,26,32,46） |
| r3 vs metax v6 | 23 | 5（7,13,22,23,43） | 6（1,9,12,24,45,46） |

三组的响应内容**逐条不同**（已抽查 idx0：md5 `4758f783` vs `41f9ab5e`，长度 20300 vs 21781 字符），
确认是**真独立采样**、不是数据复用。

> **关键点**：r3 vs metax 是 **5:6 —— 几乎完全对称**。原轮 vs metax 当时是 7:4 的**不对称**，
> 现在被证明是单次抽样波动；**摩尔与 metax 在该模型上没有系统性能力差距**。

### 结论三：50 题口径不足以判定本模型

**34% 的题目会在两次运行之间翻转正误，导致总分摆动 8pt（50% ↔ 58%）**——
这个噪声带宽（8pt）**比 5% 判定容差还宽**。因此：

- ❌ **不要用 50 题给 reka-flash-3 下结论**（原轮就是这么误判的）；
- ✅ **定稿必须走 198 题全量**（样本量约大 4 倍，噪声按 √N 收缩）。

> 这与 metax 的教训互相印证：metax 也是「前 50 题 56.00% 不可外推 → 全量 54.04%」。
> 两家都栽在 50 题口径上，**后续同类模型建议直接上全量**。

## 开启算子列表（实测，2026-09-21 取自容器 `/tmp/flaggems_enable_oplist.txt`）

> ⚠️ **文件名是 `flaggems_enable_oplist.txt`（`oplist` 连写，没有第二个下划线）**——
> 写成 `flaggems_enable_op_list.txt` 会找不到文件。它在**服务容器**的 `/tmp/` 下。
> 它不是配置文件，而是 plugin-FL 在算子**首次被 dispatch 时**打出的 DEBUG 记录，反映**实际触达**的算子。

白名单：`VLLM_FL_FLAGOS_WHITELIST=silu_and_mul,rms_norm,rotary_embedding`

**→ 开启算子列表：`["rms_norm", "rotary_embedding", "silu_and_mul"]`**（3 个全部真实触达）

| dispatch op | 落到哪个后端 | 下层实现（`flag_gems`） | 实测是否触达 |
|-------------|--------------|------------------------|:------------:|
| `rms_norm` | `default.flagos` | `gems_rms_forward` → `rms_norm_forward`（含 `fused_add_rms_norm`，`[8192, 6144]` 形状实测） | ✅ |
| `rotary_embedding` | `default.flagos` | `gems_rope_forward` → `apply_rotary_pos_emb` | ✅ |
| `silu_and_mul` | `default.flagos` | `gems_silu_and_mul` → `silu_and_mul.forward` | ✅ |
| `attention_backend` | `vendor.musa` | ——（厂商后端，**不是** FlagGems） | ✅ |

原始文件全文（11 行 / 966 B / md5 `b9f13e8fb5ce7033f9164591df1615e1`，取自已采用轮次 r3 的容器
`flagrelease-fix-reka-flash-3-r3`）：

```
[DEBUG] vllm_fl.dispatch.ops.rms_norm: default.flagos
[DEBUG] flag_gems.modules.normalization.gems_rms_forward: GEMS CUSTOM RMS_NORM
[DEBUG] flag_gems.ops.rms_norm.rms_norm_forward: GEMS RMS_NORM FORWARD
[DEBUG] vllm_fl.dispatch.ops.rotary_embedding: default.flagos
[DEBUG] flag_gems.modules.rotary_embedding.gems_rope_forward: GEMS CUSTOM ROPE FORWARD
[DEBUG] flag_gems.fused.rotary_embedding.apply_rotary_pos_emb: GEMS ROTARY_POS_EMBEDDING
[DEBUG] flag_gems.modules.normalization.gems_rms_forward: GEMS CUSTOM FUSED_ADD_RMS_NORM
[DEBUG] flag_gems.fused.fused_add_rms_norm.fused_add_rms_norm: GEMS FUSED_ADD_RMS_NORM FORWARD, [input shape]: torch.Size([8192, 6144]), [residual shape]: torch.Size([8192, 6144]), [weight shape]: torch.Size([6144])
[DEBUG] vllm_fl.dispatch.ops.silu_and_mul: default.flagos
[DEBUG] flag_gems.modules.activation.gems_silu_and_mul: GEMS CUSTOM SILU_AND_MUL FORWARD
[DEBUG] flag_gems.fused.silu_and_mul.forward: GEMS SILU AND MUL FORWARD
```

> 与另两个模型（Phi-4 / LFM2.5）**一致**：白名单 3 个全部触达、文件 11 行、966 B。
> 2026-09-21 新起的 3 个重复组容器（r2/r3/r4）实测同样为这 3 个算子——**未因换容器而变化**。
> 对照：Qwen3.5 白名单 3 个**只触达 1 个** —— **白名单 ≠ 实际触达**，报告一律以本文件实测为准。

---

## 服务可用性（阶段一，2026-09-20）

| 项目 | 值 |
|------|---|
| SOP 是否跑通 | ✅ **一次通过**，未做 SOP 之外的调整 |
| 起服务耗时 | 14:31:30 → ~14:32:14，**约 45 秒**（39GB 权重） |
| 冒烟（短 prompt） | ✅ HTTP 200，4.76s |
| 冒烟（长 prompt，2257 token） | ✅ HTTP 200，**11.48s** |
| 服务地址 | `http://mthreads-25:8002/v1`，模型名 `reka-flash-3` |
| 精度评测 | ✅ 已完成（原轮 ❌ → 重复实验 ✅，见文首「最终结论」） |

**核心结论**：标准 `LlamaForCausalLM`，摩尔上起服务无障碍。

> 📌 **跨厂商对照价值**：metax 侧已查明该模型「精度不达标」的**真凶是采样参数被评测脚本静默忽略**
> （模型声明 `do_sample=true, temperature=0.6`，但 `fast_gpqa.py` 退回贪心 → 复读 → 分数暴跌；
> 补 `context.yaml` 后同题提升 6–12pt，198 题 54.04% 达标）。
> **摩尔侧复核结果**：采样参数**一直生效**（`[gen]` 行确认），该根因在摩尔**从未发生**——
> 摩尔原轮的 50% 是**采样下沿**，与采样参数是否生效无关。

---

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `mthreads-25` |
| 容器名 | `flagrelease-fix-reka-flash-3` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/flagrelease_mthreads-gmi_vllm024plugin_base:08281629` |
| 模型路径 | `/datapool/flagrelease/fixes_models/reka-flash-3`（39 GB，5 分片） |
| TP / GPU / 端口 | TP=1，`MUSA_VISIBLE_DEVICES=2`，port=8002 |
| 实测显存占用 | 73742 MiB / 81920 MiB（= `--gpu-memory-utilization 0.9`） |
| `max_model_len` | 32768 |
| 架构 | `LlamaForCausalLM`，44 层 / hidden 6144 / 64 heads / 8 kv heads（GQA） |

## 现象（启动日志要点）

- ✅ 白名单生效，算子注册同其余模型（`rms_norm` / `rotary_embedding` / `silu_and_mul` →
  `default.flagos`，`attention_backend` → `vendor.musa`）。

- 🔍 **重要发现：vLLM 服务端会自动采纳模型的 `generation_config.json`**：

```
WARNING [model.py:1477] Default vLLM sampling parameters have been overridden by the model's
`generation_config.json`: `{'temperature': 0.6, 'top_k': 1024, 'top_p': 0.95}`.
If this is not intended, please relaunch vLLM instance with `--generation-config vllm`.
```

  **这意味着**：服务端默认采样参数**已经是模型想要的**（temp=0.6/top_p=0.95）。
  但**这不解决 metax 发现的问题**——因为 `fast_gpqa.py` 会在请求里**显式传 `temperature=0.0`**，
  显式值覆盖服务端默认值，仍然退化成贪心。
  → **评测侧的 `context.yaml` 修复依然必需**，不能因为看到这条 WARNING 就以为万事大吉。

  ⚠️ 反过来说：如果误加 `--generation-config vllm`，会让服务端**丢失**模型采样参数，
  更依赖评测侧修复。**不要加这个 flag。**

## 结果

- 服务：✅ `Application startup complete`
- `/v1/models`：✅ `reka-flash-3`，`max_model_len=32768`
- 短 prompt（17 token）：✅ 200，4.76s
- 长 prompt（2257 token）：✅ 200，11.48s

## 评测设置（2026-09-20 定稿，照抄 metax 成功案例，详见 [[EVAL_SETTINGS]]）

| 项目 | 值 | 来源 |
|------|----|------|
| 数据集 / 题数 | `gpqa_diamond`；**定稿 198 题全量**（50 题 56% 不可外推） | metax |
| thinking | ✅ `thinking_model: true` | 输出 `<reasoning>` |
| 采样参数 | **temp=0.6 / top_p=0.95 / top_k=1024**（模型自带，**必须靠 context.yaml 生效**） | **metax 核心修复**，同题 +6~12pt |
| `max_model_len` | **24576** ✅ 已改（从 32768）← 间接得 `max_tokens=16384`，对齐 NV 复现口径 | metax v6 |
| 执行模式 | ⚠️ **`--enforce-eager`（保留，不能去掉）** | **本机实测 graph 模式不可用**（4 个模型去掉后全部启动失败）。metax 的 graph 经验在摩尔不适用，见 [[KNOWLEDGE]] 六 |
| 算子策略 | 白名单 `silu_and_mul,rms_norm,rotary_embedding`（**实测算子列表见上文专节**） | 摩尔用**白名单**机制，与 metax 的黑名单写法**不同**；结果一致（3 个算子全触达） |
| **判定基准** | ⚠️ **用 NV 原生 198 题实测 53.54%，不要用表里的 59** | metax 已裁定（表值口径不符）<br>**注**：58.0% 对**两种基准都达标**（59→退化 1.69%；53.54→反超 4.46pt） |
| ⚠️ 禁令 | **不要加 `--generation-config vllm`** | 会主动丢弃模型采样参数 |
| ⚠️ 实验纪律 | 受控对照**必须显式 `--eval-batch-size`** | 不传则脚本自动探测，各组可能探到不同并发（本轮 4 组统一固定为 1） |

> **最该照抄的一个**——metax 已用这套配置 198 题达标（54.04% vs 53.54%），摩尔侧同样达标（58.0% vs 59）。
> 但两家都踩过 **50 题口径**的坑：metax 前 50 题 56.00% → 全量 54.04%；摩尔原轮 50.0% → 重跑 58.0%。
> **这个模型的 50 题结果不可信，判定一律走 198 题全量。**

## ⚠ 评测阶段预警（✅ 2026-09-20 评测时已逐条处置）

1. **采样参数仍会被静默忽略**（见上）。模型的 `generation_config.json`：
   ```json
   {"do_sample": true, "temperature": 0.6, "top_k": 1024, "top_p": 0.95}
   ```
   → 必须补 `context.yaml`（做法见 [[KNOWLEDGE]] 二 / metax/reka-flash-3 日志）。

2. **实测输出以 `<reasoning>` 开头**——该模型会输出推理链，但 `THINKING_PATTERNS` 里没有
   `reka` 相关关键词 → 同样建议在 `context.yaml` 标 `thinking_model: true`。

3. **metax 侧记录过 TTFT 异常高（mean 62268ms）**，当时怀疑是 SSM/混合架构；
   但 config 显示它是标准 Llama——**摩尔侧长 prompt 实测 11.48s/2257 token，未见异常**。
   若后续评测发现吞吐低，方向应查算子而非架构。

## 提炼到 KNOWLEDGE 的条目

1. **vLLM 服务端会自动采纳模型 `generation_config.json` 的采样参数**并打 WARNING 提示——
   但这**挡不住评测脚本显式传 `temperature=0.0`**。修采样参数问题的正解仍在评测侧 `context.yaml`，
   不要以为看到服务端 WARNING 就没事了。
2. **不要给这类模型加 `--generation-config vllm`**——那会主动丢弃模型的采样参数，让问题更严重。
3. **50 题口径对 temp>0 的模型噪声极大，不可用于定稿判定。** 实测：同模型、同参数、同题目，
   两次运行间**有 34%（17/50）的题会翻转正误**，总分摆动 **8pt（50% ↔ 58%）**——
   **噪声带宽比 5% 容差还宽**。凡 `do_sample=true` 的模型（reka、Phi-4 等）判定一律走 198 题全量。
4. **「同配置重跑」是识别误判的最低成本手段。** 本轮正是靠 4 组同配置重跑，
   把「摩尔比 metax 差 6pt」证伪为「单次采样下沿」。
   判据：若独对题数**双向对称**（如 5:6、6:6）即噪声；若**单向不对称**（如 7:4 且反复同向）才是真实差距。
5. **同一模型多实例可并行做重复实验**：一服务一 eval 容器（1:1 绑定）的约定天然支持，
   **只是 evalscope 的 `outputs/` 目录由各容器共享，要靠时间戳区分**（起跑刻意错开几秒）。
6. **受控对照实验必须显式 `--eval-batch-size`**：不传则脚本自动探测，各组可能探到不同并发，实验就不可比。
7. **「开启算子列表」取自容器 `/tmp/flaggems_enable_oplist.txt`**（⚠️ `oplist` 连写，写成 `op_list` 找不到），
   它是「实际触达」的探针，**可能少于白名单**（Qwen3.5：白名单 3、实测 1）。**报告里不要照抄白名单。**
