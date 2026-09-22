# T-Head/Ministral-8B-Instruct-2410 适配与评测记录

- **日期**：`2026-09-16`
- **远端机器**：`244-pm-aliyun-wlcb-zoned-d-810e-96G`（`8.130.132.221`）
- **主机名**：`dsw-879515-f5bf65bfd-jd7bj`
- **历史失败报告**：`flagrelease_fail_reports/T-Head/FAILED_T-Head_Ministral-8B-Instruct-2410_202609090702.md`
- **历史问题类型**：精度在小样本容忍范围内，但自动化流程按人工裁定标记为迁移失败，主要遗留性能验收问题
- **本次处理结论**：当前 PPU 机器上的新镜像服务正常，50 题 GPQA 精度按项目小样本规则通过；性能和完整 V1-V3 对比本次未重测

---

## 背景分析

历史报告中 Ministral-8B-Instruct-2410 使用 vLLM 0.24.0、plugin-FL 0.3.0 和另一套自动化运行环境，V2 GPQA 为 `26.0%`，相对 NV 参考值 `30.0%` 差 2 题，精度按小样本规则达标，但整体流程仍因性能验收被标记为失败。

本次将模型放入统一 PPU 镜像，在同一推理容器中单卡启动，并用独立评测容器完成 50 题 GPQA Diamond 重测。

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
| 模型来源 | `mistralai/Ministral-8B-Instruct-2410` |
| 模型路径 | `/models/Ministral-8B-Instruct-2410` |
| 宿主机共享路径 | `/mnt/workspace/models/Ministral-8B-Instruct-2410` |
| GPU | `CUDA_VISIBLE_DEVICES=3` |
| 服务端口 | `18081` |

三个模型共用长驻推理容器，模型权重、日志和缓存均通过 `/models` 绑定到 `/mnt/workspace/models`。

## Step 0：容器运行配置

容器由以下长驻进程保持运行，vLLM 在容器内通过 `docker exec` 手动拉起：

```text
entrypoint: ["bash", "/opt/t-head/entrypoint.sh"]
cmd:        ["sleep", "infinity"]
network:    host
ipc:        host
privileged: true
shm-size:   512 GiB
```

挂载：

```text
/dev                  -> /dev
/usr/local/PPU_SDK    -> /usr/local/PPU_SDK
/mnt/workspace/models -> /models
```

宿主机上的实际容器配置经 `docker inspect` 核对。以下命令可在同名容器不存在时重建等价的长驻推理容器；`sleep infinity` 是容器 CMD，模型服务另由 `docker exec` 启动：

```bash
set -euo pipefail
test -d /dev
test -d /usr/local/PPU_SDK
test -d /mnt/workspace/models/Ministral-8B-Instruct-2410

docker run -d \
  --name flagrelease_thead_model_dl_20260915 \
  --network host \
  --ipc host \
  --privileged \
  --shm-size=512g \
  -v /dev:/dev \
  -v /usr/local/PPU_SDK:/usr/local/PPU_SDK \
  -v /mnt/workspace/models:/models \
  harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100 \
  sleep infinity
```

评测容器 `flagrelease_thead_eval_20260915` 只需要 `/mnt/workspace/models:/models`；它不执行 PPU 推理，因此没有挂载 `/dev` 或 `/usr/local/PPU_SDK`。

## Step 1：启动 vLLM 服务

实际启动命令：

```bash
/usr/local/bin/vllm serve /models/Ministral-8B-Instruct-2410 \
  --served-model-name Ministral-8B-Instruct-2410 \
  --host 0.0.0.0 \
  --port 18081 \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.85 \
  --trust-remote-code \
  --enforce-eager
```

当前服务检查：

```bash
curl http://127.0.0.1:18081/health
curl http://127.0.0.1:18081/v1/models
```

结果：健康检查 HTTP `200`，模型名为 `Ministral-8B-Instruct-2410`。

### 环境变量

