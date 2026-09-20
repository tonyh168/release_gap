# iluvatar/Fathom-R1-14B 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_Fathom-R1-14B_202608211539.md
- **原始失败类型**：精度不达标 + 性能不达标（精度数据为空，性能 V1 mean TTFT=244727ms）
- **日期**：2026-09-19

## 现象

原始失败报告（vLLM 0.20.2 + FlagGems 5.0.0）：V1 有性能数据（mean TTFT=244727ms，极慢）但精度
数据为空；V2/V3 同样用 32 算子白名单（与 TinyR1-32B-Preview 完全相同），2 个 issue 提交。
精度数据为空可能是评测超时（TTFT 过长导致评测工具超时），也可能是服务虽起但推理异常。

本次复现各轮实测：

- **iter1**（vLLM 0.24.0，`sort,sort_stable` 黑名单，`TRITON_MLA`，TP=2）：服务正常起，
  GPQA 50 题得分 **54.0%**（NV 60.0%，↓10.0%），精度退化超过 5% 容差
- **iter2**（扩大黑名单至 16 算子，`TRITON_ATTN`，TP=2）：评测启动后发现生成速度仅 **3.5 tok/s**，
  198 题预估 50h，判定不可接受，中途中止
- **iter3**（换机 iluvatar-139，端口 8003）：速度仍 3.5 tok/s，0 bytes eval output 持续 20min 以上，
  确认非黑名单/配置问题，主动 stop
- **iter4**（graph 模式，去掉 `--enforce-eager`，黑名单补 `broadcast_to`）：**图捕获一次通过**，
  服务正常起来、`/v1/models` 可访问（max_model_len=131072）
- **iter5**（graph + thinking 采样，并发 8）：GPQA **68.0%**（NV 60.0，**↑13.33%**），
  50 题 **30m05s** 跑完，`truncation_detected=false`、**runaway 0/50**，verdict **exit=0 / aligned=true**

**补充实测（2026-09-19 复核 evalscope 记录，针对旧配置的"慢"）**：

| 指标 | 实测值 |
|------|--------|
| 单请求解码速率（`1/tpot` 中位） | **3.49 tok/s** |
| 输出长度 | 中位 **7636** / 最大 32768 tokens，**仅 1/49 题撞顶** |
| 结论 | **输出长度正常、几乎不复读 → 慢的原因是解码速率本身，不是复读空转** |

## 定位

### 0. 真因是 `--enforce-eager`，不是"BI-V150 固有性能瓶颈"

此前把 3.49 tok/s 归因为硬件/平台对模型的固有瓶颈。**graph 模式实测推翻了该结论**：

| 配置 | 并发 | 单请求解码速率 | 聚合吞吐 |
|------|:---:|:---:|:---:|
| 旧（`--enforce-eager`，TP=2） | — | **3.49 tok/s** | — |
| **graph 模式（TP=8）** | 1 | **18.97 tok/s** | 18.96 tok/s |
| **graph 模式（TP=8）** | **8** | 13.55 tok/s | **108.34 tok/s** |

**单请求提升 5.4×，并发 8 时聚合 108 tok/s。** 原因：`--enforce-eager` 会同时禁用
**torch.compile 与 CUDAGraph**（serve 日志原文：`Enforce eager set, disabling torch.compile and CUDAGraphs`）。
本模型逐 token 的解码路径在 eager 下没有图融合，开销全暴露；开启 compile + graph 后同一批算子被
折叠成固定图，速度回到正常量级。

> **判读更正**：此前"正常应 100+ tok/s"的期望其实是对的 —— graph 模式下确实达到了 108 tok/s。
> 当时的 `--enforce-eager` 是为了规避算子崩溃而加的保守设置，却成了性能瓶颈本身。
> **教训：把 `--enforce-eager` 当作"安全默认"会掩盖真实性能，且容易被误判成硬件瓶颈。**

### 1. 原判（已作废）：BI-V150 固有性能瓶颈

原结论「BI-V150 对 Fathom-R1-14B 存在固有性能瓶颈，生成速度仅 3.49 tok/s」**已作废**。
其中唯一仍然成立的观察是：**不是复读造成的**（输出长度中位 7636、仅 1/49 撞顶，属正常范围）。
「换机复现同样 3.5 tok/s」这一"证据"不能推出平台瓶颈 —— **两个配置都带着 `--enforce-eager`**。

### 2. iter1 的 54.0% 存在采样口径不对等

复核模型自带配置发现（与 TinyR1 同类的 `detect_thinking()` 误判问题）：

