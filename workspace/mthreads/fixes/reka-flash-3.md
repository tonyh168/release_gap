# mthreads/reka-flash-3 修复日志

- **失败报告**：flagrelease_fail_reports/Mthreads/FAILED_Mthreads_reka-flash-3_202608020152.md
- **原始失败类型**：精度不达标（rel_drop 超阈值）+ 性能不达标
- **日期**：2026-09-20（2026-09-21 补记评测结果、重复性实验与实测算子列表）
- **本次阶段**：⚠️ **按 53.54 基准判达标（54.8%）** —— 但 **50 题口径噪声达 8pt，结论不稳**，
  定稿须走 198 题全量。5 轮独立评测的完整图景见下。

---

## 最终结论

| 项目 | 值 |
|------|---|
| SOP 是否跑通 | ✅ **一次通过**，未做 SOP 之外的调整（45 秒起服务） |
| **修复后分（5 轮均值）** | **54.8%**（50 题口径；单轮区间 **50.0% ~ 58.0%**） |
| **判定（按 metax 裁定的 53.54）** | ✅ 反超 **2.4%** → 达标 |
| **判定（按表内 59）** | ❌ 退化 **7.1% > 5%** → 不达标 |
| 核心结论 | ① metax 那条根因（采样参数被静默忽略）在摩尔侧**从未发生**；<br>② **算子侧无需任何改动**；<br>③ **50 题口径不足以给本模型定案** —— 5 轮里出现「两簇」（50 ×2 / 58 ×3） |
| 定稿 | ⬜ **198 题全量待跑（这是唯一能定案的口径）** |

> ⚠️ **基准口径决定结论走向**：`nv_baseline.yaml` 表内 59 与 metax 裁定的 NV 原生 53.54
> 相差 5.5pt，而本模型 50 题的抖动就是 8pt——**基准的选择比测量的噪声还关键**。
> 依 metax 的裁定（表内 59 出自 NV 失败报告，同报告记录 NV 硬件上 plugin-FL 同样造成 12pt 退化，
> 口径不可比）采用 53.54，判达标。

---

## 轮次总览（5 轮，配置完全相同）

| 轮次 | 服务容器 / 服务进程 | 得分 | 判定（59 基准） |
|------|---------------------|:----:|:---------------:|
| 原轮 · 9/20 | `flagrelease-fix-reka-flash-3` / 9-20 15:13 启动 | **50.0%**（25/50） | ❌ |
| r1 · 9/21 | **同一容器、同一进程**（跑满 26h） | **50.0%**（25/50） | ❌ |
| r2 · 9/21 | `...-r2` / 9-21 14:22 启动 | **58.0%**（29/50） | ✅ |
| **r3** · 9/21 | `...-r3` / 9-21 14:22 启动 | **58.0%**（29/50） | ✅ |
| r4 · 9/21 | `...-r4` / 9-21 14:22 启动 | **58.0%**（29/50） | ✅ |

> **5 轮之间没有任何配置差异**（模型权重、采样 `0.6/0.95/1024`、`max_tokens=16384`、
> `max_model_len=24576`、算子白名单、`--enforce-eager`、并发 1 全部相同），
> **唯一变量是「服务实例」与「采样随机性」**。得分区间 50.0 ~ 58.0%，均值 **54.8%**。

---

## 🔬 重复性实验：出现「两簇」，未能归因（2026-09-21）

原计划是「同配置跑 4 组量抖动带」，结果**跑出了一个未能解释的分簇**：

```
老服务进程（9-20 启动）  : 50.0% , 50.0%     ← 同一进程跑两次
新服务进程（9-21 启动）×3 : 58.0% , 58.0% , 58.0%
```

**为什么倾向认为不是纯随机**：若单轮成功概率 p≈0.54，5 个独立样本恰好落成
`25,25,29,29,29`（前两个同分、后三个同分）的概率量级约 **10⁻⁶**。分簇太整齐。

**但也不是「确定性种子」**：

- 同一进程的两次（原轮 vs r1）**逐题并不可复现**：共对仅 18 题，**14 题翻转**，
  连抽出的选项都只有 **27/50** 相同；
- 响应长度分布两组基本一致（中位 ~14–15k 字符）；
- **全链路没有任何 `--seed`**（`fast_gpqa.py` 不传、evalscope 不传、`vllm serve` 也没加）。

**已排查、均排除的原因**：引擎配置差异（两边 `GPU KV cache size: 231,376 tokens` 一致）、
响应长度分布差异、`truncation_detected`、`runaway_count`（全为 0）、`[gen]` 采样参数（逐轮一致）。

**处置**：老容器 `flagrelease-fix-reka-flash-3` **已于 2026-09-21 停止**（`docker stop`，容器保留未删），
**未继续追查根因**（发起人决定）。在跑的新容器为 `-r2` / `-r3` / `-r4`。

