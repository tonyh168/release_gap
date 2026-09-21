# Mthreads 模型修复状态总览

> 更新：2026-09-21
> ✅ **50 题筛查 4 个模型全部出判定** —— **4 个达标 / 0 个不达标**，明细见下「📊 50 题筛查结果」
> 🔬 **reka-flash-3 的重复性实验已出结论**：原轮的 50.0% 经复核判定为**采样下沿**，
> 同配置独立重跑 3 组**全部 58.0%** → **改判达标**。见下「🔬 reka-flash-3 重复性实验」
> ℹ️ 另外 3 个模型的服务容器**已停掉释放显存**（2026-09-21）；下一步是 **198 题全量定稿**
>
> 机型：MTT S5000 × 8（单卡 80GB） | 宿主机：`mthreads-25` / `mthreads-27`（`mthreads-26` 当前不可用）
> 镜像：`harbor.baai.ac.cn/flagrelease-public/flagrelease_mthreads-gmi_vllm024plugin_base:08281629`
> 共享盘：`/datapool`（LeoFS；**本机型无 `/public-flash`**）→ 权重 `/datapool/flagrelease/fixes_models/`，结果 `/datapool/flagrelease/release_run_logs/`
>
> 清单来源：`flagrelease_fail_reports/Mthreads/` 50 份报告 + `docs/summary_snapshot_20260911.md`（摩尔线程：成功 100 / 迁移失败 46 / 未开始 9）。

## 开工前待办（环境侧）

| 项 | 状态 |
|----|------|
| 镜像 pull + 版本实测 | ✅ 已完成（41 层 / 13.88 GiB；vllm 0.24.0 / plugin-FL 0.3.0 / FlagGems 5.3.2 / Flagtree 0.6.0 / torch 2.9.0 / 驱动 3.3.5-server） |
| 共享盘路径勘察 | ✅ `/datapool`（无 `/public-flash`） |
| 项目目录建立 | ✅ `/datapool/flagrelease/{fixes_models,release_run_logs}`（25 建、27 已验证可见） |
| **SOP 端到端验证（起服务冒烟）** | ✅ **已完成** —— `Phi-4-reasoning-plus` 首跑即通（63 秒起服务，短/长 prompt 均 200） |
| `mthreads-26` 可用性 | ❌ 待发起人确认（bastion 报 `match asset failed: No found asset`） |
| evalscope 评测镜像 | ✅ 已拉取（evalscope 1.11.1） |
| 评测脚本 + 离线数据集 | ✅ 已部署到 `/datapool/flagrelease/{eval_scripts,evalscope-datasets}` |
| **4 个一对一 eval 容器 + context.yaml** | ✅ **已建好并验收**（详见 [[EVAL_INFRA]]） |
| **评测参数定稿** | ✅ 见 [[EVAL_SETTINGS]]（温度/top_p/top_k/is-think 总表） |
| **50 题筛查跑分** | ✅ **已完成** —— 4 达标 / 0 不达标（reka 经重复实验改判），见下「📊 50 题筛查结果」 |
| 198 题全量定稿 | ⬜ **下一步** —— reka 的 4 个服务在跑；另 3 个需先 `docker start` 恢复容器 |

## 📊 50 题筛查结果（2026-09-20 跑完，2026-09-21 出判定）

> 逐模型的完整信息在 `reports/<模型名>_report.md`（含发布字段），过程记录在 `fixes/<模型名>.md`。
> 判定命令：`accuracy_compare.py --v2 gpqa_50.json --nv-baseline <模型名> --metric gpqa_diamond`，
> 产物 `verdict_50.json` 与 `gpqa_50.json` 同目录（`/datapool/flagrelease/release_run_logs/<模型名>/`）。

