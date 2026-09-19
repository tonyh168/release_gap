# iluvatar/Phi-4-mini-reasoning 修复日志

- **失败报告**：新增模型（STATUS.md 补录，无历史失败报告）
- **原始失败类型**：未开始（后补评测对象）
- **日期**：2026-09-16 ~ 2026-09-19（iter1 ~ iter4）
- **最终结论**：❌ **不达标**（math_500 **62.0%** vs NV 88.2%，rel_drop **29.71%**；`verdict_math500_iter4.json` 实测 exit=1）
  —— ⚠️ **两项修复都已实测**：`max-model-len` 截断修复 ✅ 有效（+18.5pt）、
  **README 采样修复 ✅ 也有效但只 +2.5pt**。**两项加起来仍差 29.71%，剩余差距无法用截断或采样解释。**

## 背景分析

Phi-4-mini-reasoning 为 Microsoft Phi-4 系列推理小模型，约 3.8B 参数，decoder-only（Phi-4 MHA）。
bf16 约 7.6 GB，单卡 32 GB 足够，TP=1。
评测指标为 mmlu + math_500（nv_baseline 无 gpqa_diamond 条目）。
NV 基线：mmlu=72.83，math_500=88.2。

模型方 README（第 141-145 行的官方示例）给出的**官方生成配置**：

```python
max_new_tokens=32768, temperature=0.8, top_p=0.95, do_sample=True
```

它是从 **DeepSeek-R1** 蒸馏的数学推理模型（README 第 169 行），
但 chat_template **不含 `<think>` / `</think>`**（与 TinyR1 / MiroThinker 的结构不同），
其 `generation_config.json` 也无 temperature 字段。

## 环境

| 项目 | 值 |
|------|----|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-phi4-mini-reasoning` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/Phi-4-mini-reasoning` |
| 卡号 | **GPU 9**（`CUDA_VISIBLE_DEVICES=9`，TP=1） |
| 端口 | 8012 |
| 实际 vLLM 版本 | 0.24.0（FlagGems 5.3.4.post1） |
| 算子黑名单 | `sort,sort_stable`（三轮未变） |

## Step 0：登录 + 查卡

```bash
ssh iluvatar-139
/usr/local/corex-4.5.0/bin/ixsmi
docker ps --format '{{.Names}}\t{{.Status}}'
```

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
model_name=phi4-mini-reasoning
docker run -itd --name flagrelease-fix-${model_name} \
  --device=/dev/iluvatar0  --device=/dev/iluvatar1  --device=/dev/iluvatar2  --device=/dev/iluvatar3 \
  --device=/dev/iluvatar4  --device=/dev/iluvatar5  --device=/dev/iluvatar6  --device=/dev/iluvatar7 \
  --device=/dev/iluvatar8  --device=/dev/iluvatar9  --device=/dev/iluvatar10 --device=/dev/iluvatar11 \
  --device=/dev/iluvatar12 --device=/dev/iluvatar13 --device=/dev/iluvatar14 --device=/dev/iluvatar15 \
  --device=/dev/itrctl --device=/dev/itrlink --device=/dev/itr_peerm_dev0 \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  ${IMAGE} bash
```

## Step 2：确认模型权重

```bash
ls /models/flagrelease/fixes_models/Phi-4-mini-reasoning/
```

**权重来源（2026-09-18 改）**：改用 **HuggingFace 官方仓库** `microsoft/Phi-4-mini-reasoning`
（<https://huggingface.co/microsoft/Phi-4-mini-reasoning>）。此前那份是从 ModelScope 下的，
因怀疑权重有问题已于 2026-09-18 删除，改从 HF 重新下载。

> HF 上该仓库非 gated，许可 MIT。模型共 2 个分片 + index。

**下载路径（一律用 HF 官方 repo id，与 URL 一致）**：

| 项 | 值 |
|----|----|
| HF 页面 | <https://huggingface.co/microsoft/Phi-4-mini-reasoning> |
| repo id | `microsoft/Phi-4-mini-reasoning` |
| 本地目录 | `/models/flagrelease/fixes_models/Phi-4-mini-reasoning` |

下载（在 **eval-scope 容器内**执行）：

```bash
docker exec -it eval-scope bash

