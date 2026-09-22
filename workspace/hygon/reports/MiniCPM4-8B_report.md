# hygon/MiniCPM4-8B 修复日志

- **失败报告**：flagrelease_fail_reports/Hygon/FAILED_Hygon_MiniCPM4-8B_202607242046.md
- **原始失败类型**：精度或评测路径异常
- **日期**：2026-09-18
- **依据**：[原始适配记录](../fixes/MiniCPM4-8B.md)

## 现象

显式固定 generation_config.json 的 temperature=0.8、top_p=0.8 后重跑 50 题，18/50 与 NV 持平。

## 定位

以上现象和归因均按原始适配记录；不能把评测后处理、服务数值路径和随机采样波动混作同一问题。

## 处置

显式固定 generation_config.json 的 temperature=0.8、top_p=0.8 后重跑 50 题，18/50 与 NV 持平。

## 结果

- GPQA Diamond 本平台 / NV：36% / 36%。
- 达标判定：本轮 GPQA 精度达标；性能或其他指标未由该记录证明。
- accuracy_compare 退出码：源适配记录未明确给出数值，本报告不推断。

## 提炼到 KNOWLEDGE 的条目

API 客户端需显式发送采样参数并记录最终生效值。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: openbmb/MiniCPM4-8B
# IMAGE: harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4
# GPU: Hygon DCU BW1000, 1 × 64GB
# TP: 1
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 36
# SCORE_FLAGOS: 36
# CONTAINER_DEVS: --security-opt seccomp=unconfined --device=/dev/kfd --device=/dev/dri --shm-size=64g -v /public-flash/models:/models -v /opt/hyhal:/opt/hyhal:ro
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -d --net=host --ipc=host --security-opt seccomp=unconfined --security-opt label=disable --group-add video --device=/dev/kfd --device=/dev/dri --shm-size=64g \
  -v /public-flash/models:/models -v /opt/hyhal:/opt/hyhal:ro \
  --name flagos-hygon-minicpm4-8b \
  harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4 \
  bash -lc 'sleep infinity'
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
export VLLM_FL_TRITON_CACHE_ROOT=/models/triton_cache/MiniCPM4-8B
mkdir -p "$VLLM_FL_TRITON_CACHE_ROOT"
export VLLM_FL_FLAGOS_WHITELIST=add,arange_start,argmax,broadcast_to,copy_,cos,cumsum,cumsum_out,expand,full,index,le,linear,lt_scalar,masked_fill_,mm_out,ones,rand_like,reciprocal,rsub_scalar,scatter_,sin,softmax,softmax_out,sub,sum_dim,to_copy,true_divide,true_divide_,where_self,where_self_out,zero_,zeros
/usr/local/bin/vllm serve /models/MiniCPM4-8B \
  --served-model-name MiniCPM4-8B \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.90 \
  --port 8010 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code
```