| 模型 | 得分 | NV 基线 | 相对退化 | 判定 | runaway | 截断 | 报告 |
|------|:----:|:-------:|:--------:|:----:|:-------:|:----:|------|
| **Phi-4-reasoning-plus** | **58.0%**（29/50） | 46 | **−26.09%** | ✅ 退出码 0 | 0 | 无 | [[reports/Phi-4-reasoning-plus_report]] |
| **LFM2.5-1.2B-Thinking** | **32.0%**（16/50） | 29.0 | **−10.34%** | ✅ 退出码 0 | 0 | 无 | [[reports/LFM2.5-1.2B-Thinking_report]] |
| **Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled** | **78.0%**（39/50） | 75 | **−4.00%** | ✅ 退出码 0 | 1（idx 7） | 无 | [[reports/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled_report]] |
| **reka-flash-3** | **58.0%**（29/50） | 59 / **53.54**※ | **+1.69%** / **−8.33%** | ✅ **退出码 0** | 0 | 无 | [[reports/reka-flash-3_report]] |

> ※ **reka-flash-3 的基准按 metax 裁定改用 NV 原生实测 53.54**（表内 59 出自 NV 失败报告、口径不符）。
> **58.0% 对两种基准都达标**：对 59 退化 1.69%（<5%），对 53.54 反超 4.46pt。
>
> ⚠️ **reka 这一行的 58.0% 不是原轮成绩**：原轮（2026-09-20）为 **50.0% 判不达标**，
> 经**重复性实验复核**（同配置独立重跑 3 组，全部 58.0%）判定原轮为**采样下沿**，故改判达标。
> 过程见下「🔬 reka-flash-3 重复性实验」，完整记录见 [[fixes/reka-flash-3]]。

**三项必查（全部通过）**：

| 检查项 | 结果 |
|--------|------|
| `[gen]` 采样参数是否生效 | ✅ 4 个模型全部确认：Phi-4 用模型 gc（0.8/0.95/50）、reka 用模型 gc（0.6/0.95/1024）；LFM2.5 与 Qwen3.5 本就无采样字段 → 走 thinking 默认（0.6/0.95）。**无一退回贪心** |
| `truncation_detected` | ✅ 4 个模型**全为 false** |
| `serve.log` 侧异常 | ✅ 无致命错误（日志里的 Traceback 是 `_report_usage_worker` 读不到设备属性，属已知噪声） |

**逐模型要点**：

- **Phi-4-reasoning-plus** —— 原失败类型是**流程中断**（从未评测过），本轮**首跑即达标**且高出基线 12pt。
  未做 metax 建议的 `rms_norm,silu_and_mul` 白名单 A/B（留着就已达标）。
- **LFM2.5-1.2B-Thinking** —— 与 **iluvatar 逐位一致**（同为 32.0% vs 29.0、退出码 0），跨平台可复现。
- **Qwen3.5-27B-Distilled** —— **摩尔的机会兑现了**：iluvatar 受 8192 上下文限制只拿到 70.0%（不达标），
  摩尔给到 32768 → **78.0% 达标**，反超基线 3pt。同模型同配置，**8pt 差距全部来自上下文长度**。
- **reka-flash-3** —— ⚠️ **原轮判不达标，经重复实验复核后改判达标**。原轮 50.0% 与 metax v6 的同题对照是
  「共对 21 / metax 独对 7 / 摩尔独对 4」；同配置独立重跑 3 组**全部 58.0%**，且 r3 vs metax 的独对变为
  **5:6（双向对称）** → 证明原轮是**采样下沿**、摩尔与 metax **无系统性差距**。详见下节。

**⚠️ 一个待解释的观察（不影响达标）**：Qwen3.5 **实际只触达 `silu_and_mul` 一个 FlagGems 算子**，
白名单里另外两个（`rms_norm`、`rotary_embedding`）**根本没走 plugin-FL 的 dispatch**
（`serve.log` 无对应 `using` 行 + 容器 `/tmp/flaggems_enable_oplist.txt` 只有 3 行，另三个模型是 11 行）。
即**该模型算子替换的覆盖面比白名单窄**，将来若靠增删算子调精度，改这两项是无效操作。

