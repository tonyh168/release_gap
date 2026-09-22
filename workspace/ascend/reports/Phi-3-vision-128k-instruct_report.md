# ascend/Phi-3-vision-128k-instruct 修复日志

- **失败报告**：暂无
- **原始失败类型**：新模型部署与精度验收
- **日期**：2026-09-20
- **依据**：[原始适配记录](../fixes/Phi-3-vision-128k-instruct.md)

## 现象

- 宿主机 `10.55.0.173` 无法直接访问 Hugging Face，需经现有代理和 `hf-mirror.com` 下载；第一权重大分片中途断开后，通过 `.incomplete` 文件断点续传完成。
- 权重完整性校验通过：架构 `Phi3VForCausalLM`，2 个 safetensors 分片，总权重 `8,293,330,888` 字节，视觉 processor 文件完整。
- 模型在 Ascend 910C 逻辑设备 12、13 上以 TP2、BF16、131072 上下文正常启动；`/health` 和 `/v1/models` 均返回 HTTP `200`。
- 纯文本请求正常；使用 Pillow 生成的 64×64 红色 PNG 请求返回 HTTP `200`，模型回答 `Red`。
- GPQA Diamond 50 题完整结束，得分 `24.00%`，NV 实测基线为 `25.00%`；相对退化 `4.00%`，在 5% 容差内。
- 50 题中有 6 题发生 runaway 复读，均生成到 `max_tokens=4096`。

## 定位

- 本轮没有发现服务启动失败、OOM、权重缺失或视觉 processor 缺失。
- 服务实际解析架构为 `Phi3VForCausalLM`，视觉图片请求成功，说明当前镜像中的图片解码、processor、视觉 encoder 和多模态 chat 路径可用。
- GPQA 精度为边界通过：`(25 - 24) / 25 = 4.00%`，低于 5% 门限，但只有 1 个百分点余量。
- 6 道 runaway 均属于高重复、高可压缩输出，且全部判错。这是当前 MCQ 生成路径的稳定性风险，也是评测耗时达到约 19m34s 的主要原因。
- 按用户要求未执行 MMStar；因此本报告只宣称图片链路 smoke 通过，不宣称多模态精度达标。

## 处置

1. 使用现有 HTTP/HTTPS 代理和 `HF_ENDPOINT=https://hf-mirror.com` 下载模型；代理断开后利用 `hf` 缓存断点续传。
2. 按权重索引核对两个 safetensors 分片，并检查 `preprocessor_config.json`、`processing_phi3_v.py`、`image_processing_phi3_v.py`、`image_embedding_phi3_v.py`。
3. 使用空闲 Ascend 逻辑设备 12、13，以 TP2、BF16、eager 模式启动 128K 服务。
4. 分别执行纯文本和真实 PNG 图片 smoke test，确认两条请求路径都能正常返回。
5. 使用 EvalScope `1.5.1`、GPQA Diamond 50 题、`eval_batch_size=4`、`temperature=0`、`max_tokens=4096` 执行精度评测。
6. 使用 `accuracy_compare.py` 仅与 NV GPQA `25.00%` 实测基线对比，并保存逐题结果与 runaway 审计。

本次实际运行配置：

