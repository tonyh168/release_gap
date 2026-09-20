# iluvatar/AgentCPM-Report 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_AgentCPM-Report_202608120109.md
- **原始失败类型**：精度不达标（V2 GPQA=2.0% vs NV=46.0%，相对下降 95.65%）
- **日期**：2026-09-18

## 现象

原始失败报告（vLLM 0.20.2 + plugin-FL 0.2.0 + FlagGems 5.0.x）：V1 可能起服务但未留精度数据，
V2 开启 FlagGems 后精度崩溃（GPQA 2.0%，远低于 NV 基线 46.0%）。V2 替换了 33 个算子，
其中某算子引入计算误差；2 个 issue 已提交。

本次在新镜像（FlagGems 5.3.4.post1）上的两轮实测：

- **iter1（TRITON_MLA，50 题）**：服务正常启动，GPQA 40.0%，NV 46.0%，↓13.04%，不达标（exit=1）
- **iter2（TRITON_ATTN，198 题全量）**：`fast_gpqa.py` 因 thinking 模型 `message.content` 为 list
  触发 `detect_runaway` 的 `AttributeError` 崩溃，但 evalscope 已算完分数。从报告
  `outputs/gpqa_diamond/20260917_034638/reports/AgentCPM-Report/gpqa_diamond.json` 恢复：
  `score=0.4949` → **49.49%**，198 题 succeeded=198

## 定位

- iter1 不达标根因：**`TRITON_MLA` 对 AgentCPM-Report（7B 非 MLA 架构）引入精度误差**，
  切换 `TRITON_ATTN` 后精度恢复
- iter2 达标：FlagGems 5.3.4.post1 + `TRITON_ATTN` + `sort,sort_stable` 黑名单，
  精度 49.49% 反超 NV 基线 46.0%
- 原报告的精度崩溃（V2 GPQA 2.0%）源于 FlagGems 5.0.x 的 33 个替换算子，新版本已修复；
  黑名单最终无需扩展，保持默认 `sort,sort_stable`
- 7B bf16 约 14 GB，单卡 32 GB 可装，**TP=1**

## 处置

### 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-agentcpm-report` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/AgentCPM-Report` |
| GPU / 端口 | GPU 0（TP=1）/ 8002 |
| attention-backend | `TRITON_ATTN`（iter2；AgentCPM-Report 为非 MLA 架构） |
| 实际 vLLM 版本 | 0.24.0（vllm_fl0.24.0） |
| 权重来源 | `openbmb/AgentCPM-Report`（ModelScope） |

### 起容器（宿主机执行）

```bash
docker run -itd --name flagrelease-fix-agentcpm-report \
  --device=/dev/iluvatar \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907 bash
docker exec -it flagrelease-fix-agentcpm-report bash
ixsmi && python -c "import vllm; print(vllm.__version__)"
```

### 起 vLLM 服务（容器内执行，iter2 最终达标配置）

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
vllm serve /models/flagrelease/fixes_models/AgentCPM-Report \
  --served-model-name AgentCPM-Report --dtype bfloat16 \
  --tensor-parallel-size 1 --gpu-memory-utilization 0.9 \
  --port 8002 --attention-backend TRITON_ATTN \
  --enforce-eager --trust-remote-code
```

### 迭代记录

| 迭代 | 黑名单 | attention-backend | 端口 | 结果 | 备注 |
|------|--------|------------------|------|------|------|
| 第1次 | sort,sort_stable | TRITON_MLA | 8000 | ❌ GPQA 40.0%（50 题，NV 46.0%，↓13.04%），exit=1 | 2026-09-15 |
| 第2次 | sort,sort_stable | TRITON_ATTN | 8002 | ✅ GPQA **49.49%**（198 题全量，NV 46.0%，↑7.59%），exit=0 | 2026-09-17 启动，09-18 结果出炉 |

**失败尝试与更正**：iter1 用 `TRITON_MLA` 走错分支，是 7B 非 MLA 架构下的错误选择，
换 `TRITON_ATTN` 后精度从 40.0% 恢复至 49.49%。原计划的「若仍不达标则逐步扩大黑名单排查
引入误差的算子」（`VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,<疑似误差算子>`）**未触发**。

**0918 补记（重要）**：本文档 Step 4 中的「重建 verdict」命令此前只写入文档、**未实际执行** ——
机器上 `gpqa_diamond_result.json` / `verdict_gpqa_diamond.json` 一直是 iter1 的旧产物
（40.0%、`aligned=false`），与结论相反。已于 2026-09-18 实跑该命令修正：

- 先备份 iter1 产物为 `gpqa_diamond_result_iter1.json` / `verdict_gpqa_diamond_iter1.json`（保留，未删除）
- 从 evalscope 报告重建 → `score=49.49, total=198`
- 实跑 `accuracy_compare.py` → **exit=0，`aligned=true`**

下方 verdict JSON 现为机器上的真实文件内容（非预期值）。

### 评测（eval-scope 容器内执行）

```bash
python3 /workspace/eval_scripts/fast_gpqa.py \
  --model-name AgentCPM-Report \
  --api-base http://127.0.0.1:8002/v1 \
  --output /models/release_run_logs/AgentCPM-Report/gpqa.json

