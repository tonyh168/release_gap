# hygon/DeepSeek-R1-Distill-Qwen-32B-Japanese 修复日志

- **失败报告**：flagrelease_fail_reports/Hygon/FAILED_Hygon_DeepSeek-R1-Distill-Qwen-32B-Japanese_202608071433.md
- **原始失败类型**：精度或评测路径异常
- **日期**：2026-09-18
- **依据**：[原始适配记录](../fixes/DeepSeek-R1-Distill-Qwen-32B-Japanese.md)

## 现象

普通贪心仅 38%，5/50 道题重复输出；改用模型声明的 thinking 采样 temperature=0.6、top_p=0.95、max_tokens=16384，并关闭 OOT、prefix cache、chunked prefill 和 FlagGems attention。

## 定位

以上现象和归因均按原始适配记录；不能把评测后处理、服务数值路径和随机采样波动混作同一问题。

## 处置

普通贪心仅 38%，5/50 道题重复输出；改用模型声明的 thinking 采样 temperature=0.6、top_p=0.95、max_tokens=16384，并关闭 OOT、prefix cache、chunked prefill 和 FlagGems attention。

## 结果

- GPQA Diamond 本平台 / NV：66% / 62%。
- 达标判定：本轮 GPQA 精度达标；性能或其他指标未由该记录证明。
- accuracy_compare 退出码：源适配记录未明确给出数值，本报告不推断。

## 提炼到 KNOWLEDGE 的条目

推理模型先核对生成配置和 runaway，再判精度。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: cyberagent/DeepSeek-R1-Distill-Qwen-32B-Japanese
# IMAGE: harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4
# GPU: Hygon DCU BW1000, 4 × 64GB
# TP: 4
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 62
# SCORE_FLAGOS: 66
# CONTAINER_DEVS: --security-opt seccomp=unconfined --device=/dev/kfd --device=/dev/dri --shm-size=64g -v /public-flash/models:/models -v /opt/hyhal:/opt/hyhal:ro
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --net=host --ipc=host --security-opt seccomp=unconfined --device=/dev/kfd --device=/dev/dri --shm-size=64g \
  -v /public-flash/models:/models -v /opt/hyhal:/opt/hyhal:ro \
  --name flagos-hygon-deepseek-r1-distill-qwen-32b-japanese \
  harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4 \
  /bin/bash
```

### 三、启动服务（容器内执行）

```bash
export DTK_HOME=/opt/dtk
export ROCM_PATH=/opt/dtk
export HIP_PATH=/opt/dtk/hip
export HSA_PATH=/opt/dtk/hsa
export DEVICE_LIB_PATH=/opt/dtk/amdgcn/bitcode
export TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18
export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
export FLAGGEMS_DB_URL=sqlite:///:memory:
export VLLM_FL_TRITON_CACHE_ROOT=/models/day0_logs/triton_cache/DeepSeek-R1-Distill-Qwen-32B-Japanese
export VLLM_FL_FLAGOS_WHITELIST=attention_backend
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_FL_OOT_ENABLED=0
export VLLM_FL_OOT_BLACKLIST=addmm,broadcast_to,copy
/usr/local/bin/vllm serve /models/DeepSeek-R1-Distill-Qwen-32B-Japanese \
  --served-model-name DeepSeek-R1-Distill-Qwen-32B-Japanese \
  --dtype bfloat16 \
  --tensor-parallel-size 4 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.90 \
  --port 8005 \
  --attention-backend TRITON_ATTN \
  --no-enable-prefix-caching \
  --no-enable-chunked-prefill \
  --enforce-eager \
  --trust-remote-code
```
