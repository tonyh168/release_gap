# Hygon/Magistral-Small-2506 适配与评测记录

- **日期**：`2026-09-18`
- **远端机器**：`10.232.2.21`
- **主机名**：`bm-srwl-nj-zone3-d-bw1000-64g-2-21`
- **历史失败报告**：暂无，本轮为新增模型部署及精度修复
- **历史问题类型**：精度不达标、长输出和 runaway；普通贪心口径初始 GPQA Diamond 50 题约 `48.00%`，低于 NV `62.00%`
- **模型来源**：`mistralai/Magistral-Small-2506`
- **本次处理结论**：当前 Hygon 新镜像下 TP2 服务正常；关闭 prefix cache / chunked prefill、核心 Mistral 算子不走普通 FlagGems 白名单，并按 reasoning 模型使用 `temperature=0.7`、`top_p=0.95`、`max_tokens=4096` 后，GPQA Diamond 50 题首轮得分 `62.00%`，与 NV `62.00%` 持平，按首轮结果通过

---

## 背景分析

Magistral-Small-2506 是 reasoning 模型，模型卡推荐使用采样解码，而不是普通模型的贪心解码。初始评测按普通模型处理时使用了 `temperature=0.0`，结果偏低，并且出现多道长重复输出：

```text
普通模型贪心口径：约 48.00%
服务侧优化后普通口径：约 54.00%
初始异常：7/50 题高重复并撞 max_tokens
NV 参考值：62.00%
```

排查后确认需要同时固定三类变量：

1. 评测模式按 reasoning/thinking 模型处理；
2. 按模型卡推荐使用 `temperature=0.7`、`top_p=0.95`；
3. 服务侧关闭当前 Hygon 组合下有精度影响的 prefix cache / chunked prefill，并让核心 Mistral 算子避开普通 FlagGems 替换路径。

模型目录中的 `generation_config.json` 没有提供完整采样参数，因此本轮采样参数依据模型卡推荐值，而不是简单回退到 `temperature=0.0`。

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `bm-srwl-nj-zone3-d-bw1000-64g-2-21` / `10.232.2.21` |
| 芯片 | Hygon DCU BW1000，8 × 64GB |
| 推理容器 | `flagrelease-magistral-small-2506` |
| 评测容器 | `flagrelease-model-download-20260917` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist` |
| 镜像 ID | `sha256:4b2a93440c3c8bc9230d6774c417e46e85211229696cb73b2141b1cd682758e4` |
| vLLM / PyTorch | `vllm 0.24.0+empty` / `torch 2.10.0+das.opt1.dtk2604.20260325.g6b060a` |
| EvalScope | `1.6.1` |
| 模型宿主机路径 | `/public-flash/models/flagrelease/fixes_models/Magistral-Small-2506` |
| 模型容器路径 | `/models/flagrelease/fixes_models/Magistral-Small-2506` |
| GPU | `HIP_VISIBLE_DEVICES=2,3` |
| Tensor Parallel | `2` |
| 服务端口 | `8001` |
| dtype | `bfloat16` |

## Step 0：模型配置核验

模型 `config.json` 声明：

```json
{
  "torch_dtype": "bfloat16",
  "max_position_embeddings": 40960,
  "model_type": "mistral"
}
```

模型 `generation_config.json` 主要只有 token 配置，没有明确提供：

```text
temperature
top_p
top_k
```

因此本轮采用模型卡推荐的 reasoning 生成参数：

```text
temperature=0.7
top_p=0.95
```

不能把“配置文件缺少 temperature”解释成“应该使用 temperature=0.0”。本模型在 Hygon 上已经实测证明，普通贪心口径会显著低估结果。

## Step 1：启动 vLLM 服务

实际 vLLM 进程命令：

```bash
/usr/bin/python3 /usr/local/bin/vllm serve /models/flagrelease/fixes_models/Magistral-Small-2506 \
  --served-model-name Magistral-Small-2506 \
  --host 0.0.0.0 \
  --port 8001 \
  --tensor-parallel-size 2 \
  --max-model-len 40960 \
  --dtype bfloat16 \
  --gpu-memory-utilization 0.90 \
  --trust-remote-code \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --block-size 64 \
  --no-enable-prefix-caching \
  --no-enable-chunked-prefill