# ⚠️ 本集群直连 huggingface.co 不通（curl 15s 超时），必须设镜像，否则下载必失败
export HF_ENDPOINT=https://hf-mirror.com

# 方式一：hf（huggingface_hub 1.x 的当前命令；容器内已装 1.31.0）
hf download microsoft/Phi-4-mini-reasoning \
  --local-dir /models/flagrelease/fixes_models/Phi-4-mini-reasoning

# 方式二：huggingface-cli（旧命令，仍可用，会提示 deprecated）
# huggingface-cli download microsoft/Phi-4-mini-reasoning \
#   --local-dir /models/flagrelease/fixes_models/Phi-4-mini-reasoning
```

**下载后校验**（避免再次拿到可疑权重）——文件大小应与 HF 上游一致：

| 文件 | 大小（bytes） | sha256 |
|------|--------------|--------|
| `model-00001-of-00002.safetensors` | 4903637712 | `a0c24f128e33afb9e406915229af56171e0a2353bc78c1ea1b5260a36b3e6707` |
| `model-00002-of-00002.safetensors` | 2768428504 | `b4bfcc826b3c637333c6bd24b0dfe38fffd45eff7f4718df454366e875a12415` |

```bash
cd /models/flagrelease/fixes_models/Phi-4-mini-reasoning
ls -l model-0000*-of-00002.safetensors                     # 应为上表两个大小
sha256sum model-0000*-of-00002.safetensors                 # 应与上表一致
```

> **2026-09-18 实测校验结果：✅ 两个分片均完全一致。**
> 从 HF 重新下载后 `sha256sum` 输出
> `a0c24f128e33afb9e406915229af56171e0a2353bc78c1ea1b5260a36b3e6707`（00001）与
> `b4bfcc826b3c637333c6bd24b0dfe38fffd45eff7f4718df454366e875a12415`（00002），均与上游一致；
> 大小也与被删除的那份旧权重逐字节相同。
> **结论：权重不是低分的原因**，此前"权重损坏"的怀疑已排除，勿再重复换权重。

> 环境要求：模型卡标注需 `transformers==4.51.3`（或更高版本支持），
> 参考依赖 `torch==2.5.1` / `accelerate==1.3.0`；推理时如遇异常可设
> `attn_implementation="eager"`。镜像内实际版本以 `pip list | grep transformers` 为准。
>
> `HF_ENDPOINT` 说明：`https://hf-mirror.com` 是国内常用的 HuggingFace 镜像站，
> 设了它之后 `hf` / `huggingface-cli` 的请求走镜像域名，**repo id 不用改**。
> 已验证：本集群 `hf-mirror.com` 可达（HTTP 307），`huggingface.co` 直连超时。

## Step 3：起 vLLM 服务

⚠️ **必须显式指定 `--max-model-len`**（见下方「定位」的推导缺陷）：

```bash
docker exec -d flagrelease-fix-phi4-mini-reasoning bash -c "
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=9
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
model_name=Phi-4-mini-reasoning
mkdir -p /models/release_run_logs/\${model_name}
vllm serve /models/flagrelease/fixes_models/\${model_name} \
  --served-model-name \${model_name} --dtype bfloat16 \
  --tensor-parallel-size 1 --gpu-memory-utilization 0.9 \
  --max-model-len 32768 \
  --port 8012 --attention-backend TRITON_ATTN \
  --enforce-eager --trust-remote-code \
  2>&1 | tee /models/release_run_logs/\${model_name}/serve.log
"
```

若 crash → 抓算子名追加黑名单：
```bash
grep -E "Error|crash|Traceback|RuntimeError|NotImplemented" \
  /models/release_run_logs/Phi-4-mini-reasoning/serve.log | tail -20
```

