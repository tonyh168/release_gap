# iluvatar/LFM2.5-1.2B-Thinking 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_LFM2.5-1.2B-Thinking_202607281813.md
- **原始失败类型**：精度不达标（V2 GPQA=2.4%）+ plugin报错（plugin-FL dispatch 错误，3 个 issue）
- **日期**：2026-09-15

## 现象

原始失败报告（vLLM 0.20.2 + plugin-FL 0.2.0 + FlagGems 5.0.x）：V2 GPQA=2.4%，精度严重偏低；
同时有 plugin-FL dispatch 报错（3 个 issue）；V1/V2 性能比约 87.5%，性能也略有下降。

本次在新镜像（vLLM 0.24.0 + FlagGems 5.3.4.post1）上复现：

- 服务正常启动，无 Operator crash，无 dispatch 报错
- evalscope 完整跑完 50 题，算出分数 32.0%
- `fast_gpqa.py` 在收尾 `detect_runaway` 处崩溃（thinking 模型 `message.content` 是 list 结构，
  `AttributeError: 'list' object has no attribute 'strip'`，line 370），result JSON 未写出
- 从 evalscope 报告重建 result JSON 后，accuracy_compare 正常运行

## 定位

- FlagGems 5.0.x 在 LFM（SSM/hybrid）架构上存在系统性精度问题（GPQA=2.4%），5.3.4.post1 已修复，
  无需扩展原报告的 32 算子白名单（含 vstack）
- plugin-FL dispatch 报错在 vLLM 0.24.0 + vllm_fl0.24.0 中已消失
- `fast_gpqa.py detect_runaway` 的 list content crash 是评测脚本独立 bug，发生在算分之后，不影响分数
- LFM2.5-1.2B-Thinking 为 SSM/hybrid 架构（非 MLA），attention-backend 用 `TRITON_ATTN`；
  1.2B 量级单卡可装，**TP=1**

## 处置

### 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-lfm2.5-1.2b-thinking` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/LFM2.5-1.2B-Thinking` |
| GPU / 端口 | GPU 0（TP=1）/ 8000 |
| attention-backend | `TRITON_ATTN`（LFM 非 MLA 架构） |
| max-model-len | `32768` |
| 实际 vLLM 版本 | 0.24.0（vllm_fl0.24.0） |
| 权重来源 | `LiquidAI/LFM2.5-1.2B-Thinking`（ModelScope） |

### 起容器（宿主机执行）

```bash
docker run -itd --name flagrelease-fix-lfm2.5-1.2b-thinking \
  --device=/dev/iluvatar \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907 bash
docker exec -it flagrelease-fix-lfm2.5-1.2b-thinking bash
ixsmi && python -c "import vllm; print(vllm.__version__)"
```

### 起 vLLM 服务（容器内执行，最终达标配置）

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
vllm serve /models/flagrelease/fixes_models/LFM2.5-1.2B-Thinking \
  --served-model-name LFM2.5-1.2B-Thinking \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --gpu-memory-utilization 0.9 \
  --max-model-len 32768 \
  --port 8000 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code
```

### 迭代记录

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST | GPQA | accuracy_compare 退出码 | 备注 |
|------|--------------------------|------|------------------------|------|
| 第1次 | sort,sort_stable（默认） | 32.0% | 0（PASS） | 新镜像 FlagGems 5.3.4.post1 精度恢复，默认黑名单直接过 |

未做失败尝试：黑名单无需调整，默认 `sort,sort_stable` 一次通过。

### 评测（eval-scope 容器内执行）

评测用 `fast_gpqa.py` 跑 gpqa_diamond（50 题）。本模型 `message.content` 为 list 结构，触发了
`detect_runaway` 的 list crash，evalscope 已算出分数但 result JSON 未写出，因此从报告重建后再跑 compare：

```bash
EVAL_DIR=/models/flagrelease/eval_methods
LOG=/models/release_run_logs/LFM2.5-1.2B-Thinking

find /root -path "*/reports/LFM2.5-1.2B-Thinking/gpqa_diamond.json" | tail -1

python3 -c "
import json, sys
d = json.loads(open(sys.argv[1]).read())
score = d['metrics'][0]['score'] * 100
total = d['metrics'][0]['num']
out = {'model': 'LFM2.5-1.2B-Thinking', 'benchmark': 'gpqa_diamond', 'mode': 'thinking',
       'score': score, 'total_questions': total}
json.dump(out, open('${LOG}/gpqa_diamond_result.json', 'w'), ensure_ascii=False, indent=2)
print('score:', score, 'total:', total)
" <report_path>

python3 ${EVAL_DIR}/accuracy_compare.py \
  --v2 ${LOG}/gpqa_diamond_result.json \
  --nv-baseline LFM2.5-1.2B-Thinking \
  --nv-baseline-file ${EVAL_DIR}/nv_baseline.yaml \
  --metric gpqa_diamond --json \
  --output ${LOG}/verdict_gpqa_diamond.json
```

其他处置：

- 黑名单无需调整，默认 `sort,sort_stable` 直接达标
- `fast_gpqa.py` 的 list→str 归一补丁已更新本地和 NFS 版本（`detect_runaway` 开头加 `isinstance(text, list)`）
- 分数从 evalscope 原始报告重建，无需重跑评测

## 结果

- 修复后分 / NV 基线：**GPQA 32.0%**（50 题，16 题正确）/ NV 29.0%
- 达标判定（accuracy_compare 退出码）：**0（PASS）** —— 相对变化 **+10.34%（反超基线）**
- verdict 时间戳：2026-09-15T07:14:06

**verdict_gpqa_diamond.json**（最终达标那一份）：

```json
{
  "baseline_mode": "nv_reference",
  "model": "LFM2.5-1.2B-Thinking",
  "metric": "gpqa_diamond",
  "nv": { "score": 29.0, "source": "NV 实测" },
  "current": {
    "path": "/models/release_run_logs/LFM2.5-1.2B-Thinking/gpqa_diamond_result.json",
    "model": "LFM2.5-1.2B-Thinking",
    "score": 32.0,
    "mode": "thinking"
  },
  "tolerance": 0.05,
  "timestamp": "2026-09-15T07:14:06.626722",
  "rel_drop": -0.1034,
  "rel_drop_pct": -10.34,
  "abs_diff": 3.0,
  "aligned": true,
  "noise_zone": false,
  "message": "精度达标: 当前=32.00%, NV=29.00%, 相对退化=-10.34% (容差 5.0%)"
}
```

## 提炼到 KNOWLEDGE 的条目

FlagGems 5.3.4.post1 修复了 LFM 系列（SSM/hybrid 架构）在 5.0.x 下的系统性精度崩溃；默认黑名单
`sort,sort_stable` 即可通过，无需扩展 vstack 等原报告白名单。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: LiquidAI/LFM2.5-1.2B-Thinking
# IMAGE: harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
# HARBOR_VER: V3
# GPU: Iluvatar BI-V150, 1 × 32GB
# TP: 1
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 29.0
# SCORE_FLAGOS: 32.0
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
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
vllm serve /models/flagrelease/fixes_models/LFM2.5-1.2B-Thinking \
  --served-model-name LFM2.5-1.2B-Thinking \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --gpu-memory-utilization 0.9 \
  --max-model-len 32768 \
  --port 8000 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code
```
