# T-Head/Magistral-Small-2506 适配与评测记录

- **日期**：`2026-09-20`
- **远端机器**：`244-pm-aliyun-wlcb-zoned-d-810e-96G`（`8.130.132.221`）
- **主机名**：`dsw-879515-f5bf65bfd-jd7bj`
- **历史问题类型**：GPQA 精度不达标、reasoning 模式未自动识别、长输出与 runaway
- **模型来源**：`mistralai/Magistral-Small-2506`
- **本次处理结论**：T-Head TP2 服务正常；按模型 README 使用 reasoning prompt、`temperature=0.7`、`top_p=0.95`，限制核心 Mistral 算子替换并关闭 prefix cache/chunked prefill 后，GPQA Diamond 50 题得到 `68.00%`，高于 NV `62.00%`，精度通过

---

## 背景分析

Magistral-Small-2506 是 reasoning 模型。初始 T-Head 评测按普通模型或不完整的 thinking 配置运行，可信的 50 题结果长期集中在 `40.00%–48.00%`，低于 NV 基线 `62.00%`。

模型 README 推荐 `temperature=0.7`、`top_p=0.95`，但 `generation_config.json` 没有相应字段；原 `fast_gpqa.py` 的 `THINKING_PATTERNS` 也没有 `magistral`，不能依赖配置文件或通用模型名检测得到正确模式。

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `244-pm-aliyun-wlcb-zoned-d-810e-96G` / `8.130.132.221` |
| 芯片 | PPU-ZW810E，16 × 96GB |
| 推理容器 | `flagrelease_thead_magistral_mistralfmt_20260917` |
| 评测容器 | `flagrelease_thead_eval_20260915` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100` |
| vLLM / PyTorch | `vllm 0.24.0+empty` / `torch 2.10.0` |
| EvalScope | `1.5.1` |
| 模型路径 | `/models/Magistral-Small-2506` |
| GPU / TP / 端口 | `12,13` / `2` / `18088` |
| dtype / max_model_len | `bfloat16` / `40960` |

## Step 0：模型与采样参数核验

模型配置为 `model_type=mistral`、`torch_dtype=bfloat16`、`max_position_embeddings=40960`。README 明确给出 `temperature=0.7`、`top_p=0.95`；`generation_config.json` 未携带采样参数，因此将 README 作为依据，不能把字段缺失解释为使用 `temperature=0.0`。

## Step 1：启动 vLLM 服务

```bash
/usr/local/bin/vllm serve /models/Magistral-Small-2506 \
  --served-model-name Magistral-Small-2506 \
  --host 0.0.0.0 --port 18088 \
  --dtype bfloat16 --tensor-parallel-size 2 \
  --max-model-len 40960 --gpu-memory-utilization 0.90 \
  --trust-remote-code --enforce-eager \
  --tokenizer-mode mistral --config-format mistral --load-format mistral \
  --tool-call-parser mistral --enable-auto-tool-choice \
  --no-enable-prefix-caching --no-enable-chunked-prefill
```

关键算子配置：

```bash
export VLLM_FL_FLAGOS_WHITELIST=arange_start,argmax,exponential_,lt_scalar,rand_like,randn,softmax,softmax_out,where_self,where_self_out,attention_backend
export VLLM_FL_OOT_BLACKLIST=silu_and_mul,rms_norm,rotary_embedding
```

日志确认 `attention_backend` 使用 FlagOS；`rms_norm`、`silu_and_mul`、`rotary_embedding` 避开替换。这三类算子分别影响归一化尺度、MLP 门控和位置信息，长推理链会放大逐层误差。

## Step 2：评测脚本修复

修改远端 `/models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods/fast_gpqa.py`，本地完整留档为 `workspace/t-head/fixes/fast_gpqa.py`：

1. 将 `magistral` 加入 `THINKING_PATTERNS`；
2. 对 Magistral 固定 README 推荐的 `temperature=0.7`、`top_p=0.95`；
3. 注入 `<think>...</think>` reasoning prompt，要求末行输出 `ANSWER: [LETTER]`；
4. 保留答案抽取审计和 runaway 检测。

远端原脚本备份：

```text
/models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods/fast_gpqa.py.bak_20260920_magistral_fix
SHA-256: 122b4dcce66f21f4f3ab8d6e70b2828d5eae4e9f91ea5d24aef11ea7582ac3bb
```

## Step 3：消融结果

| 配置 | 题数 | 得分 | 结论 |
|------|----:|----:|------|
| 初始普通配置 | 50 | `40.00%` | 未通过 |
| Mistral 格式、4096 tokens | 50 | `48.00%` | 未通过 |
| 0.7/0.95、核心算子规避、4096 tokens | 50 | `48.00%` | 未通过，`1/50` runaway |
| reasoning prompt、16384 tokens | 8 | `87.50%` | 小样本信号 |
| reasoning prompt、39000 tokens | 8 | `37.50%` | 窗口过大无收益 |
| batch=1、4096 tokens | 8 | `62.50%` | `1/8` runaway，并发不是根因 |
| 最终配置 | 50 | `68.00%` | 通过 |

## Step 4：正式评测

| 项目 | 值 |
|------|---|
| 数据集 / 题数 | GPQA Diamond / 50 |
| 模式 | thinking/reasoning |
| temperature / top_p | `0.7` / `0.95` |
| max_tokens / batch | `16384` / `2` |
| 评测耗时 | `9409.37s` |
| 截断检测 | 显式指定生成上限，未执行自动翻倍探测 |

结果文件：

```text
/models/_eval_results/20260920_magistral_fix/50_readme_prompt_16384/Magistral-Small-2506_gpqa_result.json
```

```json
{
  "score": 68.0,
  "evalscope_score": 68.0,
  "total_questions": 50,
  "temperature": 0.7,
  "max_tokens": 16384,
  "eval_batch_size": 2,
  "eval_duration_seconds": 9409.37,
  "runaway_count": 3,
  "runaway_indices": [3, 36, 45],
  "explicit_answer_found": 47,
  "parser_mismatch_count": 0
}
```

## 现象

- 最终原始分与答案审计分均为 `68.00%`，提分不是后处理“捞分”；
- 仍有 `3/50` runaway，其中题号 36、45 撞到 `max_tokens`；
- 8 题结果在 `37.50%–87.50%` 间波动，不能用小样本宣布完成。

## 定位

问题由多项配置错配共同造成：Magistral 未识别为 reasoning 模型、采样参数回退不合理、缺少训练口径对应的 prompt、核心算子与 prefix/chunked 路径增加数值偏差风险，以及输出窗口选择不当。

## 处置

1. 固定 reasoning 模式、官方采样参数和 prompt；
2. 使用 `max_tokens=16384`、`eval_batch_size=2`；
3. 关闭 prefix cache 和 chunked prefill；
4. 核心 Mistral 算子避开 FlagGems，保留 attention FlagOS 路径；
5. 以 50 题结果及答案/runaway 审计作为结论。

## 当前结果

- 服务：正常，端口 `18088`，GPU12、13，TP2
- GPQA：`68.00%`（34/50），NV `62.00%`
- 相对退化：`-9.68%`，实际提升
- 精度判定：✅ 通过
- 生成稳定性：仍有 `3/50` runaway
- 性能验收：本次未单独重测

## 可复用规则

Reasoning 模型自动化应维护“模型族 → reasoning 检测、推荐采样参数、prompt、输出窗口、算子策略”的显式映射；必须先做单变量消融，再跑至少 50 题，并同时记录原始分、答案抽取、runaway 和 NV 对比。
