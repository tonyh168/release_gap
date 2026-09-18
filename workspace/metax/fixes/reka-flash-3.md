# metax/reka-flash-3 修复日志

- **失败报告**：flagrelease_fail_reports/Metax/FAILED_Metax_reka-flash-3_202607301246.md
- **原始失败类型**：精度不达标（V3=52.02% vs NV=59%，rel_drop=11.8%）+ plugin-FL 报错
- **日期**：2026-09-16

---

## 背景分析

reka-flash-3 是 dense 模型，bf16。
ModelScope 来源：`RekaAI/reka-flash-3`
NV 基线：gpqa_diamond = **59**（容差 5%，下限 ≥ 56.05%）

原始报告：V1 无评测，V2（FlagGems，无 plugin，50 题）= 40.0%，V3（plugin-FL，198 题）= 52.02%。
V2→V3 精度偏差 12.0%（plugin-FL 开启后反而下降），两个 issue 均为精度退化 + plugin-FL error。
V3 与 NV 基线差距 rel_drop 11.8%，不达标。

注意：V1 性能数据显示 TTFT 极高（62268ms mean），可能是 reka-flash-3 架构特殊（如 SSM/混合架构）导致 prefill 慢，需观察。

TP 计算：需先确认模型权重大小，下载后查实际文件大小。

---

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `metax-60` |
| 容器名 | `flagrelease-fix-reka-flash-3` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/reka-flash-3` |
| TP / GPU / 端口 | TP=2，GPU 1,2，port=8001 |
| 实际 vLLM 版本 | 0.24.0 (v0.1.dev17936+gee0da84ab) |

---

## Step 0：登录 + 查卡

```bash
ssh metax-60
mx-smi
```

**mx-smi 输出节选**（2026-09-16，所有旧容器停止后）：
```
GPU 0-7: 858/65536 MiB（全部空闲）
```

GPU 0 分配给 SOLAR-10.7B（TP=1，port 8000），reka-flash-3 视权重大小分配后续 GPU。

---

## Step 1：下载模型权重

```bash
docker exec -it eval-scope /bin/bash
mkdir -p /models/flagrelease/fixes_models
modelscope download --model RekaAI/reka-flash-3 \
  --local_dir /models/flagrelease/fixes_models/reka-flash-3
