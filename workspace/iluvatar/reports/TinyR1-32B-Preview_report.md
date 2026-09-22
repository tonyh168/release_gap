# iluvatar/TinyR1-32B-Preview 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_TinyR1-32B-Preview_202608271844.md
- **原始失败类型**：服务启动失败（无镜像产出，全部评测数据为空）
- **日期**：2026-09-18

## 现象

原始失败报告（vLLM 0.20.2 + FlagGems 5.0.0）：服务在所有版本下均无法启动，未产出可评测服务，
3 个 issue 提交（crash + accuracy + performance degradation）。V2/V3 均有 32 算子白名单
（add, addmm, cat, cos, embedding, flash_attn_varlen_func 等，与 Fathom-R1-14B 相同），
但服务仍未成功起来，说明另有未实现算子导致 crash。

本次在新镜像（vLLM 0.24.0 + FlagGems 5.3.4.post1）上复现，三轮实测：

- **iter1**（09-17，`sort,sort_stable` 黑名单，`TRITON_ATTN`，TP=4，端口 8001）：
  - 服务正常启动，原报告无镜像产出的问题已由新镜像解决
  - 耗时 181m47s，29/50 = **58.0%**
  - `fast_gpqa.py` 收尾"解析失败"，`score` 为 null；从报告 `outputs/gpqa_diamond/20260917_075834` 恢复
  - runaway **7/50**（index 18、37、42、45、46、47、48，全部 `finish_reason=max_tokens`）
  - 输出长度：中位 7548 / 均值 11251 / 最大 32768，8 题撞顶
  - mean TTFT=6378ms，avg_output_tps=4.98 tok/s（32B TP=4，思维链模型，平均输出 11250 tokens/题）
- **iter2**（09-18，追加 `mm,addmm`，其余不变）：
  - 耗时 184m47s，29/50 = **58.0%**（**与 iter1 完全相同，一位小数都没动**）
  - **`mm,addmm` 黑名单对该模型无效** —— 与 NeuralDaredevil-8B 的教训一致
  - runaway **6/50**（index 37、44、45、46、47、48）；输出中位 7193 / 均值 11003 / 最大 32768，8 题撞顶
- **iter3**（09-18 17:58–20:04，同一服务，仅改评测侧参数：thinking + T=0.6/top_p=0.95）：
  - 耗时 125m15s（150.3 s/题，比 iter2 的 221.7 s/题快 32%），31/50 = **62.0%**
  - runaway 降到 **2/50**（index 45、48）
  - 输出长度：中位 6547 / 均值 8989，**9 题撞 20000 上限**（比 iter1/iter2 的 8 题更多）
  - 收尾崩在 `fast_gpqa.py:370` `AttributeError: 'list' object has no attribute 'strip'`，
    `score` 未写出 → 从报告 `outputs/gpqa_diamond/20260918_095855` 恢复

> 时间戳说明：evalscope 内部日志用 UTC，文件名/文件 mtime 用 CST，相差 8 小时
> （如 iter3 报告目录 `20260918_095855` = 09-18 17:58 CST）。
> 分数来源：iter1/iter2/iter3 **均未由 `fast_gpqa.py` 写出 score**（iter1/iter2 是收尾"解析失败"，
> iter3 是 `detect_runaway` 对 list content 崩溃），三轮分数都是从 evalscope 原始报告
> `outputs/gpqa_diamond/<ts>/reports/TinyR1-32B-Preview/gpqa_diamond.json` 的 `metrics[0].score` 恢复的。
> 只有 iter3 补跑生成了正式 verdict（`verdict_gpqa_iter3.json`）；iter1/iter2 的"↓9.38%"是手工算的，
> 未生成 verdict 文件。

## 定位

- **vLLM 0.24.0 解决了原服务启动失败问题**，服务三轮均正常、从未因算子 crash 中断
- iter2 证明 **`mm,addmm` 黑名单路线无效** —— 两轮分数一位小数都没动（58.0% = 58.0%）
- 真实原因是**评测侧的采样配置**：TinyR1 是 thinking 模型，却被 `fast_gpqa.detect_thinking()`
  判成 standard，拿到 **`temperature=0.0`（贪心）+ `top_p=1.0`** —— 正是模型 README 警告会引发复读的配置

