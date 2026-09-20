# mthreads/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled 修复日志

- **失败报告**：flagrelease_fail_reports/Mthreads/FAILED_Mthreads_Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled_202608020835.md
- **原始失败类型**：未达标（报告只写「未达标」，无细分原因）
- **日期**：2026-09-20
- **本次阶段**：✅ **服务已起、冒烟通过**（尚未跑精度评测）

---

## 最终结论（阶段一：服务可用性）

| 项目 | 值 |
|------|---|
| SOP 是否跑通 | ✅ 通过，**但需额外一个参数**（见下） |
| 起服务耗时 | 14:37:24 → 14:40:04，**2 分 40 秒**（52GB 权重从 LeoFS 加载） |
| 冒烟（短 prompt） | ✅ HTTP 200，10.63s |
| 冒烟（长 prompt，2261 token） | ✅ HTTP 200，**23.28s** |
| 服务地址 | `http://mthreads-25:8003/v1`，模型名 `Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled` |
| 精度评测 | ⬜ 未做（评测镜像/脚本尚未就位） |

**核心结论**：这是本轮唯一**需要偏离 SOP 默认值**的模型 —— 必须显式加 `--max-model-len 32768`，
否则按模型自带 `max_position_embeddings=262144`（256K）起会**KV cache 装不下**。

