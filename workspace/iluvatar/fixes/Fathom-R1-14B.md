# iluvatar/Fathom-R1-14B 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_Fathom-R1-14B_202608211539.md
- **原始失败类型**：精度不达标 + 性能不达标（精度数据为空，性能 V1 mean TTFT=244727ms）
- **日期**：2026-09-16 ~ 2026-09-17（iter1 ~ iter3）
- **最终结论**：❌ **已放弃**（BI-V150 固有性能瓶颈，实测 3.49 tok/s；精度 54.0% 亦不达标）

## 背景分析

V1 有性能数据（mean TTFT=244727ms，极慢），但精度数据为空；V2/V3 同样用 32算子白名单
（与 TinyR1-32B-Preview 完全相同），2个 issue 提交。
精度数据为空可能是评测超时（TTFT 过长导致评测工具超时），也可能是服务虽起但推理异常。
Fathom-R1-14B 为 14B reasoning 模型，**TP=2**（14B bf16 ~28 GB，2 卡共 64 GB）。
权重来源：`FractalAIResearch/Fathom-R1-14B`。

架构（`config.json` 实测）：`Qwen2ForCausalLM` / `qwen2`，48 层，**GQA 40:8**，**非 MoE（dense）**，
`max_position_embeddings=131072`。

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `iluvatar-147`（iter1/iter2）→ `iluvatar-139`（iter3） |
| 容器名 | `flagrelease-fix-fathom-r1-14b` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/Fathom-R1-14B` |
| 卡号 | `CUDA_VISIBLE_DEVICES=0,1`（TP=2）|
| 实际 vLLM 版本 | 0.24.0 |

## Step 0：登录 + 查卡 + 拉取镜像

```bash
ssh iluvatar-139
ixsmi   # 确认至少 2 张卡空闲
docker pull harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope
docker pull harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
```

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
model_name=fathom-r1-14b
docker run -itd --name flagrelease-fix-${model_name} \
  --device=/dev/iluvatar \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  ${IMAGE} bash
docker exec -it flagrelease-fix-${model_name} bash
ixsmi && python -c "import vllm; print(vllm.__version__)"
```

## Step 2：确认模型

权重来源：`FractalAIResearch/Fathom-R1-14B`（ModelScope）

```bash
ls /models/flagrelease/fixes_models/Fathom-R1-14B/
```

若需下载（eval-scope 容器里）：
```bash
docker exec -it eval-scope bash
modelscope download --model FractalAIResearch/Fathom-R1-14B \
  --local_dir /models/flagrelease/fixes_models/Fathom-R1-14B
```

## Step 3：起 vLLM 服务

原报告 V1 TTFT=244727ms（极慢），可能是首次 Triton 编译耗时，也可能是模型推理本身极慢。
本次起服务后先用短 prompt 冒烟，确认推理速度正常，再跑 GPQA 评测。

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=0,1
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
model_name=Fathom-R1-14B
mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} --dtype bfloat16 \
  --tensor-parallel-size 2 --gpu-memory-utilization 0.9 \
  --port 8000 --attention-backend TRITON_MLA \
  --enforce-eager --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log
```

冒烟验证推理延迟：
```bash
model_name=Fathom-R1-14B
curl -s http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"1+1=?"}],"max_tokens":16,"temperature":0}'
# 观察响应时间；若 TTFT 仍 >100s，排查是否 Triton 编译问题（首次编译正常，第二次应很快）
```

| 迭代 | 黑名单 | TP | attention-backend | 端口 | 结果 | 备注 |
|------|--------|-----|------------------|------|------|------|
| 第1次 | sort,sort_stable | 2 | TRITON_MLA | 8002 | ❌ GPQA **54.0%** (NV 60.0%，↓10.0%) | 服务正常起，精度退化 |
| 第2次 | +mm,bmm,addmm,rms_norm,fused_add_rms_norm,softmax,softmax_out,to_copy,copy_,true_divide,pow_scalar,reciprocal,silu,silu_and_mul（共16算子） | 2 | TRITON_ATTN | 8002 | ❌ 中止（50h ETA，3.5 tok/s） | 扩大黑名单，评测全量数据；速度仍 3.5 tok/s，198题预估 50h，2026-09-17 中止 |
| 第3次（iter3） | 同 iter2 | 2 | TRITON_ATTN | 8003 (u139) | ❌ 中止 | 换机器（u139）重试；速度仍 3.5 tok/s，0 bytes output 持续 20min，判定为 BI-V150 固有性能瓶颈，2026-09-17 主动 stop |

## Step 4：评测

Fathom-R1-14B 是 reasoning 模型，GPQA 每题输出可能较长。

```bash
docker exec -it eval-scope bash
cd /workspace/release_评测标准
model_name=Fathom-R1-14B
python3 fast_gpqa.py --model-name ${model_name} --api-base http://127.0.0.1:8000/v1 \
  --output /models/release_run_logs/${model_name}/gpqa.json
python3 accuracy_compare.py --v2 /models/release_run_logs/${model_name}/gpqa.json \
  --nv-baseline ${model_name} --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict.json
