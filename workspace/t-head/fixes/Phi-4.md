# T-Head/Phi-4 适配与评测记录

- **日期**：`2026-09-17`
- **远端机器**：`244-pm-aliyun-wlcb-zoned-d-810e-96G`（`8.130.132.221`）
- **主机名**：`dsw-879515-f5bf65bfd-jd7bj`
- **模型来源**：`microsoft/phi-4`
- **本次处理结论**：最小 FlagOS 白名单方向有效，但当前正式端口 50 题复测未稳定达标；服务已替换为优化配置

---

## 背景分析

Phi-4 在当前统一 PPU 镜像中可以正常启动并完成 GPQA Diamond 50 题评测。初始服务使用较宽 FlagOS 白名单，50 题结果为 `66.0%`，相对 NV 参考值 `73.0%` 超过 5% 容差。

排查时先验证采样参数，再验证算子白名单。`temperature=0.7` 未提升精度，结果下降到 `60.0%`；将 FlagOS 白名单收缩到 `attention_backend,rms_norm,silu_and_mul,rotary_embedding` 后，单次实验端口曾达到 `70.0%`，进入 5% 容差线。但将该方案替换到正式端口 `18084` 后，连续复测结果为 `64.0%`、`68.0%`、`68.0%`，说明该方案改善方向成立，但当前 50 题口径下不稳定，不能按稳定达标交付。

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `244-pm-aliyun-wlcb-zoned-d-810e-96G` / `8.130.132.221` |
| 芯片 | PPU-ZW810E，16 × 96GB |
| 推理容器 | `flagrelease_thead_model_dl_20260915` |
| 评测容器 | `flagrelease_thead_eval_20260915` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100` |
| 镜像 ID | `sha256:a54dcb164e0d9aad003884e6b0691400f6c8db1e56d513b03dc1c65d30f830ce` |
| vLLM / PyTorch | `vllm 0.24.0+empty` / `torch 2.10.0` |
| 模型路径 | `/models/phi-4` |
| 宿主机共享路径 | `/mnt/workspace/models/phi-4` |
| 当前 GPU | `CUDA_VISIBLE_DEVICES=11` |
| 当前服务端口 | `18084` |

## Step 0：容器运行配置

推理容器为长驻容器，PID 1 用于保持容器存活，vLLM 服务通过 `docker exec` 在容器内启动：

```text
entrypoint: ["bash", "/opt/t-head/entrypoint.sh"]
cmd:        ["sleep", "infinity"]
network:    host
ipc:        host
privileged: true
```

挂载：

```text
/dev                  -> /dev
/usr/local/PPU_SDK    -> /usr/local/PPU_SDK
/mnt/workspace/models -> /models
```

## Step 1：当前正式服务

旧的宽白名单 Phi-4 服务已从 `18084` 停止，临时优化实验服务 `18087` 也已停止。当前只保留优化后的正式服务：

```bash
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

健康检查：

```bash
curl http://127.0.0.1:18084/health
curl http://127.0.0.1:18084/v1/models
```

结果：健康检查 HTTP `200`，模型名为 `phi-4`。当前 `18087` 不再监听。

### 环境变量

```bash
export CUDA_VISIBLE_DEVICES=11
export HIP_VISIBLE_DEVICES=11
export XPU_VISIBLE_DEVICES=11

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
```

服务日志：

```text
/models/_serve_logs/phi-4-minflagos-formal-20260917-gpu11-port18084.log
```

日志确认实际使用的 FlagOS 路径包括：

```text
attention_backend
rms_norm
rotary_embedding
silu_and_mul
```

## Step 2：模型文件和容器变更

模型文件位于：

```text
/mnt/workspace/models/phi-4
```

镜像本身没有重新构建、重新打 tag 或 push。容器可写层变化主要来自：

- 安装 `modelscope==1.40.0`、`modelscope-hub==0.4.2`；
- ModelScope、pip、vLLM model-info 等缓存；
- FlagGems/Triton 运行时临时文件；
- `/models` 绑定共享目录中的模型、日志和缓存。

没有修改 `/workspace/vllm`、`/workspace/vllm-plugin-FL` 或 `/workspace/FlagGems` 中的源码和算子实现。

## Step 3：50 题评测记录

评测服务地址：

```text
http://127.0.0.1:18084/v1
```

