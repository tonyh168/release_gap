# mthreads/Phi-4-reasoning-plus 修复日志

- **失败报告**：flagrelease_fail_reports/Mthreads/FAILED_Mthreads_Phi-4-reasoning-plus_202608011354.md
- **原始失败类型**：容器准备未完成（流程会话中断）→ **从未真正评测过**
- **日期**：2026-09-20（2026-09-21 补记评测结果与实测算子列表）
- **本次阶段**：✅ **已达标** —— 50 题筛查 **58.0%** vs NV 基线 46，`accuracy_compare` **退出码 0**

---

## 最终结论

| 项目 | 值 |
|------|---|
| SOP 是否跑通 | ✅ **一次通过**，未做任何 SOP 之外的调整 |
| 起服务耗时 | 14:06:00 → 14:07:03，**约 63 秒** |
| 冒烟（短 prompt） | ✅ HTTP 200 |
| 冒烟（长 prompt，14.9KB ≈ 6k token） | ✅ HTTP 200，**9.55s** |
| **精度评测（50 题筛查）** | ✅ **58.0%（29/50）** vs NV 46 → 相对退化 **−26.09%**，退出码 0 |
| 定稿（198 题全量） | ⬜ 待跑（50 题只作筛查，判定以全量为准） |

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
| 执行模式 | ⚠️ **`--enforce-eager`（保留，不能去掉）** | **本机实测 graph 模式不可用**：去掉后 4 个模型全部启动失败（`MUSA driver error: operation not permitted when stream is capturing`）。<br>metax「graph 快 10 倍」在摩尔**不适用**，见 [[KNOWLEDGE]] 六 |
| 算子策略 | 白名单 `silu_and_mul,rms_norm,rotary_embedding`（**实测算子列表见下文专节**） | 对齐 t-head/phi-4 最优最小白名单 |
| NV 基线 | 46 → 达标下限 **43.7** | `nv_baseline.yaml` |
| ⚠️ **首个 A/B** | `rms_norm,silu_and_mul` 留在白名单 vs **移出**（关掉其 FlagGems 替换） | ⚠️ **metax 与 t-head 结论相反**：<br>metax/Phi-4-mini（同 GQA）实测这两个算子是退化根因（加黑名单 26%→44% 达标）；<br>t-head/phi-4（同架构）却把它们留在白名单拿到最好成绩。**必须在摩尔上实测** |

> 本模型**无同名厂商成功案例**，是 4 个里唯一没有可直接照抄配置的，见 [[EVAL_SETTINGS]] 2.1。

## ⚠ 评测阶段的两个预警（✅ 2026-09-20 评测时已按预警逐条处置）

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

## 精度评测结果（gpqa_diamond 50 题筛查，2026-09-20）

| 项目 | 值 |
|------|----|
| 得分 | **58.0%（29/50）** |
| NV 基线 / 达标下限 | 46 / 43.7（容差 5%） |
| 相对退化 | **−26.09%**（高于基线 12.0pt） |
| 判定 | ✅ `accuracy_compare` **退出码 0**，`aligned: true`，`noise_zone: false` |
| 模式 / 采样 | `thinking` / temp **0.8**、top_p **0.95**、top_k **50** |
| `max_tokens` / `max_model_len` | 20000 / 32768 |
| 截断 / runaway | `truncation_detected: false` / `runaway_count: 0`（50/50 全检） |
| 并发 / 耗时 | `eval_batch_size: 16` / 评测段 **11448s（约 3.2h）** |
| 产物 | `gpqa_50.json`、`verdict_50.json`、`eval_50.log`（`release_run_logs/Phi-4-reasoning-plus/`） |
| evalscope 报告 | `outputs/gpqa_diamond/20260920_090428/reports/Phi-4-reasoning-plus/gpqa_diamond.json` |

**采样参数确认生效**（两道预警的验证点，实际日志）：

```
[gen] 采用模型 generation_config.json 采样参数: {'temperature': 0.8, 'top_p': 0.95, 'top_k': 50}
```

→ 两个预警均已落地：`context.yaml` 写了 `thinking_model: true`，采样参数**没有被退回贪心**。

判定 JSON（`verdict_50.json`）：

```json
{"baseline_mode": "nv_reference", "model": "Phi-4-reasoning-plus", "metric": "gpqa_diamond",
 "nv": {"score": 46.0, "source": "NV 实测"}, "current": {"score": 58.0, "mode": "thinking"},
 "tolerance": 0.05, "missing_nv": false, "rel_drop": -0.2609, "abs_diff": 12.0,
 "aligned": true, "noise_zone": false,
 "message": "精度达标: 当前=58.00%, NV=46.00%, 相对退化=-26.09% (容差 5.0%)"}
```

> 逐题对错：答对 29 题（index 0,1,2,4,5,6,9,10,11,13,14,16,19,20,25,26,27,34,35,38,39,40,41,42,43,44,46,47,49）；
> 答错 21 题（3,7,8,12,15,17,18,21,22,23,24,28,29,30,31,32,33,36,37,45,48）。
> 逐题原文与判分见 evalscope 的 `reviews/Phi-4-reasoning-plus/gpqa_diamond_default.jsonl`。

## 开启算子列表（实测，2026-09-21 取自容器 `/tmp/flaggems_enable_oplist.txt`）

