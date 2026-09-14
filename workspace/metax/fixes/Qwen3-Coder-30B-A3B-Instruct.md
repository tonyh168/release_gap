# metax/Qwen3-Coder-30B-A3B-Instruct 修复日志

- **失败报告**：flagrelease_fail_reports/Metax/FAILED_Metax_Qwen3-Coder-30B-A3B-Instruct_202608012329.md
- **原始失败类型**：服务启动失败 + 精度不达标 + 性能不达标 + plugin-FL 报错（四项全失败）
- **日期**：2026-09-14

---

## 背景分析

四条 Issue：`Operator crash`、`Operator accuracy degradation`、`Operator performance degradation`、
`vllm-plugin-FL error`——是五个待修模型里最复杂的，几乎每类问题都踩到了。

Qwen3-Coder-30B-A3B 是 MoE 架构（30B 参数，A3B 表示激活 3B），使用 MLA（Multi-head Latent
Attention），与 XingChen4 同类。原报告 vLLM 0.20.2，新镜像 vLLM 0.24.0 的 MLA 接口变更
（KNOWLEDGE 一："Can't instantiate abstract class FlashMLAImpl... forward_mha/forward_mqa"）
已在 metax/XingChen4-0907 中处理，当前镜像理应已修复——但需上机确认。

TP 计算：MoE 模型权重文件约 60GB（所有专家总重量）→ 单卡 63.6GB 理论装得下，但 KV cache
空间不足→ **建议 TP=4**（XingChen4-0907 参考，Qwen3 系列 MoE 同规格）。

---

## 环境（实际运行时填写）

| 项目 | 值 |
|------|---|
| 宿主机 | `metax-___` |
| 容器名 | `Qwen3-Coder-30B-A3B-Instruct_flagos` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907` |
| 模型路径 | `/models/Qwen3-Coder-30B-A3B-Instruct` |
| 卡号 | `MACA_VISIBLE_DEVICES=0,1,2,3`（TP=4）|
| 实际 vLLM 版本 | |

---

## Step 0：登录 + 查卡

```bash
ssh metax-57
mx-smi   # 确认至少4张卡空闲
```

**mx-smi 输出节选**：
```
（上机后粘贴）
```

---

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907
docker run -d --rm \
  --name Qwen3-Coder-30B-A3B-Instruct_flagos \
  --network host \
  --shm-size 64g \
  --device /dev/dri:/dev/dri:rwm \
  --device /dev/mxcd:/dev/mxcd:rwm \
  -v /public-flash/models:/models \
  ${IMAGE} \
  sleep infinity
docker exec -it Qwen3-Coder-30B-A3B-Instruct_flagos /bin/bash

mx-smi
python -c "import vllm; print(vllm.__version__)"
```

**自检输出**：
```
vllm 版本：
```

---

## Step 2：确认模型

权重来源：`Qwen/Qwen3-Coder-30B-A3B-Instruct`（ModelScope）

```bash
ls /models/ | grep -i qwen3-coder
ls /models/Qwen3-Coder-30B-A3B-Instruct/
```

**结果**：☐ 共享盘已有 / ☐ 需下载

若需下载：
```bash
pip install -q modelscope
modelscope download --model Qwen/Qwen3-Coder-30B-A3B-Instruct \
  --local_dir /models/Qwen3-Coder-30B-A3B-Instruct
```

---

## Step 3：起 vLLM 服务

### 修复策略

Qwen3-Coder 是 MoE + MLA 架构，已知问题最多，分三阶段处理：

1. **MLA 冒烟**：先跑 eager + 默认黑名单，重点看 `forward_mha/forward_mqa` 报错（vLLM 0.24
   接口变更，当前镜像应已修复，但需确认）
2. **crash 定位**：若仍崩溃，抓算子名加黑名单
3. **精度定位**：起来后必须用长 prompt 冒烟（MLA prefill 路径只有长 prompt 才走），
   确认无 `fa_version` 报错，再跑评测

### 环境变量（每次迭代更新）

**第1次尝试**（SOP 默认黑名单 + MLA 相关设置）：
```bash
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export MACA_VISIBLE_DEVICES=0,1,2,3
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice
export VLLM_FL_USE_FLAGGEMS_ATTN=0   # MLA prefill 走 MetaX 原生 FA，避免 fa_version 问题
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
```

