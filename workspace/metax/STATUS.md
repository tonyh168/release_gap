# Metax 模型修复状态总览

> 更新：2026-09-16 | 机器：metax-58 / metax-60 | 镜像：`metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907`（vLLM 0.24.0 / plugin-FL tree3.6）

## 图例

| 标识 | 含义 |
|------|------|
| ✅ 已通过 | accuracy_compare 退出码 0 |
| 🟡 评测进行中 | 评测脚本已跑，等待结果 |
| 🟢 服务运行中 | vLLM 服务已启动，smoke test 通过，待评测 |
| ❌ 精度不达标 | accuracy_compare 退出码 1 |
| 🔵 待开始 | 修复日志已建，尚未动手 |

---

## 状态表

| 模型 | 阶段 | 原始失败类型 | 评测指标 | NV基线 | 当前得分 | 机器 / 容器 / 端口 | 下一步 |
|------|------|------------|---------|:------:|:-------:|-------------------|--------|
| Phi-3-mini-128k-instruct | ✅ 已通过 | 精度偏差 4.0%（V2=38% vs NV=42%，性能 79.2% 踩线） | gpqa_diamond | 42.0 | **（待补充）** | metax-60 / `Phi-3-mini-128k-instruct_flagos` / :8000 | 完成，达标 |
| Phi-3.5-mini-instruct | ✅ 已通过 | 精度不达标（V2=28%，V3=26%，超 5% 阈值） | gpqa_diamond | 26.0 | **34.0**（↑8pt，反超基线） | metax-60 / `flagrelease-fix-phi-3.5-mini-instruct` / :8001 | 完成，达标（doc_id 23/34 eval_missing2.py 补评） |
| Phi-4-mini-instruct | ✅ 已通过 | 精度不达标（V3=28% vs NV=38%，plugin-FL GQA 精度退化） | gpqa_diamond | 38.0 | **44.0**（↑6pt，反超基线） | metax-60 / `flagrelease-fix-phi-4-mini-instruct` / :8002 | 完成，达标（v3 扩展黑名单 rms_norm,silu_and_mul，doc_id 2 补评） |
| Qwen3-Coder-30B-A3B-Instruct | ✅ 已通过 | 服务启动失败 + 精度/性能不达标 + plugin 报错（四项全失败） | gpqa_diamond | 52.0 | **50.0**（噪声容忍达标） | metax-60 / `Qwen3-Coder-30B-A3B-Instruct_flagos` / :8002 | 完成，达标（MoE+MLA，默认黑名单 + VLLM_FL_USE_FLAGGEMS_ATTN=0） |
| EXAONE-4.0-32B | ✅ 已通过 | 服务启动失败（Operator crash） | gpqa_diamond | 62.0 | **63.13%**（↑1.13pt，198题全量，干净达标） | metax-58 / `EXAONE-4.0-32B_flagos` / :8000 | 完成，达标（默认黑名单一次成功，198题全量排除噪声，fast_gpqa score=null 从 evalscope reviews 补计分） |
| Qwen3-30B-A3B-Thinking-2507 | ✅ 已通过 | 服务启动失败（V1–V4 全无数据） | gpqa_diamond | 75.0 | **74.0**（相对退化 1.33%，容差内达标） | metax-60 / `flagrelease-fix-qwen3-30b-a3b-thinking-2507` / :8000 | 完成，达标（thinking 模式，fast_gpqa score=null 从 evalscope reviews 手工补计分） |
| Baichuan-M2-32B | ✅ 已通过 | 服务启动失败（V1–V4 全无数据） | gpqa_diamond | 64.0 | **74.0**（↑10pt，反超基线） | metax-60 / `flagrelease-fix-baichuan-m2-32b` / :8003 | 完成，达标（evalscope crash 在 runaway 后处理阶段，50 题已全部评完，从 reviews 文件补计分） |
| GLM-4-32B-0414 | ✅ 已通过 | 服务启动失败 + 精度不达标（Operator crash + 精度退化） | gpqa_diamond | 55.0 | **52.0**（噪声容忍达标） | metax-60 / `GLM-4-32B-0414_flagos` / :8003 | 完成，达标（默认黑名单一次成功，noise_zone=true，1.5 题差 ≤ 2 题阈值） |
| SOLAR-10.7B-Instruct-v1.0 | ❌ 修复暂停 | 精度不达标（V2=27.78%，V3=30.3%，均低于 NV×0.95=32.3%）+ plugin-FL 报错 | gpqa_diamond | 34.0 | v1=24.0%❌ v2=26.0%❌ v3=20.0%❌ | metax-60 / 容器已停止 | **暂停**（三轮均不达标，最优 v2=26%；plugin-FL 导致格式退化，模型生成冗长推理不输出 ANSWER 字母） |
| reka-flash-3 | 🟡 评测进行中 | 精度不达标（V3=52.02% vs NV=59%，rel_drop=11.8%）+ plugin-FL 报错 | gpqa_diamond | 59.0 | — | metax-60 / `flagrelease-fix-reka-flash-3` / :8001 | **v1 eval 跑中**（默认黑名单，TP=2，GPU 1,2；reasoning 模型，预计 9+h；服务 29-44 tok/s 正常出题） |