| 迭代 | `--max-model-len` | 并发 | 结果 | 备注 |
|------|:----------------:|:----:|------|------|
| 第1次 | **未指定**（vLLM 推导成 4096） | 16 | ❌ mmlu 58.07% + math_500 41.0% | 间接导致 `max_tokens=2048`，两轮分数均无效（见「定位」） |
| 第2次 | 32768 | 16 | ❌ 中止 | 显式指定后重测，c16 未跑完即中止 |
| 第2次（改） | 32768 | **32** | ❌ 服务被打崩 | KV cache 仅 160,353 tokens，32 并发严重超配 → KV 100%、Waiting 排队、38 分钟 1 题 |
| 第3次 | 32768 | **8** | ❌ math_500 **59.5%**（NV 88.2，↓32.54%） | 当前最新结果；采样仍为 standard 贪心 |

## Step 4：smoke test

```bash
model_name=Phi-4-mini-reasoning
curl -s http://localhost:8012/v1/models
curl -s http://localhost:8012/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"What is 2+2?"}],"max_tokens":64,"temperature":0}'
```

## Step 5：评测

评测指标为 mmlu + math_500（无 gpqa_diamond 基线）。

```bash
docker exec -d eval-scope bash -c "
cd /workspace/eval_scripts
model_name=Phi-4-mini-reasoning
mkdir -p /models/release_run_logs/\${model_name}
python3 fast_gpqa.py --model-name \${model_name} \
  --api-base http://127.0.0.1:8012/v1 --dataset mmlu \
  --output /models/release_run_logs/\${model_name}/mmlu.json \
  2>&1 | tee /models/release_run_logs/\${model_name}/eval_mmlu.log
python3 fast_gpqa.py --model-name \${model_name} \
  --api-base http://127.0.0.1:8012/v1 --dataset math_500 \
  --output /models/release_run_logs/\${model_name}/math_500.json \
  2>&1 | tee /models/release_run_logs/\${model_name}/eval_math.log
"
```

compare：
```bash
docker exec eval-scope bash -c "
cd /workspace/eval_scripts
model_name=Phi-4-mini-reasoning
python3 accuracy_compare.py \
  --v2 /models/release_run_logs/\${model_name}/mmlu.json \
  --nv-baseline \${model_name} --nv-baseline-file nv_baseline.yaml \
  --metric mmlu --json \
  --output /models/release_run_logs/\${model_name}/verdict_mmlu.json
python3 accuracy_compare.py \
  --v2 /models/release_run_logs/\${model_name}/math_500.json \
  --nv-baseline \${model_name} --nv-baseline-file nv_baseline.yaml \
  --metric math_500 --json \
  --output /models/release_run_logs/\${model_name}/verdict_math.json
"
```

| 迭代 | max_model_len | max_tokens | 采样 | 并发 | mmlu | math_500 | verdict |
|------|:---:|:---:|:---:|:---:|------|----------|---------|
| 第1次 | **4096** | **2048** | standard 0.0 | 16 | **58.07%**（1140题） | **41.0%**（200题） | ❌ |
| 第3次 | 32768 | 24576 | standard 0.0 | 8 | —（未重测） | **59.5%**（200题） | ❌ exit=1，rel_drop 32.54% |
| **第4次** | 32768 | 24576 | **T=0.8 / top_p=0.95**（README） | **16** | —（未重测） | **62.0%**（200题） | ❌ exit=1，rel_drop 29.71% |

> ⚠️ **iter3 的复评只修了截断，没有测采样**：它用的是 `/tmp/force_conc.py`（只 monkeypatch
> `probe_throughput` 锁并发），`detect_thinking` 与 `resolve_gen_params` **都没动** ——
> 日志实测 `模式: standard (temperature=0.0)`。**采样是到 iter4 才第一次被检验的。**

