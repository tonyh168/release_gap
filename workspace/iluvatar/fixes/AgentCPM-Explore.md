# iluvatar/AgentCPM-Explore 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_AgentCPM-Explore_202608111909.md
- **原始失败类型**：服务启动失败（Operator crash — `silu_and_mul` 算子缺失）
- **日期**：

---

## 背景分析

原报告中 V1/V2 均无法起服务，关键错误为 `silu_and_mul` 算子在天数后端未实现。
原始环境 vLLM 0.20.2 + plugin-FL 0.2.0，3 个 issue 已提交。
本次修复使用最新镜像（vLLM 0.24.0 + plugin-FL 0.3.0 + FlagGems 5.3.4.post1），
先确认该算子是否已在新版中修复；若仍缺实现，将其加入 `VLLM_FL_FLAGOS_BLACKLIST` 挡回原生 aten。

AgentCPM-Explore 为 7B 量级模型。TP 计算：7B bf16 ~14 GB，单卡 32 GB → **TP=1**。

---

## 环境（实际运行时填写）

| 项目 | 值 |
|------|---|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-agentcpm-explore` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/AgentCPM-Explore` |
| 卡号 | `CUDA_VISIBLE_DEVICES=0`（TP=1）|
| 实际 vLLM 版本 | |

---

## Step 0：登录 + 查卡 + 拉取镜像

```bash
ssh iluvatar-139
ixsmi   # 确认至少 1 张卡空闲

# 首次登录时拉取两个镜像
docker pull harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope
docker pull harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
```

**ixsmi 输出节选**：
```
（上机后粘贴，确认空闲卡号）
```

---

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
model_name=agentcpm-explore
docker run -itd --name flagrelease-fix-${model_name} \
  --device=/dev/iluvatar \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  ${IMAGE} bash
docker exec -it flagrelease-fix-${model_name} bash

# 容器内自检
ixsmi
python -c "import vllm; print(vllm.__version__)"
```

**自检输出**：
```
vllm 版本：
```

---

## Step 2：确认模型

权重来源：`openbmb/AgentCPM-Explore`（ModelScope）

```bash
ls /models/flagrelease/fixes_models/ | grep -i agentcpm
ls /models/flagrelease/fixes_models/AgentCPM-Explore/
```

**结果**：☐ 共享盘已有 / ☐ 需下载

若需下载（在 eval-scope 容器里）：
```bash
docker exec -it eval-scope bash
modelscope download --model openbmb/AgentCPM-Explore \
  --local_dir /models/flagrelease/fixes_models/AgentCPM-Explore
ls /models/flagrelease/fixes_models/AgentCPM-Explore/
```

---

## Step 3：起 vLLM 服务

### 修复策略

原始失败是 `silu_and_mul` 算子缺失（Operator crash）。新镜像（vLLM 0.24.0 + FlagGems 5.3.4.post1）可能已修复；若仍报错，将该算子加入黑名单挡回原生 aten。

### 环境变量（每次迭代更新）

**第1次尝试**（SOP 默认黑名单，TP=1，eager 模式）：
```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=0
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200

model_name=AgentCPM-Explore
mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --attention-backend TRITON_MLA \
  --enforce-eager \
  --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log
```

**崩溃日志关键行**（贴 traceback 最后几行 + 算子名）：
```
（崩溃时粘贴，用于定位黑名单补充项）
```

**第N次尝试**（silu_and_mul 仍缺实现时）：
```bash
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,silu_and_mul
```

### 迭代记录

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST 补充项 | 结果 | 备注 |
|------|---------------------------------|------|------|
| 第1次 | （仅默认 sort,sort_stable） | | |
| 第2次 | silu_and_mul | | |

**启动成功的日志行**：
```
（贴 "Application startup complete"）
```

### 冒烟验证

```bash
model_name=AgentCPM-Explore
curl -s http://localhost:8000/v1/models
curl -s http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"中国的首都是哪个城市？请简要介绍。"}],"max_tokens":128,"temperature":0}'
```

**冒烟输出节选**：
```
（贴 content 字段前100字）
```

---

## Step 4：评测

```bash
# eval-scope 容器内
docker exec -it eval-scope bash
cd /workspace/release_评测标准

model_name=AgentCPM-Explore
python3 fast_gpqa.py --model-name ${model_name} \
  --api-base http://127.0.0.1:8000/v1 \
  --output /models/release_run_logs/${model_name}/gpqa.json
python3 accuracy_compare.py \
  --v2 /models/release_run_logs/${model_name}/gpqa.json \
  --nv-baseline ${model_name} \
  --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict.json
```

### 评测迭代记录

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST | GPQA 正确率 | accuracy_compare 退出码 | 备注 |
|------|--------------------------|------------|------------------------|------|
| 第1次 | | | | |
| 第2次 | | | | |

**verdict.json 原文**（最终达标）：
```json
（粘贴）
```

---

## 现象

原报告：服务启动失败，`silu_and_mul` 算子缺失（Operator crash），无评测数据。

新镜像下**问题未解决**：`serve.log`（2026-09-16）持续输出

```
EngineDeadError: EngineCore encountered an issue. See stack trace (above) for the root cause.
Error in chat completion stream generator.
```

评测侧随之失败——`eval.log` 末尾为 `openai.APIConnectionError: Connection error.` /
`[ERROR] 评测失败: Connection error.`（后端已死，客户端连不上）。

产出目录 `/models/release_run_logs/AgentCPM-Explore/` 下只有 `serve.log` + `eval.log` + `serve.pid`，
**无 result、无 verdict**。

## 定位

- vLLM 0.24.0 + FlagGems 5.3.4.post1 下 `silu_and_mul` 未修复，服务始终未能稳定起来（EngineCore 崩溃循环）。
- 崩溃发生在服务层，评测根本没跑起来，因此**没有任何精度数据**。
- 未进一步排查具体缺失算子（未尝试扩大黑名单隔离）。

## 处置

**0918 决策：不再修复，标记为 ⏭️ 跳过（无需修复）。**

如后续重启：可按原计划把 `silu_and_mul` 加入 `VLLM_FL_FLAGOS_BLACKLIST` 挡回原生 aten，
再抓 `EngineCore` 栈确认是否还有第二个崩溃算子。

## 结果

- 修复后 GPQA 正确率：**无**（服务未起，评测未产出）
- NV 基线：36.0%
- 达标判定：无法判定（无数据）
- 产物：仅有 `serve.log` / `eval.log`，无 `verdict_*.json`

## 提炼到 KNOWLEDGE 的条目

`EngineDeadError` 崩溃循环会让评测端表现为 `APIConnectionError`——看到评测报连接错误时，
先查服务端 `serve.log` 是否 EngineCore 已死，不要把连接错误误判为评测脚本或网络问题。
