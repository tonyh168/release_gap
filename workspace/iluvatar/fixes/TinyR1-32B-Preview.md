# iluvatar/TinyR1-32B-Preview 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_TinyR1-32B-Preview_202608271844.md
- **原始失败类型**：服务启动失败（无镜像产出，全部评测数据为空）
- **日期**：

## 背景分析

服务在所有版本下均无法启动，3 个 issue 提交（crash + accuracy + performance degradation）。
V2/V3 均有 32 算子白名单（add, addmm, cat, cos, embedding, flash_attn_varlen_func, 等），
但服务仍未成功起来，说明另有未实现算子导致 crash。
原始环境 vLLM 0.20.2 + FlagGems 5.0.0；本次用新镜像重试。
TinyR1-32B 为 32B 参数量，**TP=4**（bf16 ~64 GB，单卡 32 GB → 4 卡）。

## 环境（实际运行时填写）

| 项目 | 值 |
|------|---|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-tinyr1-32b-preview` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/TinyR1-32B-Preview` |
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
model_name=tinyr1-32b-preview
docker run -itd --name flagrelease-fix-${model_name} \
  --device=/dev/iluvatar \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  ${IMAGE} bash
docker exec -it flagrelease-fix-${model_name} bash
ixsmi && python -c "import vllm; print(vllm.__version__)"
```

## Step 2：确认模型

权重来源：`qihoo360/TinyR1-32B-Preview`（ModelScope）

```bash
ls /models/flagrelease/fixes_models/TinyR1-32B-Preview/
```

若需下载（eval-scope 容器里）：
```bash
docker exec -it eval-scope bash
modelscope download --model qihoo360/TinyR1-32B-Preview \
  --local_dir /models/flagrelease/fixes_models/TinyR1-32B-Preview
```

## Step 3：起 vLLM 服务

原报告 V2/V3 均有 32 算子白名单（与 Fathom-R1-14B 相同），但服务仍未起来，
说明另有未实现算子导致 crash。本次用 vLLM 0.24.0 + FlagGems 5.3.4.post1 重试。

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=0,1,2,3
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
model_name=TinyR1-32B-Preview
mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} --dtype bfloat16 \
  --tensor-parallel-size 4 --gpu-memory-utilization 0.9 \
  --port 8000 --attention-backend TRITON_MLA \
  --enforce-eager --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log
```

若仍 crash，抓栈后补充黑名单：
```bash
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,<崩溃算子>
```

| 迭代 | 黑名单补充 | 结果 | 备注 |
|------|----------|------|------|
| 第1次 | 无 | | |
| 第2次 | | | |

## Step 4：评测

TinyR1 为 thinking 模型，GPQA 50 题可能数小时。

```bash
docker exec -it eval-scope bash
cd /workspace/release_评测标准
model_name=TinyR1-32B-Preview
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
（贴启动失败关键行；原报告无镜像产出）

## 定位
（vLLM 0.24.0 是否解决 crash；若否，具体缺实现的算子名）

## 处置
（补充黑名单 / 调 TP / 降 max-model-len）

## 结果
- 修复后 GPQA 正确率：
- NV 基线：
- 达标判定（accuracy_compare 退出码）：

## 提炼到 KNOWLEDGE 的条目
（一句话规律，若无则写"无新规律"）
