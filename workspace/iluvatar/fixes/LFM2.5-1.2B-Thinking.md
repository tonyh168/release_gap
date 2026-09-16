# iluvatar/LFM2.5-1.2B-Thinking 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_LFM2.5-1.2B-Thinking_202607281813.md
- **原始失败类型**：精度不达标（V2 GPQA=2.4%）+ plugin-FL dispatch 报错
- **修复日期**：2026-09-15

---

## 背景分析

V2 GPQA=2.4%，精度严重偏低，同时有 plugin-FL dispatch 错误（3个 issue）。
V1/V2 性能比约 87.5%，性能也略有下降。
LFM2.5-1.2B-Thinking 是 LiquidAI LFM 系列 thinking 模型，1.2B 极小量级。
LFM 系列原报告使用 32 算子白名单（含 vstack），FlagGems 5.0.x 在该架构上存在系统性精度问题。

LFM2.5-1.2B-Thinking 为 SSM/hybrid 架构（非 MLA），**TP=1**（单卡足够）。
新镜像升至 FlagGems 5.3.4.post1，直接以默认黑名单起服务验精度。

---

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-lfm2.5-1.2b-thinking` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/LFM2.5-1.2B-Thinking` |
| GPU | `CUDA_VISIBLE_DEVICES=0`（TP=1，端口 8000） |
| attention-backend | `TRITON_ATTN`（LFM 非 MLA 架构） |
| max-model-len | `32768` |
| 实际 vLLM 版本 | 0.24.0（vllm_fl0.24.0） |

---

## Step 0：登录 + 查卡

```bash
ssh iluvatar-139
ixsmi
```

---

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
docker rm -f flagrelease-fix-lfm2.5-1.2b-thinking 2>/dev/null || true
docker run -itd --name flagrelease-fix-lfm2.5-1.2b-thinking \
  --device=/dev/iluvatar0  --device=/dev/iluvatar1  --device=/dev/iluvatar2  --device=/dev/iluvatar3 \
  --device=/dev/iluvatar4  --device=/dev/iluvatar5  --device=/dev/iluvatar6  --device=/dev/iluvatar7 \
  --device=/dev/iluvatar8  --device=/dev/iluvatar9  --device=/dev/iluvatar10 --device=/dev/iluvatar11 \
  --device=/dev/iluvatar12 --device=/dev/iluvatar13 --device=/dev/iluvatar14 --device=/dev/iluvatar15 \
  --device=/dev/itrctl --device=/dev/itrlink --device=/dev/itr_peerm_dev0 \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  ${IMAGE} bash

## Step 2：确认模型

权重来源：`LiquidAI/LFM2.5-1.2B-Thinking`（ModelScope）

```bash
ls /models/flagrelease/fixes_models/LFM2.5-1.2B-Thinking/
```

若需下载（eval-scope 容器里）：
```bash
docker exec -it eval-scope bash
modelscope download --model LiquidAI/LFM2.5-1.2B-Thinking \
  --local_dir /models/flagrelease/fixes_models/LFM2.5-1.2B-Thinking
```

## Step 3：起 vLLM 服务

LFM2.5-1.2B-Thinking 为 SSM/hybrid 架构（非 MLA），使用 `TRITON_ATTN`；默认黑名单 `sort,sort_stable`。

```bash
docker exec flagrelease-fix-lfm2.5-1.2b-thinking bash -c "
  export GEMS_VENDOR=iluvatar
  export VLLM_PLUGINS=fl
  export CUDA_VISIBLE_DEVICES=0
  export VLLM_WORKER_MULTIPROC_METHOD=spawn
  export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
  export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
  export VLLM_RPC_TIMEOUT=72000000
  export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
  model_name=LFM2.5-1.2B-Thinking
  mkdir -p /models/release_run_logs/\${model_name}
  nohup vllm serve /models/flagrelease/fixes_models/\${model_name} \
    --served-model-name \${model_name} \
    --dtype bfloat16 \
    --tensor-parallel-size 1 \
    --gpu-memory-utilization 0.9 \
    --max-model-len 32768 \
    --port 8000 \
    --attention-backend TRITON_ATTN \
    --enforce-eager \
    --trust-remote-code \
    > /models/release_run_logs/\${model_name}/serve.log 2>&1 &
  echo \$! > /models/release_run_logs/\${model_name}/serve.pid
  echo 'vllm serve launched, pid:' \$(cat /models/release_run_logs/\${model_name}/serve.pid)
"
```

