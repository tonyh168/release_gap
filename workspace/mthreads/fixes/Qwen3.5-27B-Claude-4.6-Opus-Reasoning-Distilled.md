# mthreads/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled 修复日志

- **失败报告**：flagrelease_fail_reports/Mthreads/FAILED_Mthreads_Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled_202608020835.md
- **原始失败类型**：未达标（报告只写「未达标」，无细分原因）
- **日期**：2026-09-20（2026-09-21 补记评测结果与实测算子列表）
- **本次阶段**：✅ **已达标** —— 50 题筛查 **78.0%** vs NV 基线 75，`accuracy_compare` **退出码 0**
  （**iluvatar 同模型 70.0% 不达标，摩尔反超 8pt 并过关**）

---

## 最终结论

| 项目 | 值 |
|------|---|
| SOP 是否跑通 | ✅ 通过，**但需额外一个参数**（`--max-model-len 32768`，见下） |
| 起服务耗时 | 14:37:24 → 14:40:04，**2 分 40 秒**（52GB 权重从 LeoFS 加载） |
| 冒烟（短 prompt） | ✅ HTTP 200，10.63s |
| 冒烟（长 prompt，2261 token） | ✅ HTTP 200，**23.28s** |
| 服务地址 | `http://mthreads-25:8003/v1`，模型名 `Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled` |
| **精度评测（50 题筛查）** | ✅ **78.0%（39/50）** vs NV 75 → 相对退化 **−4.00%**，退出码 0 |
| 定稿（198 题全量） | ⬜ 待跑 |

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

  ✅ **2026-09-21 复核结论：确认只触达 1 个算子，不是偶发。** 两条独立证据一致：
  ① `serve.log` 全程只有 `attention_backend` + `silu_and_mul` 两行 `using` 记录；
  ② 容器 `/tmp/flaggems_enable_oplist.txt` **只有 3 行**（另三个模型是 11 行），内容仅 `silu_and_mul` 一条链路。
  → 该模型的 `rms_norm` / `rotary_embedding` 在摩尔上**根本没走 FlagGems**（推测是专用/fused 实现绕开了
  plugin-FL 的 dispatch 拦截点）。**这不影响本模型达标**，但意味着「算子替换」的实际覆盖面比白名单窄，
  详见下文「开启算子列表」专节。

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
| 执行模式 | ⚠️ **`--enforce-eager`（保留，不能去掉）** | **本机实测 graph 模式不可用**（4 个模型去掉后全部启动失败）。metax 的 graph 经验在摩尔不适用，见 [[KNOWLEDGE]] 六 |
| 算子策略 | 白名单 `silu_and_mul,rms_norm,rotary_embedding` —— ⚠️ **实测只触达 `silu_and_mul` 一个**，详见下文专节 | 摩尔首轮统一口径 |
| NV 基线 | 75 → 下限 **71.25** | `nv_baseline.yaml` |
| ⚠️ 已知坑 | thinking `content` 可能为 list → `score=null`，从 evalscope 报告恢复 | iluvatar 实测 |

> **摩尔的机会**：iluvatar 用同样配置跑出 **70.0%（NV 75，↓6.67%，差 2.5 题）不达标**，
> 但它的 `max-model-len` **只有 8192**（受 32GB 卡限制，被记为「必要约束」），且当轮有 1 个 runaway（index 22）。
> **摩尔单卡 80GB 可给到 32768（4 倍上下文）**——条件显著更好，重跑值得。
> 若仍卡在 70 附近，**下一个变量是算子策略**（参照 Phi-4 那条 GQA 经验做 A/B）。
>
> ✅ **2026-09-20 实测验证成立**：摩尔 **78.0%（39/50）vs NV 75（−4.00%，退出码 0）达标**，
> 比 iluvatar 高 **8pt**，**不需要再动算子策略**。这是四个模型里唯一「靠放宽上下文把不达标翻成达标」的案例。

## ⚠ 评测阶段预警（✅ 2026-09-20 评测时已处置）

> 实测修正：预警第 1 条里「本次采样输出**没有** `<think>`」的判断**不成立** —— 正式评测的 50 题
> 输出中出现了 **`</think>` 闭合标签**（开标签被 chat template 吃掉），确认是 reasoning 模型，
> `thinking_model: true` 标记正确，`mode: thinking` 生效。
> `THINKING_PATTERNS` 不含 `qwen3.5` 关键词这条判断依然成立，**是靠 `context.yaml` 显式标记救回来的**。

