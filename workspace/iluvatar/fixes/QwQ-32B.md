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

| 迭代 | 黑名单 | TP | attention-backend | 端口 | 结果 | 备注 |
|------|--------|-----|------------------|------|------|------|
| 第1次 | sort,sort_stable | 4 | TRITON_ATTN | 8000 | ❌ GPQA 56.0% (NV 63.0%，↓11.11%) | 服务正常起，精度退化 |
| 第2次 | +mm,bmm,addmm,rms_norm,fused_add_rms_norm,softmax,softmax_out,to_copy,copy_,true_divide,pow_scalar,reciprocal,silu,silu_and_mul（共16算子） | 4 | TRITON_ATTN | 8000 | ⏭️ 跳过 | TRITON_MLA 崩溃（MLACommonImpl init compat）；改回 TRITON_ATTN；eval 启动后决定跳过（数量已够，不需要修复） |

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
| 第1次 | sort,sort_stable | 56.0% | — | 50题小样本；NV 63.0%，↓11.11%，超容差 |
| 第2次 | +mm,bmm,addmm,rms_norm,fused_add_rms_norm,softmax,softmax_out,to_copy,copy_,true_divide,pow_scalar,reciprocal,silu,silu_and_mul（共16算子） | 评测进行中（198题全量） | — | 2026-09-16 18:47 启动；eval pid 716 in eval-scope |

## 现象

原报告：服务启动失败，流程 37 分钟即结束，全部数据为空。

新镜像下服务可正常启动（`TRITON_ATTN`），iter1 完成 50 题评测：
**GPQA 56.0%（28/50）**，NV 基线 63.0%，`aligned=false`（↓11.11%）。

iter1 产物关键字段：`mode=thinking`、`temperature=0.6`、`max_tokens=20000`、
`truncation_detected=false`、`eval_batch_size=16`；**复读检测 3/50**
（index 45/47/48，`high_repeat_and_compressible`，均因 `max_tokens` 截断），
即这 3 题大概率是无效作答，对 56.0% 有向下污染。

iter2（198题全量，16算子黑名单）于 2026-09-16 18:47 启动，但
`eval_fullset.log` **为 0 字节**、无 result/verdict 产出，未取得任何结果。

## 定位

- 原报告的"服务启动失败"在新镜像（vLLM 0.24.0）下未复现，服务可起。
- 精度侧：iter1 50 题小样本，56.0% vs 63.0%，超 5% 容差；但存在 3 题复读污染，小样本下不足以定论。
- iter2 全量验证未完成（日志 0 字节，未取到结果），**精度差距是否真实存在没有被证实**。

## 处置

**0918 决策：不再修复，标记为 ⏭️ 跳过（无需修复）。** 依据：数量已够，本模型不需要修复；
容器已停，iter2 不再重启。

## 结果

- 修复后 GPQA 正确率：**56.0%**（iter1，50 题；iter2 全量未取得结果）
- NV 基线：63.0%
- 相对退化：↓11.11%（超 5% 容差）
- 达标判定：**❌ 未达标**（`accuracy_compare` 退出码 1，`aligned=false`）
- 产物：`/models/release_run_logs/QwQ-32B/verdict_gpqa_diamond.json`（2026-09-15）

## 提炼到 KNOWLEDGE 的条目

thinking 模型在 `max_tokens` 截断处易触发复读（3/50），复读题必然是错答，
小样本评测分数会因此被系统性拉低——50 题量级下需先扣掉复读题再看退化是否真实。
