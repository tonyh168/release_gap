# mthreads/reka-flash-3 修复日志

- **失败报告**：flagrelease_fail_reports/Mthreads/FAILED_Mthreads_reka-flash-3_202608020152.md
- **原始失败类型**：精度不达标（rel_drop 超阈值）+ 性能不达标
- **日期**：2026-09-20（2026-09-21 补记 50 题判定 + 启动重复性实验）
- **本次阶段**：❌ **50 题筛查不达标**（50.0%）→ 🔬 **重复性实验进行中**（4 组独立 50 题并行）

---

## 50 题筛查结果（2026-09-20）

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
| mthreads | 25/50 = 50.00% | 21 | **4**（idx 17,36,45,46） |

净差 3 题（6pt）。**但 temp=0.6 采样下 50 题本身有 ±2~3 题的抖动**，7:4 的不对称**不足以定论**。

## 🔬 重复性实验（2026-09-21 起，进行中）

为把「6pt 差距是真实退化还是噪声」问清楚，**用完全相同的配置独立跑 4 组 50 题**（temp 统一取
reka 自带的 `generation_config.json`），量出抖动带再看差距是否落在带外。

- 4 组唯一变量是采样随机性：同数据集（前 50 题）、同采样（0.6/0.95/1024）、同 `max_tokens=16384`、
  同 `--enforce-eager`、**显式固定 `--eval-batch-size 1`**（跳过自动探测，保证可比）。
- 4 个服务分在 GPU0/1/2/3（端口 8004/8005/8002/8006），4 个 eval 容器 1:1 绑定。
- 输出：`release_run_logs/reka-flash-3/repeat-r1..r4/`。
- **实验设计与判定方法见 [[STATUS]] 的「🔬 reka-flash-3 重复性实验」节**，起跑细节见 [[PROGRESS]]。

> 判定规则：4 组若**全部落在 50% 附近** → 差距是真的，继续定位真凶（**先查采样口径与 `max_tokens`，
> 别折腾算子黑名单**——metax 在 v1~v5 耗过五轮）；若**出现 ≥56% 的组** → 需按全量 198 题重新判定。

## 开启算子列表（实测，2026-09-21 取自容器 `/tmp/flaggems_enable_oplist.txt`）

> **文件名注意**：`flaggems_enable_oplist.txt`（`oplist` 连写，**不是** `op_list`），在**服务容器** `/tmp/` 下。
> 它是 plugin-FL 在算子首次被 dispatch 时打出的 DEBUG 记录，反映**实际触达**的算子。

白名单：`VLLM_FL_FLAGOS_WHITELIST=silu_and_mul,rms_norm,rotary_embedding`

**→ 开启算子列表：`["rms_norm", "rotary_embedding", "silu_and_mul"]`**（3 个全部真实触达）

| dispatch op | 落到哪个后端 | 下层实现（`flag_gems`） | 实测是否触达 |
|-------------|--------------|------------------------|:------------:|
| `rms_norm` | `default.flagos` | `gems_rms_forward` → `rms_norm_forward`（含 `fused_add_rms_norm`） | ✅ |
| `rotary_embedding` | `default.flagos` | `gems_rope_forward` → `apply_rotary_pos_emb` | ✅ |
| `silu_and_mul` | `default.flagos` | `gems_silu_and_mul` → `silu_and_mul.forward` | ✅ |
| `attention_backend` | `vendor.musa` | ——（厂商后端，**不是** FlagGems） | ✅ |

> 与另两个模型（Phi-4 / LFM2.5）**一致**：白名单 3 个全部触达、文件 11 行。
> 2026-09-21 新起的 3 个重复组容器实测同样为这 3 个算子（未因新容器而变化）。
> 对照：Qwen3.5 白名单 3 个**只触达 1 个** —— **白名单 ≠ 实际触达**，报告一律以本文件实测为准。

## ⚠ 评测阶段预警（尚未处理，跑评测前必看）

---

## 最终结论（阶段一：服务可用性）

| 项目 | 值 |
|------|---|
| SOP 是否跑通 | ✅ **一次通过**，未做 SOP 之外的调整 |
| 起服务耗时 | 14:31:30 → ~14:32:14，**约 45 秒**（39GB 权重） |
| 冒烟（短 prompt） | ✅ HTTP 200，4.76s |
| 冒烟（长 prompt，2257 token） | ✅ HTTP 200，**11.48s** |
| 服务地址 | `http://mthreads-25:8002/v1`，模型名 `reka-flash-3` |
| 精度评测 | ⬜ 未做（评测镜像/脚本尚未就位） |

**核心结论**：标准 `LlamaForCausalLM`，摩尔上起服务无障碍。

> 📌 **跨厂商对照价值**：metax 侧已查明该模型「精度不达标」的**真凶是采样参数被评测脚本静默忽略**
> （模型声明 `do_sample=true, temperature=0.6`，但 `fast_gpqa.py` 退回贪心 → 复读 → 分数暴跌；
> 补 `context.yaml` 后同题提升 6–12pt，198 题 54.04% 达标）。摩尔侧本轮**服务已就绪，
> 可直接复用该结论做验证**——如果摩尔也出现同样的低分，优先查采样参数而不是算子。

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
| `max_model_len` | ⚠️ **改为 24576**（当前是 32768）← 间接得 `max_tokens=16384`，对齐 NV 复现口径 | metax v6 |
| 执行模式 | **graph（评测前去掉 `--enforce-eager` 重启）** | metax v5 用 eager 直接作废 |
| 算子策略 | **默认黑名单**（`mm,mm_out,bmm,...`）+ 采样生效 | metax：v1→v6 黑名单未变，唯一变量是采样 |
| **判定基准** | ⚠️ **用 NV 原生 198 题实测 53.54%，不要用表里的 59** | metax 已裁定（表值口径不符） |
| ⚠️ 禁令 | **不要加 `--generation-config vllm`** | 会主动丢弃模型采样参数 |

> **最该照抄的一个**——metax 已用这套配置 198 题达标（54.04% vs 53.54%）。
> 摩尔若出现 44~46% 量级的低分，**先查采样参数，别折腾算子黑名单**（metax 在这条路上耗了 v1~v5 五轮）。

## ⚠ 评测阶段预警（尚未处理，跑评测前必看）

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