---

## 当前进度快照

- **精度已通过**：7 / 10（Phi-3-mini-128k-instruct；Phi-3.5-mini-instruct 34.0；Phi-4-mini-instruct 44.0；Qwen3-Coder-30B-A3B-Instruct 50.0；GLM-4-32B-0414 52.0；Qwen3-30B-A3B-Thinking-2507 74.0；Baichuan-M2-32B 74.0）
- **评测进行中**：1 / 10（reka-flash-3 v1 eval 跑中，metax-60，~28/50）
- **修复暂停**：1 / 10（SOLAR-10.7B-Instruct-v1.0，三轮均不达标，最优 v2=26%，容器已停止）
- **尚未开始**：0 / 10（EXAONE ✅ 已完成）

### 🟡 当前运行中的服务

**metax-60**

| 模型 | GPU | 端口 | TP | 数据集 | 题数 |
|------|:---:|:----:|:--:|:------:|:----:|
| reka-flash-3 | 1,2 | 8001 | 2 | gpqa_diamond | 50（eval 进行中） |

---

## 已完成修复详情

### Phi-3.5-mini-instruct（✅ 达标）

- **关键策略**：plugin-FL 默认黑名单 + eager，TP=1，GPU 0，port 8001
- **环境变量**：`VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice`，`VLLM_FL_USE_FLAGGEMS_ATTN=0`
- **评测结果**：34%（17/50），NV 26.0%，accuracy_compare 退出码 0
- **注意**：doc_id 23/34 卡挂（GPU 15% util 持续 28min），用 eval_missing2.py 补评后合并计分

### Phi-4-mini-instruct（✅ 达标）

- **关键策略**：三轮迭代，v1 裸 vLLM 建基线（40%），v2 默认黑名单退化（26%，GQA 精度崩），v3 扩展黑名单加 `rms_norm,silu_and_mul` 达标（44%）
- **环境变量**：`VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice,rms_norm,silu_and_mul`，`VLLM_FL_USE_FLAGGEMS_ATTN=0`
- **评测结果**：44%（22/50），NV 38.0%，accuracy_compare 退出码 0
- **注意**：doc_id 2 挂起，用 eval_missing_phi4_v3.py 补评（答对，latency 132.5s）

### Qwen3-Coder-30B-A3B-Instruct（✅ 达标）

- **关键策略**：MoE + MLA 架构，`VLLM_FL_USE_FLAGGEMS_ATTN=0`（MLA prefill 用 MetaX 原生 FA），默认黑名单一次起成功，TP=4（GPU 2–5），port 8002
- **评测结果**：50%（25/50），NV 52.0%，noise_zone 容忍达标
- **注意**：长 prompt 冒烟（MLA prefill 路径）是必须验证项

### Qwen3-30B-A3B-Thinking-2507（✅ 达标）

