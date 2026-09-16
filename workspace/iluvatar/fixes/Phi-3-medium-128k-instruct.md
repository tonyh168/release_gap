# iluvatar/Phi-3-medium-128k-instruct 修复日志

- **失败报告**：release_迁移失败报告/iluvatar/FAILED_Iluvatar_Phi-3-medium-128k-instruct_202608211621.md
- **原始失败类型**：服务启动失败（全部评测数据为空，3 issues：Operator crash + accuracy degradation + perf degradation）
- **日期**：2026-09-16

## 背景分析

V1–V4 所有评测数据全空，说明服务在最早阶段就 crash，连 TTFT 都没跑出来。
原始流程用 vLLM 0.20.2 + FlagGems 5.0.0（无 plugin-FL），本轮直接用 plugin-FL vllm_fl0.24.0 修复。
Phi-3-medium-128k-instruct 为 14B 标准 decoder（Phi-3 MHA），使用 `TRITON_ATTN`。
14B bf16 ≈ 28 GB，单卡 32 GB 可容纳（TP=1），留 ~12.5% 余量；若 OOM 则升 TP=2。
权重来源：`microsoft/Phi-3-medium-128k-instruct`（ModelScope）。

## 环境

| 项目 | 值 |
|------|----|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-phi3-medium` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/Phi-3-medium-128k-instruct` |
| 卡号 | GPU 0（CUDA_VISIBLE_DEVICES=0，TP=1） |
| 端口 | 8009 |

## Step 0：登录 + 查卡

```bash
ssh iluvatar-139
ixsmi
docker ps --format '{{.Names}}\t{{.Status}}'
```

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
model_name=phi3-medium
docker run -itd --name flagrelease-fix-${model_name} \
  --device=/dev/iluvatar0  --device=/dev/iluvatar1  --device=/dev/iluvatar2  --device=/dev/iluvatar3 \
  --device=/dev/iluvatar4  --device=/dev/iluvatar5  --device=/dev/iluvatar6  --device=/dev/iluvatar7 \
  --device=/dev/iluvatar8  --device=/dev/iluvatar9  --device=/dev/iluvatar10 --device=/dev/iluvatar11 \
  --device=/dev/iluvatar12 --device=/dev/iluvatar13 --device=/dev/iluvatar14 --device=/dev/iluvatar15 \
  --device=/dev/itrctl --device=/dev/itrlink --device=/dev/itr_peerm_dev0 \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  ${IMAGE} bash
docker exec -it flagrelease-fix-${model_name} bash
ixsmi && python -c "import vllm; print(vllm.__version__)"
```

## Step 2：确认模型权重

权重来源：`microsoft/Phi-3-medium-128k-instruct`（ModelScope）

```bash
ls /models/flagrelease/fixes_models/Phi-3-medium-128k-instruct/
```

若需下载（eval-scope 容器内）：
```bash
docker exec -it eval-scope bash
modelscope download --model microsoft/Phi-3-medium-128k-instruct \
  --local_dir /models/flagrelease/fixes_models/Phi-3-medium-128k-instruct
