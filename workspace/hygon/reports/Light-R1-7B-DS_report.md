# hygon/Light-R1-7B-DS 修复日志

- **日期**：`2026-09-18`
- **评测范围**：MATH-500 50 题（Level 1--5 各 10 题）
- **依据**：[适配与评测记录](../fixes/Light-R1-7B-DS.md)；[文件修改留档](../fixes/file_fixes/Light-R1-7B-DS.md)

## 现象

在 Hygon GPU5 单卡服务上，使用 native `TRITON_ATTN`、关闭 FlagGems attention 和 FL OOT，并按模型配置固定 `temperature=0.6`、`top_p=0.95`、`max_tokens=20000`，重新生成 MATH-500 五个 Level 共 50 题。

本轮每级得分为 `9/10、9/10、10/10、9/10、9/10`，总分 `46/50=92.00%`；日志显示 `0 already fully cached`，没有复用已有答案。

## 定位

通过配置将服务路径和评测口径明确分层：

- vLLM attention backend：`TRITON_ATTN`；
- `VLLM_FL_USE_FLAGGEMS_ATTN=0`：不使用 FlagGems attention；
- `VLLM_FL_OOT_ENABLED=0`：不注册 FL OOT；
- `VLLM_FL_FLAGOS_WHITELIST=attention_backend`：只保留 plugin-FL 路由标识，不启用普通 FlagGems 算子白名单；
- 评测按 thinking 模型使用其 `generation_config.json` 声明的 `0.6/0.95`；
- MATH-500 `--limit 10` 按 Level 生效，总题数为 `5 × 10=50`。

本轮只证明上述完整配置下的50题结果；没有通过单变量消融把精度归因到某一个开关。

## 处置

1. 使用统一 Hygon `xingcgen4` 镜像、BF16、TP1、eager、GPU5和端口8003部署；
2. 显式设置clang-18路径及独立Triton缓存；
3. 服务侧固定native `TRITON_ATTN`，关闭FlagGems attention和FL OOT；
4. 专用评测脚本按模型名固定`temperature=0.6`、`top_p=0.95`、`max_tokens=20000`；
5. 使用EvalScope 1.5.1、并发4、每个MATH-500 Level取10题；
6. 保存逐题predictions/reviews并审计结束原因。

## 结果

| 指标 | 值 |
|------|---:|
| Hygon MATH-500 50题 | `92.00%（46/50）` |
| NV MATH-500记录值 | `94.00%` |
| 绝对差 | `-2`个百分点 |
| 相对精度损失 | `2.13%` |
| Level 1--5 | `90% / 90% / 100% / 90% / 90%` |
| predictions / reviews | 各`50`条 |
| 自然停止 | `49`题 |
| 达到`max_tokens=20000` | `1`题，判分正确 |
| API error / runaway | `0 / 0` |
| 退出状态 | `exit=0`，`done=0` |
| 本轮判定 | **通过** |

结果证据：

```text
/public-flash/models/day0_logs/accuracy/Light-R1-7B-DS-math500-50-fix-whitelist-attn-oot-off-b4-20260918-0051.json
/public-flash/models/day0_logs/accuracy/Light-R1-7B-DS-math500-50-fix-whitelist-attn-oot-off-b4-20260918-0051.log
/public-flash/models/day0_logs/accuracy/Light-R1-7B-DS-math500-50-fix-whitelist-attn-oot-off-b4-20260918-0051.exit
/public-flash/models/day0_logs/accuracy/Light-R1-7B-DS-math500-50-fix-whitelist-attn-oot-off-b4-20260918-0051.done
/public-flash/models/day0_eval/outputs/math_500/20260918_045356
```

本轮通过指50题相对仓库NV记录值的精度门限通过；NV基线未附逐题产物，本报告不推断逐题同源对齐或性能验收结果。

## 提炼到 KNOWLEDGE 的条目

MATH-500抽样必须记录per-subset语义、每级题数与每级分数。reasoning模型的服务算子路径、采样参数和输出终止原因需要分别落盘；runaway为0时仍需检查是否命中`max_tokens`。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: qihoo360/Light-R1-7B-DS
# IMAGE: harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4
# GPU: Hygon DCU BW1000, physical GPU 5, 1 x 64GB
# TP: 1
# VERDICT: ok
# METRIC: math_500
# EVAL_QUESTIONS: 50
# SCORE_ORIGIN: 94
# SCORE_FLAGOS: 92
# CONTAINER_DEVS: --security-opt seccomp=unconfined --security-opt label=disable --device=/dev/kfd --device=/dev/dri --shm-size=64g --group-add=video -v /public-flash/models:/models -v /opt/hyhal:/opt/hyhal:ro
```

### 二、容器配置

```text
name: day0-light-r1-7b-ds
cmd: bash -lc 'sleep infinity'
network: host
ipc: host
shm-size: 64 GiB
mounts:
  /public-flash/models -> /models (rw)
  /opt/hyhal -> /opt/hyhal (ro)
devices: /dev/kfd, /dev/dri
security: seccomp=unconfined, label=disable
group: video
```

这是现有实例的配置留档；GPU5、端口8003或容器名已占用时不要重复创建。

### 三、启动服务

```bash
export DTK_HOME=/opt/dtk
export ROCM_PATH=/opt/dtk
export HIP_PATH=/opt/dtk/hip
export HSA_PATH=/opt/dtk/hsa
export DEVICE_LIB_PATH=/opt/dtk/amdgcn/bitcode
export TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18
export LD_LIBRARY_PATH=/opt/dtk/dcc/gcvm/lib:/opt/dtk/hip/lib:/opt/dtk/llvm/lib:/opt/dtk/lib:/opt/dtk/lib64:/opt/hyhal/lib:/opt/hyhal/lib64:/opt/dtk/dushmem/lib:/opt/dtk/opencl/lib:/opt/dtk/.hyhal/rocm_smi/lib:/usr/local/lib:/usr/local/lib64:/opt/mpi/lib

export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export HIP_VISIBLE_DEVICES=5
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
export FLAGGEMS_DB_URL=sqlite:///:memory:
export VLLM_FL_TRITON_CACHE_ROOT=/models/day0_logs/triton_cache/Light-R1-7B-DS-fix-whitelist-attn-oot-off
export VLLM_FL_FLAGOS_WHITELIST=attention_backend
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_FL_OOT_ENABLED=0

/usr/bin/python3 /usr/local/bin/vllm serve /models/Light-R1-7B-DS \
  --served-model-name Light-R1-7B-DS \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 131072 \
  --gpu-memory-utilization 0.90 \
  --port 8003 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code
```

评测脚本、精确差异和复现命令见[文件修改留档](../fixes/file_fixes/Light-R1-7B-DS.md)。
