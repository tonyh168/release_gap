# 本地精度评测工具集

> 来源：FlagRelease 仓库 `refactor` 分支 `skills/flagos-eval-comprehensive/`（2026-09-11 提取）
> 用途：对一个已在运行的 OpenAI 兼容推理服务（vLLM / SGLang 等）做本地精度评测，并对两份结果做达标判定。

---

## 文件清单

| 文件 | 作用 |
|------|------|
| `fast_gpqa.py` | 评测主脚本：对服务跑题、自动判分、输出精度 JSON |
| `fast_gpqa_config.yaml` | 默认配置（API 地址、数据集来源等；命令行参数优先于配置） |
| `accuracy_compare.py` | 对比判定：两份结果 A/B 对比，或与 NV 参考基线对比，5% 相对退化阈值 |
| `nv_baseline.yaml` | NV 参考精度基线表（123 个模型，供 `--nv-baseline` 查表；不用 NV 基线可忽略） |
| `README.md` | 本文档 |

---

## 文件清单（含数据集）

| 路径 | 作用 |
|------|------|
| `fast_gpqa.py` | 评测主脚本 |
| `fast_gpqa_config.yaml` | 默认配置 |
| `accuracy_compare.py` | 对比判定脚本 |
| `nv_baseline.yaml` | NV 参考精度基线表 |
| `datasets/gpqa_diamond.tar.gz` | gpqa_diamond 数据集离线包（397K，2026-09-14 从 metax-60 提取） |
| `README.md` | 本文档 |

---

## 离线数据集使用说明

`datasets/` 目录存放预下载好的评测数据集压缩包，部署到无外网机器时直接 scp，无需再拉取。

### 部署到目标机器

```bash
# 1. 把压缩包 scp 到目标机器（示例：部署到 metax-60 的 /public-flash/models/evalscope-datasets/）
scp flagrelease_eval_methods/datasets/gpqa_diamond.tar.gz metax-60:/tmp/

# 2. 在目标机器（或容器内）解压，目标目录即 evalscope 的缓存格式
ssh metax-60 "cd /public-flash/models/evalscope-datasets && tar xzf /tmp/gpqa_diamond.tar.gz"
# 解压后得到 /public-flash/models/evalscope-datasets/gpqa_diamond/

# 3. 容器内用 --dataset-dir 指向挂载路径，跳过网络下载
docker exec <eval-container> python3 /workspace/fast_gpqa.py \
  --model-name <model_name> \
  --api-base http://127.0.0.1:8000/v1 \
  --dataset-dir /models/evalscope-datasets \
  --output /models/release_run_logs/<model_name>/gpqa.json
```

> `--dataset-dir` 指向包含 `gpqa_diamond/` 子目录的**父目录**，evalscope 会在其中查找数据集缓存，命中后不再联网。

---

## 环境依赖

```bash
pip install requests pyyaml 'evalscope==1.5.1'
```

- `evalscope` 是评测引擎（跑题+判分在其内部完成），**版本锁定 1.5.1**，其他版本行为可能与验证环境不一致（脚本会告警但继续）。
- 评测对象：任何 OpenAI 兼容服务（`http://host:port/v1`）。脚本会自动探测模型名（`--model-name` 可省略）、自动探测吞吐选并发、自动识别 thinking 模型（qwen3/qwq/deepseek-r1 等）调整 max_tokens。
- 数据集默认从 ModelScope 下载（`dataset_hub: modelscope`），首次运行需联网；可用 `--dataset-dir` 指向本地缓存目录离线复用（见上方"离线数据集使用说明"）。

---

## 一、跑评测：`fast_gpqa.py`

### 最简用法

```bash
cd /home/lz/local-eval
python3 fast_gpqa.py --model-name Qwen3-8B --api-base http://localhost:8000/v1 --output result.json
```

跑完终端打印分数，同时写 `result.json`（默认也会在 cwd 留一份 `{dataset}_result.json`）。

### 支持的数据集（`--dataset`）

| 数据集 | few-shot | 默认题数 | `--limit` 语义 | 说明 |
|--------|---------|---------|---------------|------|
| `gpqa_diamond`（默认） | 0-shot | 50 | 总题数；`0`=全量 198 | 研究生级科学选择题，主判据 |
| `mmlu` | 5-shot | 20/子集 = 1140 | **每子集**题数（57 子集）；`0`=全量 14042 | `--limit 100` = 5700 题 |
| `math_500` | 0-shot | 40/等级 = 200 | **每子集**题数（5 个 Level）；`0`=全量 500 | `\boxed{}` 答案 |
| `mm_star` | 0-shot | 全量 1500 | 每子集（6 子集）；`0`=全量 | **多模态 VLM 专用**，须服务支持图像输入 |

### 常用示例

```bash
# GPQA 全量 198 题
python3 fast_gpqa.py --model-name Qwen3-8B --api-base http://localhost:8000/v1 --limit 0 --output gpqa_full.json

# MMLU（默认 1140 题，不传 --limit）
python3 fast_gpqa.py --model-name Qwen3-8B --api-base http://localhost:8000/v1 --dataset mmlu --output mmlu.json

# 一次跑多个数据集（--output 此时是目录，每数据集写 {dataset}_result.json）
python3 fast_gpqa.py --model-name Qwen3-8B --api-base http://localhost:8000/v1 --dataset mmlu math_500 --output ./results/

# 多模态模型 MMStar 全量
python3 fast_gpqa.py --model-name Qwen2.5-VL-7B --api-base http://localhost:8000/v1 --dataset mm_star --limit 0 --output mmstar.json

# 用配置文件（命令行仍可覆盖）
python3 fast_gpqa.py --config fast_gpqa_config.yaml --output result.json
```

