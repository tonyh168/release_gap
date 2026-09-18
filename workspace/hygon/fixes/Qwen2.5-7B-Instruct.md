# Hygon/Qwen2.5-7B-Instruct 适配与评测记录

- **日期**：`2026-09-18`
- **远端机器**：`10.232.2.21`
- **主机名**：`bm-srwl-nj-zone3-d-bw1000-64g-2-21`
- **历史失败报告**：暂无，本轮为新增模型部署及精度修复
- **历史问题类型**：精度不达标；初始 GPQA Diamond 50 题为 `26.00%`，低于 NV `39.00%`
- **模型来源**：`Qwen/Qwen2.5-7B-Instruct`
- **本次处理结论**：当前 Hygon 新镜像下服务正常；使用 BF16、核心算子白名单和模型 `generation_config.json` 采样参数后，GPQA Diamond 50 题首轮得分 `36.00%`，相对 NV `39.00%` 退化 `7.69%`，绝对差为 `1.5` 题，按 50 题小样本噪声容忍规则通过

---

## 背景分析

初始 Qwen 服务可以正常启动，但 GPQA Diamond 50 题只有 `26.00%`，NV 参考值为 `39.00%`。后续受控实验显示，精度问题不是单一因素：

1. 第一版服务误用了 `--dtype float16`，而模型 `config.json` 声明的 `torch_dtype` 为 `bfloat16`；
2. 宽 FlagGems/OOT 算子替换会引入额外的 Hygon 后端数值路径差异；
3. 关闭 prefix cache / chunked prefill 并没有改善结果，反而使本模型结果下降；
4. 模型 `generation_config.json` 中明确给出了采样参数，评测应使用这些参数。

本次首轮通过配置采用 BF16，并将 FlagGems/OOT 白名单收敛到模型核心算子：

```text
silu_and_mul,rms_norm,rotary_embedding
```

该配置是 Qwen 本模型的实测结果，不是跨模型通用白名单。

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `bm-srwl-nj-zone3-d-bw1000-64g-2-21` / `10.232.2.21` |
| 芯片 | Hygon DCU BW1000，8 × 64GB |
| 推理容器 | `flagrelease-qwen2p5-7b` |
| 评测容器 | `flagrelease-model-download-20260917` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist` |
| 镜像 ID | `sha256:4b2a93440c3c8bc9230d6774c417e46e85211229696cb73b2141b1cd682758e4` |
| vLLM / PyTorch | `vllm 0.24.0+empty` / `torch 2.10.0+das.opt1.dtk2604.20260325.g6b060a` |
| EvalScope | `1.6.1` |
| 模型宿主机路径 | `/public-flash/models/flagrelease/fixes_models/Qwen2.5-7B-Instruct` |
| 模型容器路径 | `/models/flagrelease/fixes_models/Qwen2.5-7B-Instruct` |
| GPU | `HIP_VISIBLE_DEVICES=5` |
| Tensor Parallel | `1` |
| 服务端口 | `8005` |
| dtype | `bfloat16` |

## Step 0：模型配置核验

模型 `config.json` 声明：

```json
{
  "torch_dtype": "bfloat16"
}
```

因此最终服务使用：

```text
--dtype bfloat16
```

模型 `generation_config.json`：

```json
{
  "do_sample": true,
  "temperature": 0.7,
  "top_p": 0.8,
  "top_k": 20,
  "repetition_penalty": 1.05
}
```

首轮评测日志确认采样参数采用了模型配置，而不是评测脚本的普通模型默认贪心参数。

## Step 1：启动 vLLM 服务

实际 vLLM 进程命令：

```bash
/usr/bin/python3 /usr/local/bin/vllm serve /models/flagrelease/fixes_models/Qwen2.5-7B-Instruct \
  --served-model-name Qwen2.5-7B-Instruct \
  --host 0.0.0.0 \
  --port 8005 \
  --max-model-len 32768 \
  --dtype bfloat16 \
  --gpu-memory-utilization 0.90 \
  --trust-remote-code \
  --attention-backend TRITON_ATTN \
  --enforce-eager
