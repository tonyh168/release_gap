# iluvatar/MiroThinker-v1.5-30B 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_MiroThinker-v1.5-30B_202608241019.md
- **原始失败类型**：Operator crash + 精度/性能不达标（全部评测数据为空）
- **日期**：

## 背景分析

V2/V3 均无算子数据，所有评测结果为空，3个 issue 提交。
和 QwQ-32B 类似（原报告同一批失败），推测服务在最早阶段就 crash。
MiroThinker-v1.5-30B 为 30B 参数量，**TP=4**（30B bf16 ~60 GB，4 卡共 128 GB）。
权重来源：`miromind-ai/MiroThinker-v1.5-30B`。

## 环境（实际运行时填写）

| 项目 | 值 |
|------|---|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-mirothinker-v1.5-30b` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/MiroThinker-v1.5-30B` |
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
model_name=mirothinker-v1.5-30b
docker run -itd --name flagrelease-fix-${model_name} \
  --device=/dev/iluvatar \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  ${IMAGE} bash
docker exec -it flagrelease-fix-${model_name} bash
ixsmi && python -c "import vllm; print(vllm.__version__)"
```

## Step 2：确认模型

权重来源：`miromind-ai/MiroThinker-v1.5-30B`（ModelScope）

```bash
ls /models/flagrelease/fixes_models/MiroThinker-v1.5-30B/
```

若需下载（eval-scope 容器里）：
```bash
docker exec -it eval-scope bash
modelscope download --model miromind-ai/MiroThinker-v1.5-30B \
  --local_dir /models/flagrelease/fixes_models/MiroThinker-v1.5-30B
```

## Step 3：起 vLLM 服务

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=0,1,2,3
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
model_name=MiroThinker-v1.5-30B
mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} --dtype bfloat16 \
  --tensor-parallel-size 4 --gpu-memory-utilization 0.9 \
  --port 8000 --attention-backend TRITON_MLA \
  --enforce-eager --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log
```

若 OOM → 升 TP=8 或降 `--max-model-len 16384`。若 crash → 抓栈补充黑名单：
```bash
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,<崩溃算子>
```

| 迭代 | 黑名单补充 | TP | 结果 | 备注 |
|------|----------|-----|------|------|
| 第1次 | 无 | 4 | | |
| 第2次 | | | | |

## Step 4：评测

MiroThinker 为 thinking 模型，GPQA 50 题可能数小时，勿中断。

```bash
docker exec -it eval-scope bash
cd /workspace/release_评测标准
model_name=MiroThinker-v1.5-30B
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
（贴启动失败关键行；原报告全部评测数据为空）

## 定位
（crash 根因：缺实现算子名 / OOM）

## 处置
（补充黑名单 / 调整 TP / 降 max-model-len）

## 结果
- 修复后 GPQA 正确率：
- NV 基线：
- 达标判定（accuracy_compare 退出码）：

## 提炼到 KNOWLEDGE 的条目
（一句话规律，若无则写"无新规律"）