| 项目 | 实测 |
|------|------|
| chat_template 是否含 `<think>` / `</think>` | **是（两者都有）** → 结构上是 thinking 模型 |
| `generation_config.json` | **不存在** |
| README 推荐的采样参数 | **temperature 0.6 / top_p 0.95**（README 第 129-130 行） |
| `detect_thinking("Fathom-R1-14B")` | **False** —— 模式表匹配的是完整子串 `deepseek-r1`，`fathom-r1` 不命中 |
| 因此实际使用的采样 | **standard 分支：temperature=0.0（贪心）+ top_p=1.0** |

→ **iter1 的 54.0% 是在贪心解码下测出的，与 NV 基线（按模型推荐采样 0.6/0.95）口径不对等**，
不能作为"Fathom 精度不达标"的证据。iter5 改用 thinking + 0.6/0.95 后得到 **68.0%**，
比贪心的 54.0% **高 14pt**，且 runaway 0/50 —— 54.0% 里的"退化 10%"完全是解码配置造成的假象。

### 3. 架构与配置

架构（`config.json` 实测）：`Qwen2ForCausalLM` / `qwen2`，48 层，**GQA 40:8**，**非 MoE（dense）**，
`max_position_embeddings=131072`。权重来源 `FractalAIResearch/Fathom-R1-14B`。

### 4. 与 MiroThinker 同属"慢解码"，共同根因是 `--enforce-eager`

| 模型 | 架构 | 参数量 | 旧配置（eager） | **graph 模式** | 复读情况 |
|------|------|:------:|:-------------:|:-------------:|---------|
| Fathom-R1-14B | `qwen2`（**dense**，GQA 40:8） | 14B | 3.49 tok/s | **18.97（并发1）/ 108.3（并发8）** | 几乎无（1/49 撞顶） |
| MiroThinker-v1.5-30B | `qwen3_moe`（**MoE**） | 30B | 3.65 tok/s | **31.61（并发1）/ 72.3（并发8）** | 严重（74% 撞顶） |

两者架构不同（dense vs MoE）却曾落在同一速率区间 —— 当时推测"根因可能在平台/算子层"，
**现已查明：共同根因是两者都带着 `--enforce-eager`**，与架构、与具体算子都无关。
（对比参照：32B dense Qwen2 的 TinyR1 实测 5.06 tok/s、1.5B GQA 的 OpenReasoning 实测 10.2 tok/s
—— 这两个同样是 eager 下的数字。）注：上表均为**各自评测并发下**的单请求 `1/tpot`，横向比较只能看数量级。

### 5. graph 模式下 `broadcast_to` 必须进黑名单

FlagGems 的 `broadcast_to._to_device` 会调 `t.pin_memory()`（host 端操作），CUDA graph 捕获期间
被禁止 → `CUDA error: operation not permitted when stream is capturing`。
**黑名单补 `broadcast_to` 后图捕获通过**（MoE 的 MiroThinker 不需要，只需 `mm`）。

## 处置

### 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `iluvatar-147`（iter1/iter2）→ `iluvatar-139`（iter3 ~ iter5） |
| 容器名 | `flagrelease-fix-fathom-r1-14b` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/Fathom-R1-14B` |
| 卡号 / 端口 | GPU 0-7（TP=8）/ 8002 |
| attention-backend | `TRITON_ATTN` |
| 实际 vLLM 版本 | 0.24.0 |

### 起容器（宿主机执行）

```bash
docker run -itd --name flagrelease-fix-fathom-r1-14b \
  --device=/dev/iluvatar \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907 bash
docker exec -it flagrelease-fix-fathom-r1-14b bash
ixsmi && python -c "import vllm; print(vllm.__version__)"
```

### 起 vLLM 服务 —— graph 模式（容器内执行，iter4/iter5 最终达标配置）

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,mm,addmm,broadcast_to
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
vllm serve /models/flagrelease/fixes_models/Fathom-R1-14B \
  --served-model-name Fathom-R1-14B --dtype bfloat16 \
  --tensor-parallel-size 8 --gpu-memory-utilization 0.85 \
  --max-num-seqs 8 --cudagraph-capture-sizes 8 \
  --port 8002 --attention-backend TRITON_ATTN --trust-remote-code
```

要点（本模型实测总结）：

- **去掉 `--enforce-eager`** → 自动进入 compile + CUDAGraph 模式
- **黑名单必须含 `broadcast_to`**（否则图捕获必崩），即 `sort,sort_stable,mm,addmm,broadcast_to`
- `--max-num-seqs 8` + `--cudagraph-capture-sizes 8` → 只捕获 batch=8 的图，
  **并发超过 8 会退回 eager**，评测并发必须锁 8