```

关键环境变量：

```bash
export HIP_VISIBLE_DEVICES=2,3
export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export FLAGGEMS_DB_URL=sqlite:///:memory:
export VLLM_FL_FLAGOS_WHITELIST=add,arange_start,argmax,copy_,cos,expand,full,index,linear,lt_scalar,mm_out,ones,rand_like,randn,reciprocal,sin,softmax,softmax_out,sub,to_copy,true_divide,true_divide_,where_self,where_self_out,zero_,zeros
```

上述普通 FlagGems 白名单共 26 项。核心 Mistral/Qwen 类算子：

```text
silu_and_mul
rms_norm
rotary_embedding
```

没有加入该普通 FlagGems 白名单，按本次实测让其走 reference/native 路径。该选择是 Magistral 本模型的消融结果，不应直接套用于 Qwen 或其他模型。

健康检查：

```bash
curl http://127.0.0.1:8001/health
```

结果：HTTP `200`。

## Step 2：服务侧消融和生成模式修正

已验证的关键现象：

| 配置 | 结果 |
|------|------:|
| 普通模型、`temperature=0.0` | 约 `48.00%` |
| 服务侧优化后、普通贪心口径 | 约 `54.00%` |
| thinking 模式、`temperature=0.7`、核心算子避开 FlagGems | 10 题约 `70.00%` |
| thinking 模式、完整 50 题 | `62.00%` |

服务侧最终采用：

```text
--no-enable-prefix-caching
--no-enable-chunked-prefill
核心算子不加入普通 FlagGems 白名单
```

评测侧最终采用：

```text
thinking 模式
temperature=0.7
top_p=0.95
max_tokens=4096
eval_batch_size=4
```

`max_tokens=4096` 用于限制异常复读的最大成本，同时为正常 reasoning 链保留足够输出空间。GPQA 最终只需要选择题答案，不能让偶发 runaway 吃满 2 万到 3 万 token 的窗口。

## Step 3：评测

评测服务地址：

```text
http://127.0.0.1:8001/v1
```

评测配置：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.6.1` |
| 题数 | 50 |
| `eval_batch_size` | 4 |
| 模式 | `thinking` |
| `temperature` | `0.7` |
| `top_p` | `0.95` |
| `max_model_len` | 40960 |
| `max_tokens` | 4096 |
| prefix cache | 关闭 |
| chunked prefill | 关闭 |
| 截断检测 | 显式指定生成上限，跳过会改写上限的截断探测 |
| 评测耗时 | `4469.97s`，约 74m 30.0s |

本轮评测使用了 thinking 模式的数据过滤和回答提取逻辑，不能与普通贪心评测结果直接混为同一口径。

命令：

```bash
python3 fast_gpqa.py \
  --model-name Magistral-Small-2506 \
  --api-base http://127.0.0.1:8001/v1 \
  --api-key EMPTY \
  --dataset gpqa_diamond \
  --limit 50 \
  --eval-batch-size 4 \
  --max-tokens 4096 \
  --dataset-dir /models/day0_eval/cache/datasets \
  --output /models/release_run_logs/accuracy/fix_magistral_thinking_temp07_full50_20260918_0055/magistral_temp07_thinking_cap4096_batch4/gpqa50.json
```

结果文件：

```text
/public-flash/models/release_run_logs/accuracy/fix_magistral_thinking_temp07_full50_20260918_0055/magistral_temp07_thinking_cap4096_batch4/gpqa50.json
```

判定文件：

```text
/public-flash/models/release_run_logs/accuracy/fix_magistral_thinking_temp07_full50_20260918_0055/magistral_temp07_thinking_cap4096_batch4/verdict.json
```

结果摘要：

```json
{
  "score": 62.0,
  "evalscope_score": 62.0,
  "total_questions": 50,
  "eval_batch_size": 4,
  "max_tokens": 4096,
  "max_model_len": 40960,
  "temperature": 0.7,
  "runaway_detection": {
    "checked": 50,
    "runaway_count": 0
  },
  "answer_extraction_audit": {
    "checked": 50,
    "explicit_answer_found": 44,
    "fallback_to_evalscope": 3,
    "format_corrected_score": 62.0,
    "parser_mismatch_count": 0,
    "invalid_evalscope_extract_count": 3
  }
}
```

NV 基线：

```yaml
Magistral-Small-2506:
  metrics:
    gpqa_diamond: 62
```

对比结果：

| 项目 | 值 |
|------|---:|
| Hygon 当前结果 | `62.00%` |
| NV 基线 | `62.00%` |
| 绝对差 | `0` 个百分点 |
| 50 题折算差异 | `0` 题 |
| 相对退化 | `0.00%` |
| 首轮判定 | 通过 |

`accuracy_compare.py` 判定：

```json
{
  "aligned": true,
  "noise_zone": false,
  "rel_drop_pct": 0.0,
  "abs_diff": 0.0,
  "message": "精度达标: 当前=62.00%, NV=62.00%, 相对退化=0.00%"
}
```

## 稳定性复测

本文件按用户指定，以首轮 `62.00%` 作为通过配置记录。但同参数后续稳定性复测结果为：

| 轮次 | 得分 | runaway | 结论 |
|------|-----:|--------:|------|
| 首轮通过轮次 | `62.00%` | `0/50` | 与 NV 持平 |
| 稳定性复测 | `52.00%` | `1/50` | 低于 NV `10` 个百分点，不通过 |

因此当前结论应写成：

```text
该配置存在首轮与 NV 持平的通过证据，但在 temperature=0.7 的随机采样口径下，50 题重复评测尚未证明精度稳定通过。
```

## 当前结果

- 服务：正常，GPU `2,3`，端口 `8001`
- dtype：`bfloat16`
- GPQA Diamond 首轮：`62.00%`
- NV 参考值：`62.00%`
- 首轮判定：通过
- 首轮 runaway：`0/50`
- 稳定性复测：`52.00%`，未通过
- 性能验收：本次未单独重测

## 可复用规则

1. Magistral 不能按普通模型默认 `temperature=0.0` 评测；模型卡和 reasoning 行为必须纳入评测模式判断。
2. `generation_config.json` 缺少采样字段时，不能静默把模型当作贪心模型，应使用模型卡推荐参数并在结果中明确记录。
3. prefix cache / chunked prefill 和核心算子路径必须通过固定并发、固定 prompt 和固定生成参数做受控 A/B，不能仅凭一次分数归因。
4. `max_tokens=4096` 是 GPQA 选择题的评测窗口控制，不代表模型的通用服务上限；需要同时审计截断、runaway 和答案提取。
5. `temperature=0.7` 下单轮 50 题结果可能波动较大，发布验收应补充多轮或全量数据集评测。
