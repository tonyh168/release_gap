# mthreads/reka-flash-3 修复日志

- **失败报告**：flagrelease_fail_reports/Mthreads/FAILED_Mthreads_reka-flash-3_202608020152.md
- **原始失败类型**：精度不达标（rel_drop 超阈值）+ 性能不达标
- **日期**：2026-09-20
- **本次阶段**：✅ **服务已起、冒烟通过**（尚未跑精度评测）

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
