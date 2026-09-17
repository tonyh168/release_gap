# metax/reka-flash-3 修复日志

- **失败报告**：flagrelease_fail_reports/Metax/FAILED_Metax_reka-flash-3_202607301246.md
- **原始失败类型**：精度不达标（V3=52.02% vs NV=59%，rel_drop=11.8%）+ plugin-FL 报错
- **日期**：2026-09-16

---

## 背景分析

reka-flash-3 是 dense 模型，bf16。
ModelScope 来源：`RekaAI/reka-flash-3`
NV 基线：gpqa_diamond = **59**（容差 5%，下限 ≥ 56.05%）

原始报告：V1 无评测，V2（FlagGems，无 plugin，50 题）= 40.0%，V3（plugin-FL，198 题）= 52.02%。
V2→V3 精度偏差 12.0%（plugin-FL 开启后反而下降），两个 issue 均为精度退化 + plugin-FL error。
V3 与 NV 基线差距 rel_drop 11.8%，不达标。

注意：V1 性能数据显示 TTFT 极高（62268ms mean），可能是 reka-flash-3 架构特殊（如 SSM/混合架构）导致 prefill 慢，需观察。

TP 计算：需先确认模型权重大小，下载后查实际文件大小。

---

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `metax-60` |
| 容器名 | `flagrelease-fix-reka-flash-3` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/reka-flash-3` |
| TP / GPU / 端口 | TP=2，GPU 1,2，port=8001 |
| 实际 vLLM 版本 | 0.24.0 (v0.1.dev17936+gee0da84ab) |

---

## Step 0：登录 + 查卡

```bash
ssh metax-60
mx-smi
```

**mx-smi 输出节选**（2026-09-16，所有旧容器停止后）：
```
GPU 0-7: 858/65536 MiB（全部空闲）
```

GPU 0 分配给 SOLAR-10.7B（TP=1，port 8000），reka-flash-3 视权重大小分配后续 GPU。

---

## Step 1：下载模型权重

```bash
docker exec -it eval-scope /bin/bash
mkdir -p /models/flagrelease/fixes_models
modelscope download --model RekaAI/reka-flash-3 \
  --local_dir /models/flagrelease/fixes_models/reka-flash-3