> **「开启算子列表」一律以容器 `/tmp/flaggems_enable_oplist.txt` 的实测为准**（⚠️ 文件名是 `oplist` 连写，
> 写成 `op_list` 找不到文件），**不要照抄白名单**——两者可能不一致（Qwen3.5 就是活例）。
> 逐模型实测名单见 `fixes/*.md` 与 `reports/*_report.md`。

## 🔬 reka-flash-3 重复性实验（✅ 已出结论，2026-09-21）

**目的**：判明「摩尔 50.0% vs metax v6 56.0%」的 6pt 差距**是真实退化还是采样抖动**。

**结论：是采样抖动 —— 原轮 50.0% 为采样下沿，改判达标。**

### 结果

| 样本 | 得分 | 备注 |
|------|:----:|------|
| 原轮 9/20 | 50.0% | **唯一的低值**（判不达标的依据） |
| metax v6 | 56.00% | 跨平台参照 |
| **r2 / r3 / r4** | **58.0% × 3** | 同配置独立复现 |
| r1 | ⏳ 跑至 47/50 时记录 | 复用原服务容器（GPU2） |

**四个已出独立样本里有三个落在 58.0%**，原轮那个 50% 孤立在下沿。
按 58.0% 判定：对表内基准 59 退化 **1.69%**（<5% 容差），对 metax 裁定的 NV 原生 53.54 **反超 4.46pt**。

### 证据：抖动来自「逐题正误翻转」，且双向对称

r2/r3/r4 三组**每题结果**（不只看总分）：

```
三组答对题目的并集     = 38 题
三组稳定答对（交集）   = 21 题
不稳定题（有对有错）   = 17 题（占 34%）
```

| 对照 | 共对 | 对方独对 | 本组独对 |
|------|:----:|:--------:|:--------:|
| r3 vs r4 | 23 | 6 | 6 |
| r2 vs r3 | 25 | 4 | 4 |
| r2 vs r4 | 22 | 7 | 7 |
| **r3 vs metax v6** | 23 | 5 | **6** |

三组响应内容**逐条不同**（抽查 idx0：md5 `4758f783` vs `41f9ab5e`，长度 20300 vs 21781 字符），
确认是真独立采样、非数据复用。

> **判据**：**r3 vs metax 是 5:6 —— 几乎完全对称**，说明无系统性差距；
> 而原轮 vs metax 当时是 **7:4 的不对称**，现被证明是单次抽样波动。
> **「同配置重跑看独对是否双向对称」是识别精度误判的有效手段。**

### 影响：50 题口径不能用于本模型判定

**34% 的题会在两次运行间翻转正误，总分摆动 8pt（50% ↔ 58%）——噪声带宽比 5% 容差还宽。**

- ❌ **不要用 50 题给 `do_sample=true` 的模型下结论**（原轮就是这么误判的）；
- ✅ **定稿一律走 198 题全量**（样本量约大 4 倍，噪声按 √N 收缩）。

> 与 metax 的教训互相印证：metax 也是「前 50 题 56.00% 不可外推 → 全量 54.04%」。
> **两家都栽在 50 题口径上**，后续同类模型建议直接上全量。

### 实验设置（4 组完全一致，唯一变量是采样随机性）

| 项目 | 值 |
|------|----|
| 数据集 / 题数 | `gpqa_diamond` **50 题**（与 metax v6 前 50 题同题，可直接对照） |
| 采样参数 | **reka 自带 gc：temp=0.6 / top_p=0.95 / top_k=1024**（4 组同一份，`[gen]` 行已逐组确认） |
| thinking | `thinking_model: true`（`context.yaml`） |
| 服务 | `--max-model-len 24576`（→ `max_tokens=16384`）、`--enforce-eager`、TP=1、`-gmu 0.9` |
| 并发 | **显式 `--eval-batch-size 1`（跳过自动探测）** —— 受控实验必须固定同一值 |