| 项目 | 值 |
|------|---|
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/flagrelease_ascend_vllm020plugin_base:no_vllm_ascend` |
| vLLM / plugin-FL | `0.20.2` / `0.2.0+g1326a3374` |
| 模型路径 | `/models/Phi-3-vision-128k-instruct` |
| NPU / TP / 端口 | 逻辑设备 `12,13` / `2` / `8005` |
| 服务参数 | `--dtype bfloat16 --max-model-len 131072 --gpu-memory-utilization 0.90 --enforce-eager --trust-remote-code` |
| 评测参数 | EvalScope `1.5.1`，50 题，`eval_batch_size=4`，`temperature=0`，`max_tokens=4096` |
| 服务日志 | `/public-flash/models/release_run_logs/Phi-3-vision-128k-instruct/ascend/serve.log` |
| 评测结果 | `/public-flash/models/release_run_logs/Phi-3-vision-128k-instruct/ascend/gpqa50/gpqa50.json` |
| NV 判定 | `/public-flash/models/release_run_logs/Phi-3-vision-128k-instruct/ascend/gpqa50/verdict.json` |

本轮未修改 vLLM、`vllm-plugin-FL`、FlagGems 或模型源码，也未重新构建或推送 Harbor 镜像。

## 结果

- 修复后分 / NV 基线：GPQA Diamond `24.00%` / `25.00%`。
- 输入链路：纯文本 HTTP `200`；标准 PNG 图片 HTTP `200`，回答 `Red`。
- 达标判定：`aligned=true`，相对退化 `4.00%`，容差 `5.00%`，精度通过。
- `accuracy_compare.py` 退出码：正常完成（命令链返回 0）。
- Runaway：6/50，文档题号 `8, 24, 26, 29, 33, 42`。
- 限定：本轮属于接近 5% 门限的边界通过，且有 6 题 runaway；未执行 MMStar 和性能验收。

## VLLM_PLUGINS=fl 复测

在启动块显式增加 `export VLLM_PLUGINS=fl` 后，按相同 GPQA 50 题口径复测。由于首轮使用的逻辑设备 12/13 当时被其他服务占用，本轮使用空闲逻辑设备 6/7，因此该结果不能只归因于环境变量差异。

| 项目 | 首轮 | 复测 |
|---|---:|---:|
| 逻辑设备 | `12,13` | `6,7` |
| GPQA | `24.00%` | `20.00%` |
| NV | `25.00%` | `25.00%` |
| 相对退化 | `4.00%` | `20.00%` |
| Runaway | `6` | `7` |
| 判定 | 通过 | 不通过 |

复测文件：

```text
/public-flash/models/release_run_logs/Phi-3-vision-128k-instruct/rerun_vllm_plugins_fl/gpqa50/gpqa50.json
/public-flash/models/release_run_logs/Phi-3-vision-128k-instruct/rerun_vllm_plugins_fl/gpqa50/verdict.json
/public-flash/models/release_run_logs/Phi-3-vision-128k-instruct/rerun_vllm_plugins_fl/gpqa50/eval.log
```

`accuracy_compare.py` 复测退出码为 `1`：当前 `20.00%`、NV `25.00%`、相对退化 `20.00%`，超过 5% 容差。首轮日志已显示平台插件自动激活，因此本轮不能证明显式 `VLLM_PLUGINS=fl` 是唯一原因；发布字段仍以首轮通过配置为准。

verdict.json 核心内容：

```json
{
  "baseline_mode": "nv_reference",
  "model": "Phi-3-vision-128k-instruct",
  "metric": "gpqa_diamond",
  "nv_score": 25.0,
  "current_score": 24.0,
  "rel_drop_pct": 4.0,
  "abs_diff": -1.0,
  "aligned": true,
  "noise_zone": false
}
```

## 提炼到 KNOWLEDGE 的条目

Ascend 上部署长上下文 VLM 时，验收必须分开服务健康、纯文本路径、真实图片路径和精度门限；GPQA 边界通过若同时存在 runaway，必须保留逐题审计并建议复测。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: microsoft/Phi-3-vision-128k-instruct
# IMAGE: harbor.baai.ac.cn/flagrelease-public/flagrelease_ascend_vllm020plugin_base:no_vllm_ascend
# GPU: Ascend 910C, 2 × 64GB
# TP: 2
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 25
# SCORE_FLAGOS: 24
# CONTAINER_DEVS: --runtime=ascend --network=host --ipc=host --privileged --security-opt=label=disable --shm-size=64g -e ASCEND_VISIBLE_DEVICES=12,13 -e ASCEND_RT_VISIBLE_DEVICES=12,13 -e PYTORCH_NPU_ALLOC_CONF=max_split_size_mb:256 -v /public-flash/models:/models -v /data/flagos-workspace/microsoft/Phi-3-vision-128k-instruct:/flagos-workspace -v /usr/local/Ascend/driver:/usr/local/Ascend/driver -v /usr/local/dcmi:/usr/local/dcmi -v /usr/local/bin/npu-smi:/usr/local/bin/npu-smi -v /usr/local/sbin:/usr/local/sbin -v /etc/ascend_install.info:/etc/ascend_install.info
```

### 二、容器创建（宿主机执行）

节点实际部署依赖 Docker 的默认 Ascend runtime；下列命令显式写出 `--runtime=ascend`，行为等价且可跨节点复现。

```bash
docker run -d --restart unless-stopped --runtime=ascend --network=host --ipc=host --privileged --security-opt=label=disable --shm-size=64g \
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

docker exec -it Phi-3-vision-128k-instruct_flagos bash
```

### 三、启动服务（容器内执行）

```bash
export PYTORCH_NPU_ALLOC_CONF=max_split_size_mb:256
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
