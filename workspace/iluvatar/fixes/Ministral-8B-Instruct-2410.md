# iluvatar/Ministral-8B-Instruct-2410 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_Ministral-8B-Instruct-2410_202608090256.md
- **原始失败类型**：精度不达标（V2/V3 GPQA=28.0%，41个算子）
- **日期**：

## 背景分析

V1 无数据，V2/V3 GPQA=28.0%（与 NV 基线差距视 baseline 值而定）。V3 镜像已存于 Harbor。
亮点：V3 性能大幅优于 V2（TTFT 675ms vs 11967ms），说明 plugin-FL 对性能有正向收益。
本次复现使用新镜像（vLLM 0.24.0 + FlagGems 5.3.4.post1），优先跑精度验证是否达标。
权重来源：`mistralai/Ministral-8B-Instruct-2410`，8B Mistral 架构，**TP=1**（bf16 ~16 GB，单卡 32 GB）。

## 环境（实际运行时填写）

| 项目 | 值 |
|------|---|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-ministral-8b-instruct-2410` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/Ministral-8B-Instruct-2410` |
| 卡号 | `CUDA_VISIBLE_DEVICES=0`（TP=1）|
| 实际 vLLM 版本 | |

## Step 0：登录 + 查卡 + 拉取镜像

```bash
ssh iluvatar-139
ixsmi
docker pull harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope
docker pull harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
```

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
model_name=ministral-8b-instruct-2410
docker run -itd --name flagrelease-fix-${model_name} \
  --device=/dev/iluvatar \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  ${IMAGE} bash
docker exec -it flagrelease-fix-${model_name} bash
ixsmi && python -c "import vllm; print(vllm.__version__)"
```

## Step 2：确认模型

权重来源：`mistralai/Ministral-8B-Instruct-2410`（ModelScope）

```bash
ls /models/flagrelease/fixes_models/Ministral-8B-Instruct-2410/
```

若需下载（eval-scope 容器里）：
```bash
docker exec -it eval-scope bash
modelscope download --model mistralai/Ministral-8B-Instruct-2410 \
  --local_dir /models/flagrelease/fixes_models/Ministral-8B-Instruct-2410
```

## Step 3：起 vLLM 服务

V2/V3 GPQA=28.0%（41个算子），V3 性能已大幅改善（TTFT 675ms vs V2 11967ms）。
本次用新镜像重测精度，目标是 GPQA 达到 NV 基线容忍范围内。

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=0
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
model_name=Ministral-8B-Instruct-2410
mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} --dtype bfloat16 \
  --tensor-parallel-size 1 --gpu-memory-utilization 0.9 \
  --port 8000 --attention-backend TRITON_MLA \
  --enforce-eager --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log
```

若精度仍不达标，逐步扩大黑名单排查：
```bash
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,<疑似误差算子>
```

| 迭代 | 黑名单补充 | GPQA | 备注 |
|------|----------|------|------|
| 第1次 | 无 | | |
| 第2次 | | | |

## Step 4：评测

```bash
docker exec -it eval-scope bash
cd /workspace/release_评测标准
model_name=Ministral-8B-Instruct-2410
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

## 现象
（原 V2/V3 GPQA=28.0%，41算子；新镜像重测结果）

## 定位
（FlagGems 5.3.4.post1 是否修复精度差距；若仍不达标，哪个算子引入误差）

## 处置
（扩大黑名单 / 精度收敛验证）

## 结果
- 修复后 GPQA 正确率：
- NV 基线：
- 达标判定（accuracy_compare 退出码）：

## 提炼到 KNOWLEDGE 的条目
（一句话规律，若无则写"无新规律"）