### 全部参数

| 参数 | 说明 |
|------|------|
| `--config` | 配置文件路径（YAML） |
| `--model-name` | 模型名；省略时自动从 `/v1/models` 探测 |
| `--api-base` | OpenAI 兼容 API 地址，如 `http://localhost:8000/v1` |
| `--api-key` | 默认 `EMPTY` |
| `--dataset` | 数据集，可多个（空格或逗号分隔） |
| `--limit` | 题数；不传=数据集默认，`0`=全量；mmlu/math_500/mm_star 为每子集题数 |
| `--dataset-dir` | 数据集缓存目录（预下载后离线用） |
| `--output` | 结果 JSON 路径；多数据集时为目录 |

### 结果 JSON 关键字段

```json
{
  "model": "Qwen3-8B",
  "benchmark": "gpqa_diamond",
  "score": 62.5,
  "total_questions": 50,
  "truncation_detected": false,
  "eval_duration_seconds": 312.5,
  "runaway_detection": {"runaway_count": 0, ...}
}
```

- **`score`**：正确率百分比（0–100），即精度数据。
- `truncation_detected: true` 表示有输出被 max_tokens 截断，分数可能偏低。
- `runaway_detection.runaway_count > 0` 表示检测到复读死循环，该轮分数可能被污染。

**退出码**：`0` = 所有数据集成功出分；`1` = 有数据集失败。

### 评测时长参考

- 普通模型 GPQA 50 题：几分钟到几十分钟（取决于芯片吞吐）。
- thinking 模型（自动识别）单题可达数千~上万 token，50 题可能 6 小时以上——这是预算内预期，不要中途截断。
- thinking 模型 max_tokens 硬上限 20000（防 runaway 复读卡死），正常思考链不受影响。

---

## 二、对比判定：`accuracy_compare.py`

两种模式，判定口径统一为**相对退化 ≤ 5%**。

### 模式 1：两份结果对比（A 基线 vs B 待判定）

```bash
python3 accuracy_compare.py --v1 baseline.json --v2 current.json
```

判据：`(v1_score - v2_score) / v1_score ≤ 5%`（相对退化不超 5% 即达标）。

### 模式 2：对比 NV 参考基线

```bash
python3 accuracy_compare.py --v2 current.json --nv-baseline Qwen3-8B --nv-baseline-file nv_baseline.yaml --json
```

判据：`(v2_score - nv_score) / nv_score ≥ -5%`。模型名匹配大小写/连字符不敏感，自动匹配别名；查不到时退出码 3（缺基线，需自行兜底）。

### 参数

| 参数 | 说明 |
|------|------|
| `--v1` | 基线结果 JSON（模式 1） |
| `--v2` | **必填**，待判定结果 JSON |
| `--threshold` | 相对退化阈值，默认 `0.05` |
| `--nv-baseline MODEL` | NV 基线模式：模型名 |
| `--nv-baseline-file` | nv_baseline.yaml 路径（默认找 `../shared/nv_baseline.yaml`，本目录建议显式指定） |
| `--metric` | 指标名，默认 `gpqa_diamond`；其他数据集传 `mmlu` / `math_500` 等 |
| `--nv-tolerance` | NV 模式容差（默认取 nv_baseline.yaml 的 default_tolerance，即 0.05） |
| `--json` | 以 JSON 打印判定结果 |
| `--output` | 判定结果写文件（JSON） |

### 退出码

| 码 | 含义 |
|----|------|
| `0` | 达标 |
| `1` | 不达标 |
| `2` | 参数/文件错误 |
| `3` | 缺 NV 基线（模型名未命中表） |

### 小样本噪声容忍

题数 ≤ 100 的评测，若相对退化超阈值但**绝对差 ≤ 2 题**，直接判达标（退出码 0）——避免 50 题评测中 1~2 题抖动造成假阳性判负。

---

## 三、典型工作流

```bash
cd /home/lz/local-eval

# 1. 对基线服务跑一轮（如原生 vLLM）
python3 fast_gpqa.py --model-name Qwen3-8B --api-base http://localhost:8000/v1 --output baseline.json

# 2. 切换服务实现/配置后跑第二轮
python3 fast_gpqa.py --model-name Qwen3-8B --api-base http://localhost:8000/v1 --output current.json

# 3. 判定
python3 accuracy_compare.py --v1 baseline.json --v2 current.json --output compare.json
echo "退出码: $?"   # 0=达标 1=不达标
```

⚠ **两次评测必须用完全相同的参数**（数据集、题数、max_tokens 等），否则分数不可比。脚本参数由数据集和模型名自动决定，同一条命令跑两次即可。

---

## 注意事项

1. **评测期间不要同时跑性能测试**——互相抢占 GPU 会导致结果不可信。
2. `fast_gpqa.py` 内含两个可选集成（`error_writer`、`service_monitor`），独立使用时 import 失败自动降级为空操作，不影响功能。
3. 对比判定只读结果 JSON 的 `score`/`total_questions` 等字段，与评测时使用的服务类型无关——可以对比任意两次运行、任意两种服务实现。
4. `nv_baseline.yaml` 中的分数为 NV（NVIDIA）平台实测/官方榜单值，仅作参考基线；非 NV 芯片上的结果与之对比时，5% 容差是 FlagOS 流程的达标口径，可按需用 `--nv-tolerance` 调整。
