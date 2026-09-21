# iluvatar/MiroThinker-v1.5-30B 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_MiroThinker-v1.5-30B_202608241019.md
- **原始失败类型**：服务启动失败（Operator crash）+ 精度不达标 + 性能不达标（全部评测数据为空）
- **日期**：2026-09-15 ~ 2026-09-19（iter1 ~ iter5）

## 现象

原始失败报告（vLLM 0.20.2 + FlagGems 5.0.0）：V2/V3 均无算子数据，所有评测结果为空，3 个 issue 提交；
与 QwQ-32B 类似（原报告同一批失败），推测服务在最早阶段就 crash。

本次复现各轮实测：

- **iter1**（standard 贪心，`TRITON_ATTN`，TP=4）：服务正常启动。GPQA **18.0%**（NV 25.0，↓28.0%），
  verdict `aligned=false`；**runaway 45/50（90%）**，输出大量撞 24576 上限
- **iter1b**（扩到 116 题）：**89/116 题（77%）撞满 32768 上限**，中位输出长度就是 32768，
  尾部为典型退化复读：`"Wait, maybe it's X? No. Wait, maybe it's X? No."`
- **iter2**（重跑，standard）：6 小时只跑完 5 题（4/5 撞顶），ETA 约 32h，主动停止
- **iter3**（thinking + 0.6/0.95 + `top_k=20`，并发 2，mt=20000）：完成 **31/50**，共跑 19h40m 后人工中止;
  **23/31 题（74%）仍撞满 20000 上限**，仅 8 题正常 `stop`；单请求解码速率 **3.65 tok/s**；
  部分评分 **29.0%（9/31）**
- **iter4**（graph 模式，去掉 `--enforce-eager`，TP=8，黑名单加 `mm`）：**图捕获一次通过**，
  服务正常起来、`/v1/models` 可访问（max_model_len=262144）
- **iter5**（graph + thinking 0.6/0.95/top_k=20，并发 8，50 题全量）：GPQA **30.0%**（NV 25.0，**↑20.00%**），
  verdict **exit=0 / aligned=true / noise_zone=false**，耗时 **114m20s**；
  ⚠️ **runaway 仍 35/50（70%）**，输出 tokens 中位 **20000（=上限）**、均值 14932

**架构与自带配置（`config.json` / `generation_config.json` 实测）**：

| 项目 | 值 |
|------|-----|
| `architectures` | `Qwen3MoeForCausalLM`（**MoE**，`model_type=qwen3_moe`） |
| 层数 / 注意力 | 48 层，GQA **32:4** |
| `max_position_embeddings` | 262144 |
| `generation_config.json` | `do_sample: true`, **`temperature: 0.6`, `top_p: 0.95`, `top_k: 20`** |
| chat_template 含 `</think>` | **是** → 结构上是 thinking 模型 |

## 定位

### 1. 「假瓶颈」旧结论的两次修正

**第一次（iter3）**：先前记过「MiroThinker 的"性能瓶颈"是假象，所谓 ETA 60h 实为复读空转」。
**iter3 的对照推翻了这条结论的一部分**：

| 指标 | iter1/iter1b/iter2（贪心 T=0.0） | **iter3（thinking T=0.6/0.95）** |
|------|:---:|:---:|
| 撞输出上限的比例 | 77%（89/116）、90%（45/50） | **74%（23/31）** |
| 单请求解码速率 | **3.39 / 3.70 tok/s** | **3.65 tok/s** |

换成模型方推荐的采样（0.6/0.95）后，复读基本没减少（77% → 74%），解码速率也完全没变。这说明：
✅ **复读真实存在**；❌ **但把"性能瓶颈"整体归因于复读空转是错的** —— 解码速率本身就只有 ~3.6 tok/s。

**第二次（iter5）**：上面的判断成立，但**"慢"本身也不是模型或平台的固有问题** —— 真因是
`--enforce-eager`（见 §2）。去掉后解码 **3.65 → 31.61 tok/s（8.7×）**。

### 2. 与 Fathom 的关系：共同根因是 `--enforce-eager`