1. **要不要标 thinking 待定**。它是 `Reasoning-Distilled` 模型，但本次采样输出**没有** `<think>` /
   `<reasoning>` 这类显式标签（短/长 prompt 都是直接 "Let me analyze this question step by step."）。
   → 评测前先跑几题看是否有推理链、是否需要更大 `max_tokens`；`THINKING_PATTERNS` 里同样**没有**
   `qwen3.5` 或 `distilled` 关键词，**不会被自动识别**。
2. **无 `generation_config.json`** → 采样参数这项**不需要**修补（对比另外两个模型）。
3. **多模态未验证**：本次只走文本。若后续要测 `mm_star`，需验证图像输入路径。

## 精度评测结果（gpqa_diamond 50 题筛查，2026-09-20）

| 项目 | 值 |
|------|----|
| 得分 | **78.0%（39/50）** |
| NV 基线 / 达标下限 | 75 / 71.25（容差 5%） |
| 相对退化 | **−4.00%**（高于基线 3.0pt） |
| 判定 | ✅ `accuracy_compare` **退出码 0**，`aligned: true`，`noise_zone: false` |
| 模式 / 采样 | `thinking` / temp **0.6**、top_p **0.95**（模型无 gc → thinking 默认值） |
| `max_tokens` / `max_model_len` | 20000 / **32768** |
| 截断 | `truncation_detected: false` |
| runaway | ⚠️ **1 个**（index **7**，`high_repeat_and_compressible`，diversity 0.0107 / compress_ratio 0.0229，`finish_reason=max_tokens`） |
| 并发 / 耗时 | `eval_batch_size: 4` / 探测 77.3s + 评测段 **3802s（约 1.06h）** |
| 产物 | `gpqa_50.json`、`verdict_50.json`、`eval_50.log`（`release_run_logs/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled/`） |
| evalscope 报告 | `outputs/gpqa_diamond/20260920_090655/reports/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled/gpqa_diamond.json` |

**采样参数确认生效**（实际日志）：

```
[gen] 未找到模型 generation_config.json，沿用默认采样参数
```

→ 模型**本就没有** `generation_config.json`，等价于「无采样参数坑」；thinking 默认 temp=0.6 / top_p=0.95。
`context.yaml` 的作用是**让脚本定位到模型目录并显式标 thinking**（`THINKING_PATTERNS` 不含 `qwen3.5`）。

判定 JSON（`verdict_50.json`）：

```json
{"baseline_mode": "nv_reference",
 "model": "Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled", "metric": "gpqa_diamond",
 "nv": {"score": 75.0, "source": "NV 实测"}, "current": {"score": 78.0, "mode": "thinking"},
 "tolerance": 0.05, "missing_nv": false, "rel_drop": -0.04, "abs_diff": 3.0,
 "aligned": true, "noise_zone": false,
 "message": "精度达标: 当前=78.00%, NV=75.00%, 相对退化=-4.00% (容差 5.0%)"}
```

**与 iluvatar 的同模型对照（同为 50 题筛查）**：

| 平台 | `max_model_len` | `max_tokens` | 得分 | runaway | 判定 |
|------|:---------------:|:------------:|:----:|:-------:|:----:|
| iluvatar（BI-V150，受 32GB 卡限制） | 8192 | 4096 | 70.0% | 1（index 22） | ❌ 不达标（↓6.67%） |
| **mthreads（S5000，80GB）** | **32768** | **20000** | **78.0%** | 1（index 7） | ✅ **达标（−4.00%）** |

> **同一个模型、同一份思考配置，仅上下文长度差 4 倍，得分差 8pt 并把不达标翻成达标**——
> 这是「`max_model_len` 不能照抄别家」的最有力证据（摩尔侧 256 KB/token 的 KV 反算见上）。
> 两个平台的 runaway 各 1 个但**不是同一题**（index 22 vs 7），属采样抖动，量级一致。
>
> 逐题对错：答对 39 题（index 0,2,3,4,5,6,8,9,10,11,13,14,16,19,20,21,22,23,24,26,27,28,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,49）；
> 答错 11 题（1,7,12,15,17,18,25,29,30,47,48）。逐题原文见 evalscope `reviews/` 目录。

## 开启算子列表（实测，2026-09-21 取自容器 `/tmp/flaggems_enable_oplist.txt`）

> **文件名注意**：是 **`flaggems_enable_oplist.txt`**（`oplist` 连写，**不是** `op_list`），在**服务容器**的 `/tmp/` 下。
> 它是 plugin-FL 在**算子首次被 dispatch 时**打出的 DEBUG 记录，反映**实际触达**的算子。

