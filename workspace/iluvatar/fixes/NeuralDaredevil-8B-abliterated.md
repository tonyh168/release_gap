# iluvatar/NeuralDaredevil-8B-abliterated 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_NeuralDaredevil-8B-abliterated_202608090544.md
- **原始失败类型**：服务启动失败（Operator crash）+ 精度/性能不达标（全部评测数据为空）
- **日期**：

---

## 背景分析

原报告显示算子 crash，所有评测数据均为空，服务在 V1 阶段就无法起来。
原始环境 FlagGems 5.3.0rc2（较新，但仍是 RC 版），3 个 issue 已提交。
本次用正式 release 镜像（FlagGems 5.3.4.post1），先确认 eager 模式能否起服务；
若仍 crash，抓栈定位缺实现算子并加入黑名单。

NeuralDaredevil-8B 为 8B 量级（Llama 架构 abliterated 版）。**TP=1**（8B bf16 ~16 GB，单卡 32 GB）。

---

## 环境（实际运行时填写）

| 项目 | 值 |
|------|---|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-neuraldaredevil-8b` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/NeuralDaredevil-8B-abliterated` |
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
model_name=neuraldaredevil-8b-abliterated
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

权重来源：`mlabonne/NeuralDaredevil-8B-abliterated`（ModelScope）

```bash
ls /models/flagrelease/fixes_models/NeuralDaredevil-8B-abliterated/
```

若需下载（eval-scope 容器里）：
```bash
docker exec -it eval-scope bash
modelscope download --model mlabonne/NeuralDaredevil-8B-abliterated \
  --local_dir /models/flagrelease/fixes_models/NeuralDaredevil-8B-abliterated
```

---

## Step 3：起 vLLM 服务

原报告 Operator crash（FlagGems 5.3.0rc2），所有评测数据为空。
新镜像 FlagGems 5.3.4.post1 为正式 release，先以默认黑名单 eager 起服务；
若仍 crash，抓栈定位缺实现算子并补充黑名单。

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=0
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
model_name=NeuralDaredevil-8B-abliterated
mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} --dtype bfloat16 \
  --tensor-parallel-size 1 --gpu-memory-utilization 0.9 \
  --port 8000 --attention-backend TRITON_MLA \
  --enforce-eager --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log

若仍 crash，补充崩溃算子至黑名单：
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
model_name=NeuralDaredevil-8B-abliterated
python3 fast_gpqa.py --model-name ${model_name} --api-base http://127.0.0.1:8000/v1 \
  --output /models/release_run_logs/${model_name}/gpqa.json
python3 accuracy_compare.py --v2 /models/release_run_logs/${model_name}/gpqa.json \
  --nv-baseline ${model_name} --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict.json
```

| 迭代 | 黑名单 | GPQA | 退出码 | 备注 |
|------|--------|------|--------|------|
| 第1次 | | | | |
| 第2次 | | | | |

---

## 现象
（贴启动崩溃关键行；原报告全空，FlagGems 5.3.0rc2 环境 crash）

## 定位
（FlagGems 5.3.4.post1 正式版是否修复该 crash；若否，哪个算子仍缺实现）

## 处置
（加黑名单算子 / 调整 TRITON_MLA 设置）

## 结果
- 修复后 GPQA 正确率：
- NV 基线：
- 达标判定（accuracy_compare 退出码）：

## 提炼到 KNOWLEDGE 的条目
（一句话规律，若无则写"无新规律"）