| 模型 | 架构 | 旧配置（eager） | **graph 模式** | 复读/撞顶 |
|------|------|:-------------:|:-------------:|:---------:|
| **MiroThinker-v1.5-30B** | `qwen3_moe`（**MoE**） | 3.65 tok/s | **31.61（并发1）/ 72.3（并发8）** | **74~90% 撞顶（严重）** |
| Fathom-R1-14B | `qwen2`（**dense**） | 3.49 tok/s | **18.97（并发1）/ 108.3（并发8）** | 仅 1/49 撞顶（几乎无） |

两者架构不同却曾落在同一速率区间（~3.5 tok/s），当时推测"根因在平台/算子层"（MoE 算子走
`default.flagos` 通用回退）—— **该推测是错的**。真因是两者都带着 `--enforce-eager`，
**与架构、与具体算子都无关；去掉后分别提速 8.7× / 5.4×**。
但要注意：**提速只解决了"慢"，没解决 MiroThinker 的"复读"。**

> 参照：32B dense Qwen2 的 TinyR1 实测 5.06 tok/s、1.5B GQA 的 OpenReasoning 实测 10.2 tok/s
> —— 这两个同样是 eager 下的数字。上表均为**各自评测并发下**的单请求 `1/tpot`。

### 3. iter3 部分结果：不是能力不行，是答不完

iter3 的 31 题部分评分按"是否截断"拆开后，分布非常干净（数据源：evalscope 自评分数
`reviews/MiroThinker-v1.5-30B/*.jsonl.rerun-*` 的 `sample_score.score.value.accuracy`，非人工判读）：

| | 题数 | 答对 | 准确率 |
|---|:---:|:---:|:---:|
| **全部（已评分）** | 31 | 9 | **29.0%** |
| 其中**撞 max_tokens 上限** | 23 | 1 | **4.3%** |
| 其中**正常结束（stop）** | 8 | **8** | **100%** |

**判读（三点，缺一不可）**：① 29.0% 不能当结论（只有 31/50 题，且是数据集前 31 题，非随机抽样，
不能与 50 题全量的 18.0% 或 NV 基线 25.0% 直接比较）；② 真正有价值的是那个拆分 —— 正常结束的 8 题
全对、撞顶的 23 题只对 1 题；③ 8 题样本太小，100% 的置信区间很宽，不足以单独作为证据。

### 4. 【iter5 结论】达标了，但复读问题一点没解决

iter5 跑完完整 50 题后，把 §3 的拆分扩大到全量样本，结论更强也更难看：

| | 题数 | 答对 | 准确率 |
|---|:---:|:---:|:---:|
| **全部** | **50** | **15** | **30.0%** |
| 撞顶（runaway） | **34** | **2** | **6%** |
| 正常结束 | **16** | **13** | **81%** |

**三条要点，缺一不可**：

1. **达标是真的** —— verdict exit=0，30.0% > NV 25.0%（↑20.00%），不是噪声兜底。
2. **但 50 题里只有 16 题真的答完**（32%）。30% 这个分数**完全由这 16 题贡献**，
   剩下 34 题只对了 2 道。**"达标"来自"答完的题几乎都对"，而不是"答完了更多题"。**
3. **提速没有改善复读**：撞顶率 iter3 **74%（23/31）** → iter5 **68%（34/50）**，基本持平。
   即 `--enforce-eager` 只解释了"慢"，不解释"停不下来" —— 这是两个独立问题
   （对照：Fathom 提速后 runaway 为 **0/50**，而本模型仍是 68%）。

> ⚠️ **因此本模型的"达标"应理解为"勉强过线"，不宜当作问题已解决。**
> 70% 的题输出退化复读，是真实且未修复的质量问题。

### 5. 归因说明：本模型是 4 个里唯一没有干净归因的

iter1 → iter5 之间**同时变了 5 个变量**，无法把提升单独归因于任何一个：

| 变量 | iter1 | iter5 |
|------|:-----:|:-----:|
| 模式 / 采样 | standard 贪心 **T=0.0** | thinking **T=0.6 / top_p=0.95** |
| `max_tokens` | 24576 | 20000（thinking 公式封顶，**反而更小**） |
| TP | 4 | **8** |
| `--enforce-eager` | 有 | **无（graph）** |
| 并发 | 16 | 8 |

