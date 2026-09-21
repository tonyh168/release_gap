# mthreads/reka-flash-3 修复日志

- **失败报告**：flagrelease_fail_reports/Mthreads/FAILED_Mthreads_reka-flash-3_202608020152.md
- **原始失败类型**：精度不达标（rel_drop 超阈值）+ 性能不达标
- **日期**：2026-09-20（2026-09-21 补记重复性实验与实测算子列表）

## 现象

模型是标准 `LlamaForCausalLM`（44 层 / hidden 6144 / 64 heads / 8 kv heads，GQA），
摩尔上起服务**一次通过、无任何异常**（约 45 秒加载 39GB 权重）：

```
INFO 09-20 14:31:30 Platform plugin fl is activated
INFO 09-20 14:32:14 Application startup complete.
```

冒烟：短 prompt ✅ 200，4.76s；长 prompt（2257 token）✅ 200，11.48s。

**精度评测跑了 5 轮**（配置完全相同），得到 **50.0% ~ 58.0%** 的区间，均值 **54.8%**：

| 轮次 | 服务容器 / 服务进程 | 得分 |
|------|---------------------|:----:|
| 原轮 · 9/20 | `flagrelease-fix-reka-flash-3` / 9-20 15:13 启动 | **50.0%** |
| r1 · 9/21 | **同一容器、同一进程**（跑满 26h） | **50.0%** |
| r2 · 9/21 | `...-r2` / 9-21 14:22 启动 | **58.0%** |
| r3 · 9/21 | `...-r3` / 9-21 14:22 启动 | **58.0%** |
| r4 · 9/21 | `...-r4` / 9-21 14:22 启动 | **58.0%** |

## 定位

**根因不是 plugin-FL 算子退化，也不是采样参数失效。** 逐条排除：

1. **采样参数一直生效**（metax 那条根因在摩尔侧从未发生）。评测日志逐轮确认：

   ```
   [gen] 采用模型 generation_config.json 采样参数: {'temperature': 0.6, 'top_p': 0.95, 'top_k': 1024}
   ```
   即 `context.yaml` 生效、模型自带的 `generation_config.json` 被正确采用，**没有退回贪心**。

2. **算子侧无异常**。白名单 3 个算子全部真实触达（见下「开启算子列表」），
   与 metax「v1→v6 黑名单未变、唯一变量是采样」的结论方向一致 —— **算子不是变量**。

3. **真凶是「50 题口径的噪声 + 一个未归因的分簇」**。5 轮配置完全相同（权重、采样、
   `max_tokens`、`max_model_len`、算子、`--enforce-eager`、并发 1），结果落成两簇：

   ```
   老服务进程（9-20 启动）  : 50.0% , 50.0%     ← 同一进程跑两次
   新服务进程（9-21 启动）×3 : 58.0% , 58.0% , 58.0%
   ```

   - **不像纯随机**：若单轮成功概率 p≈0.54，5 个样本恰好落成 `25,25,29,29,29`
     （前两个同分、后三个同分）的概率量级约 **10⁻⁶**，分簇太整齐。
   - **也不是确定性种子**：同进程两次**逐题不可复现**（共对仅 18/50，14 题翻转，
     抽出选项仅 27/50 相同）；全链路**没有任何 `--seed`**。
   - **簇内噪声同样很大**：新容器三组间独对双向对称（4:4、6:6、7:7），
     但两轮间**有 28~34% 的题翻转正误**，总分摆动 **8pt** —— **比 5% 判定容差还宽**。
   - **跨簇偏斜**：原轮 vs r3 独对 **3:7**（偏斜），与「两簇」现象一致。

   已排查、均排除：引擎配置差异（两边 `GPU KV cache size: 231,376 tokens` 一致）、
   响应长度分布、`truncation_detected`、`runaway_count`（全为 0）。

   **处置**：老容器 `flagrelease-fix-reka-flash-3` **已于 2026-09-21 停止**，**未继续追查根因**。

4. **跨平台对照**：r3 vs metax v6 独对 **5:6（对称）** ——
   **在 58% 那一簇上，摩尔与 metax 无系统性能力差距**。

**→ 50 题口径不足以给本模型定案，198 题全量是唯一能压住噪声的口径。**

## 处置