> **iter4 用的 wrapper**：`/tmp/phi4mini_sampling.py`（NFS 备份见 `_wrappers_backup/`），
> **只覆写 `cfg["temperature"]=0.8 / cfg["top_p"]=0.95` 并锁定并发 16，
> 保持 standard 分支（不 patch `detect_thinking`），`max_tokens` 不动**。
> ⚠️ 特别注意：**没有照抄 TinyR1 的 thinking wrapper** —— 该模型 chat_template 不含 `<think>`，
> 强制 thinking 只会白加空过滤器并把 `max_tokens` 收紧到 20000（见「定位 3」）。

> ⚠️ 四轮分数都未由 `fast_gpqa.py` 写出（`detect_runaway` 对 list content 崩溃），
> 均从 evalscope 报告恢复：iter1 mmlu `outputs/mmlu/20260917_033152`、
> iter1 math_500 `outputs/math_500/20260917_102103`、iter3 math_500 `outputs/math_500/20260918_085809`、
> **iter4 math_500 `outputs/math_500/20260919_063336`**。

## 现象

- iter1（未指定 `--max-model-len`，TRITON_ATTN，TP=1，GPU 9，port 8012）：
  - 服务正常启动，smoke test 通过，生成速度约 11 tok/s（3.8B 单卡，正常）。
  - **服务端 `max_model_len` 被 vLLM 推导成 4096**（模型实际支持 131072），
    导致 `fast_gpqa` 据此把 `max_tokens` 压到 **2048**。
  - 后果（逐题核对输出长度，见下表）：**mmlu 1140 题中 300 题（26%）撞顶**、
    **math_500 200 题中 111 题（56%）撞顶，中位数就是 2048**。
- iter2（显式 `--max-model-len 32768`）：
  - c16 未跑完即中止；改 c32 后**服务被打崩**——`max_tokens` 随之变为 24576（32768-8192），
    但 32 路并发远超该模型的 KV 容量（KV cache 仅 **160,353 tokens**，32K 上下文下最多约 **4.89 并发**），
    实测 KV 100%、请求排队、38 分钟才出 1 题。
- iter3（`--max-model-len 32768` + 并发降到 **8**）：
  - math_500 **59.5%**（119/200），比 iter1 的 41.0% 大幅回升 **+18.5pt**，但仍远低于 NV 88.2。
  - 仍有两类失分：**32 题撞 24576 上限**（其中答对 2）、**31 题 runaway 复读**。
  - **排除撞顶题后为 117/168 = 69.6%**（基线 88.2）。
- **iter4（按 README 用 T=0.8 / top_p=0.95，保持 standard 分支，并发 16，`max_tokens` 不变）**：
  - math_500 **62.0%**（124/200），NV 88.2，**↓29.71%**。verdict exit=1。
  - **比 iter3 只提升 +2.5pt**（59.5% → 62.0%）。
  - **但输出行为的变化极大**：runaway 复读 **31 → 2 题**（−94%）、撞顶 **32 → 9 题**（−72%）。
  - 平均输出 token 6986 → **5134**；中位基本不变（2324 → 2371）。

## 定位

### 1. `phi3 + longrope` 的 `max_model_len` 自动推导缺陷（已修，效果确认）

vLLM 对 `phi3 + longrope` 架构**自动推导出 `max_model_len=4096`**（模型实际支持 131072）。
`fast_gpqa` 再据此套用标准模型公式 `clamp(max_model_len - 8192, 4096, 32768)` 得 4096，
又因 `max_model_len <= 16384` 触发小上下文保护 `min(tokens, max_model_len//2)` → 最终 **2048**。

**修复 = 显式 `--max-model-len 32768`**（`max_tokens` 随之变为 24576）。
**效果已确认**：math_500 41.0% → 59.5%（+18.5pt）。

iter1 两个分数的截断程度（逐题输出长度统计）：

| 数据集 | max_tokens | 题数 | 撞顶题数 | 占比 | output_tokens 中位 |
|--------|:----------:|:----:|:-------:|:----:|:-----------------:|
| mmlu | 2048 | 1140 | 300 | **26%** | 1030 |
| math_500 | 2048 | 200 | 111 | **56%** | **2048（=上限）** |

