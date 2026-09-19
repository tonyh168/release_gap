# iluvatar/MiroThinker-v1.5-30B 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_MiroThinker-v1.5-30B_202608241019.md
- **原始失败类型**：Operator crash + 精度/性能不达标（全部评测数据为空）
- **日期**：2026-09-15 ~ 2026-09-19（iter1 ~ iter3）
- **当前结论**：⏸️ **iter3 人工中止（31/50），待重跑完整轮**
  —— 已确定两件事：① **采样不是原因**（iter3 已用模型推荐的 0.6/0.95/top_k=20，74% 照样撞顶）；
  ② **"性能瓶颈是复读空转造成的假象"这一旧结论不成立**（解码仅 3.65 tok/s，是独立的第二个问题）。
  另：部分结果显示**撞顶题几乎全错、正常收尾的题全对** → 瓶颈在输出预算/解码速率，不在模型能力。

## 背景分析

V2/V3 均无算子数据，所有评测结果为空，3个 issue 提交。
和 QwQ-32B 类似（原报告同一批失败），推测服务在最早阶段就 crash。
MiroThinker-v1.5-30B 为 30B 参数量，**TP=4**（30B bf16 ~60 GB，4 卡共 128 GB）。
权重来源：`miromind-ai/MiroThinker-v1.5-30B`。

架构与自带配置（`config.json` / `generation_config.json` 实测）：

| 项目 | 值 |
|------|-----|
| `architectures` | `Qwen3MoeForCausalLM`（**MoE**，`model_type=qwen3_moe`） |
| 层数 / 注意力 | 48 层，GQA **32:4** |
| `max_position_embeddings` | 262144 |
| `generation_config.json` | `do_sample: true`, **`temperature: 0.6`, `top_p: 0.95`, `top_k: 20`** |
| chat_template 含 `</think>` | **是** → 结构上是 thinking 模型 |

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | **`iluvatar-147`** |
| 容器名 | `flagrelease-fix-mirothinker-v1.5-30b` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/MiroThinker-v1.5-30B` |
| 卡号 | **GPU 4,5,6,7**（`CUDA_VISIBLE_DEVICES=4,5,6,7`，TP=4）|
| 端口 | **8001** |
| 实际 vLLM 版本 | 0.24.0（FlagGems 5.3.4.post1） |
| 算子黑名单 | `sort,sort_stable`（各轮未变） |

## Step 0：登录 + 查卡 + 拉取镜像

```bash
ssh iluvatar-147
ixsmi   # 确认至少 4 张卡空闲
docker pull harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope
docker pull harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
```

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
model_name=mirothinker-v1.5-30b
docker run -itd --name flagrelease-fix-${model_name} \
  --device=/dev/iluvatar \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  ${IMAGE} bash
docker exec -it flagrelease-fix-${model_name} bash
ixsmi && python -c "import vllm; print(vllm.__version__)"
```

## Step 2：确认模型

权重来源：`miromind-ai/MiroThinker-v1.5-30B`（ModelScope）

```bash
ls /models/flagrelease/fixes_models/MiroThinker-v1.5-30B/
```

若需下载（eval-scope 容器里）：
```bash
docker exec -it eval-scope bash
modelscope download --model miromind-ai/MiroThinker-v1.5-30B \
  --local_dir /models/flagrelease/fixes_models/MiroThinker-v1.5-30B
```

## Step 3：起 vLLM 服务

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=4,5,6,7
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
model_name=MiroThinker-v1.5-30B
mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} --dtype bfloat16 \
  --tensor-parallel-size 4 --gpu-memory-utilization 0.9 \
  --port 8001 --attention-backend TRITON_ATTN \
  --enforce-eager --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log