通用评测配置：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.5.1` |
| 题数 | 50 |
| `max_model_len` | 16384 |
| `max_tokens` | 8192 |
| `temperature` | 0.0 |
| `top_p` | 1.0 |

结果汇总：

| 阶段 | 服务端口 | GPU | 配置 | `eval_batch_size` | 分数 | 结论 |
|------|---------|-----|------|-------------------|------|------|
| 初始服务 | `18084` | GPU2 | 宽 FlagOS 白名单 | 4 | `66.0%` | 未达标 |
| 采样实验 | `18084` | GPU2 | 宽白名单，`temperature=0.7` | 4 | `60.0%` | 采样无收益 |
| 优化实验 | `18087` | GPU11 | 最小白名单 | 4 | `70.0%` | 单次达标 |
| 正式替换复测 1 | `18084` | GPU11 | 最小白名单 | 4 | `64.0%` | 未达标 |
| 正式替换复测 2 | `18084` | GPU11 | 最小白名单 | 4 | `68.0%` | 未达标 |
| 正式替换复测 3 | `18084` | GPU11 | 最小白名单 | 1 | `68.0%` | 未达标 |

主要结果文件：

```text
/mnt/workspace/models/_eval_results/20260916_new_models/50/phi-4/phi-4_gpqa_result.json
/mnt/workspace/models/_eval_results/20260917_precision_fix/50/phi_temp07/phi-4_gpqa_result.json
/mnt/workspace/models/_eval_results/20260917_precision_fix/50/phi_minflagos/phi-4_gpqa_result.json
/mnt/workspace/models/_eval_results/20260917_precision_fix/50/phi_minflagos_formal_port18084_rerun/phi-4_gpqa_result.json
/mnt/workspace/models/_eval_results/20260917_precision_fix/50/phi_minflagos_formal_port18084_rerun2/phi-4_gpqa_result.json
/mnt/workspace/models/_eval_results/20260917_precision_fix/50/phi_minflagos_formal_port18084_batch1/phi-4_gpqa_result.json
```

当前正式复测最佳结果摘要：

```json
{
  "score": 68.0,
  "evalscope_score": 68.0,
  "total_questions": 50,
  "eval_batch_size": 1,
  "max_model_len": 16384,
  "answer_extraction_audit": {
    "checked": 50,
    "format_corrected_score": 68.0,
    "parser_mismatch_count": 0,
    "invalid_evalscope_extract_count": 0
  },
  "verdict": {
    "aligned": false,
    "raw_aligned": false,
    "noise_adjusted": false,
    "nv_score": 73.0,
    "current_score": 68.0,
    "rel_drop": 0.0685,
    "threshold": 0.05
  }
}
```

## 现象

- 宽白名单初始服务为 `66.0%`；
- 最小白名单曾在独立实验端口单次达到 `70.0%`；
- 替换到正式端口后，连续复测为 `64.0%`、`68.0%`、`68.0%`；
- `batch_size=1` 未提升分数，说明低分不是单纯并发评测导致；
- 逐题对比中，三次优化服务之间有 9 道题发生翻转，其余 41 道一致；
- 答案提取审计未发现大面积 parser mismatch。

## 定位

最小白名单可以减少宽白名单带来的精度损失，但 Phi-4 在当前 PPU/vLLM 组合下存在 50 题边界波动。由于正式服务连续复测未进入 5% 容差线，当前不能按稳定达标记录。

当前距离达标线的精确口径：

- NV 参考值：`73.0%`
- 5% 容差线：`73.0 * 0.95 = 69.35%`
- 当前正式服务最佳稳定复测：`68.0%`
- 50 题下 1 题等于 2 分，因此离达标线差 1 题；离 NV 参考值本身差约 2.5 题。

## 处置

1. 停止旧的 `18084` Phi-4 服务；
2. 停止临时 `18087` 优化实验服务；
3. 使用 GPU11、正式端口 `18084`、最小 FlagOS 白名单重新启动；
4. 完成健康检查和模型列表检查；
5. 在正式端口完成三次 50 题复测；
6. 保留当前优化服务作为后续继续排查的基线服务。

## 当前结果

- 服务：正常，端口 `18084`，GPU11
- 当前配置：最小 FlagOS 白名单
- 正式端口 50 题最佳复测：`68.0%`（34/50）
- NV 参考基线：`73.0%`
- 相对退化：`6.85%`
- 精度判定：❌ 未稳定达标
- 性能验收：未重测

## 可复用规则

当 50 题结果处在阈值边界附近时，不能只采用单次最好结果。需要至少记录：

1. 初始服务结果；
2. 优化实验结果；
3. 正式端口替换后的复测结果；
4. `eval_batch_size` 变化对结果的影响；
5. 答案提取审计结果；
6. 与 NV 参考值和 5% 容差线的题数差。

Phi-4 本次说明：白名单收缩是有效优化方向，但单次 50 题达到阈值不能等价于稳定达标。
