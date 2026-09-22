# Ascend/Phi-3-vision-128k-instruct 适配与评测记录

- **日期**：`2026-09-20`
- **远端机器**：`10.55.0.173`
- **主机名**：`bm-jn-zs-zone1-910C-64G-10-117`
- **模型来源**：`microsoft/Phi-3-vision-128k-instruct`
- **本次处理结论**：指定 Ascend vLLM 0.20.2/plugin-FL 0.2.0 基础镜像下，模型以 BF16、TP=2、131072 上下文成功部署；纯文本和真实 PNG 图片请求均通过；GPQA Diamond 50 题得分 `24.00%`，相对 NV `25.00%` 退化 `4.00%`，在 5% 容差内判定通过

---

## 背景分析

`Phi-3-vision-128k-instruct` 是视觉语言模型，模型架构为 `Phi3VForCausalLM`。本轮目标是在 Ascend 910C 节点上使用指定的统一 vLLM/plugin-FL 镜像完成部署，验证纯文本和图片输入链路，并使用 GPQA Diamond 50 题与 NV 实测基线对比。

按用户要求，本轮不执行 MMStar 多模态数据集评测。图片输入只做一条标准 OpenAI 多模态请求 smoke test，用于确认图片解码、processor、视觉 encoder 和多模态 chat 链路可用。

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `bm-jn-zs-zone1-910C-64G-10-117` / `10.55.0.173` |
| 芯片 | Ascend 910C，单个逻辑设备 64GB |
| 推理容器 | `Phi-3-vision-128k-instruct_flagos` |
| 评测容器 | `phi3-vision-128k-eval` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/flagrelease_ascend_vllm020plugin_base:no_vllm_ascend` |
| vLLM | `0.20.2` |
| vLLM plugin-FL | `0.2.0+g1326a3374` |
| EvalScope | `1.5.1` |
| 模型宿主机路径 | `/public-flash/models/Phi-3-vision-128k-instruct` |
| 模型容器路径 | `/models/Phi-3-vision-128k-instruct` |
| 逻辑设备 | `ASCEND_RT_VISIBLE_DEVICES=12,13` |
| Tensor Parallel | `2` |
| 服务端口 | `8005` |
| dtype | `bfloat16` |
| 最大上下文 | `131072` |

## Step 0：模型下载与完整性

模型下载至：

```text
/public-flash/models/Phi-3-vision-128k-instruct
```

宿主机无法直接访问 Hugging Face，通过节点现有代理 `10.6.212.42:2080` 和 `HF_ENDPOINT=https://hf-mirror.com` 下载。大分片下载期间曾因代理关闭连接中断，`hf` 保留 `.incomplete` 文件后成功断点续传。

完整性结果：

| 项目 | 值 |
|------|---|
| 架构 | `Phi3VForCausalLM` |
| `max_position_embeddings` | `131072` |
| 权重分片 | 2 |
| 权重总字节数 | `8,293,330,888` |
| 模型目录大小 | 约 `7.8G` |
| 缺失/空分片 | 0 |
| 视觉 processor 文件 | 完整 |

已验证存在：

```text
preprocessor_config.json
processing_phi3_v.py
image_processing_phi3_v.py
image_embedding_phi3_v.py
```

下载完成后已删除临时容器 `phi3-vision-128k-download`、下载日志、退出码文件和 Hugging Face 续传缓存。

## Step 1：容器运行配置

```text
cmd:        ["sleep", "infinity"]
network:    host
ipc:        host
shm-size:   64 GiB
privileged: true
restart:    unless-stopped
```

关键环境变量：

```bash
export ASCEND_RT_VISIBLE_DEVICES=12,13
export ASCEND_VISIBLE_DEVICES=12,13
export PYTORCH_NPU_ALLOC_CONF=max_split_size_mb:256
```

逻辑设备 12/13 属于同一张空闲板卡，启动前显存分别约有 `60.88 GiB` 和 `61.13 GiB` 可用。

关键挂载：

```text
/public-flash/models -> /models
/data/flagos-workspace/microsoft/Phi-3-vision-128k-instruct -> /flagos-workspace
/usr/local/Ascend/driver -> /usr/local/Ascend/driver
/usr/local/dcmi -> /usr/local/dcmi
/usr/local/bin/npu-smi -> /usr/local/bin/npu-smi
/usr/local/sbin -> /usr/local/sbin
/etc/ascend_install.info -> /etc/ascend_install.info
```

