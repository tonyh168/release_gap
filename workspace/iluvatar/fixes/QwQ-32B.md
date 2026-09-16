# iluvatar/QwQ-32B 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_QwQ-32B_202608261444.md
- **原始失败类型**：服务启动失败（全部评测数据为空，流程仅 37 分钟）
- **日期**：

## 背景分析

原报告 V1–V4 全空，37分钟内流程结束，说明服务在 V1 阶段就起不来。
原始环境 vLLM 0.20.2 + plugin-FL 0.2.0，3 个 issue 已提交。
QwQ-32B 为 Qwen2.5 架构 reasoning 模型，MLA 注意力，需 `--attention-backend TRITON_MLA`。
TP 计算：32B bf16 ~64 GB，单卡 32 GB → **TP=4**（4 卡共 128 GB，留 30% 后可用 89 GB）。

## 环境（实际运行时填写）

| 项目 | 值 |
|------|---|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-qwq-32b` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/QwQ-32B` |
| 卡号 | `CUDA_VISIBLE_DEVICES=0,1,2,3`（TP=4）|
| 实际 vLLM 版本 | |

## Step 0：登录 + 查卡 + 拉取镜像

```bash
ssh iluvatar-139
ixsmi   # 确认至少 4 张卡空闲
docker pull harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope
docker pull harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
```

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
model_name=qwq-32b
docker run -itd --name flagrelease-fix-${model_name} \
  --device=/dev/iluvatar \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  ${IMAGE} bash
docker exec -it flagrelease-fix-${model_name} bash
ixsmi && python -c "import vllm; print(vllm.__version__)"
```

## Step 2：确认模型

权重来源：`Qwen/QwQ-32B`（ModelScope）

```bash
ls /models/flagrelease/fixes_models/QwQ-32B/
```

若需下载（eval-scope 容器里）：
```bash
docker exec -it eval-scope bash
modelscope download --model Qwen/QwQ-32B \
  --local_dir /models/flagrelease/fixes_models/QwQ-32B
```

## Step 3：起 vLLM 服务

原报告 vLLM 0.20.2 完全无法起服务；vLLM 0.24.0 对 Qwen2.5 架构支持更完整。
QwQ-32B 是 MLA 模型，必须加 `--attention-backend TRITON_MLA`。
先以默认黑名单 eager 起服务；若 crash，抓栈补充黑名单。

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=0,1,2,3
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
model_name=QwQ-32B
mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} --dtype bfloat16 \
  --tensor-parallel-size 4 --gpu-memory-utilization 0.9 \
  --port 8000 --attention-backend TRITON_MLA \
  --enforce-eager --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log
```

若 OOM → 降 `--max-model-len 16384` 或升至 TP=8。

| 迭代 | 黑名单补充 | TP | 结果 | 备注 |
|------|----------|-----|------|------|
| 第1次 | 无 | 4 | | |
| 第2次 | | | | |

## Step 4：评测

QwQ-32B 为 thinking 模型，50 题 GPQA 可能数小时，勿中断。

```bash
docker exec -it eval-scope bash
cd /workspace/release_评测标准
model_name=QwQ-32B
python3 fast_gpqa.py --model-name ${model_name} --api-base http://127.0.0.1:8000/v1 \
  --output /models/release_run_logs/${model_name}/gpqa.json
python3 accuracy_compare.py --v2 /models/release_run_logs/${model_name}/gpqa.json \
  --nv-baseline ${model_name} --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict.json
```

| 迭代 | 黑名单 | GPQA | 退出码 | 备注 |
|------|--------|------|--------|------|
| 第1次 | | | | |

## 现象
（贴启动失败关键行；原报告全空，37分钟即结束）

## 定位
（vLLM 0.24.0 是否能起服务；crash 时缺实现的算子名）

## 处置
（补充黑名单 / 调整 TP / 降 max-model-len）

## 结果
- 修复后 GPQA 正确率：
- NV 基线：
- 达标判定（accuracy_compare 退出码）：

## 提炼到 KNOWLEDGE 的条目
（一句话规律，若无则写"无新规律"）