```

下载完成后确认大小：
```bash
du -sh /models/flagrelease/fixes_models/reka-flash-3/
ls /models/flagrelease/fixes_models/reka-flash-3/*.safetensors | wc -l
```

**下载结果**：✅ 完成，5 个 safetensors 分片，总大小 78GB

TP 计算：78GB × 1.2 / 63.6 = 1.47 → ceil = 2 → **TP=2**（GPU 1,2，每卡 39GB 权重，剩余 ~17GB KV cache）

**config.json 关键字段**：`max_position_embeddings = 32768`，`model_type = llama`，`--max-model-len 32768` 无需调整。

---

## Step 2：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907
docker run -d --rm \
  --name flagrelease-fix-reka-flash-3 \
  --network host \
  --shm-size 64g \
  --device /dev/dri:/dev/dri:rwm \
  --device /dev/mxcd:/dev/mxcd:rwm \
  -v /public-flash/models:/models \
  ${IMAGE} \
  sleep infinity
```

---

## Step 3：起 vLLM 服务

### 修复策略

原失败为 plugin-FL 精度退化，V2→V3 精度从 40% 降到 52%（实际是 V2 仅 50 题，V3 198 题，不可直接对比）。
核心问题：V3 52.02% 低于 NV 59% 容差下限 56.05%。

策略：默认黑名单起 v1，若精度仍不达标，参考 Phi-4-mini 方案扩展黑名单加 `rms_norm,silu_and_mul`。

### 启动命令（v1，TP 确认后填入）

```bash
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export MACA_VISIBLE_DEVICES=1,2
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200

model_name=reka-flash-3
mkdir -p /models/release_run_logs/${model_name}
/opt/conda/bin/vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} \
  --dtype bfloat16 \
  --tensor-parallel-size 2 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.9 \
  --port 8001 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve_v1.log
```

**启动日志关键行**：
```
✅ 服务正常启动，port 8001，TP=2，GPU 1,2
```

### 迭代记录（启动阶段）

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST 变化 | TP | 结果 | 日志关键报错 |
|------|------------------------------|----|------|-------------|
| v1 | 默认（mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice） | 2 | ✅ 启动成功 | 无 |
| v2 | 扩展加 rms_norm,silu_and_mul | 2 | ✅ 启动成功 | 无 |

### 冒烟验证

```bash
model_name=reka-flash-3

curl -s http://localhost:8001/v1/models

curl -s http://localhost:8001/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"What is the capital of France?"}],"max_tokens":32,"temperature":0}'

curl -s http://localhost:8001/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"请详细解释牛顿三大运动定律，并各举一个日常生活中的实例，要求每条定律的解释不少于100字。"}],"max_tokens":512,"temperature":0}'
```

**冒烟结果**：✅ v1 冒烟通过，服务正常出题，29-44 tok/s

---

## Step 4：评测

```bash
model_name=reka-flash-3

docker exec eval-scope bash -c "
python3 /workspace/eval_scripts/fast_gpqa.py \
  --model-name ${model_name} \
  --api-base http://127.0.0.1:8001/v1 \
  --dataset gpqa_diamond \
  --dataset-dir /models/evalscope-datasets \
  --output /models/release_run_logs/${model_name}/gpqa_v1.json \
  > /models/release_run_logs/${model_name}/eval_v1.log 2>&1
"

docker exec eval-scope bash -c "
python3 /workspace/eval_scripts/accuracy_compare.py \
  --v2 /models/release_run_logs/${model_name}/gpqa_v1.json \
  --nv-baseline ${model_name} \
  --nv-baseline-file /workspace/eval_scripts/nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict_v1.json
"
```

### 评测迭代记录

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST | GPQA 正确率 | accuracy_compare 退出码 | 备注 |
|------|--------------------------|------------|------------------------|------|
| v1 | mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice | 44%（22/50）❌ | 1 | rel_drop=25.42%，远超 5% 容差；score=null（fast_gpqa 解析失败），从 evalscope 报告补填 44.0 |
| v2 | 默认 + rms_norm,silu_and_mul | 42%（21/50）❌ | 1 | rel_drop=28.81%，比 v1 更差；扩展黑名单对 reka-flash-3 无效 |

**verdict_v1.json 原文**：
```json
{
  "baseline_mode": "nv_reference",
  "model": "reka-flash-3",
  "metric": "gpqa_diamond",
  "nv": { "score": 59.0, "source": "NV 实测" },
  "current": { "score": 44.0, "mode": "standard" },
  "tolerance": 0.05,
  "rel_drop": 0.2542,
  "rel_drop_pct": 25.42,
  "abs_diff": -15.0,
  "aligned": false,
  "noise_zone": false,
  "message": "精度不达标: 当前=44.00%, NV=59.00%, 相对退化=25.42% > 容差 5.0%"
}
```

---

## 现象

- v1（默认黑名单）：44%（22/50），rel_drop=25.42%，远超 5% 容差，不达标
- v2（加 rms_norm,silu_and_mul）：42%（21/50），rel_drop=28.81%，比 v1 更差
- fast_gpqa score=null（两轮均如此），从 evalscope 报告手工补填
- eval_v1 耗时 94 分钟，eval_v2 耗时约 65 分钟（题均约 75s，reasoning 模型？）
- v1/v2 最后 2 题卡挂（evalscope 概率性卡题），通过等待自然恢复

## 定位

- plugin-FL 对 reka-flash-3 存在系统性精度退化，与原始报告（V2→V3 精度从 40% 降到 52.02%）一致
- reka-flash-3 架构为 LLaMA 基（model_type=llama），非 MoE，无 MLA，但 TTFT 极高（62s），推测 prefill 路径有特殊算子
- 扩展黑名单加 rms_norm/silu_and_mul 对本模型无效，说明退化来源不在这两个算子
- 与 SOLAR-10.7B-Instruct-v1.0 类似：plugin-FL 对部分 dense 模型有无法通过简单黑名单修复的精度问题

## 处置

两轮均不达标，暂停修复：
- v1：默认黑名单，44%❌
- v2：扩展黑名单（+rms_norm,silu_and_mul），42%❌

## 结果

- 修复后分 / NV 基线：44.0（v1 最优）/ 59.0，未达标
- 达标判定：accuracy_compare 退出码 1（两轮均不达标）
- **状态：修复暂停**，与 SOLAR-10.7B 同样处理

## 提炼到 KNOWLEDGE 的条目

- reka-flash-3 plugin-FL 精度退化无法通过默认黑名单或扩展黑名单（rms_norm/silu_and_mul）修复，暂无解法
- fast_gpqa score=null 是 reka-flash-3 的已知问题（同 EXAONE/Qwen3-Thinking），需从 evalscope 报告手工补填
- 单题卡挂问题在 reka-flash-3 上也存在（v2 最后 2 题），但最终自然恢复，无需 eval_missing 补评

> 2026-09-18 新增的 5 条重要规律（generation_config.json 静默失效、采样参数对复读的影响、
> `limit` 语义与同题对照方法、eager 吞吐代价）已同步到 `_shared/KNOWLEDGE.md`，
> 详见下方「追加分析」与文末「迭代记录」。

---

## 追加分析（2026-09-18）：generation_config.json 为何始终没有生效

### 现象

v3（50 题）、v4（198 题，未跑完）两轮都在用**贪心解码**（temperature=0.0 / top_p=1.0）
评测 reka-flash-3。响应长度分布呈现明显的两极分化：

| 响应长度 | v3（50 题） | v4 前 115 题 |
|---|---:|---:|
| < 8k 字符 | 77.8%（18 题） | 72.7%（33 题） |
| 8–20k 字符 | 43.8%（16 题） | 53.1%（32 题） |
| ≥ 20k 字符 | 12.5%（16 题） | 26.0%（50 题） |

一半以上的题响应超过 2 万字符，这批题的正确率只有 12–26%，是拉低总分的主因。
逐题审计显示模型在长响应里反复自我推翻（典型样本：`idx 26` 长度 93324 字符，
末尾为 `...The answer must be B, but that's wrong`），runaway 复读检测也命中该题。

### 根因：`_resolve_model_dir()` 在标准评测流程下必然返回 None

`fast_gpqa.py` 的 `resolve_gen_params()` 是一层「优先采用模型自带
`generation_config.json` 采样参数」的增强逻辑，但它的模型目录定位函数
`_resolve_model_dir(model_path)` 只有两个来源：

1. `model_path` 本身是一个存在的本地目录（`os.path.isdir`）
2. 兜底读 `/flagos-workspace/shared/context.yaml` 的 `model.local_path` / `model.container_path`

而本项目标准评测流程里：

- `--model-name` 传的是 **NV 基线表的 key**（如 `reka-flash-3`），**不是本地路径** → 条件 1 不成立
- 评测容器 `reka-eval-v3` 里 **`/flagos-workspace/` 目录根本不存在** → 条件 2 不成立

两个条件都不成立 → 返回 `None` → `resolve_gen_params()` 静默回退到默认采样参数
（standard 模型即 `temperature=0.0 / top_p=1.0`），**模型自带的
`generation_config.json` 完全没被读取**。

reka-flash-3 的 `generation_config.json` 内容为：

```json
{ "do_sample": true, "temperature": 0.6, "top_k": 1024, "top_p": 0.95,
  "bos_token_id": 100257, "eos_token_id": 100257, "pad_token_id": 100257 }
```

即**模型作者明确要求采样解码（temperature=0.6）**，而实际评测一直在用贪心。
脚本作者显然预见到了这个风险——代码里专门有一段注释说明「修复 do_sample=true
但无显式温度时掉入贪心的问题」，但那段补丁只在**成功读到 generation_config.json**
时才生效；文件根本没被读到，补丁自然也无从触发。

### 为什么一直没被发现

脚本其实**打了日志**：

```
[gen] 未定位到模型目录（--model-name 非本地路径且 context.yaml 无路径），沿用默认采样参数
```

但这行是 `INFO` 级、夹在几十行启动输出中间，且措辞是「沿用默认采样参数」——
读起来像正常的默认行为，而不是「模型配置被忽略了」的警告。历轮评审都跳过了它。

### 影响范围：不止 reka-flash-3，是本项目全部 10 个模型

检索 NFS 上所有评测日志，**每一个模型的每一轮评测都有这行提示**：

```
Baichuan-M2-32B/eval_v1.log
EXAONE-4.0-32B/eval_v1.log / eval_v2.log / eval_198.log
GLM-4-32B-0414/eval_v1.log / eval_v2.log
Phi-3.5-mini-instruct/eval_v1.log / eval_v2.log
Phi-3-mini-128k-instruct/eval.log / eval_v2_b.log
...
```

即：**本项目所有模型的评测，都没有采用过模型自带的 generation_config.json**，
一律走的默认贪心。对多数模型这没造成问题（它们本来就该贪心评测），
但对 reka-flash-3 这种作者显式声明 `do_sample=true` 的模型，
这可能正是精度只有 46% 的原因之一。

### 修复方式

在评测容器内补出脚本设计的兜底文件（**不改任何评测脚本代码**）：

```bash
docker exec reka-eval-v3 sh -c 'mkdir -p /flagos-workspace/shared && cat > /flagos-workspace/shared/context.yaml <<EOF
model:
  local_path: /models/flagrelease/fixes_models/reka-flash-3
  container_path: /models/flagrelease/fixes_models/reka-flash-3
EOF'
```

验证通过：

```
_resolve_model_dir('reka-flash-3') -> /models/flagrelease/fixes_models/reka-flash-3
[gen] 采用模型 generation_config.json 采样参数: {'temperature': 0.6, 'top_p': 0.95, 'top_k': 1024}
```

### 后续注意事项

- **换模型评测时必须同步改 `context.yaml` 里的路径**，否则会静默退回默认贪心，
  且日志只给一行不显眼的 INFO。建议每次评测前 grep 一下日志里的
  `[gen]` 行，确认是「采用模型 generation_config.json」而不是「未定位到模型目录」。
- 更彻底的做法是给 `fast_gpqa.py` 增加显式 CLI（如 `--model-path`）来指定模型目录，
  避免依赖容器内的隐式兜底文件。当前未做，仅用兜底文件绕过。
- **注意与手动复现文档的口径差异**：`Reka-Flash-3_GPQA-Diamond_手动复现.md` 里
  FlagOS 51.52% 那一轮，请求里显式传的是 `temperature=0.0 / top_p=1.0 / top_k=-1`，
  **不是**模型自带的 0.6。因此改用 generation_config.json 后的结果
  **不能与文档的 51.52 直接对比**，属于一组新配置。

### 对照实验验证：采样参数确实是精度差距的主因

#### 前提：index 跨轮次稳定，可做同题对比

先验证 evalscope 的 `limit` 语义与 `index` 稳定性，确认可以拿不同轮次做严格同题对比：

- **`limit=50` = index 0..49，严格连续、不采样、不打乱**。评测**执行顺序**是乱序并发提交
  （v3 前 10 个写入 index 为 `3,0,2,4,10,6,9,11,13,8`），但**取的样本集合**就是文件顺序前 N 条。
- 全量（`--limit 0`）同样按文件顺序从 index 0 递增消费，进度条 `117/198` 即对应 `index 0..116`。
- 三轮（v3 / v4 / v6）在共同 index 上的 **target（标准答案）逐题一致 50/50**，
  逐题抽查前 12 个 index 的 target 完全吻合。题序由 `seed=42` 固定。

结论：**同一个 index 在所有轮次里就是同一道题**，因此可以做逐题严格对照。

#### 核心对照：完全相同的 115 道题

v4 与 v6 均为 graph 模式、同为 198 题全量跑，唯一差异是**采样参数与 max_tokens**。
取两者共同跑过的 index 0..114 做对比：

| 轮次 | 采样参数 | max_tokens | index 0..114 得分 |
|---|---|---|---:|
| v4 | temperature=0.0 / top_p=1.0（贪心） | 24576 | 54/115 = **46.96%** |
| v6 | temperature=0.6 / top_p=0.95 / top_k=1024（模型自带） | 16384 | 61/115 = **53.04%** |

**同题同量，v6 高出 6.08pt。** 这个差值建立在完全相同的题目集合上，
比不同题数的粗略对比可信得多，采样解码的收益得到干净验证。

#### 机制证据：响应长度分布被显著改善

| 响应长度 | v3（贪心，50题） | v4（贪心，前115题） | v6（采样，同期） |
|---|---:|---:|---:|
| < 8k 字符 | 77.8% | 72.7% | **84.0%** |
| 8–20k 字符 | 43.8% | 53.1% | **53.7%** |
| ≥ 20k 字符 | **12.5%** | **26.0%** | **36.7%** |

- **最长响应从 93324 字符降到 36210 字符**（v3 → v6），长尾被大幅砍掉。
- 最关键的 `≥20k` 档（v3 时只有 12.5%，是拖分主因）**提升到 36.7%**，
  即「越长越错」的自我纠结模式被明显抑制。
- 典型复读样本 `idx 26`（v3 时 93324 字符、末尾
  `...The answer must be B, but that's wrong`、被 runaway 检测命中）在 v6 中不再出现同类形态。

机制上说得通：贪心解码下模型一旦进入重复循环就会**确定性**地一路复读下去（无法逃逸）；
采样解码给了它跳出循环的概率，因此复读窗口被收窄。

#### 但精度仍未达标

v6 全程得分轨迹（198 题进行中，每 10 分钟采样）：

```
58.6 → 56.7 → 60.0 → 51.9 → 52.5 → 58.3 → 56.1 → 55.3 → 54.4 → 53.0
```

前 45 题的高分（60%）是早期样本红利，随题量增加持续回归，
说明 **采样参数修复了「复读」但没有修复「精度本身」**。
最终值预计落在 **52%–55%** 区间，距离 `nv_baseline.yaml` 的 59.0（达标线 55.85%）
仍有 2–3pt 缺口。

#### 尚未验证的方向

采样参数这条线已经走完，剩余 2–3pt 缺口**另有原因**，候选方向：

1. **NV 基线 59.0 本身可能偏高**——手动复现文档中 NV origin 198 题实测仅 **53.54%**，
   与 FlagOS 的 51.52% 只差 2pt。若 NV 真实水平就是 53–54%，则 v6 已基本追平 NV，
   问题出在基线表取值上（同 SOLAR-10.7B 的情况）。
   **这是目前最值得优先核查的方向。**
2. max_tokens 16384 vs 文档的 16384 已对齐；但文档 FlagOS 那轮用的是贪心
   （temp=0.0），本轮的 0.6 是偏离文档的变量，需注意口径。
3. 并发未对齐（本轮自动探测为 2，文档为 256），但对精度通常无系统性影响。

---

## 迭代记录 v4 / v5（配置对照实验）

| 迭代 | 题数 | temperature / top_p / top_k | max_tokens | 执行模式 | 服务 max-model-len | 并发 | 结果 |
|------|-----:|------------------------------|-----------:|---------|-------------------:|-----:|------|
| v1 | 50 | 0.0 / 1.0 / — | 24576 | eager | 32768 | 4 | 44.0%❌ |
| v2 | 50 | 0.0 / 1.0 / — | 24576 | eager | 32768 | 16 | 42.0%❌ |
| v3 | 50 | 0.0 / 1.0 / — | 24576 | graph | 32768 | 8 | 46.0%❌（从 reports 补计分） |
| v4 | 198 | 0.0 / 1.0 / — | 24576 | graph | 32768 | 4 | 中断于 125/198（前 115 题 46.96%） |
| v5 | 198 | 0.6 / 0.95 / 1024（模型自带） | 16384 | eager | 24576 | 自动探测 | **作废**（eager 太慢，仅跑完探测即中止） |
| v6 | 198 | **0.6 / 0.95 / 1024**（模型自带） | **16384** | **graph** | **24576** | 自动探测(2) | 进行中（前 115 题 53.04%） |

### v6 配置说明（当前采用）

- **采样参数**：由 `context.yaml` 兜底使 `generation_config.json` 生效，
  得到 temperature=0.6 / top_p=0.95 / top_k=1024。这是与 v3/v4 的**核心差异**。
- **max_tokens=16384 的实现**：脚本设计上禁止命令行指定 max_tokens（由
  `auto_max_tokens()` 按 `max_model_len - 8192` 自适应），且截断检测还会自动翻倍。
  为不改脚本，改用**服务端间接控制**：把 `--max-model-len` 从 32768 降到 24576，
  则 `auto_max_tokens()` 自动算出 `24576 - 8192 = 16384`。已实测确认。
  代价是上下文窗口从 32768 缩到 24576（GPQA prompt 很短，实际无影响）。
- **执行模式**：graph（与 v4 相同，未加 `--enforce-eager`）。
- **并发**：脚本自动探测，实测选中 2，与文档的 256 不一致（无 CLI 可强制）。

### v5 作废说明

v5 曾按「对齐手动复现文档」的思路改用 **eager 模式**启动，
但实测 eager 下 decode 吞吐仅 **16 tok/s**，而 graph 模式为 **160 tok/s**（差 10 倍），
单请求耗时不可接受，遂在探测阶段即中止并改回 graph（即 v6）。
**结论：本项目评测一律用 graph 模式，eager 的吞吐代价不可接受。**

### v4 中断说明

v4（198 题 / max_tokens=24576 / graph / 并发 4）跑到 125/198 时因转入 v5 实验被手动
`pkill` 终止，未产出完整 198 题结果；已完成部分的前 115 题准确率为 46.96%，
方向与 v3 一致（长响应拖分）。该 115 题数据后被用作 v6 的严格同题对照组。