### 专项调查：`detect_thinking()` 误判（已闭环）

**发现一：TinyR1 没有 `generation_config.json`**。同批次模型目录对比：

| 模型 | `generation_config.json` 中的 temperature |
|------|:---:|
| QwQ-32B | 0.6 |
| Qwen3-30B-A3B-Thinking-2507 | 0.6 |
| OpenThinker-7B | 0.7 |
| Marco-o1 | 0.7 |
| **TinyR1-32B-Preview** | **（文件不存在）** |
| Phi-4-mini-reasoning | 有文件，但只有 `_from_model_config` + token ids，无 temperature |
| Qwen3.5-27B-Distilled | （文件不存在） |

**发现二：它是 thinking 模型，但被按 standard 评测**。三条独立证据：

1. **README 原文**（`TinyR1_32B_Preview.pdf` 同目录的 `README.md` 第 24 行）：
   *"We introduce our first-generation **reasoning** model, Tiny-R1-32B-Preview"*
2. **chat_template 主动注入 `<think>`**：
   `{% if add_generation_prompt and not ns.is_tool %}{{'<｜Assistant｜><think>\n'}}{% endif %}`
3. **chat_template 会剥离 `</think>`**：`{% if '</think>' in content %}{% set content = content.split('</think>')[-1] %}`

README 第 112 行明确给出采样建议并警告后果：

> "Incorrect parameter configurations may result in **repetitive output loops**, similar to R1.
> We recommend setting the **temperature to 0.6 and top-p to 0.95**, in line with R1's configuration."

但 `fast_gpqa.detect_thinking("TinyR1-32B-Preview")` 返回 `False`：

```python
THINKING_PATTERNS = ['qwen3', 'qwq', 'deepseek-r1', 'deepseek-r2', 'mimo', 'hunyuan']
```

模式表匹配的是完整子串 `"deepseek-r1"`，而 `"tinyr1"` **不含**它。于是走 standard 分支，
得到 `temperature=0.0`（贪心）+ `top_p=1.0`。

**发现三：读 generation_config 的机制在本环境下失效**。`fast_gpqa.resolve_gen_params()` 设计上会读
模型目录的 `generation_config.json`，但 `_resolve_model_dir()` 只有两条获取路径，**本环境下两条都不通**：

| 路径 | 代码 | 实际情况 |
|------|------|---------|
| 1. `model_path` 本身是目录 | `if model_path and _os.path.isdir(model_path)` | 实际传的是模型**名**，不是路径 ❌ |
| 2. 读 `/flagos-workspace/shared/context.yaml` | `ctx["model"]["local_path"]` | **该文件不存在** ❌ |

**反例验证（决定性）**：OpenThinker-7B 的 `generation_config.json` 写着 `temperature: 0.7`，
但其评测日志记录的是 `模式: standard (temperature=0.0, max_tokens=24576)`；Marco-o1 同样
（配置 0.7，实际 0.0）。**证明该覆盖机制对所有模型都未生效**，TinyR1 即便补上
`generation_config.json` 也不会被读取。

> ⚠️ **影响范围不止 TinyR1**：OpenThinker-7B、Marco-o1 同样被以 0.0 评测（应为 0.7）。
> 二者目前"达标"（一个在容差内、一个走噪声容忍），但**属侥幸**，其达标结论同样建立在不匹配的采样上。

**发现四：后果与证据吻合**。逐题核对 iter2 的判定（数据源
`outputs/gpqa_diamond/20260918_055922/reviews/`，字段 `sample_score.score.value.accuracy`）：

```
all              : 29/50 = 58.0%
runaway (6 items): 1/6 correct   (index 37 correct; 44,45,46,47,48 all wrong)
excluding runaway: 28/44 = 63.6%   <- NV baseline 64.0%
```

**排除复读题后为 63.6%，基本等于 NV 基线 64.0%。**

## 处置