```

检查是否有 chat_template.jinja：
```bash
ls /models/flagrelease/fixes_models/Phi-3-medium-128k-instruct/*.jinja 2>/dev/null
```

## Step 3：起 vLLM 服务

初始黑名单：`sort,sort_stable`（标准必设），若 crash 再从 serve.log 追加。

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=<1张空闲卡>
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
model_name=Phi-3-medium-128k-instruct
mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} --dtype bfloat16 \
  --tensor-parallel-size 1 --gpu-memory-utilization 0.9 \
  --port <PORT> --attention-backend TRITON_ATTN \
  --enforce-eager --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log
```

若有 chat_template.jinja，追加 `--chat-template /models/flagrelease/fixes_models/${model_name}/chat_template.jinja`。
若 OOM → 升 TP=2（`CUDA_VISIBLE_DEVICES=<卡A>,<卡B>` + `--tensor-parallel-size 2`）。
若 crash → 抓栈追加黑名单：
```bash
grep -E "Error|crash|Traceback|RuntimeError" /models/release_run_logs/${model_name}/serve.log | tail -30
```

| 迭代 | 黑名单 | TP | 端口 | 结果 | 备注 |
|------|--------|----|------|------|------|
| 第1次 | sort,sort_stable | 1 | 8009 | ❌ GPQA 24.0% (NV 37.0%，↓35.14%) | 服务正常启动，无 crash；精度严重退化，需算子排查 |
| 第2次 | sort,sort_stable,to_copy,copy_,rms_norm,fused_add_rms_norm,softmax,softmax_out,true_divide,pow_scalar,reciprocal | 1 | 8009 | ❌ GPQA 24.0% (NV 37.0%，↓35.14%) | 11算子黑名单无效，分数与 iter1 完全相同，需更深层排查 |
| 第3次 | iter2全部 + layer_norm,native_layer_norm,gelu,gelu_new,gelu_fast,gelu_tanh | 1 | 8009 | ❌ GPQA 24.0% (NV 37.0%，↓35.14%) | LayerNorm + GEGLU 路径全覆盖无效，算子黑名单路径彻底排查完毕 |

## Step 4：smoke test

```bash
model_name=Phi-3-medium-128k-instruct
curl -s http://localhost:<PORT>/v1/models
curl -s http://localhost:<PORT>/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"中国的首都是哪里？"}],"max_tokens":64,"temperature":0}'
```

## Step 5：评测

```bash
docker exec -it eval-scope bash
cd /workspace/release_评测标准
model_name=Phi-3-medium-128k-instruct
python3 fast_gpqa.py --model-name ${model_name} \
  --api-base http://127.0.0.1:<PORT>/v1 \
  --output /models/release_run_logs/${model_name}/gpqa.json
python3 accuracy_compare.py \
  --v2 /models/release_run_logs/${model_name}/gpqa.json \
  --nv-baseline ${model_name} --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict.json
```

若退出码 3（nv_baseline 无 gpqa_diamond）→ 改跑 `--dataset math_500`，compare 加 `--metric math_500`。

| 迭代 | 黑名单 | GPQA/数据集 | 得分 | 退出码 | 备注 |
|------|--------|------------|------|--------|------|
| 第1次 | sort,sort_stable | gpqa_diamond | 24.0% | 1（不达标） | 服务正常起，无 crash；精度严重退化 ↓35.14%，需算子排查 |
| 第2次 | sort,sort_stable,to_copy,copy_,rms_norm,fused_add_rms_norm,softmax,softmax_out,true_divide,pow_scalar,reciprocal | gpqa_diamond | 24.0% | 1（不达标） | 11算子黑名单完全无效；得分与 iter1 完全相同；退化根因不在这些算子 |
| 第3次 | iter2全部 + layer_norm,native_layer_norm,gelu,gelu_new,gelu_fast,gelu_tanh（共17算子） | gpqa_diamond | 24.0% | 1（不达标） | LayerNorm + GEGLU 全覆盖仍无效；算子黑名单路径彻底排查完毕 |

## 现象

原报告全部精度/性能数据为空（V1–V4）。3 issues：Operator crash + accuracy degradation + perf degradation。
plugin-FL vllm_fl0.24.0 服务正常启动（Application startup complete），无算子 crash。
eval 用时 ~24min，50 题全跑完。fast_gpqa.py score 字段为 null（evalscope 标准模型报告格式解析 bug），
实际分数从 evalscope 原始报告恢复：`/workspace/eval_scripts/outputs/gpqa_diamond/20260916_074048/reports/Phi-3-medium-128k-instruct/gpqa_diamond.json`，score=0.24 → **24.0%**。

## 定位

服务启动无 crash，说明原始 crash 问题已被 vllm_fl0.24.0 修复。

精度 24.0%（12/50 正确）≈ 随机水平（4选1期望25%），且 iter1/iter2 分数完全相同。这不是数值漂移型退化，而是模型输出接近随机——说明某个核心路径的算子在 iluvatar 上产生了错误结果，但没有 crash。

iter2 已排查：sort,sort_stable,to_copy,copy_,rms_norm,fused_add_rms_norm,softmax,softmax_out,true_divide,pow_scalar,reciprocal — 共 11 个算子无效。

**注意**：Phi-3 使用标准 LayerNorm（不是 RMS Norm），所以 iter2 中加入的 `rms_norm`/`fused_add_rms_norm` 根本不会被调用。真正可疑的归一化算子是 `layer_norm`/`native_layer_norm`。激活函数为 GEGLU（`gelu` 系列），也未被排查。

**iter3 方向**：黑名单追加 `layer_norm,native_layer_norm,gelu,gelu_new,gelu_fast,gelu_tanh`，覆盖 Phi-3 实际用到的归一化和激活路径。

## 处置

iter1：黑名单 sort,sort_stable → 24.0%，无 crash。

iter2：扩展至 11 算子（追加 to_copy,copy_,rms_norm,fused_add_rms_norm,softmax,softmax_out,true_divide,pow_scalar,reciprocal）→ 24.0%，与 iter1 完全相同。

iter3：在 iter2 基础上追加 layer_norm,native_layer_norm,gelu,gelu_new,gelu_fast,gelu_tanh（17 算子总计，覆盖 Phi-3 实际使用的 LayerNorm + GEGLU）→ 24.0%，三次完全相同。**算子黑名单路径彻底排查完毕。**

退化根因不在任何可通过黑名单隔离的 GPU 算子。下一步方向（优先级排序）：
1. **chat_template**：检查 fast_gpqa 构造的 prompt 是否符合 Phi-3 tokenizer 格式（`<|user|>`/`<|assistant|>` 标签），格式错误会系统性拉低分数
2. **sampling 参数**：确认 temperature=0 / max_tokens=2048 与 NV 评测一致
3. **dtype**：切换至 `--dtype float32` 排除 bf16 精度损失
4. 若以上均无效：考虑排查 attention mask 实现或扩样本确认是否为测量噪声

## 结果

- 修复后分 / NV 基线：24.0% / 37.0%
- 达标判定（accuracy_compare 退出码）：1（不达标，相对退化 35.14% > 容差 5%）

## 提炼到 KNOWLEDGE 的条目

- Phi-3-medium-128k-instruct 原始 crash 问题在 vllm_fl0.24.0 已修复，服务可正常起。
- 精度退化类（非 crash）需算子黑名单逐步排查，不同于启动 crash 的快速定位路径。
- fast_gpqa.py 标准模式下 score 字段可能为 null（evalscope 报告格式问题），须从 `outputs/` 原始报告恢复。
