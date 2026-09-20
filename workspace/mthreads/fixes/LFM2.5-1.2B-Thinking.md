# mthreads/LFM2.5-1.2B-Thinking 修复日志

- **失败报告**：flagrelease_fail_reports/Mthreads/FAILED_Mthreads_LFM2.5-1.2B-Thinking_202607151117.md
- **原始失败类型**：精度不达标（rel_drop 超阈值）
- **日期**：2026-09-20
- **本次阶段**：✅ **服务已起、冒烟通过**（尚未跑精度评测）

---

## 最终结论（阶段一：服务可用性）

| 项目 | 值 |
|------|---|
| SOP 是否跑通 | ✅ **一次通过**，未做 SOP 之外的调整 |
| 起服务耗时 | 14:31:27 → ~14:32:01，**约 35 秒** |
| 冒烟（短 prompt） | ✅ HTTP 200，3.74s |
| 冒烟（长 prompt，2262 token） | ✅ HTTP 200，**3.95s** |
| 服务地址 | `http://mthreads-25:8001/v1`，模型名 `LFM2.5-1.2B-Thinking` |
| 精度评测 | ⬜ 未做（评测镜像/脚本尚未就位） |

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

## ⚠ 评测阶段预警（尚未处理，跑评测前必看）

1. **不会被自动识别为 thinking 模型**。实测输出以 `<think>` 开头，但 `fast_gpqa.py` 的
   `THINKING_PATTERNS`（`qwen3`/`qwq`/`deepseek-r1`/`deepseek-r2`/`light-r1`/`minicpm4.1`/`mimo`/`hunyuan`）
   **不含 `lfm2` 或 `thinking`** → 需 `context.yaml` 显式标 `thinking_model: true`。

2. **`generation_config.json` 极简，未声明采样参数**（只有 bos/eos/pad）→
   本模型**大概率就该用贪心评测**，采样参数这一项对它可能不是问题。但仍建议按标准流程补 `context.yaml`
   写明 `local_path`，便于脚本正确定位模型目录。

## 提炼到 KNOWLEDGE 的条目

1. **混合 SSM 模型（LFM2 系）在摩尔上无需特殊 `--attention-backend`**，走默认即可起；
   iluvatar 侧「非 MLA 模型不要指定 TRITON_MLA」的经验在摩尔同样适用，但摩尔默认值本身就是对的。
2. **混合 SSM 会触发 `Add N padding layers` 告警**，KV cache 最多浪费 20%——不影响正确性，
   但配合大 `max_model_len` 时要核算显存。
3. **纯 1.2B 小模型在 80GB 卡上用 `--gpu-memory-utilization 0.9` 会把整卡 73GB 都预留掉**
   （实测 73882 MiB），想在同一张卡上多开服务必须显式下调该值，否则一模型独占一卡。