- **关键策略**：MoE + MLA thinking 模型，`VLLM_FL_USE_FLAGGEMS_ATTN=0`，默认黑名单，TP=4（GPU 2–5），port 8000，thinking 模式（temperature=0.6，max_tokens=20000）
- **环境变量**：`VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice`，`VLLM_FL_USE_FLAGGEMS_ATTN=0`
- **评测结果**：74.0%（37/50），NV 75.0%，相对退化 1.33%（容差 5.0%），accuracy_compare 退出码 0
- **注意**：fast_gpqa score=null（thinking 模式答案未从 `<think>` 块提取），50 题 predictions/reviews 完整，从 evalscope reviews 的 `sample_score.score.value.accuracy` 手工补计分

### Baichuan-M2-32B（✅ 达标）

- **关键策略**：dense 32B，默认黑名单，`VLLM_FL_USE_FLAGGEMS_ATTN=0`，TP=2（GPU 6–7），port 8003
- **环境变量**：`VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice`，`VLLM_FL_USE_FLAGGEMS_ATTN=0`
- **评测结果**：74.0%（37/50），NV 64.0%（↑10pt 反超），accuracy_compare 退出码 0
- **注意**：fast_gpqa crash 在 runaway 后处理阶段（`detect_runaway` 收到 list 类型 content），50 题已全部评完，从 evalscope reviews 补计分

- **历史结果**（metax-57，50 题）：58%（29/50），NV 62.0%，noise_zone=true（2.0 题差，噪声阈值），退出码 0
- **本次重跑**（metax-58）：198 题全量评测，排除小样本噪声，结果待出
- **关键策略**：默认黑名单 + eager，`VLLM_FL_USE_FLAGGEMS_ATTN=0`，TP=4（GPU 0–3），port 8000

### GLM-4-32B-0414（✅ 达标）

- **关键策略**：默认黑名单 + eager，`VLLM_FL_USE_FLAGGEMS_ATTN=0`，TP=2（GPU 0–1），port 8003，一次起成功无需调整黑名单
- **环境变量**：`VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice`，`VLLM_FL_USE_FLAGGEMS_ATTN=0`
- **评测结果**：52%（26/50），NV 55.0%，noise_zone=true（1.5 题差 ≤ 2 题阈值），accuracy_compare 退出码 0
- **注意**：原报告 V1–V4 全空（服务启动就崩）；本次 plugin-FL 默认黑名单覆盖了 GLM-4 崩溃算子，无需二分排查

---

## 已知问题与规律

### vllm 路径（非交互 shell 必须用绝对路径）

容器内 `vllm` 是 Python 包目录（`/opt/conda/lib/python3.12/site-packages/vllm/`），非交互 shell（`docker exec -d`、`nohup bash script.sh`）里 PATH 不含 `/opt/conda/bin`，裸写 `vllm serve` 报 `cannot execute: Is a directory`。**始终用 `/opt/conda/bin/vllm serve`**，交互和非交互均安全。

### evalscope 卡题（Phi-3.5 / Phi-4）

单题卡挂（GPU util 持续低迷 ~28min）是已知概率性问题，非服务崩溃。处理方式：`kill` evalscope 进程 → 用 `eval_missing*.py` 单独补评缺题 → 合并计分。

### Phi-4 GQA 精度退化根因

plugin-FL 默认黑名单未覆盖 `rms_norm` 和 `silu_and_mul`，这两个算子在 GQA 路径上有精度问题。**遇到 dense 模型 plugin-FL 后精度大幅退化，优先尝试加 `rms_norm,silu_and_mul` 到黑名单**。

### MLA 模型（Qwen3 系 MoE）

`VLLM_FL_USE_FLAGGEMS_ATTN=0` 是必需项，否则 MLA prefill 路径 OOM（FlagGems attention 共享内存不足）。TP=4 是 30B MoE 的稳定配置（单卡 KV cache 不够）。

---

> 各模型修复日志：`workspace/metax/fixes/<模型名>.md`
> 评测产出目录：`/public-flash/models/release_run_logs/<模型名>/`（metax-58/60 共享 NFS）
