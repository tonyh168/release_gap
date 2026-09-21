# mthreads/Phi-4-reasoning-plus 修复日志

- **失败报告**：flagrelease_fail_reports/Mthreads/FAILED_Mthreads_Phi-4-reasoning-plus_202608011354.md
- **原始失败类型**：容器准备未完成（流程会话中断）→ **从未真正评测过**
- **日期**：2026-09-20

## 现象

原始失败报告结论是**流程侧中断**（会话在服务启动前因 API 流式卡顿断掉），
不是芯片不兼容——该模型在摩尔上**从未产出过任何评测分数**。

本次按 SOP 重跑，起服务**一次通过**，未做 SOP 之外的调整：

```
INFO 09-20 14:06:00 Available plugins for group vllm.platform_plugins: fl -> vllm_fl:register
INFO 09-20 14:06:00 Platform plugin fl is activated
INFO 09-20 14:07:03 Application startup complete.          # 起服务 63 秒
```

冒烟：短 prompt ✅ 200；长 prompt（14.9KB ≈ 6k token）✅ 200，9.55s。

## 定位

**非芯片问题，纯流程中断。** 真正需要处理的是 plugin-FL 评测口径上的两处坑，
与「服务能不能起」无关：

1. **thinking 模型不会被自动识别**。`fast_gpqa.py` 的 `THINKING_PATTERNS` 里
   **没有** `phi-4-reasoning` / `reasoning-plus` 关键词，而本模型实测输出带 `<think>`。
   不修则按普通模型贪心评测。
2. **采样参数会被静默忽略**。模型 `generation_config.json` 声明
   `do_sample=true, temperature=0.8, top_p=0.95, top_k=50`；标准流程传的是 NV key（非本地路径），
   容器内又没有 `context.yaml` → 脚本定位不到模型目录 → **静默退回贪心 temp=0.0**。

另有一处平台级约束（与模型无关）：**摩尔 graph 模式不可用**——去掉 `--enforce-eager`
后 4 个模型全部启动失败，报 `MUSA driver error: operation not permitted when stream is capturing`。
metax「graph 快 10 倍」的经验在摩尔不适用。

启动日志另出现 4 条**非致命**告警（`Unknown vLLM environment variable: VLLM_FL_FLAGOS_WHITELIST`、
`Cannot re-initialize MUSA in forked subprocess`、两条 MoE 补丁告警），均已确认不影响启动与精度。

## 处置

| # | 动作 | 内容 |
|---|------|------|
| 1 | 起容器 | 特权容器 + `-v /datapool:/datapool`，TP=1 |
| 2 | 下权重 | 28GB / 6 分片 → `/datapool/flagrelease/fixes_models/Phi-4-reasoning-plus` |
| 3 | 收窄算子 | `VLLM_FL_FLAGOS_WHITELIST=silu_and_mul,rms_norm,rotary_embedding`（对齐 t-head/phi-4 的最小白名单） |
| 4 | 执行模式 | 保留 `--enforce-eager`（graph 实测不可用，见上） |
| 5 | 补 `context.yaml` | `thinking_model: true` + 指向本地权重目录 → 让**采样参数与 thinking 判定同时生效** |
| 6 | 跑评测 | gpqa_diamond 50 题筛查 |

**采样参数生效已二次确认**（评测日志的 `[gen]` 行）：

```
[gen] 采用模型 generation_config.json 采样参数: {'temperature': 0.8, 'top_p': 0.95, 'top_k': 50}
```

> 未做的 A/B：metax（Phi-4-mini，GQA）认为 `rms_norm`/`silu_and_mul` 走 FlagGems 是精度退化根因，
> t-head（phi-4 同架构）却把它们留在白名单里成绩最好——**两家结论相反**。
> 本轮在「留在白名单」的这一侧**直接达标（+12pt）**，故**不做**该 A/B。

## 结果

- 修复后分 / NV 基线：**58.0%（29/50）/ 46**（相对退化 **−26.09%**，高于基线 12.0pt）
- 达标判定（accuracy_compare 退出码）：**0（达标）**，`aligned: true`，`noise_zone: false`
- 截断 / runaway：`truncation_detected: false` / `runaway_count: 0`（50/50 全检）
- 评测耗时：评测段 11448s（约 3.2h，并发 16）；`max_tokens=20000`、`max_model_len=32768`
- 定稿：50 题仅作筛查，**198 题全量待跑**

## 提炼到 KNOWLEDGE 的条目

1. **`THINKING_PATTERNS` 覆盖不全**：`Phi-4-reasoning-plus`、`Magistral` 这类名字里不含已知关键词的
   reasoning 模型不会被自动识别，必须靠 `context.yaml` 的 `thinking_model: true` 显式标记。
2. **摩尔必须保留 `--enforce-eager`**（与其他厂商相反）：MUSA 驱动不允许在 stream capture 期间分配显存，
   去掉后 4 个模型全部启动失败。
3. **容器 `/tmp/flaggems_enable_oplist.txt`（注意 `oplist` 连写）是「实际触达算子」的探针**，
   比白名单本身更有信息量——报告里的「开启算子列表」应从它取，不要照抄白名单。
4. 摩尔 `VLLM_FL_FLAGOS_WHITELIST` 会触发 vLLM 的 "Unknown environment variable" 告警，但**实际生效**。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: microsoft/Phi-4-reasoning-plus
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
# METRIC: GPQA_Diamond
# SCORE_ORIGIN: 46
# SCORE_FLAGOS: 58.0
# CONTAINER_DEVS: --privileged --shm-size=64g
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --net=host --ipc=host --privileged \
  --shm-size 64g \
  --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
  --tmpfs /tmp:exec \
  -v /datapool:/datapool \
  --name flagrelease-fix-phi-4-reasoning-plus \
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
/usr/local/bin/vllm serve /datapool/flagrelease/fixes_models/Phi-4-reasoning-plus \
  --served-model-name Phi-4-reasoning-plus \
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