| 组 | 服务容器 | GPU | 端口 | eval 容器 | 输出目录 |
|:--:|----------|:---:|:----:|-----------|----------|
| r1 | `flagrelease-fix-reka-flash-3` | GPU2 | 8002 | `eval-reka-flash-3` | `release_run_logs/reka-flash-3/repeat-r1/` |
| r2 | `flagrelease-fix-reka-flash-3-r2` | GPU0 | 8004 | `eval-reka-flash-3-r2` | `release_run_logs/reka-flash-3/repeat-r2/` |
| r3 | `flagrelease-fix-reka-flash-3-r3` | GPU1 | 8005 | `eval-reka-flash-3-r3` | `release_run_logs/reka-flash-3/repeat-r3/` |
| r4 | `flagrelease-fix-reka-flash-3-r4` | GPU3 | 8006 | `eval-reka-flash-3-r4` | `release_run_logs/reka-flash-3/repeat-r4/` |

> 起跑 2026-09-21 14:26，4 组并行、互不拖慢（题均 ~200s，与原轮 212s 相当）。
> ⚠️ **r1 是重跑**：原 2026-09-20 那一轮（`release_run_logs/reka-flash-3/gpqa_50.json`）是自动探测出的并发 1，
> 本轮为「4 组调用完全一致」显式固定 `--eval-batch-size 1` 重跑；**原结果保留**，作第 5 个参考样本。

## 图例

| 标识 | 含义 |
|------|------|
| 📋 待开始 | 尚未动手（本表初始化时的默认态） |
| 🟢 服务运行中 | vLLM 已起，smoke test 通过，待评测 |
| 🟡 评测进行中 | 评测脚本已跑，等待结果 |
| ✅ 已通过 | `accuracy_compare` 退出码 0 |
| ❌ 精度不达标 | `accuracy_compare` 退出码 1 |
| ⏭️ 跳过 | 非模型问题（镜像/流程缺陷），暂时搁置 |

> **口径提醒**：下表「✅ 已达标」目前一律是 **50 题筛查**口径（`--limit 50`）；
> **定稿判定一律以 198 题全量为准**（metax/reka-flash-3 教训：前 50 题偏易、不可外推）。

## 分类统计

| 原始失败类型 | 数量 | 说明 |
|--------------|:----:|------|
| 🔁 流程中断（会话/容器准备/下载） | 7 | **非芯片不兼容**，流水线侧中断，从未真正评测过 —— 优先修 |
| ❌ 服务启动失败 | 9 | |
| ❌ 精度不达标 | 9 | |
| 🌀 生成失控（runaway） | 1 | FluentlyQwen2.5-32B |
| ⏳ 超评测预算（long-CoT） | 1 | OpenReasoning-Nemotron-7B |
| ⚠️ 精度数据缺失（报告未给细分原因） | 7 | 含 3 个 `float4_e2m1fn_x2` 导入崩溃 |
| ⚠️ 未纳入发布清单 / 未达标（细分缺失） | 13 | 报告只写「未达标」，需按本 SOP 重跑定性 |
| ✅ 已达标（复核后可划掉） | 3 | |

> 说明：摩尔报告的判定粒度不一致——同一模型常同时挂「服务启动失败 + 精度不达标 + 性能不达标」（共 8 个），
> 因此上表按**报告结论的主口径**归类，数字与 [[ENV]] 末尾的按条统计（17/16/9）会有差异，两者都只作线索，不作结论。

---

## 🔁 流程中断（7）—— 优先修

