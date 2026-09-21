# mthreads/LFM2.5-1.2B-Thinking 修复日志

- **失败报告**：flagrelease_fail_reports/Mthreads/FAILED_Mthreads_LFM2.5-1.2B-Thinking_202607151117.md
- **原始失败类型**：精度不达标（rel_drop 超阈值）
- **日期**：2026-09-20（2026-09-21 补记评测结果与实测算子列表）
- **本次阶段**：✅ **已达标** —— 50 题筛查 **32.0%** vs NV 基线 29.0，`accuracy_compare` **退出码 0**

---

## 最终结论

| 项目 | 值 |
|------|---|
| SOP 是否跑通 | ✅ **一次通过**，未做 SOP 之外的调整 |
| 起服务耗时 | 14:31:27 → ~14:32:01，**约 35 秒** |
| 冒烟（短 prompt） | ✅ HTTP 200，3.74s |
| 冒烟（长 prompt，2262 token） | ✅ HTTP 200，**3.95s** |
| 服务地址 | `http://mthreads-25:8001/v1`，模型名 `LFM2.5-1.2B-Thinking` |
| **精度评测（50 题筛查）** | ✅ **32.0%（16/50）** vs NV 29.0 → 相对退化 **−10.34%**，退出码 0 |
| 定稿（198 题全量） | ⬜ 待跑 |

**核心结论**：**混合 SSM 架构在摩尔上起服务无障碍**。该模型 `architectures=Lfm2ForCausalLM`、
config 带 `conv_L_cache` / `block_*` 系列字段（卷积块），是 LFM2 特有的混合架构——
iluvatar 侧曾因对这类模型误用 `--attention-backend TRITON_MLA` 而报 MLACommonImpl 参数错；
**摩尔侧不指定 `--attention-backend`（走默认）即可，无需特殊处理**。

