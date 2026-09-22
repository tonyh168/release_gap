# Ascend/EXAONE-4.0-32B 适配与评测记录

- **日期**：`2026-09-21`
- **节点**：`10.55.0.173` / `bm-jn-zs-zone1-910C-64G-10-117`
- **模型**：`LGAI-EXAONE/EXAONE-4.0-32B`
- **结论**：Ascend 910C TP2 部署成功；GPQA Diamond 50 题 `64.00%`，NV `62.00%`，高 `2.00` 个百分点，通过。

## 环境与部署

| 项目 | 值 |
|---|---|
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/flagrelease_ascend_vllm020plugin_base:no_vllm_ascend` |
| 容器 | `EXAONE-4.0-32B_flagos` |
| vLLM / plugin-FL | `0.20.2` / `0.2.0+g1326a3374` |
| 模型路径 | `/public-flash/models/EXAONE-4.0-32B` -> `/models/EXAONE-4.0-32B` |
| 逻辑设备 | `12,13` |
| TP / dtype | `2` / `bfloat16` |
| 端口 | `8005` |
| max model len | `32768` |

权重校验：架构 `Exaone4ForCausalLM`，14 个 safetensors 分片，权重总字节数 `64,006,515,616`，无缺失分片。

按实际运行配置规范化后的可复现命令（原节点默认 runtime 即为 `ascend`，这里显式写出）：

```bash
docker run -d --restart unless-stopped \
  --runtime=ascend --network=host --ipc=host \
  --privileged --security-opt=label=disable --shm-size=64g \
  -e ASCEND_VISIBLE_DEVICES=12,13 \
  -e ASCEND_RT_VISIBLE_DEVICES=12,13 \
  -e PYTORCH_NPU_ALLOC_CONF=max_split_size_mb:256 \
  -v /public-flash/models:/models \
  -v /usr/local/Ascend/driver:/usr/local/Ascend/driver \
  -v /usr/local/dcmi:/usr/local/dcmi \
  -v /usr/local/bin/npu-smi:/usr/local/bin/npu-smi \
  -v /usr/local/sbin:/usr/local/sbin \
  -v /etc/ascend_install.info:/etc/ascend_install.info \
  --name EXAONE-4.0-32B_flagos \
  harbor.baai.ac.cn/flagrelease-public/flagrelease_ascend_vllm020plugin_base:no_vllm_ascend \
  sleep infinity
```

```bash
export VLLM_WORKER_MULTIPROC_METHOD=spawn
vllm serve /models/EXAONE-4.0-32B \
  --host 0.0.0.0 --port 8005 \
  --served-model-name EXAONE-4.0-32B \
  --dtype bfloat16 --tensor-parallel-size 2 \
  --max-model-len 32768 --gpu-memory-utilization 0.90 \
  --enforce-eager --trust-remote-code
```

`/health` 为 HTTP 200；真实 chat 请求中 `2+2` 返回 `4`。

## GPQA Diamond 50 题

EvalScope `1.5.1`，`eval_batch_size=4`，`temperature=0`，`max_tokens=4096`，耗时 `1892.9s`。

| 项目 | 值 |
|---|---:|
| Ascend | `64.00%` / `32/50` |
| NV | `62.00%` |
| 绝对差 | `+2.00` 个百分点 |
| 相对退化 | `-3.23%`，即 Ascend 更高 |
| Runaway | `0` |
| Parser mismatch | `0` |
| 判定 | 通过 |

结果路径：

```text
/public-flash/models/release_run_logs/EXAONE-4.0-32B/ascend/gpqa50/gpqa50.json
/public-flash/models/release_run_logs/EXAONE-4.0-32B/ascend/gpqa50/verdict.json
/public-flash/models/release_run_logs/EXAONE-4.0-32B/ascend/gpqa50/eval.log
/public-flash/models/release_run_logs/EXAONE-4.0-32B/ascend/serve.log
```

### 通过题号（1 基）

```text
1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 13, 14, 15, 16, 17,
20, 21, 24, 27, 28, 32, 34, 35, 38, 39, 41, 42, 43, 45, 47, 50
```

### 失败题号（1 基）

```text
11, 18, 19, 22, 23, 25, 26, 29, 30, 31, 33, 36, 37, 40, 44, 46, 48, 49
```

## 现象与定位

- 服务启动、真实生成和 50 题评测均完整；
- 无 OOM、无算子 crash、无 runaway、无答案解析差异；
- 当前 64% 高于 NV 62%，不需要小样本噪声特例。

## 可复用规则

EXAONE-4.0-32B 在本 Ascend 基础镜像中可直接使用 TP2、BF16、eager 和 plugin 默认 Ascend vendor backend；MCQ 评测显式限制 `max_tokens=4096` 可避免过大生成窗口。
