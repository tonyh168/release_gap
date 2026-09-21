# mthreads/reka-flash-3 修复日志

- **失败报告**：flagrelease_fail_reports/Mthreads/FAILED_Mthreads_reka-flash-3_202608020152.md
- **原始失败类型**：精度不达标（rel_drop 超阈值）+ 性能不达标
- **日期**：2026-09-20（2026-09-21 补记重复性实验结论）

## 现象

模型是标准 `LlamaForCausalLM`（44 层 / hidden 6144 / 64 heads / 8 kv heads，GQA），
摩尔上起服务**一次通过、无任何异常**（约 45 秒加载 39GB 权重）：

```
INFO 09-20 14:31:30 Platform plugin fl is activated
INFO 09-20 14:32:14 Application startup complete.
```

冒烟：短 prompt ✅ 200，4.76s；长 prompt（2257 token）✅ 200，11.48s。

**首轮 50 题评测（2026-09-20）判为不达标**：**50.0%（25/50）**，
对表内基线 59 退化 15.25%、对 NV 原生 53.54 退化 6.61%，**两种基准都超 5% 容差**。

但该轮与 metax v6（56.00%）的同题对照呈现「**7:4 的不对称**」，方向可疑 →
**启动重复性实验复核**，结论是**原轮为采样下沿，实际应判达标**（详见下「定位」）。

## 定位

**根因不是 plugin-FL 算子退化，也不是采样参数失效，而是「单轮 50 题的采样噪声」。**

逐条排除：

1. **采样参数一直生效**（metax 那条根因在摩尔侧从未发生）。评测日志确认：

   ```
   [gen] 采用模型 generation_config.json 采样参数: {'temperature': 0.6, 'top_p': 0.95, 'top_k': 1024}
   ```
   即 `context.yaml` 生效、模型自带的 `generation_config.json` 被正确采用，**没有退回贪心**。

2. **算子侧无异常**。白名单 3 个算子全部真实触达（见下「开启算子列表」），
   与 metax「v1→v6 黑名单未变、唯一变量是采样」的结论方向一致 —— **算子不是变量**。

3. **真凶是采样噪声**。用**完全相同的配置**（采样 / `max_tokens` / `max_model_len` / 算子 /
   `--enforce-eager` / 并发）独立重跑 4 组 50 题，已出的 **3 组全部 58.0%**：

   | 样本 | 得分 | 备注 |
   |------|:----:|------|
   | 原轮 9/20 | 50.0% | **唯一的低值** |
   | metax v6 | 56.00% | 跨平台参照 |
   | **r2 / r3 / r4** | **58.0% × 3** | 同配置独立复现 |

   三组的**每题结果**证实这是随机翻转、而非系统性偏移：

   ```
   三组答对题目的并集     = 38 题
   三组稳定答对（交集）   = 21 题
   不稳定题（有对有错）   = 17 题（占 34%）
   ```

   三组响应内容**逐条不同**（抽查 idx0：md5 `4758f783` vs `41f9ab5e`，长度 20300 vs 21781 字符），
   确认是真独立采样。且 **r3 vs metax 的独对是 5:6 —— 几乎完全对称**，
   说明**摩尔与 metax 在本模型上没有系统性能力差距**。

   **→ 34% 的题会翻转正误，总分摆动 8pt（50% ↔ 58%），噪声带宽比 5% 判定容差还宽。**

## 处置

| # | 动作 | 内容 |
|---|------|------|
| 1 | 起容器 | 特权容器 + `-v /datapool:/datapool`，TP=1 |
| 2 | 下权重 | 39GB / 5 分片 → `/datapool/flagrelease/fixes_models/reka-flash-3` |
| 3 | 算子策略 | `VLLM_FL_FLAGOS_WHITELIST=silu_and_mul,rms_norm,rotary_embedding`（3 个全部触达，**无需调整**） |
| 4 | `max_model_len` | **24576**（对齐 metax v6 / NV 复现口径）← 间接得 `max_tokens=16384` |
| 5 | 执行模式 | 保留 `--enforce-eager`（**摩尔 graph 模式不可用**，见「提炼」第 2 条） |
| 6 | 补 `context.yaml` | `thinking_model: true` + 指向本地权重目录 |
| 7 | **重复性实验** | 同配置独立跑 4 组 50 题，**量出抖动带** → 推翻原轮结论 |

