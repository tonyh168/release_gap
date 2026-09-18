# iluvatar/TinyR1-32B-Preview 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_TinyR1-32B-Preview_202608271844.md
- **原始失败类型**：服务启动失败（无镜像产出，全部评测数据为空）
- **日期**：

## 背景分析

服务在所有版本下均无法启动，3 个 issue 提交（crash + accuracy + performance degradation）。
V2/V3 均有 32 算子白名单（add, addmm, cat, cos, embedding, flash_attn_varlen_func, 等），
但服务仍未成功起来，说明另有未实现算子导致 crash。
原始环境 vLLM 0.20.2 + FlagGems 5.0.0；本次用新镜像重试。
TinyR1-32B 为 32B 参数量，**TP=4**（bf16 ~64 GB，单卡 32 GB → 4 卡）。

## 环境（实际运行时填写）

| 项目 | 值 |
|------|---|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-tinyr1-32b-preview` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/TinyR1-32B-Preview` |
| 卡号 | `CUDA_VISIBLE_DEVICES=0,1,2,3`（TP=4）|
| 实际 vLLM 版本 | |

## Step 0：登录 + 查卡 + 拉取镜像

```bash
ssh iluvatar-139
ixsmi   # 确认至少 4 张卡空闲
docker pull harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope
docker pull harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
```

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
model_name=tinyr1-32b-preview
docker run -itd --name flagrelease-fix-${model_name} \
  --device=/dev/iluvatar \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  ${IMAGE} bash
docker exec -it flagrelease-fix-${model_name} bash
ixsmi && python -c "import vllm; print(vllm.__version__)"
```

## Step 2：确认模型

权重来源：`360zhinao/TinyR1-32B-Preview`（ModelScope）
> 注：原失败报告中写的 `qihoo360/TinyR1-32B-Preview` 为错误路径（404），实际路径为 `360zhinao/TinyR1-32B-Preview`。

```bash
ls /models/flagrelease/fixes_models/TinyR1-32B-Preview/
```

若需下载（eval-scope 容器里）：
```bash
docker exec -it eval-scope bash
modelscope download --model 360zhinao/TinyR1-32B-Preview \
  --local_dir /models/flagrelease/fixes_models/TinyR1-32B-Preview
```

## Step 3：起 vLLM 服务

原报告 V2/V3 均有 32 算子白名单（与 Fathom-R1-14B 相同），但服务仍未起来，
说明另有未实现算子导致 crash。本次用 vLLM 0.24.0 + FlagGems 5.3.4.post1 重试。

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=3,4,7,8
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
model_name=TinyR1-32B-Preview
mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} --dtype bfloat16 \
  --tensor-parallel-size 4 --gpu-memory-utilization 0.9 \
  --port 8001 --attention-backend TRITON_ATTN \
  --enforce-eager --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log
```

> **注意**：TinyR1-32B-Preview 基于 Qwen2.5-32B（标准 GQA），使用 `TRITON_ATTN`，**不是** `TRITON_MLA`。
> 用 `TRITON_MLA` 会 crash：`MLACommonImpl.__init__() missing 7 required positional arguments`。

若仍 crash，抓栈后补充黑名单：
```bash
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,<崩溃算子>
```

| 迭代 | 黑名单补充 | 结果 | 备注 |
|------|----------|------|------|
| 第1次 | 无（sort,sort_stable 基础黑名单） | ❌ GPQA 58.0%（50题，NV 64.0%，↓9.38%） | TRITON_ATTN，TP=4，GPUs 3,4,7,8，port 8001；2026-09-17 启动，18:53 评测完成；fast_gpqa.py detect_runaway bug crash，分数从 evalscope 报告 `outputs/gpqa_diamond/20260917_075834` 恢复 |

## Step 4：评测

TinyR1 为 thinking 模型，GPQA 50 题可能数小时。

```bash
docker exec -it eval-scope bash
cd /workspace/release_评测标准
model_name=TinyR1-32B-Preview
python3 fast_gpqa.py --model-name ${model_name} --api-base http://127.0.0.1:8000/v1 \
  --output /models/release_run_logs/${model_name}/gpqa.json
python3 accuracy_compare.py --v2 /models/release_run_logs/${model_name}/gpqa.json \
  --nv-baseline ${model_name} --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict.json
```

| 迭代 | 黑名单 | GPQA | 退出码 | 备注 |
|------|--------|------|--------|------|
| 第1次 | sort,sort_stable | 58.0%（50题） | 1（↓9.38%） | TP=4，TRITON_ATTN，port 8001；1 轮 runaway（iter1 记录） |
| 第2次 | sort,sort_stable,**mm,addmm** | **58.0%**（50题） | 1（↓9.38%） | **与 iter1 完全相同**；6 条 runaway；耗时 184m47s |

## 现象