按实际运行配置规范化后的可复现命令（原节点默认 runtime 即为 `ascend`，这里显式写出）：

```bash
docker run -d --restart unless-stopped \
  --runtime=ascend --network=host --ipc=host \
  --privileged --security-opt=label=disable --shm-size=64g \
  -e ASCEND_VISIBLE_DEVICES=12,13 \
  -e ASCEND_RT_VISIBLE_DEVICES=12,13 \
  -e PYTORCH_NPU_ALLOC_CONF=max_split_size_mb:256 \
  -v /public-flash/models:/models \
  -v /data/flagos-workspace/microsoft/Phi-3-vision-128k-instruct:/flagos-workspace \
  -v /usr/local/Ascend/driver:/usr/local/Ascend/driver \
  -v /usr/local/dcmi:/usr/local/dcmi \
  -v /usr/local/bin/npu-smi:/usr/local/bin/npu-smi \
  -v /usr/local/sbin:/usr/local/sbin \
  -v /etc/ascend_install.info:/etc/ascend_install.info \
  --name Phi-3-vision-128k-instruct_flagos \
  harbor.baai.ac.cn/flagrelease-public/flagrelease_ascend_vllm020plugin_base:no_vllm_ascend \
  sleep infinity
```

## Step 2：启动 vLLM 服务

实际命令：

```bash
export VLLM_WORKER_MULTIPROC_METHOD=spawn

vllm serve /models/Phi-3-vision-128k-instruct \
  --host 0.0.0.0 \
  --port 8005 \
  --served-model-name Phi-3-vision-128k-instruct \
  --dtype bfloat16 \
  --tensor-parallel-size 2 \
  --max-model-len 131072 \
  --gpu-memory-utilization 0.90 \
  --enforce-eager \
  --trust-remote-code
```

健康检查：

```bash
curl --noproxy '*' http://127.0.0.1:8005/health
curl --noproxy '*' http://127.0.0.1:8005/v1/models
```

结果：

- `/health` 返回 HTTP `200`；
- `/v1/models` 返回 `Phi-3-vision-128k-instruct`；
- `max_model_len=131072`；
- 纯文本请求返回 HTTP `200`；
- 评测结束后服务进程仍存活，健康检查仍为 HTTP `200`。

服务日志：

```text
/public-flash/models/release_run_logs/Phi-3-vision-128k-instruct/ascend/serve.log
```

## Step 3：图片输入 smoke test

使用 Pillow 生成标准 `64×64` RGB 红色 PNG，并以 OpenAI `image_url` data URI 格式发送。

提问：

```text
What is the dominant color of this image? Answer with one word.
```

结果：

```text
HTTP 200
assistant: Red
prompt_tokens: 2534
completion_tokens: 3
```

该结果说明图片解码、视觉 processor、视觉 encoder 和多模态模型路径可用。本轮未执行 MMStar。

测试图片：

```text
/public-flash/models/release_run_logs/Phi-3-vision-128k-instruct/ascend/smoke_red.png
```

## Step 4：GPQA Diamond 50 题评测

评测配置：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.5.1` |
| 题数 | 50 |
| `eval_batch_size` | 4 |
| `temperature` | 0 |
| `max_model_len` | 131072 |
| `max_tokens` | 4096（显式指定） |
| 评测耗时 | `1173.93s`，约 19m 33.9s |

本模型按已有 Phi-3-Vision 评测口径将 MCQ 生成上限设为 4096，避免 128K 上下文自动导出 32768 的过大生成窗口。

命令：

```bash
python3 /flagos-workspace/eval_ascend/fast_gpqa.py \
  --model-name Phi-3-vision-128k-instruct \
  --api-base http://127.0.0.1:8005/v1 \
  --dataset gpqa_diamond \
  --limit 50 \
  --eval-batch-size 4 \
  --max-tokens 4096 \
  --dataset-dir /flagos-workspace/eval_ascend/datasets \
  --output /models/release_run_logs/Phi-3-vision-128k-instruct/ascend/gpqa50/gpqa50.json
