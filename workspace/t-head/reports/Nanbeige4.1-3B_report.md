# t-head/Nanbeige4.1-3B 修复日志

- **失败报告**：flagrelease_fail_reports/T-Head/FAILED_T-Head_Nanbeige4.1-3B_202608221700.md
- **原始失败类型**：精度或评测路径异常
- **日期**：2026-09-18
- **依据**：[原始适配记录](../fixes/Nanbeige4.1-3B.md)

## 现象

旧两轮仅 76%；修复行级结论抽取并避免从推理正文猜字母后，重新生成 50 题，校正分 80%、原始分 74%。

## 定位

以上现象和归因均按原始适配记录；不能把评测后处理、服务数值路径和随机采样波动混作同一问题。

## 处置

旧两轮仅 76%；修复行级结论抽取并避免从推理正文猜字母后，重新生成 50 题，校正分 80%、原始分 74%。

## 结果

- GPQA Diamond 本平台 / NV：80% / 81%。
- 达标判定：本轮 GPQA 精度达标；性能或其他指标未由该记录证明。
- accuracy_compare 退出码：源适配记录未明确给出数值，本报告不推断。

## 提炼到 KNOWLEDGE 的条目

答案抽取修复后必须重新生成预测并保留逐题审计。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: nanbeige/Nanbeige4.1-3B
# IMAGE: harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100
# GPU: PPU-ZW810E, 16 × 96GB
# TP: 1
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 81
# SCORE_FLAGOS: 80
# CONTAINER_DEVS: --privileged --shm-size=512g -v /dev:/dev -v /usr/local/PPU_SDK:/usr/local/PPU_SDK -v /mnt/workspace/models:/models
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --net=host --ipc=host --privileged --shm-size=512g \
  -v /dev:/dev -v /usr/local/PPU_SDK:/usr/local/PPU_SDK -v /mnt/workspace/models:/models \
  --name flagos-t-head-nanbeige4.1-3b \
  harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100 \
  /bin/bash
```

### 三、启动服务（容器内执行）

```bash
export VLLM_PLUGINS=fl
export USE_FLAGGEMS=1
export VLLM_FL_PREFER_ENABLED=true
export FLAGGEMS_DB_URL=sqlite:///:memory:
export VLLM_FL_FLAGOS_WHITELIST=add,arange_start,argmax,cat,copy_,cos,exponential_,fill_scalar_,index,lt_scalar,mul,pow_scalar,rand_like,reciprocal,scatter_,sin,softmax,softmax_out,sub,true_divide,true_divide_,where_self,where_self_out,zero_,zeros,attention_backend,rms_norm,silu_and_mul,rotary_embedding
export VLLM_CACHE_ROOT=/models/_vllm_cache/nanbeige4p1-3b-gpu14
export TORCHINDUCTOR_CACHE_DIR=/models/_vllm_cache/nanbeige4p1-3b-gpu14/torchinductor
export TRITON_CACHE_DIR=/models/_vllm_cache/nanbeige4p1-3b-gpu14/triton
export VLLM_FL_TRITON_CACHE_ROOT=/models/_vllm_cache/nanbeige4p1-3b-gpu14/triton
export PPU_HOME=/usr/local/PPU_SDK
export CUDA_HOME=/usr/local/PPU_SDK/CUDA_SDK
export HF_ENDPOINT=https://hf-mirror.com
/usr/local/bin/vllm serve /models/Nanbeige4.1-3B \
  --served-model-name Nanbeige4.1-3B \
  --host 0.0.0.0 \
  --port 18087 \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.85 \
  --trust-remote-code \
  --enforce-eager
```