```

> **注意**：本模型**不是** MLA 架构（`qwen3_moe`），用 `TRITON_ATTN`，**不是** `TRITON_MLA`。
> 见 `[[iluvatar-attention-backend]]`。

若 OOM → 升 TP=8 或降 `--max-model-len 16384`。若 crash → 抓栈补充黑名单：
```bash
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,<崩溃算子>
```

MoE 算子在本镜像走**通用回退**，非厂商优化路径（serve 日志实测）：
```
Worker_TP1: Op 'moe_align_block_size' using 'default.flagos' (kind=flagos, vendor=None)
```
⚠️ 这是**待查线索**，尚未证实与慢速解码有关。

| 服务实例 | 启动时间 | attention-backend | 黑名单 | 日志 | 服务对象 |
|---------|---------|------------------|--------|------|---------|
| #1 | 09-17 11:26 | TRITON_MLA（走错分支）→ TRITON_ATTN | sort,sort_stable | `serve_mla.log` / `serve.log` | iter1 |
| #2 | 09-18 06:19 | TRITON_ATTN | sort,sort_stable | `serve_attn.log` | iter1b / iter2 |
| #3 | 09-18 12:01 | TRITON_ATTN | sort,sort_stable | `serve2.log` | **iter3**（已停） |

## Step 4：评测

MiroThinker 为 thinking 模型，GPQA 50 题可能数小时，勿中断。

```bash
docker exec -it eval-scope bash
cd /workspace/release_评测标准
model_name=MiroThinker-v1.5-30B
python3 fast_gpqa.py --model-name ${model_name} --api-base http://127.0.0.1:8001/v1 \
  --output /models/release_run_logs/${model_name}/gpqa.json
python3 accuracy_compare.py --v2 /models/release_run_logs/${model_name}/gpqa.json \
  --nv-baseline ${model_name} --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict.json
```

| 迭代 | 模式 / 采样 | max_tokens | 并发 | 题数 | GPQA | 备注 |
|------|------------|:----------:|:---:|:---:|:----:|------|
| iter1（原始） | standard (**T=0.0** 贪心) | 24576 | 16 | 50 | **18.0%** | verdict exit=1，rel_drop 28.0%；eval 耗时 22598s |
| iter1b（扩样本） | standard (**T=0.0**) | 32768 | 2 | 116 | —（未算分） | **89/116 撞顶（77%）**，中位输出就是 32768 |
| iter2 | standard (**T=0.0**) | 32768 | 2 | 5 | —（中止） | 6 小时仅 5/50；**4/5 撞顶** |
| **iter3** | **thinking (T=0.6, top_p=0.95, top_k=20)** | **20000** | 2 | **31/50（人工中止）** | **29.0%（9/31，部分口径）** | 见下方「iter3 采样配置」与「iter3 部分结果」两节 |

> **iter3 用的 wrapper**：`/tmp/miro_thinking.py`（NFS 备份：`release_run_logs/_wrappers_backup/`）。
> **注意：该 wrapper 真正起作用的只有 `detect_thinking→True` 这一处 ——**
> 它对 `resolve_gen_params` 的覆写（0.6/0.95）其实是**空操作**，因为 `fast_gpqa` 的 thinking 分支
> 默认值本来就是 `temperature=0.6, top_p=0.95`（源码 `resolve_gen_params` 第 819 行）。
> 详见下方「iter3 采样配置」。

### iter3 采样配置（2026-09-19 逐字段核对）

**结论：iter3 的采样参数与模型自带推荐完全一致，三个字段全部命中。**

| 参数 | iter3 实际值 | 来源 | 模型要求 |
|------|:-----------:|------|:--------:|
| `temperature` | **0.6** | evalscope 请求显式发送 | 0.6 ✅ |
| `top_p` | **0.95** | evalscope 请求显式发送 | 0.95 ✅ |
| `top_k` | **20** | ⚠️ **vLLM 服务端**（非 evalscope） | 20 ✅ |
| `n` | 1 | evalscope | — |
| `max_tokens` | **20000** | `fast_gpqa` thinking 公式封顶 | — |
| 并发 | **2** | `fast_gpqa` 自动探测 | — |

evalscope 实际请求（eval 日志 `Creating model` 行）：
```
config={'batch_size': 2, 'stream': True, 'max_tokens': 20000,
        'top_p': 0.95, 'temperature': 0.6, 'n': 1}
