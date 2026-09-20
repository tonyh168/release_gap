# mthreads/Phi-4-reasoning-plus 修复日志

- **失败报告**：flagrelease_fail_reports/Mthreads/FAILED_Mthreads_Phi-4-reasoning-plus_202608011354.md
- **原始失败类型**：容器准备未完成（流程会话中断）→ **从未真正评测过**
- **日期**：2026-09-20
- **本次阶段**：✅ **服务已起、冒烟通过**（尚未跑精度评测）

---

## 最终结论（阶段一：服务可用性）

| 项目 | 值 |
|------|---|
| SOP 是否跑通 | ✅ **一次通过**，未做任何 SOP 之外的调整 |
| 起服务耗时 | 14:06:00 → 14:07:03，**约 63 秒** |
| 冒烟（短 prompt） | ✅ HTTP 200 |
| 冒烟（长 prompt，14.9KB ≈ 6k token） | ✅ HTTP 200，**9.55s** |
| 精度评测 | ⬜ 未做（评测镜像/脚本尚未就位） |

**核心结论**：SOP 第 1/2/3 节的命令（特权容器 + `/datapool` 挂载 + `/usr/local/bin/vllm` +
收窄白名单 + `--enforce-eager`）在摩尔 MTT S5000 上**首次执行即成功**，无需额外调试。