---

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `mthreads-25` |
| 容器名 | `flagrelease-fix-LFM2.5-1.2B-Thinking` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/flagrelease_mthreads-gmi_vllm024plugin_base:08281629` |
| 模型路径 | `/datapool/flagrelease/fixes_models/LFM2.5-1.2B-Thinking`（2.2 GB，单文件） |
| TP / GPU / 端口 | TP=1，`MUSA_VISIBLE_DEVICES=1`，port=8001 |
| 实测显存占用 | 73882 MiB / 81920 MiB（= `--gpu-memory-utilization 0.9`，权重仅占 2.2GB，其余为预留 KV） |
| `max_model_len` | 128000（来自模型 config 的 `max_position_embeddings`） |

## 现象（启动日志要点）

- ✅ 白名单生效，算子注册不多不少：

```
[INFO] [vllm_fl.dispatch.manager] Op 'attention_backend' using 'vendor.musa'
[INFO] [vllm_fl.dispatch.manager] Op 'rms_norm'          using 'default.flagos'
[INFO] [vllm_fl.dispatch.manager] Op 'rotary_embedding'  using 'default.flagos'
[INFO] [vllm_fl.dispatch.manager] Op 'silu_and_mul'      using 'default.flagos'
```

- ⚠️ **混合 SSM 特有告警**：`Add 2 padding layers, may waste at most 20.00% KV cache memory`
  —— 卷积层与注意力层结构不同，vLLM 需补 padding 层对齐。**不影响正确性**，但 KV cache 利用率最多损失 20%，
  长上下文场景（本模型 `max_model_len=128000`）要留意显存。

## 结果

- 服务：✅ `Application startup complete`
- `/v1/models`：✅ `LFM2.5-1.2B-Thinking`，`max_model_len=128000`
- 短 prompt（16 token）：✅ 200，3.74s
- 长 prompt（2262 token）：✅ 200，3.95s

## 评测设置（2026-09-20 定稿，详见 [[EVAL_SETTINGS]]）

| 项目 | 值 | 来源 |
|------|----|------|
| 数据集 / 题数 | `gpqa_diamond`；筛查 50 题，**定稿 198 题全量** | 有 NV 基线 |
| thinking | ✅ `thinking_model: true` | 输出 `<think>` |
| 采样参数 | 模型无采样字段 → thinking 默认 temp=0.6 / top_p=0.95 | `resolve_gen_params()` |
| `max_model_len` | 32768 | iluvatar 采用值 |
| 执行模式 | ⚠️ **`--enforce-eager`（保留，不能去掉）** | **本机实测 graph 模式不可用**（4 个模型去掉后全部启动失败）。metax 的 graph 经验在摩尔不适用，见 [[KNOWLEDGE]] 六 |
| 算子策略 | 白名单 `silu_and_mul,rms_norm,rotary_embedding`（**实测算子列表见下文专节**） | ✅ **iluvatar 实测 PASS**（32.0% vs NV 29.0，退出码 0）；本机同样达标 |
| NV 基线 | 29.0 → 下限 27.55 | iluvatar 同基线同结果 |
| ⚠️ 已知坑 | thinking 的 `content` 可能是 **list** → `detect_runaway` 崩、`score=null`；<br>**别重跑**，从 evalscope 报告恢复分数 | iluvatar 实测 |

> **4 个模型里最可能一次过的**——iluvatar 已用同一套设置 PASS，直接照抄。

## ⚠ 评测阶段预警（✅ 2026-09-20 评测时已处置）

> 实测结果：**`score=null` 这个坑这次没有复现** —— `gpqa_50.json` 的 `score` 直接是 32.0，无需从 evalscope 报告回填。
> （预警本身仍成立，只是本轮未触发；下轮若命中按原方案回填。）

1. **不会被自动识别为 thinking 模型**。实测输出以 `<think>` 开头，但 `fast_gpqa.py` 的
   `THINKING_PATTERNS`（`qwen3`/`qwq`/`deepseek-r1`/`deepseek-r2`/`light-r1`/`minicpm4.1`/`mimo`/`hunyuan`）
   **不含 `lfm2` 或 `thinking`** → 需 `context.yaml` 显式标 `thinking_model: true`。

2. **`generation_config.json` 极简，未声明采样参数**（只有 bos/eos/pad）→
   本模型**大概率就该用贪心评测**，采样参数这一项对它可能不是问题。但仍建议按标准流程补 `context.yaml`
   写明 `local_path`，便于脚本正确定位模型目录。

## 精度评测结果（gpqa_diamond 50 题筛查，2026-09-20）

| 项目 | 值 |
|------|----|
| 得分 | **32.0%（16/50）** |
| NV 基线 / 达标下限 | 29.0 / 27.55（容差 5%） |
| 相对退化 | **−10.34%**（高于基线 3.0pt） |
| 判定 | ✅ `accuracy_compare` **退出码 0**，`aligned: true`，`noise_zone: false` |
| 模式 / 采样 | `thinking` / temp **0.6**、top_p **0.95**、top_k 未设（模型 gc 无采样字段 → 走服务端默认） |
| `max_tokens` / `max_model_len` | 20000 / 32768 |
| 截断 / runaway | `truncation_detected: false` / `runaway_count: 0`（50/50 全检） |
| 并发 / 耗时 | `eval_batch_size: 4` / 探测 88.1s + 评测段 **1341s（约 22min）** |
| 产物 | `gpqa_50.json`、`verdict_50.json`、`eval_50.log`（`release_run_logs/LFM2.5-1.2B-Thinking/`） |
| evalscope 报告 | `outputs/gpqa_diamond/20260920_090345/reports/LFM2.5-1.2B-Thinking/gpqa_diamond.json` |

**采样参数确认生效**（预警第 2 条的验证点，实际日志）：

```
[gen] generation_config.json 无可用采样字段，沿用默认
```

→ `context.yaml` 生效（脚本**定位到了模型目录**并读到了它的 `generation_config.json`），该 gc 只有
bos/eos/pad、本就无采样字段 → 按 **thinking 默认 temp=0.6 / top_p=0.95** 评测，与预期一致。

判定 JSON（`verdict_50.json`）：

```json
{"baseline_mode": "nv_reference", "model": "LFM2.5-1.2B-Thinking", "metric": "gpqa_diamond",
 "nv": {"score": 29.0, "source": "NV 实测"}, "current": {"score": 32.0, "mode": "thinking"},
 "tolerance": 0.05, "missing_nv": false, "rel_drop": -0.1034, "abs_diff": 3.0,
 "aligned": true, "noise_zone": false,
 "message": "精度达标: 当前=32.00%, NV=29.00%, 相对退化=-10.34% (容差 5.0%)"}