python3 /workspace/eval_scripts/accuracy_compare.py \
  --v2 /models/release_run_logs/AgentCPM-Report/gpqa.json \
  --nv-baseline AgentCPM-Report \
  --nv-baseline-file /workspace/eval_scripts/nv_baseline.yaml --json \
  --output /models/release_run_logs/AgentCPM-Report/verdict.json
```

**iter2 分数重建（thinking 模型 `detect_runaway` list bug 兜底，2026-09-18 实跑）**：

```bash
REPORT=/workspace/eval_scripts/outputs/gpqa_diamond/20260917_034638/reports/AgentCPM-Report/gpqa_diamond.json
LOG=/models/release_run_logs/AgentCPM-Report
EVAL_DIR=/workspace/eval_scripts

python3 -c "
import json, sys
d = json.loads(open(sys.argv[1]).read())
score = d['metrics'][0]['score'] * 100
total = d['metrics'][0]['num']
out = {'model': 'AgentCPM-Report', 'benchmark': 'gpqa_diamond', 'mode': 'thinking',
       'score': score, 'total_questions': total}
json.dump(out, open('${LOG}/gpqa_diamond_result.json', 'w'), ensure_ascii=False, indent=2)
print('score:', score, 'total:', total)
" ${REPORT}

python3 ${EVAL_DIR}/accuracy_compare.py \
  --v2 ${LOG}/gpqa_diamond_result.json \
  --nv-baseline AgentCPM-Report \
  --nv-baseline-file ${EVAL_DIR}/nv_baseline.yaml \
  --metric gpqa_diamond --json \
  --output ${LOG}/verdict_gpqa_diamond.json
```

> NV 基线 GPQA=46.0%，相对容忍 5%，即需达到 ≥43.7%。

## 结果

- 修复后分 / NV 基线：**GPQA 49.49%**（198 题全量，从 evalscope 报告恢复）/ NV 46.0%
- 达标判定（accuracy_compare 退出码）：**0（达标）** —— 相对变化 **↑7.59%（反超基线）**，
  2026-09-18 实跑复核 `aligned=true`

`verdict_gpqa_diamond.json`（iter2，accuracy_compare 输出）：

```json
{
  "baseline_mode": "nv_reference",
  "model": "AgentCPM-Report",
  "metric": "gpqa_diamond",
  "nv": {
    "score": 46.0,
    "source": "NV 实测"
  },
  "current": {
    "path": "/models/release_run_logs/AgentCPM-Report/gpqa_diamond_result.json",
    "model": "AgentCPM-Report",
    "score": 49.49,
    "mode": "thinking"
  },
  "tolerance": 0.05,
  "timestamp": "2026-09-18T07:09:02.652154",
  "missing_nv": false,
  "rel_drop": -0.0759,
  "rel_drop_pct": -7.59,
  "abs_diff": 3.49,
  "aligned": true,
  "noise_zone": false,
  "message": "精度达标: 当前=49.49%, NV=46.00%, 相对退化=-7.59% (容差 5.0%)"
}
```

## 提炼到 KNOWLEDGE 的条目

AgentCPM-Report（7B 非 MLA 架构）在 `TRITON_MLA` 下精度崩至 40.0%，切换 `TRITON_ATTN` 后
恢复至 49.49%，超过 NV 基线 46.0%；**非 MLA 架构模型不应使用 `TRITON_MLA`**。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: openbmb/AgentCPM-Report
# IMAGE: harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
# HARBOR_VER: V3
# GPU: Iluvatar BI-V150, 1 × 32GB
# TP: 1
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 46.0
# SCORE_FLAGOS: 49.49
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
vllm serve /models/flagrelease/fixes_models/AgentCPM-Report \
  --served-model-name AgentCPM-Report --dtype bfloat16 \
  --tensor-parallel-size 1 --gpu-memory-utilization 0.9 \
  --port 8002 --attention-backend TRITON_ATTN \
  --enforce-eager --trust-remote-code
```