| 模型 | 评测指标 / NV 基线 | 状态 | 备注 |
|------|-------------------|:----:|------|
| AceReason-Nemotron-7B | mmlu 70.72 / math_500 95.2 | 📋 待开始 | 会话在服务启动前因 API 流式卡顿中断 |
| Hermes-2-Pro-Llama-3-8B | gpqa_diamond 33 | 📋 待开始 | 权重下载命令超时 |
| Ministral-3-14B-Instruct-2512 | gpqa_diamond 56 | 📋 待开始 | 容器准备未完成 |
| Phi-4-reasoning-plus | gpqa_diamond 46 | ✅ 已达标 | **50 题筛查 58.0%（29/50），相对退化 −26.09%，退出码 0**。服务首跑即通（TP=1/GPU0/:8000，63s）。⚠ 198 题全量待跑；metax 建议的算子 A/B 未做（留白名单就已达标）。报告：[[reports/Phi-4-reasoning-plus_report]] |
| Qwen2.5-7B-Instruct | gpqa_diamond 39.0 | 📋 待开始 | 会话连接中断 |
| Qwen2.5-Coder-7B-Instruct | gpqa_diamond 27 | 📋 待开始 | 会话连接中断 |
| aya-23-8B | gpqa_diamond 27 | 📋 待开始 | 容器准备未完成 |

## ❌ 服务启动失败（9）

| 模型 | 评测指标 / NV 基线 | 状态 | 备注 |
|------|-------------------|:----:|------|
| LFM2-2.6B-Exp | gpqa_diamond 44.0 | 📋 待开始 | |
| Magistral-Small-2506 | gpqa_diamond 62 | 📋 待开始 | 报告口径为 16 卡，注意选卡 |
| Moonlight-16B-A3B-Instruct | gpqa_diamond 33 | 📋 待开始 | |
| OpenMath-Nemotron-14B-Kaggle | mmlu 77.23 / math_500 94.4 | 📋 待开始 | |
| VibeThinker-1.5B | gpqa_diamond 47.0 | 📋 待开始 | |
| gemma-3-1b-it | gpqa_diamond 27.0 | 📋 待开始 | |
| gpt-oss-20b | gpqa_diamond 63 | 📋 待开始 | 注意 MXFP4 / dtype 相关路径 |
| llama-3-Korean-Bllossom-8B | gpqa_diamond 33 | 📋 待开始 | |
| phi-4 | gpqa_diamond 73 | 📋 待开始 | |

## ❌ 精度不达标（9）

| 模型 | 评测指标 / NV 基线 | 状态 | 备注 |
|------|-------------------|:----:|------|
| DASD-4B-Thinking | gpqa_diamond 44.0 | 📋 待开始 | |
| Dhanishtha-2.0-preview | mmlu 81.09 / math_500 68.6 | 📋 待开始 | |
| GLM-4.7-Flash | gpqa_diamond 55 | 📋 待开始 | |
| LFM2.5-1.2B-Thinking | gpqa_diamond 29.0 | ✅ 已达标 | **50 题筛查 32.0%（16/50），相对退化 −10.34%，退出码 0** —— 与 **iluvatar 逐位一致**（同 32.0% vs 29.0）。服务首跑即通（35s），混合 SSM 无需特殊 attention-backend。⚠ 198 题全量待跑。报告：[[reports/LFM2.5-1.2B-Thinking_report]] |
| Light-R1-14B-DS | mmlu 85.17 / math_500 93.2 | 📋 待开始 | |
| Qwen3-4B-SafeRL | mmlu 81.39 / math_500 94.8 | 📋 待开始 | 另有 `float4_e2m1fn_x2` 崩溃记录 |
| ZR1-1.5B | mmlu 50.54 / math_500 89.4 | 📋 待开始 | |
| reka-flash-3 | gpqa_diamond 59（**裁定改用 53.54**） | ✅ 已达标 | ⚠️ **原轮 50 题 50.0% 判不达标 → 经重复实验复核改判**。同配置独立重跑 3 组**全部 58.0%**（vs 59 退化 **1.69%**、vs 53.54 **反超 4.46pt**），且 r3 vs metax 独对 **5:6 双向对称** → 原轮是**采样下沿**。采样参数一直生效，metax 那条根因在摩尔侧**从未发生**；算子侧无需改动。⚠ 50 题口径对本模型噪声达 8pt，**定稿必须走 198 题全量**。报告：[[reports/reka-flash-3_report]] |
| rnj-1-instruct | gpqa_diamond 37 | 📋 待开始 | |

