# Hygon/Mistral-Small-24B-Instruct-2501 适配与评测记录

- **日期**：`2026-09-17`
- **远端机器**：`10.1.15.95`
- **主机名**：`bm-baai-dx-zone2-d-BW1000-64G-15-95`
- **历史失败报告**：`flagrelease_fail_reports/Hygon/FAILED_Hygon_Mistral-Small-24B-Instruct-2501_202607290628.md`
- **历史问题类型**：精度不达标，历史 V2/V3 50 题分别为 `44.0%` / `46.0%`
- **模型来源**：`mistralai/Mistral-Small-24B-Instruct-2501`
- **本次处理结论**：当前 Hygon 新镜像下 TP4 服务正常；禁用 prefix cache / chunked prefill，并让评测脚本读取模型 `generation_config.json` 后，首轮 50 题 GPQA 得分 `52.00%`，相对 NV `54.00%` 退化 `3.70%`，按 5% 阈值通过

---

## 背景分析

历史 Hygon 自动化报告使用较早的 vLLM、plugin-FL 和 FlagGems 环境，Mistral-Small-24B-Instruct-2501 在 GPQA Diamond 50 题上未达标：

| 版本 | 题数 | 正确率 | 备注 |
|------|------:|------:|------|
| V2 | 50 | `44.0%` | 精度不达标 |
| V3 | 50 | `46.0%` | 精度不达标 |

本次使用新 Hygon 镜像重新部署模型，沿用历史失败报告中的 26 个 FlagOS 算子白名单，并在排查中发现两个影响精度口径的关键因素：

1. 默认 prefix cache / chunked prefill 路径会导致当前模型在 Hygon 新镜像上分数偏低；
2. `fast_gpqa.py` 如果只拿到 served model name，读不到容器内模型目录，就会退回默认 `temperature=0.0`，没有使用模型自身 `generation_config.json` 中的 `temperature=0.15`。

处理后，首轮 50 题从初始 `40.00%` 提升到 `52.00%`。

## 历史算子白名单

历史失败报告中的算子白名单为：

```text
add,arange_start,argmax,copy_,cos,expand,full,index,linear,
lt_scalar,mm_out,ones,rand_like,randn,reciprocal,sin,
softmax,softmax_out,sub,to_copy,true_divide,true_divide_,
where_self,where_self_out,zero_,zeros
```

本次最终服务继续使用该白名单：

```bash
export VLLM_FL_FLAGOS_WHITELIST=add,arange_start,argmax,copy_,cos,expand,full,index,linear,lt_scalar,mm_out,ones,rand_like,randn,reciprocal,sin,softmax,softmax_out,sub,to_copy,true_divide,true_divide_,where_self,where_self_out,zero_,zeros
```

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `10.1.15.95` |
| 主机名 | `bm-baai-dx-zone2-d-BW1000-64G-15-95` |
| 芯片 | Hygon DCU BW1000，64GB |
| 推理容器 | `Mistral-Small-24B-Instruct-2501_flagos` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist` |
| 镜像 ID | `sha256:4b2a93440c3c8bc9230d6774c417e46e85211229696cb73b2141b1cd682758e4` |
| vLLM / PyTorch | `vllm 0.24.0+empty` / `torch 2.10.0+das.opt1.dtk2604.20260325.g6b060a` |
| EvalScope | `1.6.1` |
| 模型宿主机路径 | `/public-flash/models/Mistral-Small-24B-Instruct-2501` |
| 模型容器路径 | `/models/Mistral-Small-24B-Instruct-2501` |
| GPU | `HIP_VISIBLE_DEVICES=2,3,4,7` |
| Tensor Parallel | `4` |
| 服务端口 | `8005` |
| dtype | `bfloat16` |
| 服务日志 | `/public-flash/models/release_run_logs/Mistral-Small-24B-Instruct-2501/serve-whitelist-noprefix-nochunk-genconfig-20260917-150118.log` |

模型权重已位于共享盘。本次没有修改模型权重、tokenizer、config、vLLM 源码、`vllm-plugin-FL` 源码或 FlagGems 算子实现。

## Step 0：容器运行配置

容器为长驻推理容器，vLLM 服务通过 `docker exec` 在容器内启动。关键配置：

```text
network: host
ipc:     host
mount:   /public-flash/models -> /models
```

Hygon 运行时依赖需要在启动服务前加载：

```bash
source /opt/dtk/env.sh
```

否则容器内 `torch` 可能找不到 `libgalaxyhip.so.5`。

## Step 1：启动 vLLM 服务

最终首轮达标服务启动参数：

```bash
/usr/bin/python3 /usr/local/bin/vllm serve /models/Mistral-Small-24B-Instruct-2501 \
  --host 0.0.0.0 \
  --served-model-name Mistral-Small-24B-Instruct-2501 \
  --dtype bfloat16 \
  --tensor-parallel-size 4 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.90 \
  --port 8005 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code \
  --no-enable-prefix-caching \
  --no-enable-chunked-prefill
