# ascend/Phi-3-mini-128k-instruct 修复日志

- **失败报告**：暂无
- **原始失败类型**：精度或评测路径异常
- **日期**：2026-09-20
- **依据**：[原始适配记录](../fixes/Phi-3-mini-128k-instruct.md)

## 现象

单逻辑设备 KV cache 不足以支持 131072 上下文；映射板卡 5 到逻辑设备 10、11，以 TP2 部署。50 题得 40%，但同参轮次存在 9/50 正确性翻转。

## 定位

以上现象和归因均按原始适配记录；不能把评测后处理、服务数值路径和随机采样波动混作同一问题。

## 处置

单逻辑设备 KV cache 不足以支持 131072 上下文；映射板卡 5 到逻辑设备 10、11，以 TP2 部署。50 题得 40%，但同参轮次存在 9/50 正确性翻转。

## 结果

- GPQA Diamond 本平台 / NV：40% / 33%。
- 达标判定：本轮 GPQA 精度达标；性能或其他指标未由该记录证明。
- accuracy_compare 退出码：源适配记录未明确给出数值，本报告不推断。
- 限定：源记录提示同参数仍有逐题翻转。

## 提炼到 KNOWLEDGE 的条目

先估算 KV cache 与物理/逻辑设备映射；抽样通过需附稳定性限制。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: microsoft/Phi-3-mini-128k-instruct
# IMAGE: harbor.baai.ac.cn/flagrelease-public/flagrelease_ascend_vllm020plugin_base:no_vllm_ascend
# GPU: Ascend 910C, 2 × 64GB
# TP: 2
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 33
# SCORE_FLAGOS: 40
# CONTAINER_DEVS: --privileged --shm-size=64g -v /public-flash/models:/models -v /usr/local/Ascend/driver:/usr/local/Ascend/driver -v /usr/local/dcmi:/usr/local/dcmi -v /usr/local/bin/npu-smi:/usr/local/bin/npu-smi -v /etc/ascend_install.info:/etc/ascend_install.info
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --net=host --ipc=host --privileged --shm-size=64g \
  -v /public-flash/models:/models -v /usr/local/Ascend/driver:/usr/local/Ascend/driver -v /usr/local/dcmi:/usr/local/dcmi -v /usr/local/bin/npu-smi:/usr/local/bin/npu-smi -v /etc/ascend_install.info:/etc/ascend_install.info \
  --name flagos-ascend-phi-3-mini-128k-instruct \
  harbor.baai.ac.cn/flagrelease-public/flagrelease_ascend_vllm020plugin_base:no_vllm_ascend \
  /bin/bash
```

### 三、启动服务（容器内执行）

```bash
export PYTORCH_NPU_ALLOC_CONF=max_split_size_mb:256
export VLLM_WORKER_MULTIPROC_METHOD=spawn
vllm serve /models/Phi-3-mini-128k-instruct \
  --host 0.0.0.0 \
  --port 8004 \
  --served-model-name Phi-3-mini-128k-instruct \
  --dtype bfloat16 \
  --tensor-parallel-size 2 \
  --max-model-len 131072 \
  --gpu-memory-utilization 0.90 \
  --enforce-eager \
  --trust-remote-code
```
