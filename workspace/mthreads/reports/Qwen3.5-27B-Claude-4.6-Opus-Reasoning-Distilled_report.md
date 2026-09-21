# mthreads/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled 修复日志

- **失败报告**：flagrelease_fail_reports/Mthreads/FAILED_Mthreads_Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled_202608020835.md
- **原始失败类型**：未达标（报告只写「未达标」，无细分原因）
- **日期**：2026-09-20

## 现象

模型是 `Qwen3_5ForConditionalGeneration`（`model_type=qwen3_5`）：**稠密**（无任何 expert/moe 字段）、
**多模态**（带 `vision_config` + `image_token_id`，索引里 333 个 vision 张量）、并带 **MTP** 权重。
vLLM 0.24.0 **已原生支持**该架构（`registry.py` 映射到 `qwen3_5`，同目录有 `qwen3_5_mtp.py`）。

起服务需 **2 分 40 秒**（52GB 权重从 LeoFS 加载）：

```
INFO 09-20 14:37:24 Platform plugin fl is activated
INFO 09-20 14:40:04 Application startup complete.
```

冒烟：短 prompt ✅ 200，10.63s；长 prompt（2261 token）✅ 200，23.28s。

## 定位

**非芯片问题，根因是「上下文被卡死」。** 原报告没给细分原因，跨厂商案例把它定位清楚了：

iluvatar 侧（BI-V150，32GB 卡）同模型、同配置跑出 **70.0% vs NV 75 → 不达标**，
但其 `max-model-len` **只有 8192**（`max_tokens` 被压到 4096），被记为「必要约束」而非配置问题。

而本模型的 KV 开销极大：`64 层 × 2(K,V) × 4 kv_heads × 256 head_dim × 2 字节` = **256 KB/token**。
权重 51.75GB、`--gpu-memory-utilization 0.9` 在 80GB 卡上给 73.7GB → **留给 KV 约 20GB**：

| `max_model_len` | KV 需求 | 结论 |
|-----------------|---------|------|
| 32768 | 8.0 GB | ✅ 采用 |
| 65536 | 16.0 GB | ⚠️ 理论可行，余量仅 4GB，偏紧 |
| 262144（模型默认 `max_position_embeddings`） | 64.0 GB | ❌ 远超 |

→ **必须显式给 `--max-model-len 32768`**，不能信模型 config 的 256K。
摩尔单卡 80GB 给了 4 倍于 iluvatar 的上下文，这正是把「不达标」翻成「达标」的变量。

## 处置

| # | 动作 | 内容 |
|---|------|------|
| 1 | 起容器 | 特权容器 + `-v /datapool:/datapool`，TP=1 |
| 2 | 下权重 | 51.75GB / 11 分片 → `/datapool/flagrelease/fixes_models/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled` |
| 3 | **限长** | **显式 `--max-model-len 32768`**（按上表 KV 反算；不加则按 256K 起、KV 装不下） |
| 4 | 算子策略 | `VLLM_FL_FLAGOS_WHITELIST=silu_and_mul,rms_norm,rotary_embedding` |
| 5 | 补 `context.yaml` | `thinking_model: true` + 指向本地权重目录（`THINKING_PATTERNS` **不含** `qwen3.5`） |
| 6 | 跑评测 | gpqa_diamond 50 题筛查（**只测文本路径，图像输入未验证**） |

**采样参数确认**（评测日志的 `[gen]` 行）：

```
[gen] 未找到模型 generation_config.json，沿用默认采样参数
```

→ 模型**本就没有** `generation_config.json`，没有采样参数坑；走 thinking 默认 temp=0.6 / top_p=0.95。

⚠️ **算子覆盖面比白名单窄（实测复核）**：白名单写了 3 个算子，但**实际只有 `silu_and_mul` 触达**
`default.flagos` —— `serve.log` 全程没有 `Op 'rms_norm' using 'default.flagos'` /
`Op 'rotary_embedding' using 'default.flagos'` 两行，容器 `/tmp/flaggems_enable_oplist.txt` 也只有
3 行（另三个模型是 11 行）。结论：该模型的 rms_norm / rotary **绕开了 plugin-FL 的 dispatch 拦截点**。
**本次达标（78% vs 75）就是在这个覆盖面上取得的，无需改动**；但将来若要靠增删算子调精度，
改 `rms_norm`/`rotary_embedding` 是**无效操作**。

## 结果

- 修复后分 / NV 基线：**78.0%（39/50）/ 75**（相对退化 **−4.00%**，高于基线 3.0pt）
- 达标判定（accuracy_compare 退出码）：**0（达标）**，`aligned: true`，`noise_zone: false`
- 截断：`truncation_detected: false`
- runaway：⚠️ **1 个**（index 7，`high_repeat_and_compressible`，`finish_reason=max_tokens`）
  —— 与 iluvatar 同量级（其 1 个在 index 22，**不是同一题**，属采样抖动）
- 评测耗时：探测 77.3s + 评测段 3802s（约 1.06h，并发 4）；`max_tokens=20000`、`max_model_len=32768`
- **与 iluvatar 同模型对照（同为 50 题筛查）**：

| 平台 | `max_model_len` | `max_tokens` | 得分 | 判定 |
|------|:---------------:|:------------:|:----:|:----:|
| iluvatar（BI-V150） | 8192 | 4096 | 70.0% | ❌ 不达标（↓6.67%） |
| **mthreads（S5000）** | **32768** | **20000** | **78.0%** | ✅ **达标（−4.00%）** |

- 定稿：50 题仅作筛查，**198 题全量待跑**

## 提炼到 KNOWLEDGE 的条目

1. **起服务前必须按 KV cache 反算 `--max-model-len`**，不能直接信模型 config 的
   `max_position_embeddings`。公式：`每 token KV = 层数 × 2 × kv_heads × head_dim × dtype 字节`。
   本模型 256 KB/token，256K 上下文需 64GB KV，80GB 卡装不下。
2. **`max_model_len` 是精度变量，不只是显存变量**：同模型同配置，8192 → 70.0%（不达标）、
   32768 → 78.0%（达标），8pt 差距全部来自上下文长度。**跨厂商不要照抄 `max-model-len`。**
3. **算子注册数是 FlagGems 覆盖面的探针**：同一白名单下不同模型实际触达的算子数**真的会不同**
   （Phi-4=3 个、本模型=1 个）。**白名单写了不等于生效**，报告里要按实测写「开启算子列表」。
4. **vLLM 0.24.0 已原生支持 `Qwen3_5ForConditionalGeneration`（含 MTP）**，摩尔镜像可直接起，
   不需要额外适配。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled
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
# SCORE_ORIGIN: 75
# SCORE_FLAGOS: 78.0
# CONTAINER_DEVS: --privileged --shm-size=64g
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --net=host --ipc=host --privileged \
  --shm-size 64g \
  --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
  --tmpfs /tmp:exec \
  -v /datapool:/datapool \
  --name flagrelease-fix-qwen3.5-27b \
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
/usr/local/bin/vllm serve /datapool/flagrelease/fixes_models/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled \
  --served-model-name Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --enforce-eager \
  --trust-remote-code
```

### 四、开启算子列表

```json
[
  "silu_and_mul"
]
```