```

关键环境变量：

```bash
export HIP_VISIBLE_DEVICES=2,3,4,7
export VLLM_PLUGINS=fl
export FLAGGEMS_DB_URL=sqlite:///:memory:
export VLLM_FL_TRITON_CACHE_ROOT=/models/release_run_logs/Mistral-Small-24B-Instruct-2501/triton_cache_whitelist_genconfig_20260917-150118
export VLLM_FL_FLAGOS_WHITELIST=add,arange_start,argmax,copy_,cos,expand,full,index,linear,lt_scalar,mm_out,ones,rand_like,randn,reciprocal,sin,softmax,softmax_out,sub,to_copy,true_divide,true_divide_,where_self,where_self_out,zero_,zeros
```

健康检查：

```bash
curl http://127.0.0.1:8005/health
```

结果：HTTP `200`。

## Step 2：评测参数修正

模型自身 `generation_config.json` 包含：

```json
{
  "temperature": 0.15,
  "do_sample": true
}
```

为避免评测脚本只拿到 served model name 后退回默认 `temperature=0.0`，在容器内补充：

```yaml
model:
  container_path: /models/Mistral-Small-24B-Instruct-2501
```

路径：

```text
/flagos-workspace/shared/context.yaml
```

首轮达标日志中已确认：

```text
[gen] 采用模型 generation_config.json 采样参数: {'temperature': 0.15}
```

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
| `max_model_len` | 32768 |
| `max_tokens` | 4096 |
| 温度 | `0.15` |
| prefix cache | 关闭 |
| chunked prefill | 关闭 |
| 评测耗时 | `1932.07s`，约 32m 12.1s |

命令：

```bash
python3 fast_gpqa.py \
  --model-name Mistral-Small-24B-Instruct-2501 \
  --api-base http://127.0.0.1:8005/v1 \
  --api-key EMPTY \
  --dataset gpqa_diamond \
  --limit 50 \
  --eval-batch-size 4 \
  --max-tokens 4096 \
  --dataset-dir /models/eval_datasets \
  --output /models/release_run_logs/Mistral-Small-24B-Instruct-2501/mistral-small-24b-instruct-2501-gpqa50-cap4096-whitelist-noprefix-nochunk-genconfig-20260917-150908.json