```

结果文件：

```text
/public-flash/models/release_run_logs/Phi-3-vision-128k-instruct/ascend/gpqa50/gpqa50.json
/public-flash/models/release_run_logs/Phi-3-vision-128k-instruct/ascend/gpqa50/verdict.json
/public-flash/models/release_run_logs/Phi-3-vision-128k-instruct/ascend/gpqa50/eval.log
```

结果摘要：

```json
{
  "score": 24.0,
  "evalscope_score": 24.0,
  "total_questions": 50,
  "eval_batch_size": 4,
  "temperature": 0.0,
  "max_tokens": 4096,
  "max_model_len": 131072,
  "eval_duration_seconds": 1173.93,
  "runaway_detection": {
    "checked": 50,
    "runaway_count": 6,
    "runaway_indices": [7, 23, 25, 28, 32, 41]
  },
  "answer_extraction_audit": {
    "checked": 50,
    "explicit_answer_found": 44,
    "format_corrected_score": 24.0,
    "parser_mismatch_count": 0,
    "invalid_evalscope_extract_count": 6
  }
}
```

### NV 基线对比

NV 实测基线：

```yaml
Phi-3-vision-128k-instruct:
  metrics:
    gpqa_diamond: 25.0
```

| 项目 | 值 |
|------|---:|
| Ascend 当前结果 | `24.00%` |
| NV 基线 | `25.00%` |
| 绝对差 | `-1.00` 个百分点 |
| 相对退化 | `4.00%` |
| 容差 | `5.00%` |
| 判定 | 通过 |

```json
{
  "baseline_mode": "nv_reference",
  "current_score": 24.0,
  "nv_score": 25.0,
  "rel_drop_pct": 4.0,
  "abs_diff": -1.0,
  "aligned": true,
  "noise_zone": false,
  "message": "精度达标: 当前=24.00%, NV=25.00%, 相对退化=4.00% (容差 5.0%)"
}
```

## 50 题逐题结果

文档题号使用 `1–50`，EvalScope 原始 `index` 使用 `0–49`：

```text
文档题号 = EvalScope 原始 index + 1
```

### 通过题号

共 12 题：

```text
1, 2, 5, 6, 11, 13, 14, 17, 19, 30, 32, 37
```

对应原始索引：

```text
0, 1, 4, 5, 10, 12, 13, 16, 18, 29, 31, 36
```

### 失败题号

共 38 题：

```text
3, 4, 7, 8, 9, 10, 12, 15, 16, 18,
20, 21, 22, 23, 24, 25, 26, 27, 28, 29,
31, 33, 34, 35, 36, 38, 39, 40, 41, 42,
43, 44, 45, 46, 47, 48, 49, 50
```

对应原始索引：

```text
2, 3, 6, 7, 8, 9, 11, 14, 15, 17,
19, 20, 21, 22, 23, 24, 25, 26, 27, 28,
30, 32, 33, 34, 35, 37, 38, 39, 40, 41,
42, 43, 44, 45, 46, 47, 48, 49
```

### Runaway 题号

6 题均为错误，且 `finish_reason=max_tokens`：

| 文档题号 | 原始 index | diversity | compress ratio |
|---:|---:|---:|---:|
| 8 | 7 | `0.0293` | `0.0428` |
| 24 | 23 | `0.0427` | `0.0622` |
| 26 | 25 | `0.0608` | `0.0748` |
| 29 | 28 | `0.0276` | `0.0353` |
| 33 | 32 | `0.0343` | `0.0433` |
| 42 | 41 | `0.0763` | `0.0923` |

## 现象

- `Phi3VForCausalLM` 在当前 Ascend vLLM/plugin-FL 镜像中正常加载；
- TP=2 下成功保留 131072 上下文；
- 纯文本生成正常；
- 标准 PNG 图片请求正常，模型能识别红色图像；
- GPQA 50 题得分 `24.00%`，低于 NV `25.00%` 1 个百分点；
- 相对退化 `4.00%`，在 5% 门限内通过；
- 即使将 `max_tokens` 限制到 4096，仍有 6 题发生复读 runaway，说明该模型当前 MCQ 生成稳定性不理想。

## 定位

### 1. 精度门限

本轮不依赖小样本噪声特例，而是直接满足 5% 相对退化门限：

```text
(25 - 24) / 25 = 4.00% <= 5.00%
```

但 50 题中一题等于 2 个百分点，当前仅比 NV 低 0.5 题的折算分值，仍然属于边界通过。

### 2. Runaway 对结果的影响

6 道 runaway 题全部因高重复、高可压缩输出而生成到 4096 token 上限。这些题在当前评测中均为错误，因此有可能拉低得分，并显著增加耗时。

### 3. 视觉验收边界

本轮图片 smoke test 只能证明图片链路可用，不能代替 MMStar 或其他多模态精度集。本次遵循用户要求，不执行 MMStar，因此不对视觉精度做量化结论。

## 处置

1. 使用断点续传完成 Hugging Face 大分片下载；
2. 完成权重索引、权重分片和视觉 processor 文件完整性校验；
3. 使用空闲逻辑设备 `12,13`、TP=2、BF16、eager 模式部署；
4. 完成纯文本和真实 PNG 图片 smoke test；
5. 使用 EvalScope 1.5.1 执行 GPQA Diamond 50 题；
6. 使用 NV `25.00%` 基线和 5% 相对退化门限判定；
7. 记录逐题结果和 runaway 题号。

## 当前结果

- 服务：正常，逻辑设备 `12,13`，TP=2，端口 `8005`
- 最大上下文：`131072`
- 纯文本路径：通过
- PNG 图片输入 smoke test：通过
- GPQA Diamond 50 题：`24.00%` / `12/50`
- NV 基线：`25.00%`
- 相对退化：`4.00%`
- 精度判定：通过，但接近 5% 门限
- Runaway：6 题，题号 `8, 24, 26, 29, 33, 42`
- MMStar：按用户要求未执行
- 性能验收：本次未执行

## VLLM_PLUGINS=fl 复测（第二轮）

为验证显式设置插件环境变量的影响，使用相同模型、镜像、TP=2、BF16、131072 上下文和 GPQA 50 题口径重新启动，并在服务启动块增加：

```bash
export VLLM_PLUGINS=fl
```

本轮因逻辑设备 12/13 当时被其他服务占用，实际使用空闲逻辑设备 `6,7`；这是与首轮不同的外部变量，不能把分数变化全部归因于 `VLLM_PLUGINS`。

| 项目 | 首轮 | `VLLM_PLUGINS=fl` 复测 |
|---|---:|---:|
| 逻辑设备 | `12,13` | `6,7` |
| GPQA | `24.00%` | `20.00%` |
| NV 基线 | `25.00%` | `25.00%` |
| 相对退化 | `4.00%` | `20.00%` |
| Runaway | `6/50` | `7/50` |
| Parser mismatch | `0` | `0` |
| accuracy_compare | 0（通过） | 1（不通过） |

复测结果文件：

```text
/public-flash/models/release_run_logs/Phi-3-vision-128k-instruct/rerun_vllm_plugins_fl/gpqa50/gpqa50.json
/public-flash/models/release_run_logs/Phi-3-vision-128k-instruct/rerun_vllm_plugins_fl/gpqa50/verdict.json
/public-flash/models/release_run_logs/Phi-3-vision-128k-instruct/rerun_vllm_plugins_fl/gpqa50/eval.log
/public-flash/models/release_run_logs/Phi-3-vision-128k-instruct/rerun_vllm_plugins_fl/serve.log
```

复测正确题号（1 基）：`1, 5, 11, 13, 14, 17, 30, 32, 34, 37`；失败题号：`2, 3, 4, 6, 7, 8, 9, 10, 12, 15, 16, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 31, 33, 35, 36, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50`。

Runaway 题号（1 基）：`2, 8, 24, 26, 29, 33, 42`。

结论：复测不通过；首轮日志已经显示该镜像会自动激活 `fl` 平台插件，因此不能将本轮 20% 单独解释为显式环境变量造成。发布字段仍保留首轮通过配置，不将失败复测写成发布配置。

## 可复用规则

1. VLM 部署完成后必须分别验证纯文本和图片输入，仅 `/health` 和文本 GPQA 不能证明视觉链路可用。
2. 模型下载自动化必须以日志和权重完整性校验为准，不能仅依赖包装命令写入的退出码文件；断点续传后仍需核对索引引用的所有分片。
3. 长上下文 VLM 的设备数量计算必须同时考虑语言模型 KV cache、视觉 encoder 和图像 token 预留。
4. MCQ 任务应设置专用生成上限和在线复读中止机制。本轮即使使用 4096 上限仍有 6/50 题 runaway。
5. `24%` 对 NV `25%` 属于门限内边界通过，如用于严格发布门控，应增加第二轮 50 题或 198 题全量复测，并关注 runaway 是否重现。