```

> 与 **iluvatar 同题同分同基线**（32.0% vs 29.0，退出码 0）——**跨平台口径复现成功**，
> 这条是最干净的一组对照：同一模型、同一配置、两家芯片、同为 50 题筛查，结果一字不差。
>
> 逐题对错：答对 16 题（index 0,2,8,10,13,15,19,26,27,30,38,40,42,43,47,49）；其余 34 题答错。
> 逐题原文与判分见 evalscope 的 `reviews/LFM2.5-1.2B-Thinking/gpqa_diamond_default.jsonl`。

## 开启算子列表（实测，2026-09-21 取自容器 `/tmp/flaggems_enable_oplist.txt`）

> **文件名注意**：是 **`flaggems_enable_oplist.txt`**（`oplist` 连写，**不是** `op_list`），在**服务容器**的 `/tmp/` 下。
> 它不是配置文件，而是 plugin-FL 在**算子首次被 dispatch 时**打出的 DEBUG 记录——逐行记「哪个 dispatch op 落到哪个后端」
> 以及其下 flag_gems 的具体实现函数。所以它反映的是**实际触达**的算子，比白名单本身更有信息量。

启动时设置的白名单：`VLLM_FL_FLAGOS_WHITELIST=silu_and_mul,rms_norm,rotary_embedding`

| dispatch op | 落到哪个后端 | 下层实现（`flag_gems`） | 实测是否触达 |
|-------------|--------------|------------------------|:------------:|
| `rms_norm` | `default.flagos` | `gems_rms_forward` → `rms_norm_forward`；另有 **`fused_add_rms_norm`**（`[8192, 2048]` 形状实测） | ✅ |
| `rotary_embedding` | `default.flagos` | `gems_rope_forward` → `apply_rotary_pos_emb` | ✅ |
| `silu_and_mul` | `default.flagos` | `gems_silu_and_mul` → `silu_and_mul.forward` | ✅ |
| `attention_backend` | `vendor.musa` | ——（厂商后端，**不是** FlagGems） | ✅ |

**→ 开启算子列表：`["rms_norm", "rotary_embedding", "silu_and_mul"]`**（白名单 3 个全部真实触达）

> 📌 注意：**不是** iluvatar 那套 `sort,sort_stable` 默认黑名单口径——摩尔用**白名单**机制
> （`VLLM_FL_FLAGOS_WHITELIST`，与黑名单互斥、优先级最高），两者只是「最终都用到了这几个算子」，
> **命令行写法完全不同，报告里别照抄 iluvatar 的名单**。

原始文件全文（11 行 / 966 B / md5 `79f4cea3dd8f0144371bb30619ad904b`）：

```
[DEBUG] vllm_fl.dispatch.ops.rms_norm: default.flagos
[DEBUG] flag_gems.modules.normalization.gems_rms_forward: GEMS CUSTOM RMS_NORM
[DEBUG] flag_gems.ops.rms_norm.rms_norm_forward: GEMS RMS_NORM FORWARD
[DEBUG] flag_gems.modules.normalization.gems_rms_forward: GEMS CUSTOM FUSED_ADD_RMS_NORM
[DEBUG] flag_gems.fused.fused_add_rms_norm.fused_add_rms_norm: GEMS FUSED_ADD_RMS_NORM FORWARD, [input shape]: torch.Size([8192, 2048]), [residual shape]: torch.Size([8192, 2048]), [weight shape]: torch.Size([2048])
[DEBUG] vllm_fl.dispatch.ops.silu_and_mul: default.flagos
[DEBUG] flag_gems.modules.activation.gems_silu_and_mul: GEMS CUSTOM SILU_AND_MUL FORWARD
[DEBUG] flag_gems.fused.silu_and_mul.forward: GEMS SILU AND MUL FORWARD
[DEBUG] vllm_fl.dispatch.ops.rotary_embedding: default.flagos
[DEBUG] flag_gems.modules.rotary_embedding.gems_rope_forward: GEMS CUSTOM ROPE FORWARD
[DEBUG] flag_gems.fused.rotary_embedding.apply_rotary_pos_emb: GEMS ROTARY_POS_EMBEDDING
```

> 与服务日志交叉验证一致（`serve.log` 的 `Op '…' using '…'` 行同样得到这 3 个 + `attention_backend`）。
> 混合 SSM 架构（卷积块 + 注意力）**没有**引入额外的 FlagGems 算子。

## 提炼到 KNOWLEDGE 的条目

1. **混合 SSM 模型（LFM2 系）在摩尔上无需特殊 `--attention-backend`**，走默认即可起；
   iluvatar 侧「非 MLA 模型不要指定 TRITON_MLA」的经验在摩尔同样适用，但摩尔默认值本身就是对的。
2. **混合 SSM 会触发 `Add N padding layers` 告警**，KV cache 最多浪费 20%——不影响正确性，
   但配合大 `max_model_len` 时要核算显存。
3. **纯 1.2B 小模型在 80GB 卡上用 `--gpu-memory-utilization 0.9` 会把整卡 73GB 都预留掉**
   （实测 73882 MiB），想在同一张卡上多开服务必须显式下调该值，否则一模型独占一卡。
4. **容器 `/tmp/flaggems_enable_oplist.txt`（`oplist` 连写）＝「实际触达算子」探针**：
   逐行记 `vllm_fl.dispatch.ops.<op>: <后端>` + 下层 `flag_gems` 实现函数。
   **报告里的「开启算子列表」应从它取，不要照抄白名单**（两者可能不一致，见 Qwen3.5 日志）。
5. **跨平台同配置可复现**：本模型摩尔 **32.0% vs NV 29.0**，与 iluvatar 的 **32.0% vs 29.0** 逐位一致
   ——同一模型 + 同一 NV 基线 + 同为 50 题筛查，两家芯片给出相同结论。**这类模型可直接照抄配置，不必逐家试错**。