---

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `mthreads-25` |
| 容器名 | `flagrelease-fix-qwen3.5-27b` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/flagrelease_mthreads-gmi_vllm024plugin_base:08281629` |
| 模型路径 | `/datapool/flagrelease/fixes_models/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled`（51.75 GB，11 分片） |
| TP / GPU / 端口 | TP=1，`MUSA_VISIBLE_DEVICES=3`，port=8003 |
| 实测显存占用 | 73393 MiB / 81920 MiB |
| `max_model_len` | **32768（需显式指定）** |

## 模型特征（决定了它和另外三个模型的不同处置）

| 特征 | 值 | 影响 |
|------|----|------|
| 架构 | `Qwen3_5ForConditionalGeneration`（`model_type=qwen3_5`） | ✅ vLLM 0.24.0 **已支持**：`registry.py:566` 映射到 `qwen3_5`，且同目录有 `qwen3_5_mtp.py` |
| 稠密度 | **稠密**（config 无任何 `expert`/`moe` 字段） | ✅ 避开了摩尔 MoE 补丁告警那条线 |
| **多模态** | 有 `vision_config`（depth 27 / hidden 1152 / patch 16）、`image_token_id`、`video_token_id`；索引里 **333 个 vision 张量**；带 `processor_config.json`（Qwen3VL 图像/视频处理器） | ⚠️ 是 VLM。本次只测文本路径，**图像输入未验证** |
| **MTP** | 索引前缀含 `mtp`（Multi-Token Prediction 权重） | vLLM 有 `qwen3_5_mtp.py`，本次按常规单 token 解码起，未启用 MTP |
| 层/维度 | 64 层 / hidden 5120 / 24 heads / **4 kv heads** / **head_dim 256** | KV cache 极大，见下 |
| `max_position_embeddings` | **262144（256K）** | ⚠️ **必须下调** |
| `generation_config.json` | **不存在** | ✅ 无采样参数坑（对比 Phi-4-reasoning-plus / reka-flash-3） |

### 为什么要显式限长（本模型的关键点）

KV cache 每 token 大小 = `64 层 × 2(K,V) × 4 kv_heads × 256 head_dim × 2 字节` = **256 KB/token**。

权重 51.75 GB，`--gpu-memory-utilization 0.9` 在 80GB 卡上给 73.7 GB → **留给 KV 约 20 GB**：

| `max_model_len` | KV 需求 | 结论 |
|-----------------|---------|------|
| 32768 | 8.0 GB | ✅ 采用（留足激活/视觉塔余量） |
| 65536 | 16.0 GB | ⚠️ 理论可行但余量仅 4GB，偏紧 |
| 131072 | 32.0 GB | ❌ 超 |
| 262144（模型默认） | 64.0 GB | ❌ 远超 |

→ 命令里加 `--max-model-len 32768`。GPQA 场景 prompt 短、输出几千 token，够用。
**若评测报 `truncation_detected:true`，优先提这个值到 65536 而不是直接上 256K。**

## 现象（启动日志要点）

- ✅ 无新增致命告警；4 条已知非致命告警照常出现（`Unknown vLLM env var`、MUSA fork 上报、
  两条 MoE 补丁告警）——均不影响启动，见 [[KNOWLEDGE]] 一。

- 🔍 **算子注册比另三个模型少一个**：

```
[INFO] [vllm_fl.dispatch.manager] OpManager initialized: 5 ops with 8 implementations
[INFO] [vllm_fl.dispatch.manager] Op 'attention_backend' using 'vendor.musa'
[INFO] [vllm_fl.dispatch.manager] Op 'silu_and_mul'      using 'default.flagos'
```

  Phi-4 / LFM2 / reka 都看到 **3 个**算子（`rms_norm`、`rotary_embedding`、`silu_and_mul`）落到
  `default.flagos`，**本模型只有 `silu_and_mul` 一个**。这两行是在算子**首次被 dispatch 时**才打印的，
  所以更可能是「Qwen3.5 的 rms_norm / rotary 走了别的代码路径」而非「白名单没生效」。
  ⚠️ **待评测时复核**：跑起来后 grep `OpManager` 相关行，确认是否有 `rms_norm` 出现。
  若始终不出现，说明该模型的这两个算子在摩尔上**根本没走 FlagGems**（可能是 fused 变体或专用实现），
  这会影响「算子替换」的覆盖面，报告里要写清楚。

## 结果

- 服务：✅ `Application startup complete`
- `/v1/models`：✅ `max_model_len=32768`（已按我们的参数，非模型默认的 262144）
- 短 prompt（15 token）：✅ 200，10.63s
- 长 prompt（2261 token）：✅ 200，23.28s

## 评测设置（2026-09-20 定稿，详见 [[EVAL_SETTINGS]]）

| 项目 | 值 | 来源 |
|------|----|------|
| 数据集 / 题数 | `gpqa_diamond`；筛查 50 题，**定稿 198 题全量** | 有 NV 基线 |
| thinking | ✅ `thinking_model: true` | 实测输出含 **`</think>`** 闭合标签（开标签被 chat template 吃掉） |
| 采样参数 | 模型无 `generation_config.json` → thinking 默认 temp=0.6 / top_p=0.95 | — |
| `max_model_len` | **32768**（受 KV 限制，80GB 卡上限约 65536） | 见上「为什么要显式限长」 |
| `max_tokens` | 自动 24576 → thinking 上限 20000 | `auto_max_tokens()` |
| 执行模式 | **graph（评测前去掉 `--enforce-eager` 重启）** | metax 实测 eager 慢 10 倍 |
| 算子策略 | 白名单 `silu_and_mul,rms_norm,rotary_embedding` | 摩尔首轮统一口径 |
| NV 基线 | 75 → 下限 **71.25** | `nv_baseline.yaml` |
| ⚠️ 已知坑 | thinking `content` 可能为 list → `score=null`，从 evalscope 报告恢复 | iluvatar 实测 |

> **摩尔的机会**：iluvatar 用同样配置跑出 **70.0%（NV 75，↓6.67%，差 2.5 题）不达标**，
> 但它的 `max-model-len` **只有 8192**（受 32GB 卡限制，被记为「必要约束」），且当轮有 1 个 runaway（index 22）。
> **摩尔单卡 80GB 可给到 32768（4 倍上下文）**——条件显著更好，重跑值得。
> 若仍卡在 70 附近，**下一个变量是算子策略**（参照 Phi-4 那条 GQA 经验做 A/B）。

## ⚠ 评测阶段预警（尚未处理）

1. **要不要标 thinking 待定**。它是 `Reasoning-Distilled` 模型，但本次采样输出**没有** `<think>` /
   `<reasoning>` 这类显式标签（短/长 prompt 都是直接 "Let me analyze this question step by step."）。
   → 评测前先跑几题看是否有推理链、是否需要更大 `max_tokens`；`THINKING_PATTERNS` 里同样**没有**
   `qwen3.5` 或 `distilled` 关键词，**不会被自动识别**。
2. **无 `generation_config.json`** → 采样参数这项**不需要**修补（对比另外两个模型）。
3. **多模态未验证**：本次只走文本。若后续要测 `mm_star`，需验证图像输入路径。

## 提炼到 KNOWLEDGE 的条目

1. **起服务前必须按 KV cache 反算 `--max-model-len`**，不能直接信模型 config 的
   `max_position_embeddings` —— 大 head_dim × 多层数的模型（本模型 256KB/token）会把 KV 撑爆。
   公式：`每 token KV = 层数 × 2 × kv_heads × head_dim × dtype字节`。
2. **算子注册数可以当作 FlagGems 覆盖面的探针**。同一白名单下不同模型注册到的 `default.flagos`
   算子数会不同（Phi-4=3 个、Qwen3.5=1 个）——因为 executor 只在算子首次被 dispatch 时打印，
   模型架构不同则触达的算子不同。**不能只看这一项判断白名单是否生效**。
3. **vLLM 0.24.0 已原生支持 `Qwen3_5ForConditionalGeneration`（含 MTP）**，摩尔镜像可直接起，
   不需要额外适配。