```
模型自带 `generation_config.json` 的要求：
```json
{"do_sample": true, "temperature": 0.6, "top_p": 0.95, "top_k": 20}
```

**`top_k=20` 从哪来的（容易漏掉的一点）**：evalscope **没有**发送 `top_k`，
是 **vLLM 服务端自己补的** —— vLLM 默认 `--generation-config auto`，启动时会读模型目录里的
`generation_config.json` 作为服务端默认采样参数。serve2.log 有明确警告：

```
WARNING [model.py:1477] Default vLLM sampling parameters have been overridden by the
model's `generation_config.json`: `{'temperature': 0.6, 'top_k': 20, 'top_p': 0.95}`.
```

合并规则（vLLM `chat_completion/protocol.py:559` 起，`to_sampling_params`）：**逐字段判断，
请求里是 `None` 才回退服务端默认**。evalscope 没发 `top_k` → 用服务端的 **20**。

> **⚠️ 由此需要修正一条早先的判断**：此前记过「`generation_config.json` 覆盖机制在本环境完全失效」。
> 该说法**只对 `fast_gpqa` 的客户端路径成立**（`_resolve_model_dir()` 两条路径都不通）；
> **服务端这条路径是通的** —— 只要模型目录里有 `generation_config.json`，vLLM 就会把它读成默认值。
> 判读任何模型的实际采样时，**必须同时看 evalscope 请求参数和服务端 `model.py:1477` 那条警告**。

### iter3 部分结果（2026-09-19，人工中止时 31/50）

> **数据来源**：evalscope 自评分数，`reviews/MiroThinker-v1.5-30B/*.jsonl.rerun-*` 的
> `sample_score.score.value.accuracy`（非人工判读）。原始数据存档：
> `release_run_logs/MiroThinker-v1.5-30B/iter3_partial_20260919/`。

| | 题数 | 答对 | 准确率 |
|---|:---:|:---:|:---:|
| **全部（已评分）** | 31 | 9 | **29.0%** |
| 其中**撞 max_tokens 上限** | 23 | 1 | **4.3%** |
| 其中**正常结束（stop）** | 8 | **8** | **100%** |

参照：**NV 基线 25.0%**、iter1（贪心、50 题全量）18.0%。

**判读（三点，都必须带上）**：

1. **29.0% 不能当结论**：只有 31/50 题，且是数据集的**前 31 题（index 0–30）**，不是随机抽样，
   不能与 50 题全量的 18.0% 或 NV 基线 25.0% 直接比较。
2. **真正有价值的是那个拆分**：**正常结束的 8 题全对（100%），撞顶的 23 题只对 1 题（4.3%）**。
   这把"它不是能力不行、是答不完"从推测变成了实测。
3. **8 题样本太小**，100% 的置信区间很宽，真实水平可能明显更低，不足以单独作为证据。

> 该结果已回写进存档：`iter3_partial_20260919/partial_result.json`（含逐题对错与截断标记）。

## 现象

- iter1（原始，standard 贪心，TRITON_ATTN，TP=4）：
  - 服务正常启动。GPQA **18.0%**（NV 25.0，↓28.0%），verdict `aligned=false`。
  - **runaway 45/50（90%）**，输出大量撞 24576 上限。
- iter1b（扩到 116 题）：
  - **89/116 题（77%）撞满 32768 上限**，中位输出长度就是 32768；
    尾部为典型退化复读：`"Wait, maybe it's X? No. Wait, maybe it's X? No."`
- iter2（重跑，standard）：
  - 6 小时只跑完 5 题（4/5 撞顶），ETA 约 32h，主动停止。
- iter3（**thinking + 0.6/0.95 + top_k=20**，并发 2，mt=20000）——**关键对照轮**：
  - 2026-09-18 18:27 启动，**2026-09-19 14:2x 按用户要求人工中止**，完成 **31/50**，共跑 19h40m。
  - **23/31 题（74%）仍撞满 20000 上限**（其中 23 题被判 runaway 复读），仅 8 题正常 `stop`。
  - 单请求解码速率：**3.65 tok/s**（`1/tpot` 中位，并发 2）。
  - **部分评分：29.0%（9/31）**；拆分后 **正常结束 8 题全对（100%）/ 撞顶 23 题只对 1 题（4.3%）**。
  - ⚠️ evalscope **不支持断点续跑**，中止后这 20 小时的算力无法恢复；已存档的是数据不是进度。

## 定位

### 1. 复读是真的，但**不是**"假瓶颈"的全部 —— 旧结论需要修正

先前 STATUS 记过一条结论：「MiroThinker 的"性能瓶颈"是假象，所谓 ETA 60h 实为复读空转」。
**iter3 的对照推翻了这条结论的一部分**：

| 指标 | iter1/iter1b/iter2（贪心 T=0.0） | **iter3（thinking T=0.6/0.95）** |
|------|:---:|:---:|
| 撞输出上限的比例 | 77%（89/116）、90%（45/50） | **74%（23/31）** |
| 单请求解码速率 | **3.39 / 3.70 tok/s** | **3.65 tok/s** |

**换成模型方推荐的采样（0.6/0.95）后，复读基本没减少（77% → 74%），解码速率也完全没变**
（3.4~3.7 tok/s 区间内波动）。这说明：

- ✅ **复读真实存在**（74~90% 的输出撞顶，尾部是退化复读）——这部分旧结论没错；
- ❌ **但把"性能瓶颈"整体归因于复读空转是错的**：解码速率本身就只有 ~3.6 tok/s，
  即便输出长度正常，单题也要跑几十分钟。**慢是独立于复读的第二个问题。**

以 iter3 实测为例：并发 2、3.65 tok/s、输出 20000 token → 单题约 **91 分钟**，
50 题即约 **38 小时**（与日志里 ETA 13h + 已跑 19.7h 相符）。

### 2. 与 Fathom 的关系：两者都慢，但"慢"的机制不同

| 模型 | 架构 | 单请求解码速率 | 复读/撞顶 |
|------|------|:-------------:|:---------:|
| **MiroThinker-v1.5-30B** | `qwen3_moe`（**MoE**） | **3.65 tok/s** | **74~90% 撞顶（严重）** |
| Fathom-R1-14B | `qwen2`（**dense**） | **3.49 tok/s** | 仅 1/49 撞顶（几乎无） |

- Fathom 的慢是**纯吞吐**问题（输出长度正常）；
- MiroThinker 是**吞吐慢 + 复读**两个问题叠加，且**采样修正只对第二个问题无效**。
- 两者架构不同却落在同一速率区间（~3.5-3.7 tok/s），**提示根因可能在平台/算子层**
  （MoE 算子在本镜像走 `default.flagos` 通用回退，见上）。**本轮未定位到具体算子，不下结论。**

> 参照：同为 32B dense Qwen2 的 TinyR1（TP=4）实测 5.06 tok/s，
> 1.5B GQA 的 OpenReasoning 实测 10.2 tok/s。上表均为**各自评测并发下**的单请求 `1/tpot`，
> 并发档位不同，只能看数量级，不是严格吞吐基准。

### 3. 部分结果进一步印证：**不是能力不行，是答不完**（0919 新增）

iter3 的 31 题部分评分按"是否截断"拆开后，分布非常干净：

| | 题数 | 答对 | 准确率 |
|---|:---:|:---:|:---:|
| 撞 max_tokens 上限 | 23 | 1 | **4.3%** |
| 正常结束（stop） | 8 | **8** | **100%** |

**能正常收尾的题它几乎都做对了，跑不完的题几乎全错。** 这直接支持"瓶颈在输出预算 /
解码速率，而不是模型能力"的判断。

**同时也要注意**：这也说明**换采样救不了它** —— iter3 已经是模型方推荐的采样
（0.6/0.95/top_k=20 全中），74% 的题照样跑满预算。**下一步应该是抬 `max_tokens` 或解决
解码速率，而不是继续调采样参数。**

⚠️ 该拆分只覆盖 31 题、且是前 31 题（非随机），`100%` 那一栏只有 8 个样本，
**不足以作为达标证据**，仅用于指示排查方向。

### 4. 尚未验证的可能

- **`--max-model-len` 过大拖慢解码**：服务端 `max_seq_len=262144`，KV cache 按 262144 预留；
  实际评测只用到 20000 输出 + 短 prompt。降到 32768 是否提速**未测**。
- **MoE 算子回退**：`moe_align_block_size` 走 `default.flagos`，是否有更优后端**未测**。
- **`--enforce-eager`**：各轮均带 `--enforce-eager`（禁用 torch.compile / CUDAGraph），
  对本来就慢的解码是雪上加霜，但去掉有稳定性风险，**未测**。

## 处置

- **iter3 已人工中止**（2026-09-19 14:2x，31/50）：用户要求停止全部容器与评测，为
  OpenReasoning / Phi-4-mini 的 iter4 腾出机器。原始数据已存档（见下）。
- **采样假设已闭环**：iter3 采样与模型推荐**完全一致**（0.6/0.95/top_k=20），
  但 74% 撞顶、解码 3.65 tok/s **均无改善** → **采样不是原因，不再在采样上投入**。
- **下一步（待重跑完整轮）**，按性价比排序：
  1. **抬 `max_tokens`**：既然"正常结束的题全对"，把上限从 20000 提到 65536，
     让更多题有机会收尾 —— 这是最直接、且已被 OpenReasoning 印证有效的手段。
  2. **解决解码速率**（根因，但更难）：按 `--max-model-len` 降 32768 → 去 `--enforce-eager`
     → 查 MoE 算子后端（`default.flagos` 通用回退）的顺序做对照实验。
  3. 若 1 有效但 2 不解决，则仍需面对 50 题 × 91 分钟 = 38h 的墙钟时间问题。

## 结果

- 修复后 GPQA 正确率：**iter1 18.0%**（50题全量，贪心）；**iter3 部分 29.0%**（31题，口径不完整）
- NV 基线：**25.0%**
- 达标判定：**未定** —— iter1 verdict exit=1；iter3 因人工中止**未生成 verdict**，
  且部分口径不可与基线直接比较。**待重跑完整 50 题后再判定。**

### 存档位置（人工中止前的抢救）

| 内容 | 路径 |
|------|------|
| 31 题原始预测 | `release_run_logs/MiroThinker-v1.5-30B/iter3_partial_20260919/predictions/` |
| 31 题评分记录（`*.jsonl.rerun-*`） | `.../iter3_partial_20260919/reviews/` |
| 评测配置（`task_config.yaml`） | `.../iter3_partial_20260919/configs/` |
| 汇总（含逐题对错、截断标记） | `.../iter3_partial_20260919/partial_result.json` |
| 评测 wrapper | `release_run_logs/_wrappers_backup/miro_thinking.py` |

## 提炼到 KNOWLEDGE 的条目

1. **"复读导致的假瓶颈"这类结论必须用"正确采样的对照轮"验证，不能只靠推理**：
   MiroThinker 换成模型推荐的 0.6/0.95 后，撞顶率 77% → 74%（几乎没变）、
   解码速率 3.39 → 3.65 tok/s（没变）—— **复读真实存在，但慢是独立问题**。
2. **"是否复读"和"解码快不快"是两个独立指标，要分开看**：
   - 复读看 `stop_reason=max_tokens` 占比 + runaway 检测；
   - 吞吐看 `1/tpot`（与输出长度无关）。
   Fathom 是"慢但不复读"，MiroThinker 是"又慢又复读"。
3. **不同架构（dense / MoE）落到同一速率区间 → 先怀疑平台而非模型**：
   14B dense `qwen2` 与 30B MoE `qwen3_moe` 都在 ~3.5 tok/s。
4. **`--enforce-eager` + 超大 `max-model-len` 是慢速解码的两个高嫌疑配置项**，
   排查吞吐问题时值得优先做对照。
5. **判定"模型能力不足"之前，先按"是否撞 max_tokens"拆开看分数**：
   MiroThinker 撞顶的 23 题只对 1 题（4.3%）、正常结束的 8 题**全对（100%）**。
   **撞顶题的得分率极低，会把整体分数系统性拉低，掩盖模型的真实水平。**
   （同类教训见 `[[fast-gpqa-thinking-detection-bug]]` 与 OpenReasoning 的截断分析。）
6. **判读实际采样必须同时看两处**：evalscope 请求参数 **+ 服务端 `model.py:1477` 警告**。
   `top_k` 这类参数 evalscope 可能根本不发，而由 vLLM 从模型 `generation_config.json` 补齐
   （本例 `top_k=20` 即如此）。只看请求 payload 会漏判。
7. **`generation_config.json` 覆盖机制"失效"的说法要限定范围**：它只在 `fast_gpqa` 的
   **客户端路径**（`_resolve_model_dir()` 两条路径都不通）失效；**服务端 vLLM 那条路径是通的**。
   切勿把"客户端没读到"推广成"全环境无效"。
8. **evalscope 不支持断点续跑**：中止 = 已投入的算力作废，只能从 `reviews/` 抢救已完成的分数。
   跑长任务前应预估总墙钟时间（本例 50 题 × 91 分钟 ≈ 38h），并确认能接受再启动。
