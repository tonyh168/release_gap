# mthreads/LFM2.5-1.2B-Thinking 修复日志

- **失败报告**：flagrelease_fail_reports/Mthreads/FAILED_Mthreads_LFM2.5-1.2B-Thinking_202607151117.md
- **原始失败类型**：精度不达标（rel_drop 超阈值）
- **日期**：2026-09-20

## 现象

模型是 **LFM2 特有的混合 SSM 架构**（`architectures=Lfm2ForCausalLM`，config 带
`conv_L_cache` / `block_*` 卷积块字段），在别的厂商处曾因误配 attention-backend 起不来。
摩尔侧**不指定 `--attention-backend`（走默认）即可**，起服务一次通过：

```
INFO 09-20 14:31:27 Platform plugin fl is activated
INFO 09-20 14:32:01 Application startup complete.          # 起服务 35 秒
```

冒烟：短 prompt ✅ 200，3.74s；长 prompt（2262 token）✅ 200，3.95s。

启动时有一条混合架构特有告警：`Add 2 padding layers, may waste at most 20.00% KV cache memory`
—— 卷积层与注意力层结构不同，vLLM 需补 padding 层对齐。**不影响正确性**，仅 KV 利用率最多损失 20%。

## 定位

**非芯片问题。** 原始「精度不达标」的根因有两条，都是**评测口径**而非算子：

1. **thinking 模型不会被自动识别**：`THINKING_PATTERNS` 里**没有** `lfm2` / `thinking` 关键词，
   而本模型实测输出以 `<think>` 开头。不修则按普通模型贪心评测。
2. **采样参数取值口径**：模型 `generation_config.json` 极简（只有 bos/eos/pad，**无采样字段**）
   → 走 thinking 默认 temp=0.6 / top_p=0.95。仍需 `context.yaml` 让脚本**正确定位模型目录**。

跨厂商已有结论（iluvatar）：该系模型早年低分（GPQA=2.4%）是 **FlagGems 5.0.x 在 LFM 架构上的
系统性精度问题**，新 FlagGems 已修复。本机镜像为 FlagGems **5.3.2.post1.dev22**，**已在该修复之后**。

## 处置

| # | 动作 | 内容 |
|---|------|------|
| 1 | 起容器 | 特权容器 + `-v /datapool:/datapool`，TP=1 |
| 2 | 下权重 | 2.2GB 单文件 → `/datapool/flagrelease/fixes_models/LFM2.5-1.2B-Thinking` |
| 3 | 算子策略 | `VLLM_FL_FLAGOS_WHITELIST=silu_and_mul,rms_norm,rotary_embedding` |
| 4 | attention-backend | **不指定**（走默认；混合 SSM 无需特殊后端） |
| 5 | `max_model_len` | 32768（模型默认 128000，评测无需） |
| 6 | 补 `context.yaml` | `thinking_model: true` + 指向本地权重目录 |
| 7 | 跑评测 | gpqa_diamond 50 题筛查 |

**采样参数生效已二次确认**（评测日志的 `[gen]` 行）：

```
[gen] generation_config.json 无可用采样字段，沿用默认
```

> 脚本**定位到了模型目录**（说明 `context.yaml` 生效）并读到了它的 `generation_config.json`；
> 该文件本就无采样字段 → 按 thinking 默认 temp=0.6 / top_p=0.95 评测，与预期一致。

> 已知坑未复现：iluvatar 记录过 thinking 模型 `message.content` 为 list 导致 `detect_runaway` 崩、
> `score=null` 的问题，**本轮没有触发**，`gpqa_50.json` 的 `score` 直接可读。

## 结果

- 修复后分 / NV 基线：**32.0%（16/50）/ 29.0**（相对退化 **−10.34%**，高于基线 3.0pt）
- 达标判定（accuracy_compare 退出码）：**0（达标）**，`aligned: true`，`noise_zone: false`
- 截断 / runaway：`truncation_detected: false` / `runaway_count: 0`（50/50 全检）
- 评测耗时：探测 88.1s + 评测段 1341s（约 22min，并发 4）；`max_tokens=20000`、`max_model_len=32768`
- **跨平台一致性**：与 iluvatar **逐位相同**（同为 32.0% vs NV 29.0、退出码 0）
- 定稿：50 题仅作筛查，**198 题全量待跑**

## 提炼到 KNOWLEDGE 的条目

1. **混合 SSM 模型（LFM2 系）在摩尔上无需特殊 `--attention-backend`**，走默认即可起服务。
2. **混合 SSM 会触发 `Add N padding layers` 告警**，KV cache 最多浪费 20%——不影响正确性，
   但配合大 `max_model_len` 时要核算显存。
3. **跨平台同配置可复现**：同一模型 + 同一 NV 基线 + 同为 50 题筛查，摩尔与 iluvatar 给出**相同结论**
   ——这类型号可直接照抄配置，不必逐家试错。
4. **容器 `/tmp/flaggems_enable_oplist.txt`（`oplist` 连写）＝「实际触达算子」探针**，
   报告里的「开启算子列表」应从它取，不要照抄白名单。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: LiquidAI/LFM2.5-1.2B-Thinking
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
# SCORE_ORIGIN: 29.0
# SCORE_FLAGOS: 32.0
# CONTAINER_DEVS: --privileged --shm-size=64g
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --net=host --ipc=host --privileged \
  --shm-size 64g \
  --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
  --tmpfs /tmp:exec \
  -v /datapool:/datapool \
  --name flagrelease-fix-LFM2.5-1.2B-Thinking \
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
/usr/local/bin/vllm serve /datapool/flagrelease/fixes_models/LFM2.5-1.2B-Thinking \
  --served-model-name LFM2.5-1.2B-Thinking \
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
  "rms_norm",
  "rotary_embedding",
  "silu_and_mul"
]
```
