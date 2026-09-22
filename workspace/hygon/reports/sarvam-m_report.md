# hygon/sarvam-m 修复日志

- **失败报告**：flagrelease_fail_reports/Hygon/FAILED_Hygon_sarvam-m_202607290952.md
- **原始失败类型**：精度不达标
- **日期**：2026-09-16
- **依据**：[原始适配记录](../fixes/sarvam-m.md)

## 现象

SQLite autotune 数据库锁导致 53/198 后崩溃；评测临时容器被清理导致 24/198 中断。内存 SQLite 与常驻容器规避中断后，全量 40/198 runaway，精度仍不达标。

## 定位

以上现象和归因均按原始适配记录；不能把评测后处理、服务数值路径和随机采样波动混作同一问题。

## 处置

SQLite autotune 数据库锁导致 53/198 后崩溃；评测临时容器被清理导致 24/198 中断。内存 SQLite 与常驻容器规避中断后，全量 40/198 runaway，精度仍不达标。

## 结果

- GPQA Diamond 本平台 / NV：29.80% / 48%。
- 达标判定：精度未达标。
- accuracy_compare 退出码：源适配记录未明确给出数值，本报告不推断。

## 提炼到 KNOWLEDGE 的条目

隔离多 worker SQLite 缓存；对服务、评测容器和 runaway 分层定位。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: sarvamai/sarvam-m
# IMAGE: harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist
# GPU: Hygon DCU BW1000, 2 × 64GB
# TP: 2
# VERDICT: bad
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 48
# SCORE_FLAGOS: 29.80
# CONTAINER_DEVS: --security-opt seccomp=unconfined --device=/dev/kfd --device=/dev/dri --shm-size=64g -v /public-flash/models:/models -v /opt/hyhal:/opt/hyhal:ro
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -d --net=host --ipc=host --security-opt seccomp=unconfined --security-opt label=disable --group-add video --device=/dev/kfd --device=/dev/dri --shm-size=64g \
  -v /public-flash/models:/models -v /opt/hyhal:/opt/hyhal:ro \
  --name flagos-hygon-sarvam-m \
  harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist \
  bash -lc 'sleep infinity'
```

### 三、启动服务（容器内执行）

```bash
export VLLM_PLUGINS=fl
export VLLM_FL_FLAGOS_BLACKLIST=cat,slice
export FLAGGEMS_DB_URL=sqlite:///:memory:
vllm serve /models/sarvam-m --served-model-name sarvam-m --dtype bfloat16 --tensor-parallel-size 2 --max-model-len 32768 --gpu-memory-utilization 0.9 --port 8100 --attention-backend TRITON_ATTN --no-enable-chunked-prefill --no-enable-prefix-caching --enforce-eager --trust-remote-code
```
