# t-head/Phi-4 修复日志

- **失败报告**：暂无
- **原始失败类型**：精度不达标
- **日期**：2026-09-17
- **依据**：[原始适配记录](../fixes/Phi-4.md)

## 现象

宽白名单 66%，采样试验 60%，最小白名单临时端口 70%；正式端口复测仅 64%、68%、68%，未达 69.35% 门限。

## 定位

以上现象和归因均按原始适配记录；不能把评测后处理、服务数值路径和随机采样波动混作同一问题。

## 处置

宽白名单 66%，采样试验 60%，最小白名单临时端口 70%；正式端口复测仅 64%、68%、68%，未达 69.35% 门限。

## 结果

- GPQA Diamond 本平台 / NV：68% / 73%。
- 达标判定：精度未达标。
- accuracy_compare 退出码：源适配记录未明确给出数值，本报告不推断。

## 提炼到 KNOWLEDGE 的条目

正式端口多轮不达标时不能采用临时实验的单轮最高分。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: microsoft/phi-4
# IMAGE: harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100
# GPU: PPU-ZW810E, 16 × 96GB
# TP: 1
# VERDICT: bad
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 73
# SCORE_FLAGOS: 68
# CONTAINER_DEVS: --privileged --shm-size=512g -v /dev:/dev -v /usr/local/PPU_SDK:/usr/local/PPU_SDK -v /mnt/workspace/models:/models
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --net=host --ipc=host --privileged --shm-size=512g \
  -v /dev:/dev -v /usr/local/PPU_SDK:/usr/local/PPU_SDK -v /mnt/workspace/models:/models \
  --name flagos-t-head-phi-4 \
  harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100 \
  /bin/bash
```

### 三、启动服务（容器内执行）

```bash
export VLLM_PLUGINS=fl
export USE_FLAGGEMS=1
export VLLM_FL_PREFER_ENABLED=true
export VLLM_FL_FLAGOS_WHITELIST=attention_backend,rms_norm,silu_and_mul,rotary_embedding
export FLAGGEMS_DB_URL=sqlite:///:memory:
export VLLM_CACHE_ROOT=/models/_vllm_cache/phi-4-minflagos-formal-gpu11
export TORCHINDUCTOR_CACHE_DIR=/models/_vllm_cache/phi-4-minflagos-formal-gpu11/torchinductor
export TRITON_CACHE_DIR=/models/_vllm_cache/phi-4-minflagos-formal-gpu11/triton
export VLLM_FL_TRITON_CACHE_ROOT=/models/_vllm_cache/phi-4-minflagos-formal-gpu11/triton
export PPU_HOME=/usr/local/PPU_SDK
export CUDA_HOME=/usr/local/PPU_SDK/CUDA_SDK
export HF_ENDPOINT=https://hf-mirror.com
/usr/local/bin/vllm serve /models/phi-4 \
  --served-model-name phi-4 \
  --host 0.0.0.0 \
  --port 18084 \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 16384 \
  --gpu-memory-utilization 0.85 \
  --trust-remote-code \
  --enforce-eager
```
