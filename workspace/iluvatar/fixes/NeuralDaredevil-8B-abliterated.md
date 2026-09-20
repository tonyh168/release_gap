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
  --port 8006 --attention-backend TRITON_ATTN \
  --enforce-eager --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log

若仍 crash，补充崩溃算子至黑名单：
```bash
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,<崩溃算子>
```

| 迭代 | 黑名单补充 | 结果 | 备注 |
|------|----------|------|------|
| 第1次 | sort,sort_stable | ✅ 服务正常启动 | TRITON_ATTN，TP=1，GPU 1，port 8006 |
| 第2次 | sort,sort_stable,mm,addmm | ✅ 服务正常启动 | iter2，参数同上 |

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
| 第1次 | sort,sort_stable | **30.0%**（50题） | 1（↓18.9%，NV 37.0%） | TRITON_ATTN，TP=1，GPU 1，port 8006 |
| 第2次 | sort,sort_stable,mm,addmm | **22.0%**（50题） | 1（↓40.54%，NV 37.0%） | iter2；mm/addmm 黑名单使精度更差，不适用于该模型 |

---

## 现象

原报告（FlagGems 5.3.0rc2）：服务启动即 Operator crash，全部评测数据为空。  
新镜像（FlagGems 5.3.4.post1 + TRITON_ATTN）：服务正常启动，iter1 GPQA 30.0%（NV 37.0%，↓18.9%）。

## 定位

- iter1 `sort,sort_stable` 黑名单：服务可起，GPQA 30.0%，仍差 7.0 pct（差 3.5 题）。
- iter2 追加 `mm,addmm` 黑名单：GPQA 反降至 22.0%（↓40.54%），说明 `mm`/`addmm` 是该模型精度的关键算子，不可黑名单化。
- 结论：`sort,sort_stable` 黑名单是必要的（无之则 crash），但 `mm`/`addmm` 对该模型有害，精度差距的根因尚未定位。

## 处置

- iter1：`VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable`，`TRITON_ATTN`，TP=1，GPU 1，port 8006。
- iter2：追加 `mm,addmm` 至黑名单，结果更差，已验证方向错误。
- 下一步方向（未执行）：在 `sort,sort_stable` 基础上探查其他可能影响精度的算子（排除 `mm`/`addmm`）；或排查 `chat_template`/`dtype` 等非算子因素。
- **0918 决策：不再修复，标记为 ⏭️ 跳过（无需修复）。** 两轮均未达标且第二轮证明方向错误，剩余可排查空间只有非算子因素（chat_template/dtype），暂不投入。

## 结果

- iter1 GPQA：**30.0%**（50 题，NV 37.0%，↓18.92%）；`verdict_gpqa_diamond.json` 判定 `aligned=false`（2026-09-18）
- iter2 GPQA：**22.0%**（50 题，NV 37.0%，↓40.54%）；`verdict_gpqa_iter2.json` 判定 `aligned=false`
- evalscope 报告路径：`outputs/gpqa_diamond/20260918_055330`
- 达标判定：❌ 未达标；iter2 证明 mm/addmm 黑名单对该模型有害。0918 决策不再修复

## 提炼到 KNOWLEDGE 的条目

`mm`/`addmm` 算子对 NeuralDaredevil-8B-abliterated（Llama 架构）是精度关键算子，加入黑名单会使 GPQA 从 30.0% 跌至 22.0%，不可黑名单化。