→ **iter1 的 mmlu 58.07% 与 math_500 41.0% 都不能作为模型能力的证据**，它们测的是"被砍到
2048 token 的模型"。此后引用这两个数字时必须带上这个前提。

### 2. 采样修复：**行为改善巨大，但分数只涨了 2.5pt**（iter4 的核心发现）

iter4 是本模型**第一次**按 README 用正确采样评测。结果出人意料：

| 指标 | iter3（T=0.0 贪心） | **iter4（T=0.8/0.95）** | 变化 |
|------|:---:|:---:|:---:|
| math_500 得分 | 59.5% (119/200) | **62.0% (124/200)** | **+2.5pt** |
| runaway 复读 | 31 | **2** | **−94%** |
| 撞 24576 上限 | 32（答对 2） | **9**（答对 0） | **−72%** |
| 排除撞顶后 | 69.6% (117/168) | **64.9% (124/191)** | **反而 −4.7pt** |
| 平均输出 tokens | 6986 | 5134 | −26% |

**两条结论，都必须同时说：**

1. ✅ **采样确实是复读的直接原因。** README 推荐的 0.8/0.95 几乎完全消除了复读
   （31 题 → 2 题）。这验证了"贪心解码导致 R1 系模型复读"这条机制。
2. ❌ **但复读不是失分的主因。** 复读题从 31 降到 2，分数只涨 2.5pt。
   更能说明问题的是：**排除撞顶题后的分数反而从 69.6% 降到 64.9%** ——
   因为现在更多题"能答完了"，而那些答案**大多是错的**。
   **复读只是在掩盖错误，不是在制造错误。**

### 3. 剩余 29.71% 的差距：**截断与采样都已排除**

| 假设 | 验证方式 | 结论 |
|------|---------|------|
| 权重损坏 | HF 重下 + sha256 与上游逐字节一致 | ❌ 排除 |
| `max_model_len` 截断 | iter3 显式 32768 → +18.5pt | ✅ **已修**（但只解释一部分） |
| 采样配置错误 | **iter4 用 README 的 0.8/0.95 → 仅 +2.5pt** | ❌ **本轮排除** |
| 并发过高 | c32 打崩 → c16 健康（KV 未满、无 Waiting） | ❌ 排除 |

**四项排除后仍有 29.71% 的差距（62.0% vs 88.2），无法用截断或采样解释。**
按排除法，嫌疑指向**算子精度**（`sort,sort_stable` 之外的算子影响了数值正确性），
但这**尚无直接证据**，需要单独设计实验验证。

> ⚠️ 一个值得注意的旁证：iter3 和 iter4 的**撞顶题几乎全错**（32 题对 2 / 9 题对 0）。
> 说明仍有约 5% 的题会陷入无法收敛的状态，这与 OpenReasoning 的现象一致
> （见 `fixes/OpenReasoning-Nemotron-1.5B.md`：抬上限也救不回来）。
> **两个模型都出现"少量题死循环"，可能同源。**

### 4. 采样假设的来龙去脉（保留供判读）

- 模型方 README 的官方示例是 **`temperature=0.8, top_p=0.95, do_sample=True, max_new_tokens=32768`**。
- 但 iter1/iter3 实测都是 **`temperature=0.0`（贪心）+ `top_p=1.0`**。
  原因同 `[[fast-gpqa-thinking-detection-bug]]`：`detect_thinking("Phi-4-mini-reasoning")` 返回 `False`
  （名字不含 `qwen3/qwq/deepseek-r1/deepseek-r2/mimo/hunyuan`），
  且 `generation_config.json` 里没有 temperature 字段可兜底（该文件只有 `_from_model_config` + token ids）。