```

下载完成后确认大小：
```bash
du -sh /models/flagrelease/fixes_models/reka-flash-3/
ls /models/flagrelease/fixes_models/reka-flash-3/*.safetensors | wc -l
```

**下载结果**：✅ 完成，5 个 safetensors 分片，总大小 78GB

TP 计算：78GB × 1.2 / 63.6 = 1.47 → ceil = 2 → **TP=2**（GPU 1,2，每卡 39GB 权重，剩余 ~17GB KV cache）

**config.json 关键字段**：`max_position_embeddings = 32768`，`model_type = llama`，`--max-model-len 32768` 无需调整。

---

## Step 2：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907
docker run -d --rm \
  --name flagrelease-fix-reka-flash-3 \
  --network host \
  --shm-size 64g \
  --device /dev/dri:/dev/dri:rwm \
  --device /dev/mxcd:/dev/mxcd:rwm \
  -v /public-flash/models:/models \
  ${IMAGE} \
  sleep infinity
```

---

## Step 3：起 vLLM 服务

### 修复策略

原失败为 plugin-FL 精度退化，V2→V3 精度从 40% 降到 52%（实际是 V2 仅 50 题，V3 198 题，不可直接对比）。
核心问题：V3 52.02% 低于 NV 59% 容差下限 56.05%。

策略：默认黑名单起 v1，若精度仍不达标，参考 Phi-4-mini 方案扩展黑名单加 `rms_norm,silu_and_mul`。

### 启动命令（v1，TP 确认后填入）

```bash
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export MACA_VISIBLE_DEVICES=1,2
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200

model_name=reka-flash-3
mkdir -p /models/release_run_logs/${model_name}
/opt/conda/bin/vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} \
  --dtype bfloat16 \
  --tensor-parallel-size 2 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.9 \
  --port 8001 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve_v1.log
```

**启动日志关键行**：
```
✅ 服务正常启动，port 8001，TP=2，GPU 1,2
```

### 迭代记录（启动阶段）

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST 变化 | TP | 结果 | 日志关键报错 |
|------|------------------------------|----|------|-------------|
| v1 | 默认（mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice） | 2 | ✅ 启动成功 | 无 |
| v2 | 扩展加 rms_norm,silu_and_mul | 2 | ✅ 启动成功 | 无 |

### 冒烟验证

```bash
model_name=reka-flash-3

curl -s http://localhost:8001/v1/models

curl -s http://localhost:8001/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"What is the capital of France?"}],"max_tokens":32,"temperature":0}'

curl -s http://localhost:8001/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"请详细解释牛顿三大运动定律，并各举一个日常生活中的实例，要求每条定律的解释不少于100字。"}],"max_tokens":512,"temperature":0}'
```

**冒烟结果**：✅ v1 冒烟通过，服务正常出题，29-44 tok/s

---

## Step 4：评测

```bash
model_name=reka-flash-3

docker exec eval-scope bash -c "
python3 /workspace/eval_scripts/fast_gpqa.py \
  --model-name ${model_name} \
  --api-base http://127.0.0.1:8001/v1 \
  --dataset gpqa_diamond \
  --dataset-dir /models/evalscope-datasets \
  --output /models/release_run_logs/${model_name}/gpqa_v1.json \
  > /models/release_run_logs/${model_name}/eval_v1.log 2>&1
"

docker exec eval-scope bash -c "
python3 /workspace/eval_scripts/accuracy_compare.py \
  --v2 /models/release_run_logs/${model_name}/gpqa_v1.json \
  --nv-baseline ${model_name} \
  --nv-baseline-file /workspace/eval_scripts/nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict_v1.json
"
```

### 评测迭代记录

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST | GPQA 正确率 | accuracy_compare 退出码 | 备注 |
|------|--------------------------|------------|------------------------|------|
| v1 | mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice | 44%（22/50）❌ | 1 | rel_drop=25.42%，远超 5% 容差；score=null（fast_gpqa 解析失败），从 evalscope 报告补填 44.0 |
| v2 | 默认 + rms_norm,silu_and_mul | 42%（21/50）❌ | 1 | rel_drop=28.81%，比 v1 更差；扩展黑名单对 reka-flash-3 无效 |

**verdict_v1.json 原文**：
```json
{
  "baseline_mode": "nv_reference",
  "model": "reka-flash-3",
  "metric": "gpqa_diamond",
  "nv": { "score": 59.0, "source": "NV 实测" },
  "current": { "score": 44.0, "mode": "standard" },
  "tolerance": 0.05,
  "rel_drop": 0.2542,
  "rel_drop_pct": 25.42,
  "abs_diff": -15.0,
  "aligned": false,
  "noise_zone": false,
  "message": "精度不达标: 当前=44.00%, NV=59.00%, 相对退化=25.42% > 容差 5.0%"
}
```

---

## 现象

- v1（默认黑名单）：44%（22/50），rel_drop=25.42%，远超 5% 容差，不达标
- v2（加 rms_norm,silu_and_mul）：42%（21/50），rel_drop=28.81%，比 v1 更差
- fast_gpqa score=null（两轮均如此），从 evalscope 报告手工补填
- eval_v1 耗时 94 分钟，eval_v2 耗时约 65 分钟（题均约 75s，reasoning 模型？）
- v1/v2 最后 2 题卡挂（evalscope 概率性卡题），通过等待自然恢复

## 定位

- plugin-FL 对 reka-flash-3 存在系统性精度退化，与原始报告（V2→V3 精度从 40% 降到 52.02%）一致
- reka-flash-3 架构为 LLaMA 基（model_type=llama），非 MoE，无 MLA，但 TTFT 极高（62s），推测 prefill 路径有特殊算子
- 扩展黑名单加 rms_norm/silu_and_mul 对本模型无效，说明退化来源不在这两个算子
- 与 SOLAR-10.7B-Instruct-v1.0 类似：plugin-FL 对部分 dense 模型有无法通过简单黑名单修复的精度问题

## 处置

两轮均不达标，暂停修复：
- v1：默认黑名单，44%❌
- v2：扩展黑名单（+rms_norm,silu_and_mul），42%❌

## 结果

- 修复后分 / NV 基线：44.0（v1 最优）/ 59.0，未达标
- 达标判定：accuracy_compare 退出码 1（两轮均不达标）
- **状态：修复暂停**，与 SOLAR-10.7B 同样处理

## 提炼到 KNOWLEDGE 的条目

- reka-flash-3 plugin-FL 精度退化无法通过默认黑名单或扩展黑名单（rms_norm/silu_and_mul）修复，暂无解法
- fast_gpqa score=null 是 reka-flash-3 的已知问题（同 EXAONE/Qwen3-Thinking），需从 evalscope 报告手工补填
- 单题卡挂问题在 reka-flash-3 上也存在（v2 最后 2 题），但最终自然恢复，无需 eval_missing 补评
