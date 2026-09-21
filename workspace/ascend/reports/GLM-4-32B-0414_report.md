# ascend/GLM-4-32B-0414 修复日志

- **失败报告**：暂无
- **原始失败类型**：新模型部署与精度验收
- **日期**：2026-09-20
- **依据**：[适配记录](../fixes/GLM-4-32B-0414.md)

## 现象

Hugging Face 大分片经代理下载时曾断流，断点续传后 14 个权重分片完整。Ascend TP2 服务健康且真实生成正常。GPQA 50 题为 `54%`，NV 为 `55%`。

## 定位

未发现服务 crash、OOM、runaway 或答案解析差异；相对退化 `1.82%`，直接满足 5% 门限。

## 处置

使用逻辑设备 12/13、TP2、BF16、eager、32768 上下文部署；EvalScope 1.5.1 用 batch 4、temperature 0、max_tokens 4096 评测。

## 结果

- 修复后分 / NV 基线：`54.0% / 55.0%`
- 达标判定：`aligned=true`，accuracy_compare 退出码 0
- Runaway / parser mismatch：`0 / 0`

## 提炼到 KNOWLEDGE 的条目

32B BF16 在 Ascend 910C 两个 64GB 逻辑设备上可以 TP2 部署；代理断流后必须断点续传并按索引校验全部分片。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: zai-org/GLM-4-32B-0414
# IMAGE: harbor.baai.ac.cn/flagrelease-public/flagrelease_ascend_vllm020plugin_base:no_vllm_ascend
# GPU: Ascend 910C, 2 × 64GB
# TP: 2
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 55
# SCORE_FLAGOS: 54
# CONTAINER_DEVS: --privileged --shm-size=64g -v /public-flash/models:/models -v /usr/local/Ascend/driver:/usr/local/Ascend/driver -v /usr/local/dcmi:/usr/local/dcmi -v /usr/local/bin/npu-smi:/usr/local/bin/npu-smi -v /etc/ascend_install.info:/etc/ascend_install.info
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --net=host --ipc=host --privileged --shm-size=64g \
  -v /public-flash/models:/models \
  -v /usr/local/Ascend/driver:/usr/local/Ascend/driver \
  -v /usr/local/dcmi:/usr/local/dcmi \
  -v /usr/local/bin/npu-smi:/usr/local/bin/npu-smi \
  -v /etc/ascend_install.info:/etc/ascend_install.info \
  --name flagos-ascend-glm-4-32b-0414 \
  harbor.baai.ac.cn/flagrelease-public/flagrelease_ascend_vllm020plugin_base:no_vllm_ascend \
  /bin/bash
```

### 三、启动服务（容器内执行）

```bash
export PYTORCH_NPU_ALLOC_CONF=max_split_size_mb:256
export VLLM_WORKER_MULTIPROC_METHOD=spawn
vllm serve /models/GLM-4-32B-0414 \
  --host 0.0.0.0 --port 8005 \
  --served-model-name GLM-4-32B-0414 \
  --dtype bfloat16 --tensor-parallel-size 2 \
  --max-model-len 32768 --gpu-memory-utilization 0.90 \
  --enforce-eager --trust-remote-code
```