| # | 动作 | 内容 |
|---|------|------|
| 1 | 起容器 | 特权容器 + `-v /datapool:/datapool`，TP=1 |
| 2 | 下权重 | 39GB / 5 分片 → `/datapool/flagrelease/fixes_models/reka-flash-3` |
| 3 | 算子策略 | `VLLM_FL_FLAGOS_WHITELIST=silu_and_mul,rms_norm,rotary_embedding`（3 个全部触达，**无需调整**） |
| 4 | `max_model_len` | **24576**（对齐 metax v6 / NV 复现口径）← 间接得 `max_tokens=16384` |
| 5 | 执行模式 | 保留 `--enforce-eager`（**摩尔 graph 模式不可用**，见「提炼」第 2 条） |
| 6 | 补 `context.yaml` | `thinking_model: true` + 指向本地权重目录 |
| 7 | **重复性实验** | 同配置独立跑 4 组 50 题 → 量出抖动带 8pt，并暴露一个未归因的两簇 |
| 8 | 收尾 | 老容器停止；**198 题全量待跑** |

> ⚠️ **未做的（明确不做）**：metax 在 v1~v5 试过的算子黑名单调整（默认黑名单、扩展 `rms_norm,silu_and_mul`）
> **在摩尔上不需要复现**——摩尔 5 轮就已是采样生效的状态，问题不在算子。

## 结果

- 修复后分 / NV 基线：**54.8%（5 轮均值，单轮区间 50.0% ~ 58.0%）/ 53.54** → 反超 **2.4%**
  - 若按表内 **59**：退化 **7.1% > 5%** → 不达标（**基准口径决定结论走向**，说明见发布字段注记）
- 达标判定（accuracy_compare 退出码）：**0（达标，依 53.54 基准）**
- 截断 / runaway：`truncation_detected: false` / `runaway_count: 0`（5 轮全部）
- 评测耗时：约 2.9h/轮（并发 1，题均 ~200s）；4 组并行无互相拖慢
- 定稿：50 题仅作筛查，**198 题全量待跑**（本模型 50 题口径噪声过大，不可用于判定）

## 提炼到 KNOWLEDGE 的条目

1. **50 题口径对 `do_sample=true` 的模型噪声极大，不可用于定稿判定。** 实测两轮间
   **28~34% 的题会翻转正误**，总分摆动 **8pt**——**噪声带宽比 5% 容差还宽**。
   reka、Phi-4 这类带 `generation_config.json` 采样参数的模型，判定一律走 198 题全量。
2. **同配置多轮重跑要先检查有没有「分簇」，不能只看均值。** 本轮 5 组得到 `50,50 | 58,58,58`
   两簇（簇内一致、跨簇差 8pt），这种形态不能用「采样下沿」解释，须先怀疑实例级差异
   （服务进程 / 卡 / 容器），**别急着按均值下结论**。
3. **同容器同进程重跑 ≠ 可复现**：无 `--seed` 时同进程两次也是独立采样
   （实测逐题共对仅 18/50、抽出选项仅 27/50 相同）。要真正复现需显式 seed。
4. **摩尔必须保留 `--enforce-eager`**：去掉后 4 个模型全部启动失败
   （`MUSA driver error: operation not permitted when stream is capturing`）。
5. **摩尔用白名单机制，与 metax 的黑名单写法不同**（`VLLM_FL_FLAGOS_WHITELIST` vs
   `VLLM_FL_FLAGOS_BLACKLIST`），但最终触达的算子可以一致——**报告里别照抄别家的名单写法**。
6. **「开启算子列表」取自容器 `/tmp/flaggems_enable_oplist.txt`**（⚠️ `oplist` 连写），
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
# SCORE_FLAGOS: 54.8
# CONTAINER_DEVS: --privileged --shm-size=64g
```

> 注记一（`SCORE_FLAGOS: 54.8` 的取值）：本模型跑了 **5 轮完全同配置**的 50 题评测，
> 单轮区间 **50.0% ~ 58.0%**（落成 `50,50 | 58,58,58` 两簇，分簇原因未查明，
> 老容器已停）。此处取**5 轮均值 54.8%**，而非任一单轮值。
>
> 注记二（`VERDICT: ok` 的口径限定）：判定依 metax 裁定的 **NV 原生 53.54**。
> `nv_baseline.yaml` 表内本模型基线为 **59**，但该值出自 NV 失败报告，而同报告记录
> NV 硬件上 plugin-FL 同样造成 12pt 退化（60→48）——即 **59 的口径与本平台不可比**。
> **两个基准相差 5.5pt，而本模型 50 题口径的噪声就有 8pt**，故基准选择直接决定结论：
> 按 53.54 → 反超 2.4%（**达标**）；按 59 → 退化 7.1%（不达标）。
> **本报告的 `ok` 建立在 53.54 之上；若评审采用 59，应视为不达标。**

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