```bash
export CUDA_VISIBLE_DEVICES=3
export VLLM_PLUGINS=fl
export USE_FLAGGEMS=1
export VLLM_FL_PREFER_ENABLED=true
export VLLM_FL_OOT_BLACKLIST=silu_and_mul

export VLLM_FL_FLAGOS_WHITELIST=lift_fresh,empty,zero_,zeros,arange_start,true_divide,pow_scalar,reciprocal,mul,unsqueeze,cos,sin,cat,to_copy,ones,narrow,fill_scalar_,mm_out,index,rand_like,linear,alias,full,argmax,lt_scalar,scalar_tensor,where_self,where_self_out,true_divide_,softmax,softmax_out,exponential_,unbind,add,copy_,sub,expand,scatter_,attention_backend,rms_norm,silu_and_mul,rotary_embedding

export PPU_HOME=/usr/local/PPU_SDK
export CUDA_HOME=/usr/local/PPU_SDK/CUDA_SDK
export HF_ENDPOINT=https://hf-mirror.com
```

容器基础环境中 `XPU_VISIBLE_DEVICES=all`，当前服务通过 `CUDA_VISIBLE_DEVICES=3` 绑定实际计算设备。

当前实际使用的主要 FlagOS 路径包括 `attention_backend`、`rms_norm`、`rotary_embedding`、`silu_and_mul`。没有修改 vLLM、plugin-FL 或 FlagGems 源码。

## Step 2：模型文件和容器变更

模型文件位于：

```text
/mnt/workspace/models/Ministral-8B-Instruct-2410
```

镜像本身没有重新构建、重新打 tag 或 push。容器可写层的变化主要来自：

- 安装 `modelscope==1.40.0`、`modelscope-hub==0.4.2`；
- ModelScope、pip、vLLM model-info 等缓存；
- FlagGems/Triton 运行时临时文件；
- `/models` 绑定共享目录中的模型、日志和缓存。

没有修改 `/workspace/vllm`、`/workspace/vllm-plugin-FL` 或 `/workspace/FlagGems` 中的算子实现。

服务日志：

```text
/models/_serve_logs/Ministral-8B-Instruct-2410-20260915_155906.log
```

## Step 3：评测

评测服务地址：

```text
http://127.0.0.1:18081/v1
```

评测配置：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.5.1` |
| 题数 | 50 |
| `eval_batch_size` | 4 |
| `max_model_len` | 32768 |
| `max_tokens` | 24576 |
| 截断检测 | 未检测到截断 |
| 评测耗时 | 1593.69 秒 |

结果文件：

```text
/mnt/workspace/models/_eval_results/20260915_accuracy/formal_20260915_164849/Ministral-8B-Instruct-2410/Ministral-8B-Instruct-2410_gpqa_result.json
```

结果摘要：

```json
{
  "score": 28.0,
  "evalscope_score": 28.0,
  "total_questions": 50,
  "truncation_detected": false,
  "answer_extraction_audit": {
    "checked": 50,
    "format_corrected_score": 28.0,
    "parser_mismatch_count": 0,
    "invalid_evalscope_extract_count": 3
  },
  "verdict": {
    "aligned": true,
    "raw_aligned": false,
    "noise_adjusted": true,
    "nv_score": 30.0,
    "current_score": 28.0,
    "rel_drop": 0.0667,
    "diff_questions": 1.0,
    "threshold": 0.05
  }
}
```

## 现象

- 服务正常启动并完成评测；
- 当前得分比 NV 记录值低 2 个百分点，即 50 题只差 1 题；
- 按单纯相对退化计算为 `6.67%`，超过 5%；
- 由于评测题数为 50，绝对差为 1 题，命中项目小样本噪声容忍规则。

## 定位

本次没有发现服务崩溃、输出截断或答案解析错位。当前“通过”依赖项目规定的小样本容忍规则，不是严格相对退化小于等于 5% 的通过。

## 处置

1. 使用统一 PPU 镜像重新启动模型；
2. 使用 GPU3、端口 `18081`、TP=1；
3. 保留当前 FlagOS 算子白名单；
4. 使用独立评测容器，固定 GPQA 50 题；
5. 对原始分数执行答案提取审计和小样本噪声判定。

## 当前结果

- 服务：正常，端口 `18081`，GPU3
- GPQA Diamond：`28.0%`（14/50）
- NV 参考基线：`30.0%`
- 原始相对退化：`6.67%`
- 绝对差：1 题
- 项目判定：✅ 精度通过（小样本噪声容忍）
- 本次完整性能验收：未重测

## 可复用规则

50 题 GPQA 的结果必须同时记录 `current_score`、NV 分数、相对退化和绝对差题数。Ministral 本次属于“原始相对退化超 5%，但按绝对差 1 题容忍通过”，后续汇报时不能简写成“严格 5% 相对退化达标”。