> **文件名注意**：是 **`flaggems_enable_oplist.txt`**（`oplist` 连写，**不是** `op_list`），在**服务容器**的 `/tmp/` 下。
> 它不是配置文件，而是 plugin-FL 在**算子首次被 dispatch 时**打出的 DEBUG 记录——逐行记「哪个 dispatch op 落到哪个后端」
> 以及其下 flag_gems 的具体实现函数。所以它反映的是**实际触达**的算子，比白名单本身更有信息量。

启动时设置的白名单：`VLLM_FL_FLAGOS_WHITELIST=silu_and_mul,rms_norm,rotary_embedding`

| dispatch op | 落到哪个后端 | 下层实现（`flag_gems`） | 实测是否触达 |
|-------------|--------------|------------------------|:------------:|
| `rms_norm` | `default.flagos` | `gems_rms_forward` → `rms_norm_forward`；另有 **`fused_add_rms_norm`**（`[8192, 5120]` 形状实测） | ✅ |
| `rotary_embedding` | `default.flagos` | `gems_rope_forward` → `apply_rotary_pos_emb` | ✅ |
| `silu_and_mul` | `default.flagos` | `gems_silu_and_mul` → `silu_and_mul.forward` | ✅ |
| `attention_backend` | `vendor.musa` | ——（厂商后端，**不是** FlagGems） | ✅ |

**→ 开启算子列表：`["rms_norm", "rotary_embedding", "silu_and_mul"]`**（白名单 3 个全部真实触达，一个不多一个不少）

原始文件全文（11 行 / 966 B / md5 `4e35deedbe0c7457f731382b95547e9c`）：

```
[DEBUG] vllm_fl.dispatch.ops.rms_norm: default.flagos
[DEBUG] flag_gems.modules.normalization.gems_rms_forward: GEMS CUSTOM RMS_NORM
[DEBUG] flag_gems.ops.rms_norm.rms_norm_forward: GEMS RMS_NORM FORWARD
[DEBUG] vllm_fl.dispatch.ops.rotary_embedding: default.flagos
[DEBUG] flag_gems.modules.rotary_embedding.gems_rope_forward: GEMS CUSTOM ROPE FORWARD
[DEBUG] flag_gems.fused.rotary_embedding.apply_rotary_pos_emb: GEMS ROTARY_POS_EMBEDDING
[DEBUG] flag_gems.modules.normalization.gems_rms_forward: GEMS CUSTOM FUSED_ADD_RMS_NORM
[DEBUG] flag_gems.fused.fused_add_rms_norm.fused_add_rms_norm: GEMS FUSED_ADD_RMS_NORM FORWARD, [input shape]: torch.Size([8192, 5120]), [residual shape]: torch.Size([8192, 5120]), [weight shape]: torch.Size([5120])
[DEBUG] vllm_fl.dispatch.ops.silu_and_mul: default.flagos
[DEBUG] flag_gems.modules.activation.gems_silu_and_mul: GEMS CUSTOM SILU_AND_MUL FORWARD
[DEBUG] flag_gems.fused.silu_and_mul.forward: GEMS SILU AND MUL FORWARD
```

> 与服务日志交叉验证一致：`grep -oE "Op .[a-z_]+. using .[a-z._]+." serve.log` 同样得到
> `rms_norm` / `rotary_embedding` / `silu_and_mul` → `default.flagos`，外加 `attention_backend` → `vendor.musa`。
>
> ⚠️ 与 `serve.log` 里那条 `IrOpPriorityConfig(rms_norm=['native'], fused_add_rms_norm=['native'])` **不矛盾**：
> 该行是 vLLM 自己的 IR 融合优先级打印，**4 个模型全都一样**，与 plugin-FL 的 dispatch 是两套机制。

## 提炼到 KNOWLEDGE 的条目

1. 摩尔 `VLLM_FL_FLAGOS_WHITELIST` 会触发 vLLM 的 "Unknown environment variable" 告警，但**实际生效**——别被误导。
2. 摩尔起服务时 `Cannot re-initialize MUSA in forked subprocess` traceback 出现在用量上报路径，**非致命**，日志分析别按 Traceback 判死。
3. `VLLM_WORKER_MULTIPROC_METHOD=spawn` **不能**消除上述 fork 报错（触发点不是 worker）；要消噪声用 `VLLM_NO_USAGE_STATS=1`。
4. **`THINKING_PATTERNS` 覆盖不全**：`Phi-4-reasoning-plus`、`Magistral` 这类名字里没有已知关键词的 reasoning 模型不会被自动识别，必须靠 `context.yaml` 标记。
5. **容器 `/tmp/flaggems_enable_oplist.txt`（注意 `oplist` 连写）是「实际触达算子」的探针**，比白名单本身更有信息量——
   逐行记 `vllm_fl.dispatch.ops.<op>: <后端>` + 下层 `flag_gems` 实现函数。**报告里的「开启算子列表」应从它取，而不是照抄白名单**：
   两者可能不一致（见 Qwen3.5 日志：白名单 3 个、实际只触达 1 个）。
6. **同一个白名单下，不同架构触达的算子数不同**：Phi-4（dense GQA）3 个全触达；
   `attention_backend` 恒为 `vendor.musa`（厂商后端），**不属于 FlagGems 算子，不要写进算子列表**。
7. 顺手存证：`serve.log` 里 `IrOpPriorityConfig(rms_norm=['native'], …)` 是 vLLM 自己的 IR 融合优先级，
   **4 个模型全一样**，与 plugin-FL dispatch 是两套机制，别把它当成「算子没走 FlagGems」的证据。