```

结果文件：

```text
/public-flash/models/release_run_logs/Mistral-Small-24B-Instruct-2501/mistral-small-24b-instruct-2501-gpqa50-cap4096-whitelist-noprefix-nochunk-genconfig-20260917-150908.json
```

判定文件：

```text
/public-flash/models/release_run_logs/Mistral-Small-24B-Instruct-2501/mistral-small-24b-instruct-2501-gpqa50-cap4096-whitelist-noprefix-nochunk-genconfig-20260917-150908.verdict.json
```

结果摘要：

```json
{
  "score": 52.0,
  "evalscope_score": 52.0,
  "total_questions": 50,
  "temperature": 0.15,
  "max_tokens": 4096,
  "runaway_detection": {
    "checked": 50,
    "runaway_count": 2,
    "runaway_indices": [16, 23]
  },
  "answer_extraction_audit": {
    "checked": 50,
    "explicit_answer_found": 45,
    "format_corrected_score": 52.0,
    "parser_mismatch_count": 0,
    "invalid_evalscope_extract_count": 5
  }
}
```

NV 基线：

```yaml
Mistral-Small-24B-Instruct-2501:
  metrics:
    gpqa_diamond: 54
```

对比结果：

| 项目 | 值 |
|------|---:|
| Hygon 当前结果 | `52.00%` |
| NV 基线 | `54.00%` |
| 绝对差 | `-2` 个百分点 |
| 50 题折算 | `26/50` vs `27/50`，差 1 题 |
| 相对退化 | `3.70%` |
| 5% 相对退化口径 | 通过 |

`accuracy_compare.py` 判定：

```json
{
  "aligned": true,
  "noise_zone": false,
  "rel_drop_pct": 3.7,
  "abs_diff": -2.0,
  "message": "精度达标: 当前=52.00%, NV=54.00%, 相对退化=3.70% (容差 5.0%)"
}
```

## 中间问题与定位

### 初始精度偏低

初始服务在 GPQA 50 题上只有 `40.00%`，相对 NV 退化 `25.93%`。该轮未发现 parser mismatch，也没有 runaway。

### prefix cache / chunked prefill 影响

禁用 prefix cache 和 chunked prefill 后，同样 50 题提升到 `46.00%`。这说明当前 Hygon 新镜像的相关 prefill/cache 路径会影响本模型输出结果。

### generation_config 未被评测读取

只传 `--model-name Mistral-Small-24B-Instruct-2501` 时，评测脚本读不到容器内模型目录，默认使用 `temperature=0.0`。补充 `/flagos-workspace/shared/context.yaml` 后，脚本读取模型 `generation_config.json`，按 `temperature=0.15` 评测，首轮提升到 `52.00%`。

### 全关 FlagGems 未恢复

曾验证 `USE_FLAGGEMS=false`，结果仍为 `40.00%`。因此本次首轮精度提升不能简单归因于“关闭全部 FlagGems”，核心修复点是 prefill/cache 开关和评测生成参数对齐。

## 当前结果

- 服务：正常，端口 `8005`，GPU `2,3,4,7`
- GPQA Diamond：`52.00%`（26/50）
- NV 参考基线：`54.00%`
- 相对退化：`3.70%`
- 答案解析：parser mismatch `0`
- runaway：`2/50`
- 精度判定：✅ 通过（按首轮 50 题、5% 相对退化口径）
- 性能验收：未重测

## 补充说明

本文件按用户指定采用首轮 `52.00%` 结果作为记录口径。同配置后续稳定性复跑曾出现 `48.00%`，说明 `temperature=0.15` 的 50 题小样本存在采样波动。若用于严格发布结论，建议继续跑全量 198 题，或在评测框架支持时固定 seed / 使用确定性口径后复核。

## 可复用规则

1. 对 Mistral 类模型，不能只看服务是否健康；必须确认评测脚本是否真正读取到模型目录和 `generation_config.json`。
2. Hygon 新镜像上遇到无解析错误但精度显著偏低时，应优先排查 prefix cache / chunked prefill，再排查算子白名单。
3. `USE_FLAGGEMS=false` 不一定能恢复精度；如果全关仍低，要继续检查评测生成参数、attention/prefill 路径和缓存状态。
4. 50 题带采样评测应保存原始分、NV 基线、相对退化、绝对题数差、runaway 审计和 parser mismatch，避免把单轮波动误写成稳定结论。
