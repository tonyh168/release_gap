# iluvatar/AgentCPM-Report 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_AgentCPM-Report_202608120109.md
- **原始失败类型**：精度不达标（V2 GPQA=2.0% vs NV=46.0%，相对下降 95.65%）
- **日期**：

---

## 背景分析

V1 可能起服务但未留精度数据，V2 开启 FlagGems 后精度崩溃（GPQA 2.0%，远低于 NV 基线 46.0%）。
V2 替换了 33 个算子，其中某算子引入计算误差。2 个 issue 已提交。
原始环境 vLLM 0.20.2 + plugin-FL 0.2.0 + FlagGems 5.0.x；本次用新镜像（FlagGems 5.3.4.post1）。

AgentCPM-Report 为 7B 量级。TP 计算：7B bf16 ~14 GB，单卡 32 GB → **TP=1**。

---

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-agentcpm-report` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/AgentCPM-Report` |
| GPU | `CUDA_VISIBLE_DEVICES=0`（TP=1，端口 8002） |
| attention-backend | `TRITON_ATTN`（iter2；AgentCPM-Report 为非 MLA 架构） |
| 实际 vLLM 版本 | 0.24.0（vllm_fl0.24.0） |

---

## Step 0：登录 + 查卡 + 拉取镜像

```bash
ssh iluvatar-139
ixsmi   # 确认至少 1 张卡空闲

# 首次登录时拉取两个镜像
docker pull harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope
docker pull harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
```

---

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
model_name=agentcpm-report
docker run -itd --name flagrelease-fix-${model_name} \
  --device=/dev/iluvatar \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  ${IMAGE} bash
docker exec -it flagrelease-fix-${model_name} bash
ixsmi && python -c "import vllm; print(vllm.__version__)"
```

---

## Step 2：确认模型

权重来源：`openbmb/AgentCPM-Report`（ModelScope）

```bash
ls /models/flagrelease/fixes_models/AgentCPM-Report/
```

若需下载（eval-scope 容器里）：
```bash
docker exec -it eval-scope bash
modelscope download --model openbmb/AgentCPM-Report \
  --local_dir /models/flagrelease/fixes_models/AgentCPM-Report
```

---

## Step 3：起 vLLM 服务

精度崩溃（V2 GPQA 2.0% vs NV 46.0%）源于 FlagGems 5.0.x 33个替换算子中存在计算误差。
FlagGems 5.3.4.post1 已修复多个精度问题；先以默认黑名单起服务验证精度，若仍不达标扩大黑名单排查。

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=0
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
model_name=AgentCPM-Report
mkdir -p /models/release_run_logs/${model_name}
# iter2（最终达标配置）：TRITON_ATTN，port 8002
# iter1 曾用 TRITON_MLA → GPQA 40.0%（50题）❌；AgentCPM-Report 为非 MLA 架构，TRITON_MLA 引入精度误差
vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} --dtype bfloat16 \
  --tensor-parallel-size 1 --gpu-memory-utilization 0.9 \
  --port 8002 --attention-backend TRITON_ATTN \
  --enforce-eager --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log

若精度仍不达标，逐步扩大黑名单排查引入误差的算子：
```bash
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,<疑似误差算子>
```

| 迭代 | 黑名单补充 | 结果 | 备注 |
|------|----------|------|------|
| 第1次 | 无（sort,sort_stable） | ❌ GPQA 40.0%（50题，NV 46.0%，↓13.04%） | TRITON_MLA，TP=1，port 8000，2026-09-15 |
| 第2次 | 无（sort,sort_stable） | ✅ GPQA 49.49%（198题全量，NV 46.0%，↑7.59%） | TRITON_ATTN，TP=1，port 8002，2026-09-17 启动，09-18 结果出炉 |

---

## Step 4：评测

```bash
docker exec -it eval-scope bash
cd /workspace/release_评测标准
model_name=AgentCPM-Report
python3 fast_gpqa.py --model-name ${model_name} --api-base http://127.0.0.1:8002/v1 \
  --output /models/release_run_logs/${model_name}/gpqa.json
python3 accuracy_compare.py --v2 /models/release_run_logs/${model_name}/gpqa.json \
  --nv-baseline ${model_name} --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict.json
