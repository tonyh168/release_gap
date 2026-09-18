# Hygon/gemma-1.1-7b-it 适配与评测记录

- **日期**：`2026-09-16`
- **远端机器**：`10.232.2.33`
- **主机名**：`bm-srwl-nj-zone3-d-bw1000-64g-2-33`
- **历史失败报告**：`flagrelease_fail_reports/Hygon/FAILED_Hygon_gemma-1.1-7b-it_202607220702.md`
- **历史问题类型**：旧栈 V2 GPQA 为 `32%`，相对 NV `37%` 下降 `13.51%`；`silu_and_mul` OOT 路径还导致历史性能退化
- **本次处理结论**：新镜像单卡服务正常，关闭 FL OOT 后部分 50 题轮次通过，但同配置结果仍明显波动；全量 198 题校正后为 `32.83%`，相对 NV 下降 `11.27%`，精度尚未稳定修复

---

## 背景分析

历史报告使用 vLLM `0.20.2`、FlagGems `5.4.0dev`、Flagtree `0.6.1` 和已安装的 plugin-FL。V2 采用 27 项 FlagGems 算子，50 题 GPQA 为 `32%`，低于 NV 记录值 `37%`；历史性能问题在禁用 `silu_and_mul` 后恢复到合成 V1 基线的 `83.9%`。

本次改用统一 Hygon 新镜像，保留历史 FlagGems 白名单和 `silu_and_mul` 黑名单，并通过 `VLLM_FL_OOT_ENABLED=0` 关闭 vllm-plugin-FL 的高层 OOT 注册路径。50 题隔离实验一度提升到 `38%`、`40%` 和 `42%`，但相同协议也出现过 `32%`；全量 198 题结果为 `32.83%`，因此不能把一次小样本通过当作稳定修复。

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `bm-srwl-nj-zone3-d-bw1000-64g-2-33` / `10.232.2.33` |
| 芯片 | Hygon DCU BW1000，8 × 64GB |
| 推理容器 | `day0-gemma-1-1-7b-it` |
| 评测容器 | `day0-eval-standard` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4` |
| 镜像 ID | `sha256:b4dd95d30aa8213e0721856672ee544e773c51216b3737c12069b32ad71d07a0` |
| vLLM / PyTorch | `vLLM 0.24.0` / `PyTorch 2.10.0`（镜像版本口径） |
| 模型来源 | `google/gemma-1.1-7b-it` |
| 模型路径 | `/models/gemma-1.1-7b-it` |
| 宿主机共享路径 | `/public-flash/models/gemma-1.1-7b-it` |
| GPU | `HIP_VISIBLE_DEVICES=6` |
| 服务端口 | `8004` |

## Step 0：容器运行配置

推理容器由常驻进程保持运行，vLLM 通过 `docker exec` 在容器内启动：

```text
cmd:      ["bash", "-lc", "sleep infinity"]
network:  host
ipc:      host
shm-size: 64 GiB
```

设备与权限：

```text
/dev/kfd
/dev/dri
seccomp=unconfined
group-add=video
```

挂载：

```text
/public-flash/models -> /models      读写
/opt/hyhal           -> /opt/hyhal  只读
```

评测容器使用 host 网络，并挂载：

```text
/public-flash/models/day0_eval -> /models/day0_eval
/public-flash/models/day0_logs -> /models/day0_logs
```

## Step 1：启动 vLLM 服务

当前实际启动命令：

```bash
/usr/bin/python3 /usr/local/bin/vllm serve /models/gemma-1.1-7b-it \
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

当前服务检查：

```bash
curl http://127.0.0.1:8004/health
curl http://127.0.0.1:8004/v1/models
```

只读核验结果：`/v1/models` 返回 HTTP `200`，服务模型名为 `gemma-1.1-7b-it`，`max_model_len=8192`。

### 环境变量