```

> 若 `truncation_detected: true` → 加大 `--max-model-len` 后重跑。

| 迭代 | 黑名单 | GPQA | 退出码 | 备注 |
|------|--------|------|--------|------|
| 第1次 | sort,sort_stable | 54.0% | — | 50题小样本；NV 60.0%，↓10.0%，超容差 |
| 第2次 | +16算子 | 评测中止（198题全量） | — | 3.5 tok/s，ETA 50h |
| 第3次 | 同 iter2 | 评测中止 | — | 换机后同样 3.5 tok/s |

## 现象

- V1 报告：mean TTFT=244727ms，精度数据为空，说明服务起了但推理极慢导致评测超时。
- iter1（vLLM 0.24.0，sort,sort_stable 黑名单，TRITON_MLA，TP=2）：服务正常起，
  GPQA 50题得分 **54.0%**（NV 60.0%，↓10.0%），精度退化超过 5% 容差。
- iter2（扩大黑名单至 16 算子，TRITON_ATTN，TP=2）：评测启动后发现生成速度仅 **3.5 tok/s**，
  198题预估 50h，判定不可接受，中途中止。
- iter3（换机 iluvatar-139，端口 8003）：速度仍 3.5 tok/s，0 bytes eval output 持续 20min 以上，
  确认非黑名单/配置问题，主动 stop。

**补充实测（2026-09-19 复核 evalscope 记录）**：

| 指标 | 实测值 |
|------|--------|
| 单请求解码速率（`1/tpot` 中位） | **3.49 tok/s** |
| 输出长度 | 中位 **7636** / 最大 32768 tokens，**仅 1/49 题撞顶** |
| 结论 | **输出长度正常、几乎不复读 → 慢的原因是解码速率本身，不是复读空转** |

## 定位

**根因：BI-V150 对 Fathom-R1-14B（14B reasoning 模型）存在固有性能瓶颈，生成速度仅 3.49 tok/s
（正常应 100+ tok/s）。**

- 黑名单对速度无影响（iter2 → iter3 换机同样 3.5 tok/s）。
- **不是复读造成的**：输出长度中位 7636、仅 1/49 撞顶，属正常范围（与 MiroThinker 的
  "77% 撞顶"型问题性质不同）。
- 精度退化（iter1 54.0% vs NV 60.0%）叠加极低吞吐，双重不达标。
- 具体算子级根因未深入排查（非本 session 目标）。

### ⚠️ 2026-09-19 补充：iter1 的 54.0% 存在**采样口径不对等**

复核模型自带配置发现（与 TinyR1 同类的 `[[fast-gpqa-thinking-detection-bug]]`）：

| 项目 | 实测 |
|------|------|
| chat_template 是否含 `<think>` / `</think>` | **是（两者都有）** → 结构上是 thinking 模型 |
| `generation_config.json` | **不存在** |
| README 推荐的采样参数 | **temperature 0.6 / top_p 0.95**（README 第 129-130 行） |
| `detect_thinking("Fathom-R1-14B")` | **False** —— 模式表匹配的是完整子串 `deepseek-r1`，`fathom-r1` 不命中 |
| 因此实际使用的采样 | **standard 分支：temperature=0.0（贪心）+ top_p=1.0** ❌ |

→ **iter1 的 54.0% 是在贪心解码下测出的，与 NV 基线（按模型推荐采样 0.6/0.95）口径不对等。**
该分数**不能**作为"Fathom 精度不达标"的最终证据。不过——由于本模型的性能瓶颈是**决定性**的
（198 题 ETA 50h，不可接受），**精度结论即使修正也不改变"放弃"的处置**。

### ⚠️ 2026-09-19 补充：与 MiroThinker 同属"慢解码"，但两者机制不同

同期复核 MiroThinker-v1.5-30B 发现它同样只有 ~3.6 tok/s，两台机器、两种架构：

| 模型 | 架构 | 参数量 | 单请求解码速率 | 复读情况 |
|------|------|:------:|:-------------:|---------|
| Fathom-R1-14B | `qwen2`（**dense**，GQA 40:8） | 14B | **3.49 tok/s** | 几乎无（1/49 撞顶） |
| MiroThinker-v1.5-30B | `qwen3_moe`（**MoE**） | 30B | **3.65 tok/s** | 严重（74% 撞顶） |

两者架构不同（dense vs MoE）却落在同一速率区间，**提示根因可能在平台/算子层而非某个模型**，
但本轮未定位到具体算子，**不下结论**。（对比参照：同为 32B dense Qwen2 的 TinyR1 实测 5.06 tok/s，
1.5B GQA 的 OpenReasoning 实测 10.2 tok/s。）

> 注：以上为**各自评测并发下**的单请求 `1/tpot`，并发档位不同（Fathom、MiroThinker 大体在低并发），
> 横向比较只能看数量级，不能当作严格的吞吐基准。

## 处置

iter1–3 均不达标，不再继续迭代。结论：**放弃**，标记 ❌ 精度不达标 + 性能瓶颈待查。

## 结果

- 修复后 GPQA 正确率：iter1 **54.0%**（50题，**贪心解码，口径不对等**）
- NV 基线：**60.0%**
- 相对退化：↓10.0%（超 5% 容差）
- 达标判定：**❌ 不达标**
- 额外问题：生成速度 3.49 tok/s（BI-V150 固有瓶颈），198题评测 ETA 约 50h，不可接受

## 提炼到 KNOWLEDGE 的条目

1. Fathom-R1-14B 在 BI-V150 TP=2 上生成速度仅 **3.49 tok/s**（正常应 100+ tok/s），
   根因待查；与黑名单配置无关，换机复现。**且它的输出长度正常（中位 7636、仅 1/49 撞顶），
   所以不是复读造成的慢** —— 这是与 MiroThinker（74% 撞顶）的关键区别。
2. **`Fathom-R1-14B` 也被 `detect_thinking()` 误判**（名字不命中 `deepseek-r1`），
   iter1 的 54.0% 是贪心解码下测出的，与 NV 基线口径不对等；引用该数字时须带此前提。
3. **慢解码可能是跨模型的平台问题**：14B dense（qwen2）与 30B MoE（qwen3_moe）两种完全不同的架构，
   在两台机器上都落在 ~3.5 tok/s，提示根因在平台/算子层。**遇到了别逐个模型怀疑模型本身。**
