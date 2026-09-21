# iluvatar/Qwen3-30B-A3B-Thinking-2507 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_Qwen3-30B-A3B-Thinking-2507_202608261448.md
- **原始失败类型**：服务启动失败（Operator crash: `libentry`, `mm on unknown platform`）
- **日期**：2026-09-16

## 现象

原始失败报告（vLLM 0.20.2 + FlagGems 5.0.0）：全部精度/性能数据为空（V2/V3）。
V1 有 TTFT=12265ms，说明裸 vLLM 可以起服务；V2/V3 评测全空，说明 plugin-FL 启动时 `mm` 算子 crash。
Issue 标题：`【FR】Bug: Operator crash: libentry, mm on unknown platform`。

本次在新镜像（vLLM 0.24.0 + FlagGems 5.3.4.post1，黑名单加 `mm`）上复现：

- 服务正常启动，无 crash
- 评测跑完（thinking 模型，50 题耗时约 **159 min**），精度超基线，达标
- `fast_gpqa.py` 写出 `score=null`（thinking 模型 evalscope 报告格式 bug），分数从 evalscope 原始报告恢复

## 定位

- plugin-FL 启动时 **`mm`（矩阵乘法）算子在天数硬件上 crash**（`libentry` 路径）
- V2 白名单里含 MoE expert routing 相关 triton 代码片段（`cumsum_ptr`、`expert_ids_ptr`、
  `distributed_barrier`），这些是**正常 MoE kernel，与 crash 无关**；crash 在 `mm`
- 模型为 Qwen3 MoE（30B 总参数 / 3B 激活），标准 GQA attention，使用 `TRITON_ATTN`
- 30B bf16 约 60 GB，**TP=4**（4×32 GB=128 GB），MoE routing overhead 不影响权重大小

## 处置

### 环境

| 项目 | 值 |
|------|----|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-qwen3-30b-a3b-thinking` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/Qwen3-30B-A3B-Thinking-2507` |
| 卡号 / 端口 | GPU 4,5,6,7（TP=4）/ 8010 |
| attention-backend | `TRITON_ATTN` |
| 实际 vLLM 版本 | 0.24.0（vllm_fl0.24.0） |
| 权重来源 | `Qwen/Qwen3-30B-A3B-Thinking-2507`（ModelScope） |

### 起容器（宿主机执行）

```bash
docker run -itd --name flagrelease-fix-qwen3-30b-a3b-thinking \
  --device=/dev/iluvatar \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907 bash
docker exec -it flagrelease-fix-qwen3-30b-a3b-thinking bash
ixsmi && python -c "import vllm; print(vllm.__version__)"
```

### 起 vLLM 服务（容器内执行，最终达标配置）

初始黑名单即最终黑名单：`sort,sort_stable,mm`（原始 crash 为 `mm on unknown platform`）。

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,mm
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
vllm serve /models/flagrelease/fixes_models/Qwen3-30B-A3B-Thinking-2507 \
  --served-model-name Qwen3-30B-A3B-Thinking-2507 --dtype bfloat16 \
  --tensor-parallel-size 4 --gpu-memory-utilization 0.9 \
  --port 8010 --attention-backend TRITON_ATTN \
  --enforce-eager --trust-remote-code