```bash
model_name=Qwen3-Coder-30B-A3B-Instruct
mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/Qwen3-Coder-30B-A3B-Instruct \
  --served-model-name ${model_name} \
  --dtype bfloat16 \
  --tensor-parallel-size 4 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log
```

**启动日志关键行**（贴 startup complete 或 traceback）：
```
（粘贴）
```

**特别检查点**：若日志出现以下任意一条，按说明处理：
- `Can't instantiate abstract class FlashMLAImpl ... forward_mha/forward_mqa` → plugin-FL 未对齐 vLLM 0.24，需换镜像或检查 plugin-FL 版本
- `flash_attn_varlen_func() got an unexpected keyword argument 'fa_version'` → 确认 `VLLM_FL_USE_FLAGGEMS_ATTN=0` 已设，若已设仍报错需上报
- `PassManager::run failed` / `shape_judge` → 该算子编译崩，加入黑名单（注意用下划线而非点号）

### 迭代记录（启动阶段）

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST 变化 | 结果 | 日志关键报错 |
|------|------------------------------|------|-------------|
| 第1次 | 默认 | | |
| 第2次 | | | |
| 第3次 | | | |

**启动成功日志行**：
```
（贴 "Application startup complete"）
```

### 冒烟验证（必须用长 prompt，验证 MLA prefill 路径）

```bash
model_name=Qwen3-Coder-30B-A3B-Instruct
curl -s http://localhost:8000/v1/models

# 短 prompt（decode 路径）
curl -s http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"1+1=?"}],"max_tokens":16,"temperature":0,"chat_template_kwargs":{"enable_thinking":false}}'

# 长 prompt（MLA prefill 路径，这个才是关键）
curl -s http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"请写一段 Python 代码，实现一个完整的链表数据结构，包含插入、删除、搜索、反转操作，并附上详细的单元测试。要求代码符合 PEP8 规范，有完整的类型注解和 docstring。"}],"max_tokens":1024,"temperature":0,"chat_template_kwargs":{"enable_thinking":false}}'
```

**冒烟结果**：
- 短 prompt：☐ 正常 / ☐ 报错
- 长 prompt：☐ 正常 / ☐ 500错误（贴报错）

```
（长 prompt 输出节选或报错）
```

---

## Step 4：评测

```bash
# 宿主机
docker cp /path/to/release_评测标准 Qwen3-Coder-30B-A3B-Instruct_flagos:/workspace/release_评测标准

# 容器内
docker exec -it Qwen3-Coder-30B-A3B-Instruct_flagos /bin/bash
cd /workspace/release_评测标准
pip install -q 'evalscope==1.5.1' requests pyyaml

model_name=Qwen3-Coder-30B-A3B-Instruct
python3 fast_gpqa.py --model-name ${model_name} \
  --api-base http://127.0.0.1:8000/v1 \
  --output /models/release_run_logs/${model_name}/gpqa.json
python3 accuracy_compare.py \
  --v2 /models/release_run_logs/${model_name}/gpqa.json \
  --nv-baseline ${model_name} \
  --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict.json
```

> ⚠ Qwen3 Coder 是 thinking 模型（`enable_thinking` 默认开启），单题输出可能数千 token，
> 50 题 GPQA 可能跑数小时，不要中断。
> 若 `truncation_detected: true` → 加大 `--max-model-len` 后重跑。

### 评测迭代记录

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST | GPQA 正确率 | accuracy_compare 退出码 | 备注 |
|------|--------------------------|------------|------------------------|------|
| 第1次 | | | | |
| 第2次 | | | | |

**verdict.json 原文**（最终达标）：
```json
（粘贴）
```

---

## 现象
（上机后填）

## 定位
（crash 算子名 / plugin-FL 报错类型 / 精度退化算子）

## 处置
（各阶段做了什么调整）

## 结果
- 修复后 GPQA 正确率：
- NV 基线：
- 达标判定（accuracy_compare 退出码）：

## 提炼到 KNOWLEDGE 的条目
（一句话规律，若无则写"无新规律"）