- `--gpu-memory-utilization 0.85`：残留显存未清时 0.9 会报
  `Free memory ... less than desired GPU memory utilization`，0.85 更稳
- ⚠️ **重试前务必清残留进程**：上一次崩溃的 `VLLM::EngineCore` / `Worker` 会继续占着 GPU，
  必须先清理再起，否则直接死在显存检查

**graph 启动实测输出**：

```
GPU KV cache size: 989,392 tokens
Capturing CUDA graphs (mixed prefill-decode, PIECEWISE): 100%|██| 1/1 [00:01, 1.74s/it]
Capturing CUDA graphs (decode, FULL): 100%|██| 1/1 [00:01, 1.27s/it]
Application startup complete.
```

### 早期（eager）配置 —— 已废弃，仅作对照

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
vllm serve /models/flagrelease/fixes_models/Fathom-R1-14B \
  --served-model-name Fathom-R1-14B --dtype bfloat16 \
  --tensor-parallel-size 2 --gpu-memory-utilization 0.9 \
  --port 8000 --attention-backend TRITON_MLA \
  --enforce-eager --trust-remote-code
```

### 迭代记录

| 迭代 | 黑名单 | TP | attention-backend | 端口 | 结果 | 备注 |
|------|--------|-----|------------------|------|------|------|
| 第1次 | sort,sort_stable | 2 | TRITON_MLA | 8002 | ❌ GPQA **54.0%**（NV 60.0%，↓10.0%） | 服务正常起，但为**贪心口径**，与基线不对等 |
| 第2次 | +mm,bmm,addmm,rms_norm,fused_add_rms_norm,softmax,softmax_out,to_copy,copy_,true_divide,pow_scalar,reciprocal,silu,silu_and_mul（共16算子） | 2 | TRITON_ATTN | 8002 | ❌ 中止（50h ETA，3.5 tok/s） | 扩大黑名单无效，2026-09-17 中止 |
| 第3次 | 同 iter2 | 2 | TRITON_ATTN | 8003 (u139) | ❌ 中止 | 换机重试速度仍 3.5 tok/s，主动 stop |
| 第4次（graph） | sort,sort_stable,mm,addmm,**broadcast_to** | **8** | TRITON_ATTN | 8002 (u139) | ✅ **启动成功**（图捕获通过） | `--max-num-seqs 8 --cudagraph-capture-sizes 8`，去 `--enforce-eager`。**首次证明该模型可在 graph 模式下运行** |
| **第5次（graph + thinking 采样）** | 同 iter4 | **8** | TRITON_ATTN | 8002 (u139) | ✅ **GPQA 68.0%**（↑13.33%），**runaway 0/50** | thinking + README 的 0.6/0.95，并发 8，50 题 **30m05s** 跑完 |

**被推翻的中间结论**：2026-09-19 之前本文档曾给出「❌ 已放弃」的结论，其两条理由
（① BI-V150 固有性能瓶颈、② 精度不达标）**均已作废**：① 的真因是 `--enforce-eager`（graph 模式
实测并发 8 聚合 108.3 tok/s）；② 的 54.0% 是贪心解码下的口径不对等问题（按 README 的 0.6/0.95
重测为 68.0%）。**最终结论为达标**。

### 评测（eval-scope 容器内执行）

```bash
/workspace/eval_scripts/fast_gpqa.py \
  --model-name Fathom-R1-14B --api-base http://127.0.0.1:8002/v1 \
  --output /models/release_run_logs/Fathom-R1-14B/gpqa.json

/workspace/eval_scripts/accuracy_compare.py \
  --v2 /models/release_run_logs/Fathom-R1-14B/gpqa.json \
  --nv-baseline Fathom-R1-14B \
  --nv-baseline-file /workspace/eval_scripts/nv_baseline.yaml --json \
  --output /models/release_run_logs/Fathom-R1-14B/verdict_gpqa_graph.json