```bash
export DTK_HOME=/opt/dtk
export ROCM_PATH=/opt/dtk-26.04-DCC2602-0317
export HIP_PATH=/opt/dtk-26.04-DCC2602-0317/hip
export HSA_PATH=/opt/dtk/hsa
export DEVICE_LIB_PATH=/opt/dtk/amdgcn/bitcode
export TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18

export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export HIP_VISIBLE_DEVICES=6
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200

export VLLM_FL_TRITON_CACHE_ROOT=/models/day0_logs/triton_cache/gemma-1.1-7b-it
export FLAGGEMS_ENABLE_OPLIST_PATH=/models/day0_logs/gemma-1.1-7b-it-enabled-ops-20260915-oot-disabled-final-v2.txt

export VLLM_FL_FLAGOS_WHITELIST=add,addmm_out,arange_start,argmax,broadcast_to,copy_,cos,expand,full,index,linear,lt_scalar,mm_out,rand_like,randn,reciprocal,sin,softmax,softmax_out,sub,to_copy,true_divide,true_divide_,where_self,where_self_out,zero_,zeros

export VLLM_FL_OOT_BLACKLIST=silu_and_mul
export VLLM_FL_OOT_ENABLED=0
```

`VLLM_FL_OOT_ENABLED=0` 关闭的是 vllm-plugin-FL 向 vLLM 注册的高层 OOT 替换路径，不会关闭上述普通 FlagGems 白名单。由于 OOT 已整体关闭，保留的 `silu_and_mul` 黑名单主要用于配置追溯，不再单独改变本轮注册结果。

服务没有显式传入 prefix cache 或 chunked prefill 开关；vLLM `0.24.0` 实际日志显示二者均为默认开启：

```text
enable_prefix_caching=True
enable_chunked_prefill=True
```

## Step 2：模型文件和容器变更

模型文件位于：

```text
/public-flash/models/gemma-1.1-7b-it
```

本次没有重新构建、重新打 tag 或推送镜像，也没有修改 vLLM、vllm-plugin-FL 或 FlagGems 源码。主要运行时变更为：

- 固化历史 27 项 FlagGems 白名单；
- 保留 `silu_and_mul` OOT 黑名单；
- 新增 `VLLM_FL_OOT_ENABLED=0`，关闭全部 FL OOT 注册；
- 使用独立 Triton 缓存和算子记录文件；
- 生成部署、服务、A/B 诊断和评测日志。

当前重部署证据：

```text
/public-flash/models/day0_logs/gemma-1.1-7b-it-deploy-20260916-103723.log
/public-flash/models/day0_logs/gemma-1.1-7b-it-serve-20260916-103723.log
```

## Step 3：评测

评测服务地址：

```text
http://127.0.0.1:8004/v1
```