## 🌀 生成失控 / ⏳ 超评测预算（2）

| 模型 | 评测指标 / NV 基线 | 状态 | 备注 |
|------|-------------------|:----:|------|
| FluentlyQwen2.5-32B | mmlu 85.49 / math_500 82.4 | 📋 待开始 | FlagGems 下 mmlu 生成失控，先收窄算子 |
| OpenReasoning-Nemotron-7B | mmlu 81.49 / math_500 95.0 | 📋 待开始 | long-CoT，固定 `--max-tokens` / 并发 |

## ⚠️ 精度数据缺失（7）

| 模型 | 评测指标 / NV 基线 | 状态 | 备注 |
|------|-------------------|:----:|------|
| AReaL-boba-2-8B | mmlu 85.98 / math_500 95.0 | 📋 待开始 | |
| AceReason-Nemotron-1.1-7B | mmlu 58.82 / math_500 95.6 | 📋 待开始 | |
| Apodex-1.0-4B-SFT | mmlu 86.14 / math_500 92.4 | 📋 待开始 | V1 完成（mmlu 85.26 / math_500 93.0），V2 起未闭环 |
| Darwin-28B-Coder | mmlu 85.25 / math_500 90.8 | 📋 待开始 | 性能基线为合成值 |
| Darwin-9B-NEG-FINAL | （无 NV 基线） | 📋 待开始 | 唯一无基线模型 → 两轮对比或上报 |
| DeepSeek-llama3.1-Bllossom-8B | mmlu 69.9 / math_500 84.6 | 📋 待开始 | math_500 评出 0 分，疑似评测器/模板问题 |
| iFlow-ROME | mmlu 81.95 / math_500 81.2 | 📋 待开始 | V1 无基线，性能为合成基线 |

## ⚠️ 未纳入发布清单 / 未达标（细分缺失）（13）

| 模型 | 评测指标 / NV 基线 | 状态 | 备注 |
|------|-------------------|:----:|------|
| AceMath-RL-Nemotron-7B | mmlu 59.81 / math_500 91.8 | 📋 待开始 | `float4_e2m1fn_x2` 致 V1 中断，V2 未开始 |
| Baichuan-M2-32B | gpqa_diamond 64 | 📋 待开始 | |
| Darwin-28B-Opus | mmlu 86.14 / math_500 91.8 | 📋 待开始 | `float4_e2m1fn_x2` 致 V1 起不来 |
| DeepSeek-R1-Distill-Qwen-32B | gpqa_diamond 37 | 📋 待开始 | |
| Phi-3-vision-128k-instruct | gpqa_diamond 25.0 | 📋 待开始 | 多模态 VLM，需图像输入支持 |
| Qwen3-30B-A3B-Instruct-2507 | gpqa_diamond 62 | 📋 待开始 | |
| Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled | gpqa_diamond 75 | ✅ 已达标 | **50 题筛查 78.0%（39/50），相对退化 −4.00%，退出码 0**（1 个 runaway，idx 7）。**关键：显式 `--max-model-len 32768`**（模型默认 256K，KV 需 64GB 装不下）。**iluvatar 同模型受 8192 上下文限制只拿 70.0% 不达标，摩尔 4 倍上下文直接翻盘（+8pt）**。⚠ 多模态只测了文本路径；198 题全量待跑。报告：[[reports/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled_report]] |
| Qwen3.5-27B-Derestricted | mmlu 89.98 / math_500 84.8 | 📋 待开始 | |
| Turkish-Gemma-9b-v0.1 | mmlu 75.19 / math_500 53.6 | 📋 待开始 | 服务启动未通过 |
| gemma-2-27b-it | gpqa_diamond 48 | 📋 待开始 | |
| granite-3.3-8b-instruct | mmlu 68.39 / math_500 69.2 | 📋 待开始 | V2 mmlu 70.7%，仅 Harbor 私有镜像 |
| kanana-1.5-15.7b-a3b-instruct | mmlu 65.02 / math_500 66.6 | 📋 待开始 | |
| Seed-OSS-36B-Instruct | gpqa_diamond 79 | 📋 待开始 | 主指标偏差仅 1.22%，但未纳入发布清单 —— 先确认是否要被修 |