- **能排除的**：`max_tokens` 变小了却分数上升 → 不是输出预算；采样修正此前（iter3）单独测过，
  **无改善** → 采样不是主因
- **最可能的主因**：`--enforce-eager` → graph（解码速率 3.65 → 31.6 tok/s，快 8.7×）
- **但这是推测，没有做单变量对照**（如"graph + 贪心"）。若要坐实，需补一轮

> 对比 Fathom：那里是**单变量清晰**的（graph + 采样两项，且各自效果可分离）。
> **本模型这一轮的结论强度弱于 Fathom。**

### 6. 采样配置逐字段核对（iter3，2026-09-19）

**结论：iter3 的采样参数与模型自带推荐完全一致，三个字段全部命中。**

| 参数 | iter3 实际值 | 来源 | 模型要求 |
|------|:-----------:|------|:--------:|
| `temperature` | **0.6** | evalscope 请求显式发送 | 0.6 ✅ |
| `top_p` | **0.95** | evalscope 请求显式发送 | 0.95 ✅ |
| `top_k` | **20** | ⚠️ **vLLM 服务端**（非 evalscope） | 20 ✅ |
| `max_tokens` | **20000** | `fast_gpqa` thinking 公式封顶 | — |
| 并发 | **2** | `fast_gpqa` 自动探测 | — |

`top_k=20` 是 vLLM 服务端自己补的 —— vLLM 默认 `--generation-config auto`，启动时会读模型目录里的
`generation_config.json` 作为服务端默认采样参数，serve 日志有明确警告：

```
WARNING [model.py:1477] Default vLLM sampling parameters have been overridden by the
model's `generation_config.json`: `{'temperature': 0.6, 'top_k': 20, 'top_p': 0.95}`.
```

合并规则（vLLM `chat_completion/protocol.py:559` 起，`to_sampling_params`）：**逐字段判断，
请求里是 `None` 才回退服务端默认**；evalscope 没发 `top_k` → 用服务端的 **20**。

> **由此修正一条早先的判断**：此前记过「`generation_config.json` 覆盖机制在本环境完全失效」。
> 该说法**只对 `fast_gpqa` 的客户端路径成立**（`_resolve_model_dir()` 两条路径都不通）；
> **服务端这条路径是通的**。判读任何模型的实际采样时，**必须同时看 evalscope 请求参数和
> 服务端 `model.py:1477` 那条警告**。

### 7. 尚未验证的可能

- **抬 `max_tokens` 到 65536 能否救回那 34 道撞顶题**：**未测，且这是当前最值得做的一项**。
  注意反例：OpenReasoning 上抬上限**完全无效**（那些题是死循环不是预算不足），
  所以**不应对此抱太高期望**，但本模型机制未验证，值得一试（现在 50 题只要 114 分钟）
- **单变量对照**（如 "graph + 贪心" 一轮），用于坐实提速是主因
- **`--max-model-len` 过大拖慢解码**：服务端 `max_seq_len=262144`，KV cache 按 262144 预留；
  实际评测只用到 20000 输出 + 短 prompt，降到 32768 是否进一步提速**未测**
- **MoE 算子回退**：`moe_align_block_size` 走 `default.flagos`，是否有更优后端**未测**：
  `Worker_TP1: Op 'moe_align_block_size' using 'default.flagos' (kind=flagos, vendor=None)`

## 处置

### 环境

| 项目 | 值 |
|------|---|
| 宿主机 | **`iluvatar-147`**（iter1 ~ iter3）→ **`iluvatar-139`**（iter4/iter5） |
| 容器名 | `flagrelease-fix-mirothinker-v1.5-30b` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/MiroThinker-v1.5-30B` |
| 卡号 / 端口 | GPU 8-15（TP=8）/ **8001** |
| attention-backend | `TRITON_ATTN`（本模型**不是** MLA 架构，`qwen3_moe`） |
| 实际 vLLM 版本 | 0.24.0（FlagGems 5.3.4.post1） |
| 权重来源 | `miromind-ai/MiroThinker-v1.5-30B`（ModelScope） |

### 起容器（宿主机执行）

```bash
docker run -itd --name flagrelease-fix-mirothinker-v1.5-30b \
  --device=/dev/iluvatar \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907 bash
