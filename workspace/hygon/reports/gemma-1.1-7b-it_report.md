# hygon/gemma-1.1-7b-it 修复日志

- **失败报告**：flagrelease_fail_reports/Hygon/FAILED_Hygon_gemma-1.1-7b-it_202607220702.md
- **原始失败类型**：精度或评测路径异常
- **日期**：2026-09-16
- **依据**：[原始适配记录](../fixes/gemma-1.1-7b-it.md)

## 现象

重部署且关闭 FL OOT 后，50 题原始分 40%、校正分 42%；但源文档此前 198 题仅 32.83%，重复轮次亦有波动，不能以单轮覆盖全量失败。

## 定位

以上现象和归因均按原始适配记录；不能把评测后处理、服务数值路径和随机采样波动混作同一问题。

## 处置

重部署且关闭 FL OOT 后，50 题原始分 40%、校正分 42%；但源文档此前 198 题仅 32.83%，重复轮次亦有波动，不能以单轮覆盖全量失败。

## 结果

- GPQA Diamond 本平台 / NV：42% / 37%。
- 达标判定：精度尚未完成稳定验收，不得以本轮分数发布。
- accuracy_compare 退出码：源适配记录未明确给出数值，本报告不推断。
- 限定：50 题单轮通过，但此前 198 题不达标，故标记 pending。

## 提炼到 KNOWLEDGE 的条目

单轮抽样通过不能代替全量、多轮的稳定验收。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: google/gemma-1.1-7b-it
# IMAGE: harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4
# GPU: Hygon DCU BW1000, 1 × 64GB
# TP: 1
# VERDICT: pending
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 37
# SCORE_FLAGOS: -
# CONTAINER_DEVS: --security-opt seccomp=unconfined --device=/dev/kfd --device=/dev/dri --shm-size=64g -v /public-flash/models:/models -v /opt/hyhal:/opt/hyhal:ro
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --net=host --ipc=host --security-opt seccomp=unconfined --device=/dev/kfd --device=/dev/dri --shm-size=64g \
  -v /public-flash/models:/models -v /opt/hyhal:/opt/hyhal:ro \
  --name flagos-hygon-gemma-1.1-7b-it \
  harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4 \
  /bin/bash
```

### 三、启动服务（容器内执行）

```bash
export DTK_HOME=/opt/dtk
export ROCM_PATH=/opt/dtk-26.04-DCC2602-0317
export HIP_PATH=/opt/dtk-26.04-DCC2602-0317/hip
export HSA_PATH=/opt/dtk/hsa
export DEVICE_LIB_PATH=/opt/dtk/amdgcn/bitcode
export TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18
export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
export VLLM_FL_TRITON_CACHE_ROOT=/models/day0_logs/triton_cache/gemma-1.1-7b-it
export FLAGGEMS_ENABLE_OPLIST_PATH=/models/day0_logs/gemma-1.1-7b-it-enabled-ops-20260915-oot-disabled-final-v2.txt
export VLLM_FL_FLAGOS_WHITELIST=add,addmm_out,arange_start,argmax,broadcast_to,copy_,cos,expand,full,index,linear,lt_scalar,mm_out,rand_like,randn,reciprocal,sin,softmax,softmax_out,sub,to_copy,true_divide,true_divide_,where_self,where_self_out,zero_,zeros
export VLLM_FL_OOT_BLACKLIST=silu_and_mul
export VLLM_FL_OOT_ENABLED=0
/usr/local/bin/vllm serve /models/gemma-1.1-7b-it \
  --served-model-name gemma-1.1-7b-it \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 8192 \
  --gpu-memory-utilization 0.90 \
  --port 8004 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code
```
