# iluvatar/gemma-1.1-7b-it 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_gemma-1.1-7b-it_202608061005.md
- **原始失败类型**：全部数据为空（V1–V4 均无算子数据、无评测数据）
- **日期**：

---

## 背景分析

原报告 V1–V4 评测全空，无 issue 提交，流程仅耗时 32m39s，推测服务根本未能启动
（32 分钟内无法完成任何有效评测）。原始环境 vLLM 0.20.2 + FlagGems 5.0.0。
本次用新镜像（vLLM 0.24.0 + FlagGems 5.3.4.post1）从零复现，先以 eager 模式起服务，
抓启动日志确认失败原因。

gemma-1.1-7b-it 架构为 Gemma，attention 可能与标准 MHA 不同，注意 `--attention-backend` 设置。
**TP=1**（7B bf16 ~14 GB，单卡 32 GB 够用）。

---

## 环境（实际运行时填写）

| 项目 | 值 |
|------|---|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-gemma-1.1-7b-it` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/gemma-1.1-7b-it` |
| 卡号 | `CUDA_VISIBLE_DEVICES=0`（TP=1）|
| 实际 vLLM 版本 | |

---

## Step 0：登录 + 查卡 + 拉取镜像

```bash
ssh iluvatar-139
ixsmi

docker pull harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope
docker pull harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
```

---

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
model_name=gemma-1.1-7b-it
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

权重来源：`google/gemma-1.1-7b-it`（ModelScope）

```bash
ls /models/flagrelease/fixes_models/gemma-1.1-7b-it/
```

若需下载（eval-scope 容器里）：
```bash
docker exec -it eval-scope bash
modelscope download --model google/gemma-1.1-7b-it \
  --local_dir /models/flagrelease/fixes_models/gemma-1.1-7b-it
```

---

## Step 3：起 vLLM 服务

原报告 V1–V4 数据全空，32分钟内流程结束，推测为极早期服务启动失败。
Gemma 系列有独特 attention 实现，注意 `--attention-backend` 设置是否需调整。
先以 eager + 默认黑名单起服务，抓启动日志确认失败根因。

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=0
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
model_name=gemma-1.1-7b-it
mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} --dtype bfloat16 \
  --tensor-parallel-size 1 --gpu-memory-utilization 0.9 \
  --port 8000 --attention-backend TRITON_MLA \
  --enforce-eager --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log

若启动失败，抓栈关键行后补充黑名单：
```bash
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,<崩溃算子>
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
model_name=gemma-1.1-7b-it
python3 fast_gpqa.py --model-name ${model_name} --api-base http://127.0.0.1:8000/v1 \
  --output /models/release_run_logs/${model_name}/gpqa.json
python3 accuracy_compare.py --v2 /models/release_run_logs/${model_name}/gpqa.json \
  --nv-baseline ${model_name} --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict.json
```

> 若 gpqa 无基线（退出码3）→ 改跑 `--dataset mmlu` + `--metric mmlu`。

| 迭代 | 黑名单 | 指标/分数 | 退出码 | 备注 |
|------|--------|----------|--------|------|
| 第1次 | | | | |

---

## 现象
（贴启动日志关键行；原报告全空，需从头复现）

## 定位
（服务是否能在新镜像下启动；是否为 Gemma attention 实现问题）

## 处置
（补充黑名单 / 调整 --attention-backend）

## 结果
- 修复后正确率：
- NV 基线：
- 达标判定（accuracy_compare 退出码）：

## 提炼到 KNOWLEDGE 的条目
（一句话规律，若无则写"无新规律"）