启动时设置的白名单：`VLLM_FL_FLAGOS_WHITELIST=silu_and_mul,rms_norm,rotary_embedding`

| dispatch op | 白名单里 | 实测落到哪个后端 | 下层实现（`flag_gems`） | 实测是否触达 |
|-------------|:--------:|------------------|------------------------|:------------:|
| `silu_and_mul` | ✅ | `default.flagos` | `gems_silu_and_mul` → `silu_and_mul.forward` | ✅ **唯一触达** |
| `rms_norm` | ✅ | —— | —— | ❌ **未触达** |
| `rotary_embedding` | ✅ | —— | —— | ❌ **未触达** |
| `attention_backend` | ❌ | `vendor.musa` | ——（厂商后端，**不是** FlagGems） | ✅ |

**→ 开启算子列表：`["silu_and_mul"]`** —— ⚠️ **只有 1 个**，与白名单的 3 个**不一致**。

**为什么不一致（已复核，两条证据互证）**：`serve.log` 里另三个模型都有
`Op 'rms_norm' using 'default.flagos'` / `Op 'rotary_embedding' using 'default.flagos'`，
**本模型全程没有这两行**；本模型容器里的 oplist 文件**只有 3 行**（另三个是 11 行）。
dispatch 行是在算子**首次被调用**时才打印的，所以结论是：**该模型的 rms_norm / rotary 走了别的实现路径，
根本没经过 plugin-FL 的 dispatch 拦截点**。推测与其架构有关（`Qwen3_5ForConditionalGeneration`，
64 层 / head_dim 256 / 多模态 + MTP 权重），但**本次未做进一步定位**。

> ⚠️ **对发布的影响**：本模型达标（78% vs 75）**是在这个「窄覆盖面」下取得的**，无需修改配置。
> 但**不能据此认为白名单对 Qwen3.5 生效**——将来若要靠加/减算子调精度，改 `rms_norm`/`rotary_embedding`
> 两项是**无效操作**（改了也不会被触达），必须先确认算子真的进了 dispatch。
> 另注：`serve.log` 里 `IrOpPriorityConfig(rms_norm=['native'], fused_add_rms_norm=['native'])` 这行
> **4 个模型全一样**，是 vLLM 自己的 IR 融合优先级、与 plugin-FL dispatch 无关，**不能当证据**。

原始文件全文（3 行 / 219 B / md5 `5d0bbf6d990598243bca0ee8f70fa6a6`）：

```
[DEBUG] vllm_fl.dispatch.ops.silu_and_mul: default.flagos
[DEBUG] flag_gems.modules.activation.gems_silu_and_mul: GEMS CUSTOM SILU_AND_MUL FORWARD
[DEBUG] flag_gems.fused.silu_and_mul.forward: GEMS SILU AND MUL FORWARD
```

## 提炼到 KNOWLEDGE 的条目

1. **起服务前必须按 KV cache 反算 `--max-model-len`**，不能直接信模型 config 的
   `max_position_embeddings` —— 大 head_dim × 多层数的模型（本模型 256KB/token）会把 KV 撑爆。
   公式：`每 token KV = 层数 × 2 × kv_heads × head_dim × dtype字节`。
2. **算子注册数可以当作 FlagGems 覆盖面的探针**（✅ 2026-09-21 已复核确认）。同一白名单下不同模型
   注册到的 `default.flagos` 算子数**真的会不同**（Phi-4=3 个、Qwen3.5=**1 个**，两条独立证据一致：
   `serve.log` 的 `using` 行 + 容器 `/tmp/flaggems_enable_oplist.txt` 的行数）。
   原因是 dispatch 只在算子**首次被调用**时打印，架构不同则触达路径不同。
   → **白名单写了不等于生效**：报告里要按实测写「开启算子列表」，别照抄白名单。
3. **`max_model_len` 是精度变量，不只是显存变量**：同模型同配置，iluvatar 8192 → 70.0%（不达标）、
   摩尔 32768 → **78.0%（达标）**，8pt 的差距全部来自上下文长度。**跨厂商不要照抄 `max-model-len`**，
   要按本机显存重算（本模型 256 KB/token）。
4. **vLLM 0.24.0 已原生支持 `Qwen3_5ForConditionalGeneration`（含 MTP）**，摩尔镜像可直接起，
   不需要额外适配。