> ⚠️ **这意味着当前对 reka 的任何判定都带不确定性**：若老进程存在系统性偏差，54.8% 的均值被拉低；
> 若只是噪声，54.8% 就是真相。**198 题全量是唯一能压住这个噪声的口径**（样本量 ×4，噪声按 √N 收缩）。

### 用来判断的分项证据

| 对照 | 关系 | 共对 | 独对 |
|------|------|:----:|:----:|
| 原轮 vs r1 | **同容器同进程** | 18 | 14 题翻转 |
| r2 vs r3 | 同批新容器 | 25 | 4 / 4 |
| r3 vs r4 | 同批新容器 | 23 | 6 / 6 |
| r2 vs r4 | 同批新容器 | 22 | 7 / 7 |
| 原轮 vs r3 | **跨簇** | 22 | 3 / 7 |
| **r3 vs metax v6** | 跨平台 | 23 | **5 / 6（对称）** |

> 新容器三组之间独对**双向对称**（4:4、6:6、7:7），符合纯噪声特征；
> 但**跨簇对照（原轮 vs r3）是 3:7 的偏斜**，与「两簇」现象一致。
> 而 **r3 vs metax v6 是 5:6 对称** —— **在 58% 那一簇上，摩尔与 metax 无系统性差距**。


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

净差 3 题（6pt）。当时记为「7:4 的不对称不足以定论，需重复实验」——
**实验证实了这个怀疑，但也带出了一个未能解释的分簇**（见上「🔬 重复性实验」）。

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
| 精度评测 | ✅ 已完成（5 轮，见文首「轮次总览」与「最终结论」） |

**核心结论**：标准 `LlamaForCausalLM`，摩尔上起服务无障碍。

> 📌 **跨厂商对照价值**：metax 侧已查明该模型「精度不达标」的**真凶是采样参数被评测脚本静默忽略**
> （模型声明 `do_sample=true, temperature=0.6`，但 `fast_gpqa.py` 退回贪心 → 复读 → 分数暴跌；
> 补 `context.yaml` 后同题提升 6–12pt，198 题 54.04% 达标）。
> **摩尔侧复核结果**：采样参数**一直是生效的**（`[gen]` 行逐轮确认），该根因在摩尔**从未发生**——
> 摩尔的问题在别处（50 题口径噪声 + 未归因的两簇，见上），**与采样参数是否生效无关**。

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
   两轮间**有 14~17 题（28~34%）翻转正误**，总分摆动 **8pt（50.0% ↔ 58.0%）**——
   **噪声带宽比 5% 容差还宽**。凡 `do_sample=true` 的模型（reka、Phi-4 等）判定一律走 198 题全量。
4. **「同配置重跑」能证伪误判，但不能只看均值 —— 要先检查有没有「分簇」。** 本轮 5 组同配置重跑
   得到 `50,50 | 58,58,58` 两簇：**簇内高度一致、跨簇差 8pt**，这种形态**不能用「采样下沿」解释**。
   判据：① 独对题数**双向对称**（5:6、6:6）→ 噪声；② 样本落成**整齐的分簇** → 先怀疑实例级差异
   （服务进程 / 卡 / 容器），**别急着按均值下结论**。
5. **同容器同进程重跑并不等于可复现**：实测同一 `vllm serve` 进程跑两轮，逐题共对仅 18/50、
   14 题翻转，抽出的选项只有 27/50 相同 —— **无 `--seed` 时，同进程两次也是独立采样**。
   想真正复现需要显式 seed（`fast_gpqa.py` / evalscope / `vllm serve` 目前都不传）。
6. **同一模型多实例可并行做重复实验**：一服务一 eval 容器（1:1 绑定）的约定天然支持，
   **只是 evalscope 的 `outputs/` 目录由各容器共享，要靠时间戳区分**（起跑刻意错开几秒）。
7. **受控对照实验必须显式 `--eval-batch-size`**：不传则脚本自动探测，各组可能探到不同并发，实验就不可比。
8. **「开启算子列表」取自容器 `/tmp/flaggems_enable_oplist.txt`**（⚠️ `oplist` 连写，写成 `op_list` 找不到），
   它是「实际触达」的探针，**可能少于白名单**（Qwen3.5：白名单 3、实测 1）。**报告里不要照抄白名单。**
9. **基准取值可以直接翻转结论**：本模型表内 59 与 metax 裁定的 NV 原生 53.54 相差 5.5pt，
   而 50 题口径的噪声就有 8pt —— **基准不确定时，任何精度判定都是不牢的**。
   报告里必须把「用了哪个基准、为什么」写清楚（本报告采用 53.54，理由见发布字段注记）。