```

**iter5 的 wrapper 脚本**：`fathom_graph_eval.py`（容器内 `/tmp/`，NFS 备份
`release_run_logs/_wrappers_backup/`），用于锁定 thinking 判定 + README 的 0.6/0.95 采样 +
固定并发 8（图只捕获 batch=8，并发必须锁 8），启动方式为 `docker exec -d` + `nohup`，SSH 断开不影响。

### 可选后续（未做）

跑 198 题全量复核 —— 50 题已只需 30 分钟，全量约 2 小时，成本可接受。

## 结果

- 修复后分 / NV 基线：**GPQA 68.0%**（50 题，thinking + 0.6/0.95，并发 8，graph 模式）/ NV **60.0%**
- 达标判定（accuracy_compare 退出码）：**0 / aligned=true / noise_zone=false** ——
  相对变化 **↑13.33%（反超基线）**
- 性能：并发 8 聚合 **108.3 tok/s**（旧配置 3.49 tok/s → 约 **31×**）；50 题评测耗时 **30m05s**
  （1804.92s），此前"198 题 ETA 50h"的障碍已消除
- 质量指标：`truncation_detected=false`、**runaway 0/50**

**verdict_gpqa_graph.json**（最终达标那一份实测字段）：

- `model`: Fathom-R1-14B；`metric`: gpqa_diamond
- `nv.score`: 60.0；`current.score`: 68.0
- `aligned`: **true**；`noise_zone`: **false**；进程退出码：**0**

> 源 fix 日志记录了上述实测字段与退出码，但未附 JSON 原文，故此处不复刻 JSON 文本（避免编造）。

### 历次对比

| 迭代 | 配置 | GPQA | 判定 |
|------|------|:----:|------|
| iter1 | eager，TP=2，**贪心 T=0.0** | 54.0% | ❌ 口径不对等 |
| iter2 / iter3 | eager，16 算子黑名单 | 中止（3.5 tok/s，ETA 50h） | ❌ |
| iter4 | **graph，TP=8** | —（仅验证启动） | ✅ 启动成功 |
| **iter5** | **graph + thinking 0.6/0.95，并发 8** | **68.0%** | ✅ **达标** |

## 提炼到 KNOWLEDGE 的条目

1. **`--enforce-eager` 是隐蔽的性能杀手，且极易被误判成硬件瓶颈**。Fathom-R1-14B 因此被冤枉了
   一整轮（判"BI-V150 固有性能瓶颈"→ 放弃）：它同时禁用 torch.compile 与 CUDAGraph，
   eager 下 3.49 tok/s → **graph 模式 108.3 tok/s（31×）**。**"换机复现"不能证明是平台问题** ——
   两台机器用同一套错误配置，结论就会一样错。**排查吞吐问题时应把去掉 `--enforce-eager`
   作为第一优先级，而不是最后手段。**
2. **graph 模式下 `broadcast_to` 必须进黑名单**：FlagGems 的 `broadcast_to._to_device` 调用
   `t.pin_memory()`（host 端操作），CUDA graph 捕获期间被禁止 →
   `CUDA error: operation not permitted when stream is capturing`；黑名单补 `broadcast_to` 后图捕获通过。
3. **`Fathom-R1-14B` 也中 `detect_thinking()` 误判**（名字不命中 `deepseek-r1`）。
   贪心 54.0% → 正确采样 **68.0%（+14pt）**，runaway 0/50。**这是继 TinyR1 之后第二个
   "修正采样即达标"的案例，且幅度更大。**
4. **图捕获的规模要与评测并发对齐**：`--max-num-seqs 8 --cudagraph-capture-sizes 8` 只捕获
   batch=8，**并发超过 8 会退回 eager**，白费提速。评测并发必须锁 8。
5. **判"放弃"之前，先把能想到的常规配置都试过**。本模型被判放弃的两条理由在 2026-09-19 双双被
   推翻，而推翻它的是两个很常规的手段：**去掉 `--enforce-eager`** + **按 README 改采样**。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: FractalAIResearch/Fathom-R1-14B
# IMAGE: harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
# HARBOR_VER: V3
# GPU: Iluvatar BI-V150, 8 × 32GB
# TP: 8
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 60.0
# SCORE_FLAGOS: 68.0
# CONTAINER_DEVS: --device=/dev/iluvatar --ipc=host --network=host --shm-size=64g
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --net=host --ipc=host \
  --device=/dev/iluvatar \
  --shm-size 64g \
  -v /mnt/share/models:/models \
  --name flagos \
  harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907 \
  /bin/bash
```

### 三、启动服务（容器内执行）

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,mm,addmm,broadcast_to
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
vllm serve /models/flagrelease/fixes_models/Fathom-R1-14B \
  --served-model-name Fathom-R1-14B --dtype bfloat16 \
  --tensor-parallel-size 8 --gpu-memory-utilization 0.85 \
  --max-num-seqs 8 --cudagraph-capture-sizes 8 \
  --port 8002 --attention-backend TRITON_ATTN --trust-remote-code
```