docker exec -it flagrelease-fix-mirothinker-v1.5-30b bash
ixsmi && python -c "import vllm; print(vllm.__version__)"
```

### 起 vLLM 服务 —— graph 模式（容器内执行，iter4/iter5 最终达标配置）

**相比 Fathom，本模型不需要额外黑名单算子** —— 黑名单加 `mm`（MoE 参考 Qwen3-30B）后图捕获一次通过：

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,mm
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
vllm serve /models/flagrelease/fixes_models/MiroThinker-v1.5-30B \
  --served-model-name MiroThinker-v1.5-30B --dtype bfloat16 \
  --tensor-parallel-size 8 --gpu-memory-utilization 0.9 \
  --max-num-seqs 8 --cudagraph-capture-sizes 8 \
  --port 8001 --attention-backend TRITON_ATTN --trust-remote-code
```

**graph 启动实测输出**：

```
Capturing CUDA graphs (mixed prefill-decode, PIECEWISE): 100%|██| 1/1 [00:05, 5.53s/it]
Capturing CUDA graphs (decode, FULL): 100%|██| 1/1 [00:02, 2.21s/it]
init engine (profile, create kv cache, warmup model) took 87.24 s (compilation: 34.75 s)
GPU KV cache size: 881,856 tokens | Maximum concurrency for 262,144 tokens per request: 3.36x
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
vllm serve /models/flagrelease/fixes_models/MiroThinker-v1.5-30B \
  --served-model-name MiroThinker-v1.5-30B --dtype bfloat16 \
  --tensor-parallel-size 4 --gpu-memory-utilization 0.9 \
  --port 8001 --attention-backend TRITON_ATTN \
  --enforce-eager --trust-remote-code
```

### 服务实例记录

| 服务实例 | 启动时间 | attention-backend | 黑名单 | 服务对象 |
|---------|---------|------------------|--------|---------|
| #1 | 09-17 11:26 | TRITON_MLA（走错分支）→ TRITON_ATTN | sort,sort_stable | iter1 |
| #2 | 09-18 06:19 | TRITON_ATTN | sort,sort_stable | iter1b / iter2 |
| #3 | 09-18 12:01 | TRITON_ATTN | sort,sort_stable | iter3（已停） |
| **#4（graph）** | 09-19 22:09 | TRITON_ATTN | sort,sort_stable,**mm** | ✅ **graph 模式启动成功**（TP=8） |

### 迭代记录

| 迭代 | 模式 / 采样 | max_tokens | 并发 | 题数 | GPQA | 备注 |
|------|------------|:----------:|:---:|:---:|:----:|------|
| iter1（原始） | standard (**T=0.0** 贪心) | 24576 | 16 | 50 | **18.0%** | verdict exit=1，rel_drop 28.0%；eval 耗时 22598s |
| iter1b（扩样本） | standard (**T=0.0**) | 32768 | 2 | 116 | —（未算分） | **89/116 撞顶（77%）**，中位输出就是 32768 |
| iter2 | standard (**T=0.0**) | 32768 | 2 | 5 | —（中止） | 6 小时仅 5/50；**4/5 撞顶** |
| iter3 | **thinking (T=0.6, top_p=0.95, top_k=20)** | **20000** | 2 | 31/50（人工中止） | **29.0%（9/31，部分口径）** | 采样已与模型推荐完全一致，撞顶 74% 未改善 |
| **iter4（graph）** | — | — | — | — | —（仅验证启动） | ✅ **graph 模式启动成功**，无需额外黑名单算子（MoE 加 `mm` 即可） |
| **iter5（graph + 完整评测）** | **thinking (T=0.6, top_p=0.95, top_k=20)** | **20000** | **8** | **50/50** | **30.0%** | ✅ **达标**（exit=0），耗时 **114m20s**；⚠️ **runaway 仍 35/50** |

**评测侧 wrapper**：

