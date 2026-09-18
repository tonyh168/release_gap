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

权重来源：`360zhinao/TinyR1-32B-Preview`（ModelScope）
> 注：原失败报告中写的 `qihoo360/TinyR1-32B-Preview` 为错误路径（404），实际路径为 `360zhinao/TinyR1-32B-Preview`。

```bash
ls /models/flagrelease/fixes_models/TinyR1-32B-Preview/
```

若需下载（eval-scope 容器里）：
```bash
docker exec -it eval-scope bash
modelscope download --model 360zhinao/TinyR1-32B-Preview \
  --local_dir /models/flagrelease/fixes_models/TinyR1-32B-Preview
```

## Step 3：起 vLLM 服务

原报告 V2/V3 均有 32 算子白名单（与 Fathom-R1-14B 相同），但服务仍未起来，
说明另有未实现算子导致 crash。本次用 vLLM 0.24.0 + FlagGems 5.3.4.post1 重试。

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=3,4,7,8
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
  --port 8001 --attention-backend TRITON_ATTN \
  --enforce-eager --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log
```

> **注意**：TinyR1-32B-Preview 基于 Qwen2.5-32B（标准 GQA），使用 `TRITON_ATTN`，**不是** `TRITON_MLA`。
> 用 `TRITON_MLA` 会 crash：`MLACommonImpl.__init__() missing 7 required positional arguments`。

若仍 crash，抓栈后补充黑名单：
```bash
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,<崩溃算子>
```

| 迭代 | 黑名单补充 | 结果 | 备注 |
|------|----------|------|------|
| 第1次 | 无（sort,sort_stable 基础黑名单） | ❌ GPQA 58.0%（50题，NV 64.0%，↓9.38%） | TRITON_ATTN，TP=4，GPUs 3,4,7,8，port 8001；2026-09-17 启动，18:53 评测完成；fast_gpqa.py detect_runaway bug crash，分数从 evalscope 报告 `outputs/gpqa_diamond/20260917_075834` 恢复 |

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

- iter1（vLLM 0.24.0，sort,sort_stable 黑名单，TRITON_ATTN，TP=4，GPUs 3,4,7,8，port 8001）：
  - 服务正常启动，原报告无镜像产出的问题已由新镜像解决。
  - 评测于 2026-09-17 启动，18:53 跑完（50题，耗时 181m 47s）。
  - fast_gpqa.py 因 thinking 模型 list content 触发 detect_runaway AttributeError 崩溃，score 字段未写出。
  - 从 evalscope 报告 `outputs/gpqa_diamond/20260917_075834/reports/TinyR1-32B-Preview/gpqa_diamond.json` 恢复：`score=0.58` → **58.0%**，50题全部 succeeded。
  - 性能数据：mean TTFT=6378ms，avg_output_tps=4.98 tok/s（32B TP=4，思维链模型，平均输出 11250 tokens/题，属正常区间）。

## 定位

- vLLM 0.24.0 解决了原服务启动失败问题，服务正常起来。
- sort,sort_stable 基础黑名单下精度 58.0%，NV 基线 64.0%，相对退化 9.38%，超出 5% 容差。
- 差距约 3 题，可考虑扩大黑名单进一步排查。

## 处置

iter1 不达标（58.0% vs 64.0%，↓9.38%）。下一步选项：
1. 扩大黑名单（追加 mm、bmm、addmm 等算子）重跑
2. 视资源安排决定是否继续迭代

当前结论：**结果记录，待资源安排决定是否继续**。

## 结果

- 修复后 GPQA 正确率：**58.0%**（50题，从 evalscope 报告恢复）
- NV 基线：**64.0%**
- 相对退化：↓9.38%（超 5% 容差）
- 达标判定：**❌ 不达标**

## 提炼到 KNOWLEDGE 的条目

TinyR1-32B-Preview（Qwen2.5-32B GQA 架构，TP=4）在 vLLM 0.24.0 + sort,sort_stable 黑名单 + TRITON_ATTN 下服务可正常起来，GPQA 58.0% vs NV 64.0%（↓9.38%），仍不达标；原报告服务启动失败已由新镜像修复。