---

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `mthreads-25` |
| 容器名 | `flagrelease-fix-phi-4-reasoning-plus` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/flagrelease_mthreads-gmi_vllm024plugin_base:08281629` |
| 模型路径 | `/datapool/flagrelease/fixes_models/Phi-4-reasoning-plus`（28 GB，6 分片） |
| TP / GPU / 端口 | TP=1，`MUSA_VISIBLE_DEVICES=0`，port=8000 |
| 实测显存占用 | 73795 MiB / 81920 MiB（= `--gpu-memory-utilization 0.9`） |
| 进程 | PID 1131（APIServer）+ EngineCore |

## 现象（启动日志要点）

```
INFO 09-20 14:06:00 Available plugins for group vllm.platform_plugins: fl -> vllm_fl:register
INFO 09-20 14:06:00 Platform plugin fl is activated
INFO 09-20 14:06:43 Checkpoint size: 27.31 GiB. Available RAM: 2205.46 GiB.
INFO 09-20 14:07:03 Application startup complete.
```

**✅ 白名单按预期生效**（这是我加的三个算子，一个不多一个不少）：

```
[INFO] [vllm_fl.dispatch.manager] Op 'rms_norm'         using 'default.flagos'
[INFO] [vllm_fl.dispatch.manager] Op 'rotary_embedding' using 'default.flagos'
[INFO] [vllm_fl.dispatch.manager] Op 'silu_and_mul'     using 'default.flagos'
```

## 定位：启动过程中观察到的 4 处非致命告警（均未影响起服务）

| # | 告警 | 影响 | 处置建议 |
|---|------|------|----------|
| 1 | `Unknown vLLM environment variable detected: VLLM_FL_FLAGOS_WHITELIST` | **无影响**——vLLM 只认自己的 `VLLM_*` 命名空间，这个变量是 plugin-FL 读的，实际已生效（见上方三条注册日志） | 记录为噪声，**不要**因此以为白名单没生效 |
| 2 | `RuntimeError: Cannot re-initialize MUSA in forked subprocess... use the 'spawn' start method`（EngineCore，出现 2 次） | **无影响**（服务正常起来）——发生在 `vllm/usage/usage_lib.py` 的**用量上报**路径，它 fork 子进程时撞上 torch_musa 的 MUSA 初始化检查 | 可用 `VLLM_NO_USAGE_STATS=1`（或 `DO_NOT_TRACK=1`）消掉噪声。注意：已设 `VLLM_WORKER_MULTIPROC_METHOD=spawn` **挡不住这条**，因为触发点不是 worker |
| 3 | `patch_moe_topk_softmax_for_musa: cannot import topk_softmax_flaggems ... MoE models will fail on MUSA` | **对本模型无影响**（Phi-4 是 dense，非 MoE） | MoE 模型（gpt-oss-20b、Moonlight、Qwen3-30B-A3B 等）**要重点验证这条** |
| 4 | `Failed to register Reference operators: 'ReferenceBackend' object has no attribute 'moe_align_block_size'` | 同上，**仅影响 MoE** | 同上 |

> ⚠ 第 2 条值得记入 KNOWLEDGE：**MUSA 用量上报路径的 fork 问题**——凡是在摩尔上起服务都会看到这条 traceback，
> 不代表服务坏了。若后续日志分析脚本按 `Traceback` 关键字判失败，会误报。

## 结果

- 服务：✅ `Application startup complete`
- `/v1/models`：✅ 返回 `Phi-4-reasoning-plus`，`max_model_len=32768`
- 短 prompt：✅ 正常作答（reasoning 模型，输出带 `<think>`）
- 长 prompt（14.9KB，约 6000 token）：✅ HTTP 200，9.55s —— **prefill 变长注意力路径已验证**

## 评测设置（2026-09-20 定稿，详见 [[EVAL_SETTINGS]]）

| 项目 | 值 | 来源 |
|------|----|------|
| 数据集 / 题数 | `gpqa_diamond`；筛查 50 题，**定稿 198 题全量** | 有 NV 基线；50 题不可外推 |
| thinking | ✅ `thinking_model: true`（必须） | 输出 `<think>`，关键词名单不含 |
| 采样参数 | temp=0.8 / top_p=0.95 / top_k=50（模型自带） | `generation_config.json` |
| `max_model_len` | 32768（模型默认） | config |
| `max_tokens` | 自动 24576 → thinking 上限 20000 | `auto_max_tokens()` |
| 执行模式 | **graph（评测前去掉 `--enforce-eager` 重启）** | metax 实测 eager 慢 10 倍 |
| 算子策略 | 白名单 `silu_and_mul,rms_norm,rotary_embedding` | 对齐 t-head/phi-4 最优最小白名单 |
| NV 基线 | 46 → 达标下限 **43.7** | `nv_baseline.yaml` |
| ⚠️ **首个 A/B** | `rms_norm,silu_and_mul` 留在白名单 vs **移出**（关掉其 FlagGems 替换） | ⚠️ **metax 与 t-head 结论相反**：<br>metax/Phi-4-mini（同 GQA）实测这两个算子是退化根因（加黑名单 26%→44% 达标）；<br>t-head/phi-4（同架构）却把它们留在白名单拿到最好成绩。**必须在摩尔上实测** |

> 本模型**无同名厂商成功案例**，是 4 个里唯一没有可直接照抄配置的，见 [[EVAL_SETTINGS]] 2.1。

## ⚠ 评测阶段的两个预警（尚未处理，跑评测前必看）

1. **本模型不会被自动识别为 thinking 模型**。`fast_gpqa.py` 的 `THINKING_PATTERNS`（`qwen3`/`qwq`/`deepseek-r1`/`light-r1`/`minicpm4.1`/`mimo`/`hunyuan`）
   **不含 `phi-4-reasoning` 或 `reasoning-plus`**，而 Phi-4-reasoning-plus 是实打实的 reasoning 模型
   （实测输出 `<think>...`）。→ 需通过 `context.yaml` 的 `thinking_model` 字段显式标记。

2. **采样参数会被静默忽略（reka-flash-3 同款坑）**。模型 `generation_config.json` 声明
   `do_sample=true, temperature=0.8, top_p=0.95, top_k=50`；标准流程下 `--model-name` 传的是 NV key（非本地路径）、
   容器内又无 `context.yaml` → `_resolve_model_dir()` 定位失败 → **静默退回贪心**。
   → 跑评测前必须补 `context.yaml`（做法见 [[KNOWLEDGE]] 二 / metax/reka-flash-3 日志）。

   ```bash
   docker exec flagrelease-fix-phi-4-reasoning-plus sh -c 'mkdir -p /flagos-workspace/shared && cat > /flagos-workspace/shared/context.yaml <<EOF
   model:
     local_path: /datapool/flagrelease/fixes_models/Phi-4-reasoning-plus
     container_path: /datapool/flagrelease/fixes_models/Phi-4-reasoning-plus
     thinking_model: true
   EOF'
   ```
   > 注意：`context.yaml` 的路径是脚本**硬编码**的 `/flagos-workspace/shared/context.yaml`。
   > 摩尔容器目前没挂 `/flagos-workspace`——补这个文件时要挂在 `<eval容器>:/flagos-workspace`，
   > 或在评测容器里建同路径目录。

## 提炼到 KNOWLEDGE 的条目

1. 摩尔 `VLLM_FL_FLAGOS_WHITELIST` 会触发 vLLM 的 "Unknown environment variable" 告警，但**实际生效**——别被误导。
2. 摩尔起服务时 `Cannot re-initialize MUSA in forked subprocess` traceback 出现在用量上报路径，**非致命**，日志分析别按 Traceback 判死。
3. `VLLM_WORKER_MULTIPROC_METHOD=spawn` **不能**消除上述 fork 报错（触发点不是 worker）；要消噪声用 `VLLM_NO_USAGE_STATS=1`。
4. **`THINKING_PATTERNS` 覆盖不全**：`Phi-4-reasoning-plus`、`Magistral` 这类名字里没有已知关键词的 reasoning 模型不会被自动识别，必须靠 `context.yaml` 标记。