### 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-tinyr1-32b-preview` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/TinyR1-32B-Preview` |
| 卡号 / 端口 | GPU 3,4,7,8（TP=4）/ 8001 |
| attention-backend | `TRITON_ATTN`（Qwen2.5-32B 标准 GQA，非 MLA） |
| 实际 vLLM 版本 | 0.24.0（FlagGems 5.3.4.post1） |
| 权重来源 | `360zhinao/TinyR1-32B-Preview`（ModelScope） |

> 注：原失败报告中写的 `qihoo360/TinyR1-32B-Preview` 为错误路径（404），实际路径为 `360zhinao/TinyR1-32B-Preview`。

### 起容器（宿主机执行）

```bash
docker run -itd --name flagrelease-fix-tinyr1-32b-preview \
  --device=/dev/iluvatar \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907 bash
docker exec -it flagrelease-fix-tinyr1-32b-preview bash
ixsmi && python -c "import vllm; print(vllm.__version__)"
```

### 起 vLLM 服务（容器内执行，iter2/iter3 配置，最终达标）

原报告 V2/V3 有 32 算子白名单但服务仍未起来，说明另有未实现算子导致 crash；
新镜像（vLLM 0.24.0）下服务正常，**从未因算子 crash 中断**。

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,mm,addmm
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
vllm serve /models/flagrelease/fixes_models/TinyR1-32B-Preview \
  --served-model-name TinyR1-32B-Preview --dtype bfloat16 \
  --tensor-parallel-size 4 --gpu-memory-utilization 0.9 \
  --port 8001 --attention-backend TRITON_ATTN \
  --enforce-eager --trust-remote-code
```

> **注意**：TinyR1-32B-Preview 基于 Qwen2.5-32B（标准 GQA），使用 `TRITON_ATTN`，**不是** `TRITON_MLA`。
> 用 `TRITON_MLA` 会 crash：`MLACommonImpl.__init__() missing 7 required positional arguments`。

**实际只起了两次服务，第一次即成功启动**（`TRITON_MLA` 那次是走错分支的尝试）：

| 服务实例 | 启动时间(CST) | attention-backend | 黑名单 | 服务对象 |
|---------|--------------|------------------|--------|---------|
| #1 | 09-17 15:48:43 | TRITON_ATTN | sort,sort_stable | iter1 |
| #2 | 09-18 13:45:48 | TRITON_ATTN | sort,sort_stable,**mm,addmm** | iter2 + iter3（**未重启，两个迭代共用同一进程**） |

> **服务侧从未因算子 crash 中断** —— 原报告的"服务启动失败"由新镜像（vLLM 0.24.0）解决。
> 后续三轮的差异全部来自评测侧配置，与算子黑名单无关。

### 迭代记录

| 迭代 | 评测时间(CST) | 黑名单 | mode / 采样 | max_tokens | GPQA | runaway | 判定 |
|------|--------------|--------|------------|:----------:|:----:|:-------:|------|
| iter1 | 09-17 15:58 → 18:53 | sort,sort_stable | standard (T=**0.0**, top_p=1.0) | 32768 | 58.0% (29/50) | 7/50 | ❌ 不达标 |
| iter2 | 09-18 13:52 → 16:57 | +mm,addmm | standard (T=**0.0**, top_p=1.0) | 32768 | **58.0%** (29/50) | 6/50 | ❌ 不达标（与 iter1 完全相同） |
| iter3 | 09-18 17:58 → 20:04 | +mm,addmm | **thinking (T=0.6, top_p=0.95)** | 20000 | **62.0% (31/50)** | **2/50** | ✅ **exit=0 / aligned=true** |

### 评测（eval-scope 容器内执行）

```bash
/workspace/eval_scripts/fast_gpqa.py \
  --model-name TinyR1-32B-Preview --api-base http://127.0.0.1:8001/v1 \
  --output /models/release_run_logs/TinyR1-32B-Preview/gpqa.json

/workspace/eval_scripts/accuracy_compare.py \
  --v2 /models/release_run_logs/TinyR1-32B-Preview/gpqa_iter3_thinking.json \
  --nv-baseline TinyR1-32B-Preview \
  --nv-baseline-file /workspace/eval_scripts/nv_baseline.yaml --json \
  --output /models/release_run_logs/TinyR1-32B-Preview/verdict_gpqa_iter3.json
