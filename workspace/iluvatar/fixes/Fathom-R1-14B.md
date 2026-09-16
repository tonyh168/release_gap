# iluvatar/Fathom-R1-14B 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_Fathom-R1-14B_202608211539.md
- **原始失败类型**：精度不达标 + 性能不达标（精度数据为空，性能 V1 mean TTFT=244727ms）
- **日期**：

## 背景分析

V1 有性能数据（mean TTFT=244727ms，极慢），但精度数据为空；V2/V3 同样用 32算子白名单
（与 TinyR1-32B-Preview 完全相同），2个 issue 提交。
精度数据为空可能是评测超时（TTFT 过长导致评测工具超时），也可能是服务虽起但推理异常。
Fathom-R1-14B 为 14B reasoning 模型，**TP=2**（14B bf16 ~28 GB，2 卡共 64 GB）。
权重来源：`FractalAIResearch/Fathom-R1-14B`。

## 环境（实际运行时填写）

| 项目 | 值 |
|------|---|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-fathom-r1-14b` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/Fathom-R1-14B` |
| 卡号 | `CUDA_VISIBLE_DEVICES=0,1`（TP=2）|
| 实际 vLLM 版本 | |

## Step 0：登录 + 查卡 + 拉取镜像

```bash
ssh iluvatar-139
ixsmi   # 确认至少 2 张卡空闲
docker pull harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope
docker pull harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
```

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
model_name=fathom-r1-14b
docker run -itd --name flagrelease-fix-${model_name} \
  --device=/dev/iluvatar \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  ${IMAGE} bash
docker exec -it flagrelease-fix-${model_name} bash
ixsmi && python -c "import vllm; print(vllm.__version__)"
```

## Step 2：确认模型

权重来源：`FractalAIResearch/Fathom-R1-14B`（ModelScope）

```bash
ls /models/flagrelease/fixes_models/Fathom-R1-14B/
```

若需下载（eval-scope 容器里）：
```bash
docker exec -it eval-scope bash
modelscope download --model FractalAIResearch/Fathom-R1-14B \
  --local_dir /models/flagrelease/fixes_models/Fathom-R1-14B
```

## Step 3：起 vLLM 服务

原报告 V1 TTFT=244727ms（极慢），可能是首次 Triton 编译耗时，也可能是模型推理本身极慢。
本次起服务后先用短 prompt 冒烟，确认推理速度正常，再跑 GPQA 评测。

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=0,1
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
model_name=Fathom-R1-14B
mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} --dtype bfloat16 \
  --tensor-parallel-size 2 --gpu-memory-utilization 0.9 \
  --port 8000 --attention-backend TRITON_MLA \
  --enforce-eager --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log
```

冒烟验证推理延迟：
```bash
model_name=Fathom-R1-14B
curl -s http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"1+1=?"}],"max_tokens":16,"temperature":0}'
# 观察响应时间；若 TTFT 仍 >100s，排查是否 Triton 编译问题（首次编译正常，第二次应很快）
```

| 迭代 | 黑名单 | TP | attention-backend | 端口 | 结果 | 备注 |
|------|--------|-----|------------------|------|------|------|
| 第1次 | sort,sort_stable | 2 | TRITON_MLA | 8002 | ❌ GPQA 54.0% (NV 60.0%，↓10.0%) | 服务正常起，精度退化 |
| 第2次 | +mm,bmm,addmm,rms_norm,fused_add_rms_norm,softmax,softmax_out,to_copy,copy_,true_divide,pow_scalar,reciprocal,silu,silu_and_mul（共16算子） | 2 | TRITON_ATTN | 8002 | 评测进行中（198题全量） | 扩大黑名单，评测全量数据 |

## Step 4：评测

Fathom-R1-14B 是 reasoning 模型，GPQA 每题输出可能较长。

```bash
docker exec -it eval-scope bash
cd /workspace/release_评测标准
model_name=Fathom-R1-14B
python3 fast_gpqa.py --model-name ${model_name} --api-base http://127.0.0.1:8000/v1 \
  --output /models/release_run_logs/${model_name}/gpqa.json
python3 accuracy_compare.py --v2 /models/release_run_logs/${model_name}/gpqa.json \
  --nv-baseline ${model_name} --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict.json
```

> 若 `truncation_detected: true` → 加大 `--max-model-len` 后重跑。

| 迭代 | 黑名单 | GPQA | 退出码 | 备注 |
|------|--------|------|--------|------|
| 第1次 | sort,sort_stable | 54.0% | — | 50题小样本；NV 60.0%，↓10.0%，超容差 |
| 第2次 | +mm,bmm,addmm,rms_norm,fused_add_rms_norm,softmax,softmax_out,to_copy,copy_,true_divide,pow_scalar,reciprocal,silu,silu_and_mul（共16算子） | 评测进行中（198题全量） | — | 2026-09-16 18:39 启动；eval pid 513 in eval-scope；3.5 tok/s 正常推理 |

## 现象
（原 V1 TTFT=244727ms，精度数据空；新镜像冒烟延迟 / GPQA 结果）

## 定位
（精度为空的原因：评测超时 vs 推理异常；性能慢是 Triton 首次编译 vs 算子问题）

## 处置
（确认推理延迟正常；若精度不达标扩大黑名单）

## 结果
- 修复后 GPQA 正确率：
- NV 基线：
- 达标判定（accuracy_compare 退出码）：

## 提炼到 KNOWLEDGE 的条目
（一句话规律，若无则写"无新规律"）