统一评测配置：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.5.1` |
| 正式全量题数 | 198 |
| 快速诊断题数 | 50 |
| `eval_batch_size` | 4 |
| `temperature` | 0 |
| `max_model_len` | 8192 |
| `max_tokens` | 4096 |
| 截断检测 | 通过 `--skip-truncation-check` 显式跳过，不能据此声明已排除截断 |

### 全量 198 题

结果文件：

```text
/public-flash/models/day0_logs/accuracy/gemma-1.1-7b-it-gpqa198-oot-disabled-full-20260915.json
```

结果摘要：

```json
{
  "score": 32.83,
  "evalscope_score": 31.82,
  "total_questions": 198,
  "eval_batch_size": 4,
  "temperature": 0,
  "max_tokens": 4096,
  "max_model_len": 8192,
  "runaway_detection": {
    "runaway_count": 0
  },
  "answer_extraction_audit": {
    "parser_false_negative_count": 3
  }
}
```

格式校正后 `32.83%` 对应 `65/198`，EvalScope 原始分 `31.82%` 对应 `63/198`。NV 记录值为 `37%`，绝对低 `4.17` 个百分点，相对退化 `11.27%`，不达标。

### 50 题重复性与缓存 A/B

| 配置/轮次 | EvalScope 原始分 | 格式校正分 | 结论 |
|---|---:|---:|---|
| OOT 关闭，正式轮次 1 | 38% | 38% | 达标 |
| OOT 关闭，同服务重复轮次 | 32% | 32% | 不达标 |
| OOT 关闭，第三轮 | 38% | 38% | 达标 |
| Prefix Cache 开启，冷缓存 | 36% | 36% | 达标 |
| Prefix Cache 开启，热缓存 | 32% | 32% | 不达标 |
| Prefix Cache 关闭，第 1 轮 | 40% | 42% | 达标 |
| Prefix Cache 关闭，第 2 轮 | 36% | 36% | 达标 |
| 2026-09-16 明确变量重部署后 | 40% | 42% | 达标，但仅单轮小样本 |

最新重部署后的 50 题结果：

```text
/public-flash/models/day0_logs/accuracy/gemma-1.1-7b-it-gpqa50-explicit-env-redeploy-20260916-1046.json
```

该轮 EvalScope 原始分为 `40%`，答案提取审计后为 `42%`（21/50），无 runaway；相对 NV 记录值高 5 个百分点。但在它之前，同一 OOT 关闭正式服务也测得过 `32%`，因此该轮不能覆盖全量结论。

## 现象

- 新镜像下服务稳定启动，端口 `8004` 返回 HTTP `200`；
- 关闭 OOT 后，50 题结果可从 `32%` 提升到 `38%`、`40%` 或 `42%`；
- 相同 50 题、相同 target、`temperature=0`、并发 4 时，重复轮次仍出现大量答案和完整输出变化；
- Prefix Cache 关闭后仍有明显运行间波动，因此 prefix cache 不是充分根因；
- 全量 198 题校正后仅 `32.83%`，没有 runaway，但仍明显低于 NV 记录值。

## 定位

当前证据支持以下结论：

1. 答案解析确实会影响约 1--2 个百分点，但不足以解释全部精度差距；
2. 关闭 OOT 会改变推理数值路径，部分轮次有明显改善，因此 OOT 是相关因素；
3. OOT 关闭后仍存在批量推理非确定性，不能把问题锁定为单一 OOT 算子；
4. Prefix Cache 开关不能消除波动，不是充分根因；
5. 下一步应继续隔离 `eval_batch_size=1`、chunked prefill 及 FlagGems/OOT 的 2×2 组合，定位剩余非确定性。

`nv_baseline.yaml` 仅记录 NV 分数 `37%`，没有 NV 原始题目 ID、样本量、prompt、EvalScope 版本和逐题预测。因此当前 NV 比较只能作为仓库记录值比较，不能证明两侧逐题严格同源。

## 处置

1. 使用统一 Hygon 新镜像和单卡 GPU6；
2. 保留历史 Gemma FlagGems 白名单；
3. 保留 `VLLM_FL_OOT_BLACKLIST=silu_and_mul`；
4. 增加 `VLLM_FL_OOT_ENABLED=0`，关闭 FL OOT 注册路径；
5. 固定 `TRITON_ATTN`、BF16、TP=1、eager 模式；
6. 对相同 50 题执行重复评测及 Prefix Cache 严格 A/B；
7. 使用同一 EvalScope `1.5.1` 和并发 4 完成全量 198 题；
8. 同时保留 EvalScope 原始分、答案提取校正分和逐题异常审计。

## 当前结果

- 服务：正常，GPU6，端口 `8004`
- 当前部署：历史 FlagGems 白名单保留，FL OOT 整体关闭
- GPQA Diamond 全量 198 题：`32.83%`（65/198，格式校正后）
- EvalScope 全量原始分：`31.82%`（63/198）
- NV 参考值：`37.0%`
- 全量相对退化：`11.27%`
- 全量精度判定：❌ 不达标
- 最新 50 题：原始 `40%`，校正后 `42%`，仅说明该轮小样本达标
- 性能验收：本次未重测

## 可复用规则

精度异常模型不能用单轮 50 题通过代替全量结论。应固定同一题目、评测器版本、并发和生成参数，至少重复两轮并保存逐题输出；然后按 `FlagGems 开/关 × OOT 开/关` 做 2×2 隔离。怀疑缓存时必须分别执行冷/热缓存和关闭缓存重复轮次。只有某变量关闭后重复结果稳定，才能把它判定为根因；“一次提高”只能记为候选缓解措施。