```

要点：

- **黑名单追加 `mm`**，将矩阵乘法退回 PyTorch 原生实现，第 1 次迭代直接通过
- 若有 `chat_template.jinja`，追加 `--chat-template /models/flagrelease/fixes_models/Qwen3-30B-A3B-Thinking-2507/chat_template.jinja`
- 未触发的兜底路径：若 OOM → 升 TP=8 或降 `--max-model-len 16384`；若仍 crash → 从 serve.log 抓算子名追加黑名单

### 迭代记录

| 迭代 | 黑名单 | TP | 端口 | 结果 | 备注 |
|------|--------|----|------|------|------|
| 第1次 | sort,sort_stable,mm | 4 | 8010 | ✅ GPQA 76.0%（NV 75.0%，↑1.33%） | 服务正常启动，无 crash；精度超基线，达标 |

### smoke test（容器内执行）

```bash
curl -s http://localhost:8010/v1/models
curl -s http://localhost:8010/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"Qwen3-30B-A3B-Thinking-2507","messages":[{"role":"user","content":"hello"}],"max_tokens":64,"temperature":0}'
```

### 评测（eval-scope 容器内执行）

thinking 模型，GPQA 50 题可能数小时，勿中断。

```bash
python3 /workspace/eval_scripts/fast_gpqa.py \
  --model-name Qwen3-30B-A3B-Thinking-2507 \
  --api-base http://127.0.0.1:8010/v1 \
  --output /models/release_run_logs/Qwen3-30B-A3B-Thinking-2507/gpqa.json

python3 /workspace/eval_scripts/accuracy_compare.py \
  --v2 /models/release_run_logs/Qwen3-30B-A3B-Thinking-2507/gpqa.json \
  --nv-baseline Qwen3-30B-A3B-Thinking-2507 \
  --nv-baseline-file /workspace/eval_scripts/nv_baseline.yaml --json \
  --output /models/release_run_logs/Qwen3-30B-A3B-Thinking-2507/verdict.json
```

`score=null` 的恢复来源：evalscope 原始报告
`outputs/gpqa_diamond/20260916_074652/reports/Qwen3-30B-A3B-Thinking-2507/gpqa_diamond.json`
（`metrics[0].score = 0.76` → 76.0%）。

## 结果

- 修复后分 / NV 基线：**GPQA 76.0%** / NV **75.0**
- 达标判定（accuracy_compare 退出码）：**0（达标，↑1.33%，反超基线）**
- 评测耗时：约 **159 min**（thinking 模型，50 题）
- 分数来源：`score=null` 从 evalscope 原始报告
  `outputs/gpqa_diamond/20260916_074652/reports/Qwen3-30B-A3B-Thinking-2507/gpqa_diamond.json` 恢复

**verdict 实测字段**（最终达标那一份）：

- `model`: Qwen3-30B-A3B-Thinking-2507；`metric`: gpqa_diamond
- `nv.score`: 75.0；`current.score`: 76.0
- 相对退化 **-1.33%**（反超基线）；进程退出码：**0**

> 源 fix 日志记录了上述实测字段与退出码，但未附 JSON 原文，故此处不复刻 JSON 文本（避免编造）。

## 提炼到 KNOWLEDGE 的条目

- Qwen3 MoE 模型的原始 crash 根因是 `mm`（矩阵乘法）算子在 iluvatar `libentry` 路径 crash，
  黑名单加 `mm` 即可修复
- 达标配置：黑名单 `sort,sort_stable,mm`（三算子），TP=4，`TRITON_ATTN`
- thinking 模型评测 `score=null` 是已知 evalscope 报告格式 bug，从
  `outputs/<dataset>/<ts>/reports/<model>/` 恢复即可

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: Qwen/Qwen3-30B-A3B-Thinking-2507
# IMAGE: harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
# HARBOR_VER: V3
# GPU: Iluvatar BI-V150, 4 × 32GB
# TP: 4
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 75.0
# SCORE_FLAGOS: 76.0
# CONTAINER_DEVS: --device=/dev/iluvatar --ipc=host --network=host --shm-size=64g
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --net=host --ipc=host \
  --device=/dev/iluvatar \
  --shm-size 64g \
  -v /mnt/share/models:/models \
  --name flagos \
  harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907 \
  /bin/bash
```

### 三、启动服务（容器内执行）

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,mm
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
vllm serve /models/flagrelease/fixes_models/Qwen3-30B-A3B-Thinking-2507 \
  --served-model-name Qwen3-30B-A3B-Thinking-2507 --dtype bfloat16 \
  --tensor-parallel-size 4 --gpu-memory-utilization 0.9 \
  --port 8010 --attention-backend TRITON_ATTN \
  --enforce-eager --trust-remote-code
```