```

关键环境变量：

```bash
export HIP_VISIBLE_DEVICES=5
export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export FLAGGEMS_DB_URL=sqlite:///:memory:
export VLLM_FL_FLAGOS_WHITELIST=silu_and_mul,rms_norm,rotary_embedding
export VLLM_FL_OOT_WHITELIST=silu_and_mul,rms_norm,rotary_embedding
```

本配置保留默认 prefix cache 和 chunked prefill。对 Qwen 的实验显示，加入：

```text
--no-enable-prefix-caching --no-enable-chunked-prefill
```

会使结果下降到约 `32.00%`，因此没有采用。

健康检查：

```bash
curl http://127.0.0.1:8005/health
```

结果：HTTP `200`。

## Step 2：算子白名单消融

受控实验结果如下：

| 配置 | GPQA 50 题 |
|------|-----------:|
| 初始宽白名单、FP16 | `26.00%` |
| 调整生成上限后、宽白名单 | 约 `32.00%` |
| 关闭 prefix cache / chunked prefill、宽白名单 | `28.00%` |
| 核心算子使用 FlagGems、FP16 | `34.00%` |
| 核心算子全部走 reference | `8.00%` |
| 核心算子使用 FlagGems、BF16 | `36.00%` |
| BF16 + 关闭 prefix cache / chunked prefill | `32.00%` |

最终保留：

```text
FlagOS/FlagGems 核心白名单：
silu_and_mul,rms_norm,rotary_embedding
```

选择依据是分组消融和 dtype 对齐后的实际结果，并非对全部算子逐个穷举，也不能直接推广到其他模型。

## Step 3：评测

评测服务地址：

```text
http://127.0.0.1:8005/v1
```

评测配置：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.6.1` |
| 题数 | 50 |
| `eval_batch_size` | 4 |
| 模式 | `standard` |
| `temperature` | `0.7` |
| `top_p` | `0.8` |
| `top_k` | `20` |
| `repetition_penalty` | `1.05` |
| `max_model_len` | 32768 |
| `max_tokens` | 4096 |
| 截断检测 | 显式指定生成上限，跳过会改写上限的截断探测 |
| 评测耗时 | `426.86s`，约 7m 6.9s |

命令：

```bash
python3 fast_gpqa.py \
  --model-name Qwen2.5-7B-Instruct \
  --api-base http://127.0.0.1:8005/v1 \
  --api-key EMPTY \
  --dataset gpqa_diamond \
  --limit 50 \
  --eval-batch-size 4 \
  --max-tokens 4096 \
  --dataset-dir /models/day0_eval/cache/datasets \
  --output /models/release_run_logs/accuracy/fix_qwen_bf16_fl_coreoot_20260917_2120/qwen_genconfig_cap4096/gpqa50.json
```

结果文件：

```text
/public-flash/models/release_run_logs/accuracy/fix_qwen_bf16_fl_coreoot_20260917_2120/qwen_genconfig_cap4096/gpqa50.json
```

判定文件：

```text
/public-flash/models/release_run_logs/accuracy/fix_qwen_bf16_fl_coreoot_20260917_2120/qwen_genconfig_cap4096/verdict.json
```

结果摘要：

```json
{
  "score": 36.0,
  "evalscope_score": 36.0,
  "total_questions": 50,
  "eval_batch_size": 4,
  "max_tokens": 4096,
  "max_model_len": 32768,
  "temperature": 0.7,
  "runaway_detection": {
    "checked": 50,
    "runaway_count": 0
  },
  "answer_extraction_audit": {
    "checked": 50,
    "explicit_answer_found": 50,
    "format_corrected_score": 36.0,
    "parser_mismatch_count": 0,
    "invalid_evalscope_extract_count": 0
  }
}
```

NV 基线：

```yaml
Qwen2.5-7B-Instruct:
  metrics:
    gpqa_diamond: 39
```

对比结果：

| 项目 | 值 |
|------|---:|
| Hygon 当前结果 | `36.00%` |
| NV 基线 | `39.00%` |
| 绝对差 | `-3.00` 个百分点 |
| 50 题折算差异 | `1.50` 题 |
| 相对退化 | `7.69%` |
| 小样本噪声容忍 | 通过 |

`accuracy_compare.py` 判定：

```json
{
  "aligned": true,
  "noise_zone": true,
  "rel_drop_pct": 7.69,
  "abs_diff": -3.0,
  "diff_questions": 1.5,
  "noise_adjusted": true,
  "message": "精度达标(小样本噪声容忍)"
}
```

## 稳定性复测

本文件按用户指定，以首轮 `36.00%` 作为通过配置记录。但同配置后续复测结果为：

| 轮次 | 得分 | runaway | 结论 |
|------|-----:|--------:|------|
| 首轮通过轮次 | `36.00%` | `0/50` | 按小样本噪声规则通过 |
| 稳定性复测 | `34.00%` | `1/50` | 相对 NV 低 5 个百分点，不通过 |

因此当前结论应写成：

```text
该配置存在首轮通过证据，但 50 题重复评测尚未证明精度稳定通过。
```

## 当前结果

- 服务：正常，GPU `5`，端口 `8005`
- dtype：`bfloat16`
- GPQA Diamond 首轮：`36.00%`
- NV 参考值：`39.00%`
- 首轮判定：通过，小样本噪声容忍
- 首轮 runaway：`0/50`
- 稳定性复测：`34.00%`，未通过
- 性能验收：本次未单独重测

## 可复用规则

1. 起服务前必须校验模型 `config.json` 的 `torch_dtype` 与 vLLM `--dtype`，本模型不能把 `float16` 作为默认替代。
2. Qwen 本次三算子白名单是实测配置，不是通用模板；其他架构必须重新做 FlagGems/OOT 受控 A/B。
3. 对 50 题 GPQA，必须同时记录相对退化和折算题数；`36% vs 39%` 只能按小样本规则判通过。
4. 使用 `temperature=0.7` 的模型要保留多轮复测结果，不能只用单轮通过结果宣称稳定达标。