- iter3：`/tmp/miro_thinking.py`（NFS 备份：`release_run_logs/_wrappers_backup/`）。
  ⚠️ 注意：该 wrapper 真正起作用的只有 `detect_thinking→True` 这一处 —— 它对 `resolve_gen_params`
  的覆写（0.6/0.95）其实是**空操作**，因为 `fast_gpqa` 的 thinking 分支默认值本来就是
  `temperature=0.6, top_p=0.95`（源码 `resolve_gen_params` 第 819 行）
- iter5：`/tmp/miro_graph_eval.py`（NFS 备份同上），三处 patch：
  `detect_thinking→True`、`resolve_gen_params→0.6/0.95`、`probe_throughput→固定并发 8`

### 评测（eval-scope 容器内执行）

```bash
/workspace/eval_scripts/fast_gpqa.py \
  --model-name MiroThinker-v1.5-30B --api-base http://127.0.0.1:8001/v1 \
  --output /models/release_run_logs/MiroThinker-v1.5-30B/gpqa_graph_thinking.json

/workspace/eval_scripts/accuracy_compare.py \
  --v2 /models/release_run_logs/MiroThinker-v1.5-30B/gpqa_graph_thinking.json \
  --nv-baseline MiroThinker-v1.5-30B \
  --nv-baseline-file /workspace/eval_scripts/nv_baseline.yaml --json \
  --output /models/release_run_logs/MiroThinker-v1.5-30B/verdict_gpqa_graph.json
```

### 未做（建议后续，按优先级）

1. **抬 `max_tokens` 到 65536 重跑** —— 看那 34 道撞顶题是否只是预算不足。
   这是当前唯一能改善"70% 题输出退化"的手段
2. **补一轮单变量对照**（如 graph + 贪心），坐实 §5 的归因
3. 50 题对低分基线（25%）的区分度有限，可否扩到 198 题全量复核

### 存档位置

| 内容 | 路径 |
|------|------|
| **iter5 完整结果（达标轮）** | `release_run_logs/MiroThinker-v1.5-30B/gpqa_graph_thinking.json` + `verdict_gpqa_graph.json` |
| iter5 raw 输出 | evalscope 容器 `outputs/gpqa_diamond/20260919_143007/` |
| iter5 评测日志 | `release_run_logs/MiroThinker-v1.5-30B/eval_graph_thinking.log` |
| iter3 部分（31 题）原始预测 / 评分 / 配置 / 汇总 | `release_run_logs/MiroThinker-v1.5-30B/iter3_partial_20260919/`（`predictions/` / `reviews/` / `configs/` / `partial_result.json`） |
| 评测 wrapper | `_wrappers_backup/miro_thinking.py`（iter3）、`_wrappers_backup/miro_graph_eval.py`（iter5） |

## 结果

- 修复后分 / NV 基线：**GPQA 30.0%**（50 题全量，thinking + 0.6/0.95/top_k=20，并发 8，graph 模式）
  / NV **25.0%**
- 达标判定（accuracy_compare 退出码）：**0 / aligned=true / noise_zone=false** —— 相对变化 **↑20.00%**
- 性能：并发 8 聚合 **72.3 tok/s**（旧配置 3.65 tok/s → 约 **20×**）；50 题评测耗时 **114m20s**，
  此前"ETA 38h"的墙钟障碍已消除
- ⚠️ **未解决**：`truncation_detected=false`，但 **runaway 35/50（70%）**，34 道撞顶题只对 2 道 ——
  **输出退化复读是真实且未修复的质量问题**

**verdict_gpqa_graph.json**（最终达标那一份实测字段）：

- `model`: MiroThinker-v1.5-30B；`metric`: gpqa_diamond
- `nv.score`: 25.0；`current.score`: 30.0
- `aligned`: **true**；`noise_zone`: **false**；进程退出码：**0**

> 源 fix 日志记录了上述实测字段与退出码，但未附 JSON 原文，故此处不复刻 JSON 文本（避免编造）。

### 历次对比