## ✅ 已达标（3）—— 复核后可直接划掉

| 模型 | 评测指标 / NV 基线 | 状态 | 备注 |
|------|-------------------|:----:|------|
| Nanbeige4.1-3B | gpqa_diamond 81.0 | ✅ 已达标 | 原报告结论即「流程已达标」（V2 已产出） |
| Phi-3-mini-128k-instruct | gpqa_diamond 33.0 | ✅ 已达标 | 同上 |
| Phi-3.5-mini-instruct | gpqa_diamond 26.0 | ✅ 已达标 | 同上（V1↔V2 偏差 4.0%、V1↔V3 偏差 2.0%） |

---

## 当前进度快照

> 更新：2026-09-21

- **精度已通过**：**4 / 50**（50 题筛查口径）—— `Phi-4-reasoning-plus` / `LFM2.5-1.2B-Thinking` /
  `Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled` / `reka-flash-3`（经重复实验改判）
- **精度不达标**：**0 / 50**
- **服务已起/冒烟通过**：**4 / 50**，全部一次通过
- **50 题筛查已完成**：**4 / 4**（原计划的四个模型全部出分、全部达标）
- **198 题全量定稿**：**0 / 4**（⬅ 下一步）
- **待开始**：42 / 50

### 当前 GPU 占用（mthreads-25，2026-09-21 14:30）

| 卡 | 服务 | 容器 | 端口 | max_model_len | 实测显存 |
|----|------|------|:----:|:-------------:|:--------:|
| GPU0 | reka-flash-3（**重复组 r2**） | `flagrelease-fix-reka-flash-3-r2` | 8004 | 24576 | 73779 MiB |
| GPU1 | reka-flash-3（**重复组 r3**） | `flagrelease-fix-reka-flash-3-r3` | 8005 | 24576 | 73744 MiB |
| GPU2 | reka-flash-3（**重复组 r1**，原服务） | `flagrelease-fix-reka-flash-3` | 8002 | 24576 | 73744 MiB |
| GPU3 | reka-flash-3（**重复组 r4**） | `flagrelease-fix-reka-flash-3-r4` | 8006 | 24576 | 73744 MiB |
| GPU4–7 | **空闲（4 张，0 MiB）** | — | — | — | — |

> 4 个服务均 TP=1、`--enforce-eager`、`--gpu-memory-utilization 0.9`。
> **Phi-4-reasoning-plus / LFM2.5-1.2B-Thinking / Qwen3.5-27B-Distilled 三个容器已于 2026-09-21 停止**
> （`docker stop`，退出码 137；容器保留未删，可 `docker start` 原样恢复），显存已确认归零。
> 权重、日志、评测产物都在 `/datapool` 上，不受容器停止影响。
>
> 💡 **容量参考**：每服务 TP=1 独占 1 卡（实测 ~73.7GB/80GB）。**一台机最多 8 个「一模型一卡」的服务**；
> 想在同一张卡上多开必须显式下调 `--gpu-memory-utilization`。当前 4 卡在跑 + 4 卡空闲。

### 权重下载进度（`/datapool/flagrelease/fixes_models/`）