- ⚠️ **修法不能照抄 TinyR1**：Phi-4-mini 的 chat_template **不含 `<think>`**，
  强制 `detect_thinking→True` 会连带加 `remove_until='</think>'` 过滤器（对本模型是空操作）
  并把 `max_tokens` 从 24576 收紧到 20000 —— 反而加重截断。
  **正确做法是只覆写采样参数、保持 standard 分支**（iter4 即如此）。

## 处置

- ✅ 已修并确认有效：**显式 `--max-model-len 32768`**（截断修复，+18.5pt）。
- ✅ 已修并确认有效（行为层面）：**README 采样 0.8/0.95**（复读 31→2，但分数只 +2.5pt）。
- ✅ 已排除：**权重**（sha256 逐字节一致）、**并发**（c16 健康，KV 未满、无 Waiting）、**采样**、**截断**。
- ⬜ **下一步（建议，尚未执行）**：
  1. **查算子精度**（排除法剩下的唯一方向）：以 `sort,sort_stable` 为基础，逐组打开/关闭算子做精度对照。
     代价高，但这是唯一还没试过的方向。
  2. **mmlu 重测**：iter1 的 58.07% 带着 2048 截断污染（26% 撞顶），需一轮干净重测。
     鉴于 math_500 的差距主要不在截断/采样，mmlu 大概率也不达标，但需要数据支撑。
  3. **不要**再在"采样"或"max_model_len"上投入 —— 两者都已实测。

## 结果

- **math_500**：iter4 **62.0%**（200题）— ❌ 不达标（NV 88.2，↓29.71%，`verdict_math500_iter4.json` exit=1）
- **mmlu**：iter1 **58.07%**（1140题）— ❌ 不达标（NV 72.83，↓20.3%）**但该数字受 2048 截断污染，无效**
- 达标判定：**❌ 不达标**（截断与采样两项修复均已实测，仍差 29.71%）

## 提炼到 KNOWLEDGE 的条目

1. **"修好了明显的问题"≠"分数就会上来"——必须实测分数**。
   Phi-4-mini 的采样修复在行为上极其成功（复读 31→2，−94%；撞顶 32→9，−72%），
   但分数只涨 **2.5pt**（59.5%→62.0%）。**复读只是在掩盖错误，不是在制造错误。**
   若只看"复读消失了"就宣布修好，会得出完全错误的结论。
2. **`phi3 + longrope` 的 `max_model_len` 推导缺陷会连锁压低 `max_tokens`**：vLLM 推导成 4096 →
   `fast_gpqa` 套小上下文保护后只剩 **2048** → 56% 的 math_500 题被截断。
   **修复=显式 `--max-model-len 32768`**，实测 math_500 +18.5pt。
3. **引用受截断污染的分数前，先数撞顶题占比**：Phi-4-mini iter1 的 mmlu/math_500
   分别有 26% / 56% 的题撞顶，两者都不该当作模型能力。
4. **KV cache 决定并发上限，不能按参数量猜**：3.8B 全 MHA 的 Phi-4-mini KV cache 仅 **160,353 tokens**，
   32K 上下文下最多约 **4.89 并发**，c32 直接把服务打崩；而 1.5B GQA 的 OpenReasoning 有 919,360 tokens，
   c32 只用 38%。**小参数模型的 KV cache 可能远小于大模型。**
   （iter4 实测：c16 在 KV 73.9% 下仍健康，无 preemption，可用。）
5. **修采样 bug 不能照抄 TinyR1 的 wrapper**：对 chat_template 不含 `<think>` 的推理模型
   （如 Phi-4-mini），强制 thinking 分支反而会收紧 `max_tokens`、加重截断；
   这种情况应**只覆写采样参数**（本例 README 给的是 0.8/0.95）。
6. **"排除撞顶题后的分数"不能当作能力估计**：iter3 的 69.6% 看着比 iter4 的 64.9% 好，
   但那只是因为 iter3 有更多题卡死在撞顶状态。**该指标只能诊断，不能估计能力。**
   （同 OpenReasoning 的教训，见 `fixes/OpenReasoning-Nemotron-1.5B.md`。）