- iter1（vLLM 0.24.0，sort,sort_stable 黑名单，TRITON_ATTN，TP=4，GPUs 3,4,7,8，port 8001）：
  - 服务正常启动，原报告无镜像产出的问题已由新镜像解决。
  - 评测于 2026-09-17 启动，18:53 跑完（50题，耗时 181m 47s）。
  - fast_gpqa.py 因 thinking 模型 list content 触发 detect_runaway AttributeError 崩溃，score 字段未写出。
  - 从 evalscope 报告 `outputs/gpqa_diamond/20260917_075834/reports/TinyR1-32B-Preview/gpqa_diamond.json` 恢复：`score=0.58` → **58.0%**，50题全部 succeeded。
  - 性能数据：mean TTFT=6378ms，avg_output_tps=4.98 tok/s（32B TP=4，思维链模型，平均输出 11250 tokens/题，属正常区间）。
- iter2（追加 `mm,addmm`，其余不变，GPUs 3,4,7,8，TP=4，port 8001）：
  - 评测于 2026-09-18 跑完，耗时 184m47s（11087s）。
  - `fast_gpqa` 同样写出 `score=null`；从 evalscope 报告 `outputs/gpqa_diamond/20260918_055922` 恢复 `score=0.58` → **58.0%**，50 题。
  - **与 iter1 分数完全相同**，`mm,addmm` 黑名单对该模型无效。
  - 输出长度：中位 7193 / 均值 11003 / 最大 32768 tokens，**8 题撞 32768 上限**。
  - runaway **6/50**（index 37、44、45、46、47、48，全部 `finish_reason=max_tokens`）。

## 定位

- vLLM 0.24.0 解决了原服务启动失败问题，服务正常起来。
- sort,sort_stable 基础黑名单下精度 58.0%，NV 基线 64.0%，相对退化 9.38%，超出 5% 容差。
- **iter2 证明 `mm,addmm` 黑名单路线无效**——两轮分数一位小数都没动（58.0% = 58.0%），
  与 NeuralDaredevil-8B 的教训一致（`mm`/`addmm` 对这类模型不可黑名单化）。
- 真实原因指向**采样配置**，见下方专项调查。

## 处置

iter1/iter2 均不达标（58.0% vs 64.0%）。黑名单路径已排查完毕（`sort,sort_stable` 必需；
`mm,addmm` 无效）。**根因调查见下方「专项调查」章节**，待决策是否按复查结论重跑。

当前结论：**结果记录，待决策**。

## 结果

- 修复后 GPQA 正确率：**58.0%**（50题，iter1/iter2 相同；从 evalscope 报告恢复）
- NV 基线：**64.0%**
- 相对退化：↓9.38%（超 5% 容差）
- 达标判定：**❌ 不达标**（两轮均不达标）

---

# 专项调查：TinyR1 的采样配置疑似错误（2026-09-18）

> 本节为**复盘用**，记录一次尚未闭环的根因调查。结论尚未执行，供后续接手者快速进入状态。

## 触发

iter2 分数与 iter1 **完全相同**（58.0% = 58.0%），且复读题集中在连续 index（44–48），
怀疑问题不在算子侧，转而检查采样配置。

## 发现一：TinyR1 没有 `generation_config.json`

同批次模型目录对比：

| 模型 | `generation_config.json` 中的 temperature |
|------|:---:|
| QwQ-32B | 0.6 |
| Qwen3-30B-A3B-Thinking-2507 | 0.6 |
| OpenThinker-7B | 0.7 |
| Marco-o1 | 0.7 |
| **TinyR1-32B-Preview** | **（文件不存在）** |
| Phi-4-mini-reasoning | 有文件，但只有 `_from_model_config` + token ids，无 temperature |
| Qwen3.5-27B-Distilled | （文件不存在） |

## 发现二：它是 thinking 模型，但被按 standard 评测

三条独立证据证明 TinyR1 是推理模型：

1. **README 原文**（`TinyR1_32B_Preview.pdf` 同目录的 `README.md` 第 24 行）：
   *"We introduce our first-generation **reasoning** model, Tiny-R1-32B-Preview"*
2. **chat_template 主动注入 `<think>`**：
   `{% if add_generation_prompt and not ns.is_tool %}{{'<｜Assistant｜><think>\n'}}{% endif %}`
   —— 模板替模型开启思考块，这是 thinking 模型的标志性写法。
3. **chat_template 会剥离 `</think>`**：`{% if '</think>' in content %}{% set content = content.split('</think>')[-1] %}`

**README 第 112 行明确给出采样建议，且警告了后果：**

> "Incorrect parameter configurations may result in **repetitive output loops**, similar to R1.
> We recommend setting the **temperature to 0.6 and top-p to 0.95**, in line with R1's configuration."

**但 `fast_gpqa.detect_thinking("TinyR1-32B-Preview")` 返回 `False`：**