```

### iter3 的 wrapper（`/tmp/tinyr1_thinking.py`，不改 `fast_gpqa.py` 本体）

按专项调查的方案 B 执行（**已闭环**）：

1. 写 wrapper `tinyr1_thinking.py`，monkeypatch `detect_thinking→True` + `resolve_gen_params→0.6/0.95`；
   **不改 `fast_gpqa.py` 本体**（同一容器还有其他评测在跑，避免污染）
2. iter3 复评（09-18 17:58 启动，20:04 完成）→ **62.0%**，runaway 6→2
3. 从 evalscope 报告重建 result JSON（`gpqa_iter3_thinking.json`，`score=62.0`）→ 跑 `accuracy_compare`
   → `verdict_gpqa_iter3.json`，**exit=0 / aligned=true / rel_drop=3.12%**

```python
import sys
sys.path.insert(0, "/workspace/eval_scripts")
MODEL, PORT = "TinyR1-32B-Preview", "8001"
OUT = "/models/release_run_logs/TinyR1-32B-Preview/gpqa_iter3_thinking.json"
sys.argv = ["fast_gpqa.py", "--model-name", MODEL,
            "--api-base", f"http://127.0.0.1:{PORT}/v1",
            "--dataset", "gpqa_diamond", "--output", OUT]
import fast_gpqa

fast_gpqa.detect_thinking = lambda model_name: True

_orig = fast_gpqa.resolve_gen_params
def _forced(is_thinking, max_tokens, model_path=None):
    cfg = _orig(is_thinking, max_tokens, model_path=model_path)
    cfg["temperature"] = 0.6
    cfg["top_p"] = 0.95
    return cfg
fast_gpqa.resolve_gen_params = _forced

