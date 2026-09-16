# iluvatar/AgentCPM-Report 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_AgentCPM-Report_202608120109.md
- **原始失败类型**：精度不达标（V2 GPQA=2.0% vs NV=46.0%，相对下降 95.65%）
- **日期**：

---

## 背景分析

V1 可能起服务但未留精度数据，V2 开启 FlagGems 后精度崩溃（GPQA 2.0%，远低于 NV 基线 46.0%）。
V2 替换了 33 个算子，其中某算子引入计算误差。2 个 issue 已提交。
原始环境 vLLM 0.20.2 + plugin-FL 0.2.0 + FlagGems 5.0.x；本次用新镜像（FlagGems 5.3.4.post1）。

AgentCPM-Report 为 7B 量级。TP 计算：7B bf16 ~14 GB，单卡 32 GB → **TP=1**。

---

## 环境（实际运行时填写）

| 项目 | 值 |
|------|---|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-agentcpm-report` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/AgentCPM-Report` |
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

---

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
model_name=agentcpm-report
docker run -itd --name flagrelease-fix-${model_name} \
  --device=/dev/iluvatar \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  ${IMAGE} bash
docker exec -it flagrelease-fix-${model_name} bash
ixsmi && python -c "import vllm; print(vllm.__version__)"
```

---

## Step 2：确认模型

权重来源：`openbmb/AgentCPM-Report`（ModelScope）

```bash
ls /models/flagrelease/fixes_models/AgentCPM-Report/
```

若需下载（eval-scope 容器里）：
```bash
docker exec -it eval-scope bash
modelscope download --model openbmb/AgentCPM-Report \
  --local_dir /models/flagrelease/fixes_models/AgentCPM-Report
```

---

## Step 3：起 vLLM 服务

精度崩溃（V2 GPQA 2.0% vs NV 46.0%）源于 FlagGems 5.0.x 33个替换算子中存在计算误差。
FlagGems 5.3.4.post1 已修复多个精度问题；先以默认黑名单起服务验证精度，若仍不达标扩大黑名单排查。

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=0
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
model_name=AgentCPM-Report
mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} --dtype bfloat16 \
  --tensor-parallel-size 1 --gpu-memory-utilization 0.9 \
  --port 8000 --attention-backend TRITON_MLA \
  --enforce-eager --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log

若精度仍不达标，逐步扩大黑名单排查引入误差的算子：
```bash
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,<疑似误差算子>
```

| 迭代 | 黑名单补充 | 结果 | 备注 |
|------|----------|------|------|
| 第1次 | 无 | | |
| 第2次 | | | |

---

## Step 4：评测

```bash
docker exec -it eval-scope bash
cd /workspace/release_评测标准
model_name=AgentCPM-Report
python3 fast_gpqa.py --model-name ${model_name} --api-base http://127.0.0.1:8000/v1 \
  --output /models/release_run_logs/${model_name}/gpqa.json
python3 accuracy_compare.py --v2 /models/release_run_logs/${model_name}/gpqa.json \
  --nv-baseline ${model_name} --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict.json
```

> NV 基线 GPQA=46.0%，相对容忍 5%，即需达到 ≥43.7%。

| 迭代 | 黑名单 | GPQA | 退出码 | 备注 |
|------|--------|------|--------|------|
| 第1次 | | | | |
| 第2次 | | | | |

---

## 现象
（贴 GPQA 分数；原 V2=2.0% vs NV=46.0%）

## 定位
（FlagGems 5.3.4.post1 是否修复精度；若仍低，定位引入误差的具体算子）

## 处置
（扩大黑名单 / 确认精度收敛至可接受范围）

## 结果
- 修复后 GPQA 正确率：
- NV 基线：46.0%
- 达标判定（accuracy_compare 退出码）：

## 提炼到 KNOWLEDGE 的条目
（一句话规律，若无则写"无新规律"）