```

> NV 基线 GPQA=46.0%，相对容忍 5%，即需达到 ≥43.7%。

> **iter2 evalscope 分数重建**：fast_gpqa.py 因 thinking 模型 detect_runaway bug 崩溃，在 eval-scope 容器内用以下命令从 evalscope 报告重建 result JSON 并运行 compare：

```bash
# eval-scope 容器内执行
REPORT=/workspace/eval_scripts/outputs/gpqa_diamond/20260917_034638/reports/AgentCPM-Report/gpqa_diamond.json
model_name=AgentCPM-Report
LOG=/models/release_run_logs/${model_name}
EVAL_DIR=/workspace/eval_scripts

# 1. 从 evalscope 报告读取分数，手写最小 result JSON
python3 -c "
import json, sys
d = json.loads(open(sys.argv[1]).read())
score = d['metrics'][0]['score'] * 100
total = d['metrics'][0]['num']
out = {'model': '${model_name}', 'benchmark': 'gpqa_diamond', 'mode': 'thinking',
       'score': score, 'total_questions': total}
json.dump(out, open('${LOG}/gpqa_diamond_result.json', 'w'), ensure_ascii=False, indent=2)
print('score:', score, 'total:', total)
" ${REPORT}
# → score: 49.49 total: 198

# 2. 运行 accuracy_compare
python3 ${EVAL_DIR}/accuracy_compare.py \
  --v2  ${LOG}/gpqa_diamond_result.json \
  --nv-baseline ${model_name} \
  --nv-baseline-file ${EVAL_DIR}/nv_baseline.yaml \
  --metric gpqa_diamond --json \
  --output ${LOG}/verdict_gpqa_diamond.json
# → 退出码 0，verdict 写入 verdict_gpqa_diamond.json
```

| 迭代 | 黑名单 | GPQA | 退出码 | 备注 |
|------|--------|------|--------|------|
| 第1次 | sort,sort_stable | 40.0%（50题） | 1（不达标） | TRITON_MLA；verdict_gpqa_diamond.json 记录 |
| 第2次 | sort,sort_stable | **49.49%**（198题全量） | 0（达标） | TRITON_ATTN；fast_gpqa.py detect_runaway bug crash，分数从 evalscope 报告 `outputs/gpqa_diamond/20260917_034638` 恢复 |

---

## 现象

- iter1（TRITON_MLA，50题）：GPQA 40.0%，NV 46.0%，↓13.04%，不达标。
- iter2（TRITON_ATTN，198题全量）：fast_gpqa.py 因 thinking 模型 list content 触发 detect_runaway AttributeError 崩溃，但 evalscope 已算完分数。从报告 `outputs/gpqa_diamond/20260917_034638/reports/AgentCPM-Report/gpqa_diamond.json` 恢复：`score=0.4949` → **49.49%**，198 题 succeeded=198。

## 定位

- iter1 不达标根因：TRITON_MLA 对 AgentCPM-Report（7B 非 MLA 架构）引入精度误差，切换 TRITON_ATTN 后精度恢复。
- iter2 达标：FlagGems 5.3.4.post1 + TRITON_ATTN + sort,sort_stable 黑名单，精度 49.49% 反超 NV 基线 46.0%。

## 处置

iter2 达标，完成。

**0918 补记**：本文档 Step 4 中的"重建 verdict"命令此前只写入文档、**未实际执行**——机器上
`gpqa_diamond_result.json` / `verdict_gpqa_diamond.json` 一直是 iter1 的旧产物（40.0%、`aligned=false`），
与结论相反。已于 2026-09-18 实跑该命令修正：

- 先备份 iter1 产物为 `gpqa_diamond_result_iter1.json` / `verdict_gpqa_diamond_iter1.json`（保留，未删除）
- 从 evalscope 报告重建 → `score=49.49, total=198`
- 实跑 `accuracy_compare.py` → **exit=0，`aligned=true`**

下方 verdict JSON 现为机器上的真实文件内容（非预期值）。

## 结果

- 修复后 GPQA 正确率：**49.49%**（198题全量，从 evalscope 报告恢复）
- NV 基线：46.0%
- 相对变化：↑7.59%（反超基线）
- 达标判定：**✅ 达标**（accuracy_compare 退出码 0，2026-09-18 实跑复核）

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

AgentCPM-Report（7B 非 MLA 架构）在 TRITON_MLA 下精度崩至 40.0%，切换 TRITON_ATTN 后恢复至 49.49%，超过 NV 基线 46.0%；非 MLA 架构模型不应使用 TRITON_MLA。