fast_gpqa.main()
```

启动方式（`docker exec -d`，SSH 断开不影响）：

```bash
docker exec -d eval-scope bash -c "python3 /tmp/tinyr1_thinking.py"
```

### 评测参数的影响（iter1 → iter3 量化对照）

iter1/iter2/iter3 **服务端配置完全一致**（同一黑名单、同一 `TRITON_ATTN`、TP=4、同一进程复用），
三轮之间唯一的变量是**评测侧参数**：

| 参数 | iter1 | iter2 | iter3 | 变化来源 |
|------|:-----:|:-----:|:-----:|---------|
| mode | standard | standard | **thinking** | wrapper `detect_thinking→True` |
| temperature | 0.0（贪心） | 0.0（贪心） | **0.6** | wrapper `resolve_gen_params` |
| top_p | 1.0 | 1.0 | **0.95** | 同上 |
| max_tokens | 32768 | 32768 | **20000** | ⚠️ thinking 分支**连带**结果 |
| 评分前过滤器 | — | — | **`remove_until: "</think>"`** | ⚠️ thinking 分支**连带**结果 |
| 算子黑名单 | sort,sort_stable | +mm,addmm | +mm,addmm | — |

> ⚠️ **两个容易忽略的连带变化**：`is_thinking=True` 不只改采样温度，它同时把 `max_tokens`
> 走 thinking 公式 `min(max(131072-8192, 8192), 20000) = 20000`（**从 32768 降到 20000**），
> 并给 evalscope 加 `remove_until='</think>'` 过滤器。因此 iter3 与 iter1/iter2 之间有 **3 个**
> 参数差异，其中 1 个（采样）是修复目标，另外 2 个是 mode 切换的副作用，方向一正一负，
> **不可全部归因于采样**。

| 指标 | iter1 | iter2 | iter3 |
|------|:-----:|:-----:|:-----:|
| 分数（全部 50 题） | 58.0% (29/50) | 58.0% (29/50) | **62.0% (31/50)** |
| runaway 复读题 | 7/50 | 6/50 | **2/50** |
| 排除 runaway 后 | 65.1% (28/43) | 63.6% (28/44) | 64.6% (31/48) |
| 输出 tokens 中位 / 均值 | 7548 / 11251 | 7193 / 11003 | **6547 / 8989** |
| 撞 max_tokens 上限题数 | 8（@32768） | 8（@32768） | **9（@20000）** |
| 撞顶题中答对数 | 0/8 | 1/8 | 1/9 |
| 耗时 | 181m47s | 184m47s | **125m15s** |
| s/题 | 218.1 | 221.7 | **150.3** |
| verdict | 未生成 | 未生成 | ✅ exit=0 |

**读法**：三轮"排除 runaway 后"的分数分别是 65.1% / 63.6% / 64.6%，**都贴着 NV 基线 64.0%** ——
这从三个独立样本印证了「TinyR1 的真实能力在本平台与 NV 基线持平，差额主要是复读造成的」。
采样修正把"全部题分数"从 58.0% 抬到**接近其真实水平**的 62.0%（↓3.12%，达标的直接原因）。

**逐题归因：+4pt 不是"复读题变对了"**（50 题，每题 2%）：

```
iter2 wrong -> iter3 correct (5 items): 8, 18, 21, 27, 35   <- 0 of them were iter2 runaway items
iter2 correct -> iter3 wrong (3 items): 0, 25, 37
net +2 items = +4pt
```

iter2 的 6 道 runaway 题在 iter3 的表现：

| index | iter2 | iter3 | 说明 |
|:-----:|-------|-------|------|
| 37 | 对（32768 撞顶） | **错**（20000 撞顶） | 复读消失但答案变错 |
| 44 | 错（32768 撞顶，复读） | 错（20000 撞顶，**不再复读**） | — |
| 45 | 错（32768 撞顶，复读） | 错（20000 撞顶，**仍复读**） | — |
| 46 | 错（32768 撞顶，复读） | 错（20000 撞顶，**不再复读**） | — |
| 47 | 错（32768 撞顶，复读） | 错（20000 撞顶，**不再复读**） | — |
| 48 | 错（32768 撞顶，复读） | 错（20000 撞顶，**仍复读**） | — |

**结论：复读被压到 2/50，但那 6 道题的答案在 iter3 依然全错** —— 它们失分的主因不是复读，
而是**模型在这个上下文预算内根本做不完**（全部撞 max_tokens 上限）。这也是为什么
"排除 runaway 后"三轮分数几乎不变（65.1 / 63.6 / 64.6）：复读只解释了分数的**一部分**偏差，
残余偏差来自截断。

### 残留不确定性：62.0% 仍是"上限受限"的低估值

iter3 **9/50 题撞 20000 上限，其中 8 题答错**（iter2 是 8 题撞 32768、7 题错）。由于 thinking 分支
把 max_tokens 从 32768 **收紧到 20000**，iter3 的截断面**反而更大**，所以：

- 62.0% 可视为 **TinyR1 在本平台的保守下界**，真实值应 ≥ 62.0%，且已足够达标（↓3.12% < 5%）
- 若要更干净的口径，可再用 **`max_tokens=32768` + `0.6/0.95`** 跑一轮
  （在 wrapper 里把 `resolve_gen_params` 返回的 `cfg["max_tokens"]` 也一并覆写成 32768 即可）。
  **非必需** —— 不改变达标结论，但能同时消除"采样"与"截断"两个混淆项
- **绝对不要把 iter1/iter2 的 58.0% 与 NV 的 64.0% 直接比**：那是贪心解码的分数，
  口径与 NV 基线（模型推荐采样）不对等

### 对 harness 的修复建议（未做，属脚本层改动，需评审）

本轮用的是 wrapper 绕过，`fast_gpqa.py` 本体**未改**。根治需要两处：

1. **`detect_thinking()` 的模式表**：`tinyr1` / `mirothinker` / `openreasoning` /
   `phi-4-mini-reasoning` 这类名字不含关键词的推理模型会被判成 standard。仅加名字解决不了通用问题，
   建议改为读 chat_template（含 `<think>` 注入）+ README / `generation_config.json` 提示
2. **`_resolve_model_dir()`**：`--model-name` 传名字时无法定位模型目录，`context.yaml` 又不存在，
   导致 `generation_config.json` 覆盖机制整体失效。建议支持 `--model-path` 显式传入

> ⚠️ **改本体前务必知悉**：`resolve_gen_params` 一旦真正生效，会**同时改变所有模型**的采样
> （OpenThinker-7B / Marco-o1 的 0.0→0.7），使已出分数的可比性被破坏，需连带复核这两个模型的
> "达标"结论。

### 本轮未做的事（接手者注意）

- ❌ iter3 未跑 `max_tokens=32768` 的对照轮（62.0% 已达标，故未追加）
- ❌ 未修改 `fast_gpqa.py` 本体（仅 wrapper 绕过，见上方建议）
- ❌ 未复核 OpenThinker-7B / Marco-o1 在正确采样（0.7）下的结论

## 结果

- 修复后分 / NV 基线：**GPQA 62.0%**（50 题，iter3，从 evalscope 报告恢复）/ NV **64.0%**
- 达标判定（accuracy_compare 退出码）：**0（达标）** —— 相对退化 **↓3.12%**（容差 5%，
  未触发噪声兜底，`noise_zone=false`）

**verdict_gpqa_iter3.json**（最终达标那一份实测字段）：

- `model`: TinyR1-32B-Preview；`metric`: gpqa_diamond
- `nv.score`: 64.0；`current.score`: 62.0（`mode: thinking`）
- `rel_drop_pct`: **3.12**；`aligned`: **true**；`noise_zone`: **false**；进程退出码：**0**

> 源 fix 日志记录了上述实测字段与退出码，但未附 JSON 原文，故此处不复刻 JSON 文本（避免编造）。

## 提炼到 KNOWLEDGE 的条目

1. **`detect_thinking()` 靠模型名子串匹配**（`qwen3/qwq/deepseek-r1/deepseek-r2/mimo/hunyuan`），
   名字不含这些关键词的推理模型（`TinyR1-32B-Preview`、`Phi-4-mini-reasoning`、
   `OpenReasoning-Nemotron-1.5B`、`MiroThinker-v1.5-30B`）会被判成 standard，
   拿到 `temperature=0.0` 贪心解码。对 R1 系蒸馏模型，贪心解码会显著加剧复读（模型方 README 已警告）。
2. **`resolve_gen_params()` 的 `generation_config.json` 覆盖机制在本环境失效** ——
   `_resolve_model_dir()` 依赖 `--model-name` 传路径或 `context.yaml`，二者都不满足。
   已用 OpenThinker-7B / Marco-o1（配置 0.7、实际 0.0）反例验证。
3. **判读推理模型分数前，先核对实际采样参数**：贪心解码下的低分可能是复读 artifact 而非真实退化。
   TinyR1 实测：贪心 58.0% → 正确采样 62.0%（↓3.12%，达标），runaway 6→2。
4. **切 `thinking` 模式会连带改两个别的参数**：`max_tokens` 走 thinking 公式被压到 20000
   （从 32768 收紧）、评分前加 `remove_until='</think>'` 过滤器。做对照实验时必须把这两个一并列入变量，
   否则会把"上限收紧"的负面影响误记到采样改动上。
5. **"排除 runaway 后的分数"比"runaway 计数"更能定位问题**：TinyR1 三轮排除后都 ≈64%（基线），
   说明复读确实压低了分数；但 iter3 复读归零后那 6 题**仍然全错**，说明还有一层**截断**失分
   （9/50 撞顶），需分开归因。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: 360zhinao/TinyR1-32B-Preview
# IMAGE: harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
# HARBOR_VER: V3
# GPU: Iluvatar BI-V150, 4 × 32GB
# TP: 4
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 64.0
# SCORE_FLAGOS: 62.0
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
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,mm,addmm
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
vllm serve /models/flagrelease/fixes_models/TinyR1-32B-Preview \
  --served-model-name TinyR1-32B-Preview --dtype bfloat16 \
  --tensor-parallel-size 4 --gpu-memory-utilization 0.9 \
  --port 8001 --attention-backend TRITON_ATTN \
  --enforce-eager --trust-remote-code
```