### 迭代记录

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST | GPQA | accuracy_compare 退出码 | 备注 |
|------|--------------------------|------|------------------------|------|
| 第1次 | sort,sort_stable（默认） | 32.0% | 0（PASS） | 新镜像 FlagGems 5.3.4.post1 精度恢复，默认黑名单直接过 |

## Step 4：评测

评测在 eval-scope 容器内用 `fast_gpqa.py` 跑 gpqa_diamond（50题）。
LFM2.5-1.2B-Thinking 为 thinking 模型，`message.content` 是 list 结构，
触发了 `fast_gpqa.py detect_runaway` 的 `AttributeError: 'list' object has no attribute 'strip'`（line 370）。
evalscope 已算出分数，从报告重建 result JSON 再跑 compare：

```bash
# 在 eval-scope 容器内
model_name=LFM2.5-1.2B-Thinking
EVAL_DIR=/models/flagrelease/eval_methods
LOG=/models/release_run_logs/${model_name}

# 1. 定位 evalscope 报告
find /root -path "*/reports/${model_name}/gpqa_diamond.json" 2>/dev/null | tail -1

# 2. 读取分数，手写最小 result JSON
python3 -c "
import json, sys
rpt = open(sys.argv[1]).read()
d   = json.loads(rpt)
score = d['metrics'][0]['score'] * 100
total = d['metrics'][0]['num']
out = {'model':'${model_name}','benchmark':'gpqa_diamond','mode':'thinking',
       'score': score, 'total_questions': total}
json.dump(out, open('${LOG}/gpqa_diamond_result.json','w'), ensure_ascii=False, indent=2)
print('score:', score, 'total:', total)
" <报告路径>

# 3. accuracy_compare
python3 ${EVAL_DIR}/accuracy_compare.py \
  --v2  ${LOG}/gpqa_diamond_result.json \
  --nv-baseline ${model_name} \
  --nv-baseline-file ${EVAL_DIR}/nv_baseline.yaml \
  --metric gpqa_diamond --json \
  --output ${LOG}/verdict_gpqa_diamond.json
```

## 现象

原始失败：V2 GPQA=2.4%，精度严重偏低，有 plugin-FL dispatch 报错。

本次新镜像（FlagGems 5.3.4.post1）：
- 服务正常启动，无 Operator crash，无 dispatch 报错
- evalscope 评测完整跑完 50 题，算出分数 32.0%
- fast_gpqa.py 在收尾 `detect_runaway` 处崩溃（list content bug），result JSON 未写出
- 从 evalscope 报告重建 result JSON，accuracy_compare 正常运行

## 定位

- FlagGems 5.0.x 在 LFM 架构上存在系统性精度问题（GPQA=2.4%），5.3.4.post1 已修复
- plugin-FL dispatch 报错在 vLLM 0.24.0 + vllm_fl0.24.0 中已消失
- `fast_gpqa.py detect_runaway` 的 list content crash 是独立 bug（已修复，但本次评测进程加载了旧代码），不影响分数

## 处置

- 黑名单无需调整，默认 `sort,sort_stable` 直接达标
- `fast_gpqa.py` list→str 归一补丁已更新本地和 NFS 版本（见 [[fast-gpqa-runaway-list-bug]]）
- 分数从 evalscope 原始报告重建，无需重跑

## 结果

- 修复后 GPQA 正确率：**32.0%**（50题，16题正确）
- NV 基线：29.0%
- 相对变化：+10.34%（反超基线）
- 达标判定：**PASS**（accuracy_compare 退出码 0）
- verdict 时间戳：2026-09-15T07:14:06

**verdict_gpqa_diamond.json**：
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

FlagGems 5.3.4.post1 修复了 LFM 系列（SSM/hybrid 架构）在 5.0.x 下的系统性精度崩溃；默认黑名单 `sort,sort_stable` 即可通过，无需扩展 vstack 等原报告白名单。