```python
THINKING_PATTERNS = ['qwen3', 'qwq', 'deepseek-r1', 'deepseek-r2', 'mimo', 'hunyuan']
```

模式表匹配的是完整子串 `"deepseek-r1"`，而 `"tinyr1"` **不含**它（`tinyr1` vs `deepseek-r1`）。
于是走 standard 分支，得到 **`temperature=0.0`（贪心）+ `top_p=1.0`** ——
**正是 README 警告会引发复读的那个配置。**

## 发现三：读 generation_config 的机制在本环境下失效

`fast_gpqa.resolve_gen_params()` 设计上会读模型目录的 `generation_config.json` 覆盖采样参数，
但 `_resolve_model_dir()` 只有两条获取路径，**在本环境下两条都不通**：

| 路径 | 代码 | 实际情况 |
|------|------|---------|
| 1. `model_path` 本身是目录 | `if model_path and _os.path.isdir(model_path)` | 实际传的是模型**名**（`TinyR1-32B-Preview`），不是路径 ❌ |
| 2. 读 `/flagos-workspace/shared/context.yaml` | `ctx["model"]["local_path"]` | **该文件不存在** ❌ |

**反例验证**（决定性）：OpenThinker-7B 的 `generation_config.json` 写着 `temperature: 0.7`，
但其评测日志记录的是——

```
模式: standard (temperature=0.0, max_tokens=24576)
```

Marco-o1 同样（配置 0.7，实际 0.0）。**证明该覆盖机制对所有模型都未生效**，
TinyR1 即便补上 `generation_config.json` 也不会被读取。

> ⚠️ **影响范围不止 TinyR1**：OpenThinker-7B、Marco-o1 同样被以 0.0 评测（应为 0.7）。
> 二者目前"达标"（一个在容差内、一个走噪声容忍），但属侥幸，其达标结论同样建立在不匹配的采样上。

## 发现四：后果与证据吻合

逐题核对 iter2 的判定（数据源 `outputs/gpqa_diamond/20260918_055922/reviews/`，
字段 `sample_score.score.value.accuracy`）：

```
全部          : 29/50 = 58.0%
复读 6 题     : 1/6 正确   (index 37 对；44,45,46,47,48 全错)
排除复读后    : 28/44 = 63.6%    ← NV 基线 64.0%
```

**排除复读题后为 63.6%，基本等于 NV 基线 64.0%。** 即 6 个百分点的差距几乎全部由复读造成，
而贪心解码正是 README 指出的复读诱因。**TinyR1 的真实能力可能本就达标。**

## 待决策的修复方案

| 方案 | 做法 | 代价 |
|------|------|------|
| **A. 建 `context.yaml`** | 写 `/flagos-workspace/shared/context.yaml`，含 `model.container_path` + `thinking_model: true` | 用 harness 自带机制；但会**同时改变所有模型**的采样（OpenThinker/Marco-o1 的 0.0→0.7），破坏与已有结果的可比性 |
| **B. 显式指定（推荐）** | 仿 `force_conc.py` 写 wrapper，覆盖 `resolve_gen_params` 返回 `temperature=0.6, top_p=0.95` | 只影响 TinyR1；属绕过脚本 |
| **C. 不动** | 接受 58.0%，记为不达标 | 但这等于拿贪心解码分数比 NV 的采样解码基线，**口径不对等** |

**建议 B**：只改 TinyR1、采用官方推荐参数、不污染其他模型。

**重跑前还应做**：抓 index 44–48 的原始输出，确认是纯复读而非其他退化模式。

## 本轮未做的事（接手者注意）

- ❌ 未生成 verdict（`score=null` 解析 bug，需从报告重建后跑 `accuracy_compare`）
- ❌ 未执行上述任何修复方案
- ❌ 未抓复读题原文

## 提炼到 KNOWLEDGE 的条目

1. **`detect_thinking()` 靠模型名子串匹配**（`qwen3/qwq/deepseek-r1/deepseek-r2/mimo/hunyuan`），
   名字不含这些关键词的推理模型（`TinyR1-32B-Preview`、`Phi-4-mini-reasoning`、
   `OpenReasoning-Nemotron-1.5B`）会被判成 standard，拿到 `temperature=0.0` 贪心解码。
   对 R1 系蒸馏模型，贪心解码会显著加剧复读（模型方 README 已警告）。
2. **`resolve_gen_params()` 的 `generation_config.json` 覆盖机制在本环境失效**——
   `_resolve_model_dir()` 依赖 `--model-name` 传路径或 `context.yaml`，二者都不满足。
   已用 OpenThinker-7B / Marco-o1（配置 0.7、实际 0.0）反例验证。
3. **判读推理模型分数前，先核对实际采样参数**：贪心解码下的低分可能是复读 artifact 而非真实退化。
   扣掉 runaway 题后的分数（本例 58.0% → 63.6%）更能反映真实能力。