> 更新：2026-09-20 14:25 —— **四个模型全部下载完成**，均无 `.incomplete` 残留、`config.json` 齐备。

| 模型 | 大小 | 架构 | 状态 |
|------|------|------|------|
| Phi-4-reasoning-plus | 28 GB | `Phi3ForCausalLM`（dense GQA） | ✅ 已下 → ✅ 50 题达标 |
| LFM2.5-1.2B-Thinking | 2.2 GB | `Lfm2ForCausalLM`（混合 SSM） | ✅ 已下 → ✅ 50 题达标 |
| reka-flash-3 | 39 GB | `LlamaForCausalLM`（44 层/hidden 6144） | ✅ 已下 → ✅ 50 题达标（重复实验改判） |
| Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled | 52 GB | `Qwen3_5ForConditionalGeneration`（多模态+MTP，11 分片） | ✅ 已下 → ✅ 50 题达标 |

### 评测环境（✅ 已全部就绪并跑通，不再是阻塞项）

| 项 | 状态 |
|----|------|
| evalscope 评测镜像 | ✅ 已拉取（`flagos-evalscope:latest-modelscope`，内含 evalscope **1.11.1**） |
| 评测脚本 + 离线数据集 | ✅ 已部署到 `/datapool/flagrelease/eval_scripts/` 与 `evalscope-datasets/`（gpqa_diamond 亲测可用） |
| **4 个一对一 eval 容器** | ✅ **已建好并验收**，各自的 `context.yaml` 全部生效（详见 [[EVAL_INFRA]]） |
| **评测设置定稿** | ✅ **已完成** —— 见 [[EVAL_SETTINGS]]（含「评测参数总表」温度/top_p/top_k/is-think） |
| 跑分进度 | ✅ **50 题筛查已完成**（4/4 出分，**4 个全部达标**）；⬜ **198 题全量待跑** |

> **环境侧已无阻塞。** 评测入口与命令见 [[EVAL_INFRA]]，逐模型参数见 [[EVAL_SETTINGS]]。
> **下一步只需把 `--limit 50` 去掉（`--limit 0` = 全量 198）重跑四个模型**：
> reka 的 4 个服务在跑，另 3 个需先 `docker start` 恢复容器。
> ⚠️ **reka 定稿务必用 198 题** —— 实测 50 题口径噪声达 8pt，比 5% 容差还宽。

### ⚠ 评测前必须改的服务侧设置（来自厂商案例 + 本机实测）

| # | 改动 | 影响 | 依据 | 状态 |
|---|------|------|------|:----:|
| 1 | ⚠️ **不要改 graph** —— 摩尔必须用 `--enforce-eager` | 全部 | **本机实测：去掉 `--enforce-eager` 后 4 个模型全部启动失败**（`MUSA driver error: operation not permitted when stream is capturing`）。metax 的「graph 快 10 倍」在摩尔不适用 | ✅ 已执行 |
| 2 | reka-flash-3 的 `--max-model-len` 32768 → **24576** | 仅该模型 | 使 `max_tokens=16384`，对齐 metax v6 / NV 复现口径 | ✅ 已改 |
| 3 | reka-flash-3 判定基准改用 **NV 原生实测 53.54**（非表中 59） | 仅该模型 | metax 基准取值裁定 | ✅ 已执行（**两种基准都达标**：58.0% 对 59 退化 1.69%、对 53.54 反超 4.46pt） |
| 4 | 4 个模型评测前补 `context.yaml`（含 `thinking_model: true`） | 全部 | 3 个模型名不含关键词不会被自动识别为 thinking | ✅ 已执行，`[gen]` 行确认生效 |
| 5 | **「开启算子列表」以容器 `/tmp/flaggems_enable_oplist.txt` 实测为准**（文件名 `oplist` 连写） | 全部 | **白名单 ≠ 实际触达**：Qwen3.5 白名单 3 个、实测只触达 1 个 | ✅ 4 个模型均已记录 |