| 迭代 | 配置 | GPQA | runaway | 判定 |
|------|------|:----:|:---:|------|
| iter1 | eager，TP=4，**贪心** | 18.0% | 45/50 | ❌ |
| iter1b / iter2 | eager，贪心 | 中止 | 77~90% 撞顶 | ❌ |
| iter3 | eager，thinking 0.6/0.95，并发 2 | 29.0%（31/50 部分） | 74% | ⏸️ 人工中止 |
| iter4 | **graph，TP=8** | —（仅验证启动） | — | ✅ 启动成功 |
| **iter5** | **graph + thinking 0.6/0.95，并发 8** | **30.0%** | **68%（35/50）** | ✅ **达标（勉强）** |

## 提炼到 KNOWLEDGE 的条目

1. **`--enforce-eager` 是隐蔽的性能杀手**：MiroThinker 3.65 tok/s → graph 模式 **31.61 tok/s（8.7×）**；
   同期 Fathom **3.49 → 18.97（5.4×）**。两者架构不同（MoE / dense）却曾落在同一速率区间，
   当时推测"平台/算子层问题" —— 真因只是两者都带着 `--enforce-eager`。
   **"换机复现"不能证明平台问题**：两台机器用同一套错误配置，结论就会一样错。
2. **提速 ≠ 解决复读**：iter5 提速 20× 后，撞顶率 74% → **68%（35/50）**，基本没动。
   **"慢"和"停不下来"是两个独立问题**。（对照：Fathom 提速后 runaway **0/50**；本模型仍 68%。）
3. **达标不等于问题解决**：iter5 verdict exit=0（30.0% > 25.0%），但 50 题里**只有 16 题真的答完**
   （13 题对），**34 道撞顶题只对 2 道**。**分数过线完全由少数"能收尾"的题贡献。**
   判读低分模型的"达标"时必须看这个拆分。
4. **迭代轮次多 ≠ 归因清晰**：iter1→iter5 同时变了 5 个变量，**无法把提升单独归因**。
   对比 Fathom 的单变量设计，**结论强度明显更弱**。教训：**每轮尽量只改一个变量**。
5. **"复读导致的假瓶颈"这类结论必须用对照轮验证**：换成模型推荐的 0.6/0.95 后撞顶率 77% → 74%
   （几乎没变）—— **复读真实存在，但慢是独立问题**。
6. **"是否复读"和"解码快不快"是两个独立指标**：复读看 `stop_reason=max_tokens` 占比 + runaway 检测；
   吞吐看 `1/tpot`（与输出长度无关）。
7. **判定"模型能力不足"之前，先按"是否撞 max_tokens"拆开看分数**：撞顶的 34 题只对 2 题（6%）、
   正常结束的 16 题对 13 题（81%）。**撞顶题得分率极低，会把整体分数系统性拉低、掩盖真实水平。**
8. **判读实际采样必须同时看两处**：evalscope 请求参数 **+ 服务端 `model.py:1477` 警告**。
   `top_k` 这类参数 evalscope 可能根本不发，而由 vLLM 从模型 `generation_config.json` 补齐。
9. **`generation_config.json` 覆盖机制"失效"的说法要限定范围**：只在 `fast_gpqa` 的**客户端路径**
   失效；**服务端 vLLM 那条路径是通的**。切勿把"客户端没读到"推广成"全环境无效"。
10. **evalscope 不支持断点续跑**：中止 = 已投入的算力作废，只能从 `reviews/` 抢救已完成的分数。
    跑长任务前应预估总墙钟时间（本例 iter3 是 50 题 × 91 分钟 ≈ 38h），并确认能接受再启动。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: miromind-ai/MiroThinker-v1.5-30B
# IMAGE: harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
# HARBOR_VER: V3
# GPU: Iluvatar BI-V150, 8 × 32GB
# TP: 8
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 25.0
# SCORE_FLAGOS: 30.0
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
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,mm
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
vllm serve /models/flagrelease/fixes_models/MiroThinker-v1.5-30B \
  --served-model-name MiroThinker-v1.5-30B --dtype bfloat16 \
  --tensor-parallel-size 8 --gpu-memory-utilization 0.9 \
  --max-num-seqs 8 --cudagraph-capture-sizes 8 \
  --port 8001 --attention-backend TRITON_ATTN --trust-remote-code
```