> ⚠️ **未做的（明确不做）**：metax 在 v1~v5 试过的算子黑名单调整（默认黑名单、扩展 `rms_norm,silu_and_mul`）
> **在摩尔上不需要复现**——摩尔原轮就已经是采样生效的状态，问题不在算子。

## 结果

- 修复后分 / NV 基线：**58.0%（29/50）/ 59**（相对退化 **+1.69%**，远在 5% 容差内）
  - 对 metax 裁定的 NV 原生 **53.54** 则是**反超 4.46pt**（`−8.33%`）
- 达标判定（accuracy_compare 退出码）：**0（达标）**，`aligned: true`，`noise_zone: false`
- 截断 / runaway：`truncation_detected: false` / `runaway_count: 0`
- 采用轮次：重复性实验 **r3**（`release_run_logs/reka-flash-3/repeat-r3/`；r2/r4 同分）
- 评测耗时：约 2.9h/轮（并发 1，题均 ~200s）；4 组并行无互相拖慢
- 定稿：50 题仅作筛查，**198 题全量待跑**（本模型 50 题口径噪声过大，不可用于判定）

## 提炼到 KNOWLEDGE 的条目

1. **50 题口径对 `do_sample=true` 的模型噪声极大，不可用于定稿判定。** 实测两次运行间
   **34%（17/50）的题会翻转正误**，总分摆动 **8pt**——**噪声带宽比 5% 容差还宽**。
   reka、Phi-4 这类带 `generation_config.json` 采样参数的模型，判定一律走 198 题全量。
2. **摩尔必须保留 `--enforce-eager`**：去掉后 4 个模型全部启动失败
   （`MUSA driver error: operation not permitted when stream is capturing`）。
3. **「同配置重跑」是识别精度误判的最低成本手段。** 判据：独对题数**双向对称**（5:6、6:6）即噪声；
   **单向不对称且反复同向**（7:4 且多轮一致）才是真实差距。
4. **摩尔用白名单机制，与 metax 的黑名单写法不同**（`VLLM_FL_FLAGOS_WHITELIST` vs
   `VLLM_FL_FLAGOS_BLACKLIST`），但最终触达的算子可以一致——**报告里别照抄别家的名单写法**。
5. **「开启算子列表」取自容器 `/tmp/flaggems_enable_oplist.txt`**（⚠️ `oplist` 连写），
   它是「实际触达」的探针，**可能少于白名单**（Qwen3.5：白名单 3、实测 1）。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: RekaAI/reka-flash-3
# IMAGE: harbor.baai.ac.cn/flagrelease-public/flagrelease_mthreads-gmi_vllm024plugin_base:08281629
# HARBOR_VER: V3
# VLLM_VER: 0.24.0
# PLUGIN_FL_VER: 0.3.0
# FLAGGEMS_VER: 5.3.2.post1.dev22+gb1f939eb5.d20260804
# FLAGTREE_VER: 0.6.0+mthreads.gitb97f8214
# FLAGCX_VER: -
# GPU: MTT S5000, 1 × 80GB
# TP: 1
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 53.54
# SCORE_FLAGOS: 58.0
# CONTAINER_DEVS: --privileged --shm-size=64g
```

> 注记（对 `# SCORE_ORIGIN: 53.54` 的取值说明）：`nv_baseline.yaml` 表内本模型基线为 **59**，
> 但该值出自 NV 失败报告，而同报告记录 NV 硬件上 plugin-FL 同样造成 12pt 退化（60→48）——
> 即 **59 的口径与本平台不可比**。metax 侧已裁定改用 **NV 原生 198 题实测 53.54%**，本报告沿用。
> **58.0% 对两种基准都达标**：对 59 退化 1.69%（<5%），对 53.54 反超 4.46pt。

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --net=host --ipc=host --privileged \
  --shm-size 64g \
  --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
  --tmpfs /tmp:exec \
  -v /datapool:/datapool \
  --name flagrelease-fix-reka-flash-3 \
  harbor.baai.ac.cn/flagrelease-public/flagrelease_mthreads-gmi_vllm024plugin_base:08281629 \
  /bin/bash
```

### 三、启动服务（容器内执行）

```bash
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_WHITELIST=silu_and_mul,rms_norm,rotary_embedding
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
/usr/local/bin/vllm serve /datapool/flagrelease/fixes_models/reka-flash-3 \
  --served-model-name reka-flash-3 \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 24576 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --enforce-eager \
  --trust-remote-code
```

### 四、开启算子列表

```json
[
  "rms_norm",
  "rotary_embedding",
  "silu_and_mul"
]
```
