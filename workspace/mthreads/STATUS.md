# Mthreads 模型修复状态总览

> 更新：2026-09-20（环境勘察完成，尚未开工）
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
| evalscope 评测镜像 | ⚠️ 25/27 上均无，需拉取 |
| 评测脚本（`fast_gpqa.py` / `accuracy_compare.py` / `nv_baseline.yaml`） | ⚠️ 25/27 上均无，需传到共享盘 |

## 图例

| 标识 | 含义 |
|------|------|
| 📋 待开始 | 尚未动手（本表初始化时的默认态） |
| 🟢 服务运行中 | vLLM 已起，smoke test 通过，待评测 |
| 🟡 评测进行中 | 评测脚本已跑，等待结果 |
| ✅ 已通过 | `accuracy_compare` 退出码 0 |
| ❌ 精度不达标 | `accuracy_compare` 退出码 1 |
| ⏭️ 跳过 | 非模型问题（镜像/流程缺陷），暂时搁置 |

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
| Phi-4-reasoning-plus | gpqa_diamond 46 | 🟢 服务运行中 | **SOP 首跑即通**（TP=1/GPU0/:8000，63s 起服务，短+长 prompt 冒烟均 200）；待评测。⚠ 评测前须补 `context.yaml`（thinking 模型 + 采样参数，见修复日志） |
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
| LFM2.5-1.2B-Thinking | gpqa_diamond 29.0 | 🟢 服务运行中 | **SOP 首跑即通**（TP=1/GPU1/:8001，35s 起服务，短+长 prompt 均 200）；混合 SSM 架构无需特殊 attention-backend。⚠ 评测前须补 `context.yaml`（thinking 标记） |
| Light-R1-14B-DS | mmlu 85.17 / math_500 93.2 | 📋 待开始 | |
| Qwen3-4B-SafeRL | mmlu 81.39 / math_500 94.8 | 📋 待开始 | 另有 `float4_e2m1fn_x2` 崩溃记录 |
| ZR1-1.5B | mmlu 50.54 / math_500 89.4 | 📋 待开始 | |
| reka-flash-3 | gpqa_diamond 59 | 🟢 服务运行中 | **SOP 首跑即通**（TP=1/GPU2/:8002，45s 起服务，短+长 prompt 均 200）。⚠ 评测前须补 `context.yaml`——metax 侧已查明其低分真凶是采样参数被忽略（`do_sample=true,temp=0.6`），摩尔可直接复用该结论验证 |
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
| Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled | gpqa_diamond 75 | 🟢 服务运行中 | **已起**（TP=1/GPU3/:8003，2m40s 起服务，短+长 prompt 均 200）。⚠ **必须显式 `--max-model-len 32768`**——模型默认 256K，KV 需 64GB 装不下（256KB/token）。多模态架构（含视觉塔 + MTP 权重），文本路径已验证，图像未验证 |
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

> 更新：2026-09-20 14:45

- **精度已通过**：0 / 50（3 个模型在流水线侧已达标，待复核确认后计入）
- **精度不达标**：0 / 50
- **服务已起/冒烟通过**：**4 / 50** —— `Phi-4-reasoning-plus` / `LFM2.5-1.2B-Thinking` /
  `reka-flash-3` / `Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled`，**全部一次通过**
- **评测进行中**：0 / 50
- **待开始**：46 / 50

### 当前 GPU 占用（mthreads-25，2026-09-20 15:30）

| 卡 | 服务 | 端口 | max_model_len |
|----|------|:----:|:-------------:|
| GPU0 | Phi-4-reasoning-plus | 8000 | 32768 |
| GPU1 | LFM2.5-1.2B-Thinking | 8001 | 32768 |
| GPU2 | reka-flash-3 | 8002 | **24576** |
| GPU3 | Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled | 8003 | 32768 |
| GPU4–7 | **空闲（4 张）** | — | — |

> 4 个服务均以 `--enforce-eager` 运行（**摩尔 graph 模式不可用**，见下方「评测前必须改的服务侧设置」），
> 首都测试全部通过（均正确答「北京」）。评测参数总表见 [[EVAL_SETTINGS]]。

### 权重下载进度（`/datapool/flagrelease/fixes_models/`）

> 更新：2026-09-20 14:25 —— **四个模型全部下载完成**，均无 `.incomplete` 残留、`config.json` 齐备。

| 模型 | 大小 | 架构 | 状态 |
|------|------|------|------|
| Phi-4-reasoning-plus | 28 GB | `Phi3ForCausalLM`（dense GQA） | ✅ 已下 + 🟢 服务运行中 |
| LFM2.5-1.2B-Thinking | 2.2 GB | `Lfm2ForCausalLM`（混合 SSM） | ✅ 已下 + 🟢 服务运行中 |
| reka-flash-3 | 39 GB | `LlamaForCausalLM`（44 层/hidden 6144） | ✅ 已下 + 🟢 服务运行中 |
| Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled | 52 GB | `Qwen3_5ForConditionalGeneration`（多模态+MTP，11 分片） | ✅ 已下 + 🟢 服务运行中 |

### 评测阻塞项（四个服务都已就绪，卡在评测环境）

| 项 | 状态 |
|----|------|
| evalscope 评测镜像 | ⚠️ 25/27 上均无，需拉取 |
| 评测脚本（`fast_gpqa.py` / `accuracy_compare.py` / `nv_baseline.yaml`） | ⚠️ 25/27 上均无，需传到共享盘 |
| **评测设置定稿** | ✅ **已完成** —— 见 [[EVAL_SETTINGS]]（横比 metax / iluvatar / t-head 案例） |
| 四个模型的 `context.yaml` | ⬜ 待补（`/flagos-workspace/shared/context.yaml` 路径硬编码，容器需建同路径）；<br>4 个全部要标 `thinking_model: true` |

### ⚠ 评测前必须改的服务侧设置（来自厂商案例 + 本机实测）

| # | 改动 | 影响 | 依据 |
|---|------|------|------|
| 1 | ⚠️ **不要改 graph** —— 摩尔必须用 `--enforce-eager` | 全部 | **本机实测：去掉 `--enforce-eager` 后 4 个模型全部启动失败**（`MUSA driver error: operation not permitted when stream is capturing`）。metax 的「graph 快 10 倍」在摩尔不适用 |
| 2 | reka-flash-3 的 `--max-model-len` 32768 → **24576** | 仅该模型 | 使 `max_tokens=16384`，对齐 metax v6 / NV 复现口径 ✅ **已改** |
| 3 | reka-flash-3 判定基准改用 **NV 原生实测 53.54**（非表中 59） | 仅该模型 | metax 基准取值裁定 |
| 4 | 4 个模型评测前补 `context.yaml`（含 `thinking_model: true`） | 全部 | 3 个模型名不含关键词不会被自动识别为 thinking |
