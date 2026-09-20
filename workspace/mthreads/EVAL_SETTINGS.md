# Mthreads 评测设置（四模型定稿）

> 更新：2026-09-20 | 依据：**metax / iluvatar / t-head 同名或同架构模型修复成功（或已定位）案例**横比得出
> 配套：[[SOP]] 第 4 节、`_shared/EVAL.md`、`_shared/KNOWLEDGE.md`

---

## ⭐ 评测参数总表（温度 / top_p / is-think）

> 下表是 `fast_gpqa.py` 在补好 `context.yaml` 后**实际会用到**的参数，
> 由 `resolve_gen_params()`（thinking 默认 → 模型 `generation_config.json` 覆盖）与
> `auto_max_tokens()`（按服务端 `max_model_len` 反算）共同决定。
> **`is-think` 一列**：脚本的 `THINKING_PATTERNS` 是按模型名做**子串匹配**，命中即自动按 thinking 评测。

| 模型 | 端口 | **temperature** | **top_p** | **top_k** | **is-think** | max_tokens | 服务 max_model_len | 参数来源 |
|------|:----:|:---------------:|:---------:|:---------:|:------------:|:----------:|:-----------------:|----------|
| Phi-4-reasoning-plus | 8000 | **0.8** | **0.95** | **50** | ✅ 是<br>（❌ 名字未命中，**须 context.yaml**） | 20000 | 32768 | 模型的 `generation_config.json` |
| LFM2.5-1.2B-Thinking | 8001 | **0.6** | **0.95** | 未设<br>（服务默认） | ✅ 是<br>（❌ 名字未命中，**须 context.yaml**） | 20000 | 32768 | thinking 默认值<br>（模型 gc 无采样字段） |
| reka-flash-3 | 8002 | **0.6** | **0.95** | **1024** | ✅ 是<br>（❌ 名字未命中，**须 context.yaml**） | 16384 | **24576** | 模型的 `generation_config.json` |
| Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled | 8003 | **0.6** | **0.95** | 未设<br>（服务默认） | ✅ 是<br>（✅ 名字含 `qwen3`，**自动命中**） | 20000 | 32768 | thinking 默认值<br>（**无** gc 文件） |

**表格说明**

- **is-think 全部为「是」**：4 个模型实测输出都带显式推理标签
  （Phi-4-reasoning-plus / LFM2.5 → `<think>`；reka-flash-3 → `<reasoning>`；Qwen3.5 → `</think>`）。
- **只有 Qwen3.5 会被自动识别**（模型名含 `qwen3`，命中 `THINKING_PATTERNS`）；
  **另外 3 个名字都不含关键词，必须靠 `context.yaml` 的 `thinking_model: true`**，
  否则会按普通模型贪心 `temperature=0.0` 评测（metax/reka-flash-3 就是栽在这）。
- **`max_tokens` 由服务端 `max_model_len` 反算**：thinking 走 `max(max_model_len-8192, 8192)` 再
  cap 到 `THINKING_MAX_TOKENS_CAP=20000`。所以 reka-flash-3 把 `max-model-len` 定为 **24576**
  才能得到 **16384**（对齐 metax v6 / NV 复现口径）；若用 32768 会得到 20000，口径不符。
- **top_k 的两种情形**：reka-flash-3 的 gc 显式写了 `top_k: 1024`（且服务端日志确认 vLLM 也采纳了它）；
  LFM2.5 / Qwen3.5 的 gc 没有采样字段 → 请求不带 top_k → 用服务端默认。

---

## 0. 四条与厂商无关的通用设置（**四个模型都适用**）

| # | 设置 | 值 | 依据 |
|---|------|----|------|
| 1 | **执行模式** | ⚠️ **`--enforce-eager`（摩尔必须保留，不能去）** | **2026-09-20 实测：4 个模型去掉 `--enforce-eager` 后全部启动失败**，报 `MUSA driver error: operation not permitted when stream is capturing` —— MUSA 驱动不允许 capture 期间分配显存。<br>metax「graph 160 vs eager 16 tok/s」的经验**在摩尔不适用**。曾试过退一步的「只编译不捕获」（`-cc '{"cudagraph_mode":"NONE"}'`）**能启动但比 eager 更慢**（3.95s vs 5.42s），不采用。详见 [[KNOWLEDGE]] 六 |
| 2 | **数据集** | `gpqa_diamond` | 4 个模型在 `nv_baseline.yaml` 里**都有** gpqa 基线，无需回退 mmlu/math_500 |
| 3 | **题数** | 定稿用 **`--limit 0`（全量 198 题）** | metax/reka-flash-3 教训：**前 50 题偏易、56% 不可外推**（全量 54.04%，后半段仅 53.38%）。<br>可用 50 题做快速筛查，但**判定一律以 198 题为准** |
| 4 | **评测前必查** | `grep '\[gen\]' <eval日志>` | 必须看到「**采用模型 generation_config.json 采样参数**」；若见「未定位到模型目录…沿用默认采样参数」，说明 `context.yaml` 没生效，分数不可信 |

> **并发**：`--eval-batch-size` 不传则脚本自动探测。做配置对照实验时**必须显式固定同一值**（`_shared/EVAL.md`）。
> t-head/Phi-4 验证过 `batch_size=1` 并不会提升分数（64/68/68 vs 68），低分不是并发造成的。

---

## 1. `context.yaml` 统一补法（4 个模型都要）

`fast_gpqa.py` 的模型目录定位只有两个来源：`--model-name` 是本地路径，或读
**硬编码路径** `/flagos-workspace/shared/context.yaml`。标准流程传的是 NV key，两条都不满足 → **静默退回贪心**。

```bash
docker exec <eval容器> sh -c 'mkdir -p /flagos-workspace/shared && cat > /flagos-workspace/shared/context.yaml <<EOF
model:
  local_path: /datapool/flagrelease/fixes_models/<模型名>
  container_path: /datapool/flagrelease/fixes_models/<模型名>
  thinking_model: true
EOF'
```

> ⚠️ 摩尔容器默认**没有挂 `/flagos-workspace`**，评测容器要单独 `-v` 或就地建目录。
> **换模型时必须同步改路径**，否则静默退回贪心。

---

## 2. 逐模型设置

### 2.1 Phi-4-reasoning-plus

| 项目 | 设定 | 依据 |
|------|------|------|
| thinking | ✅ **必须显式标 true** | 实测输出 `<think>`；`THINKING_PATTERNS` **不含** `phi-4-reasoning` |
| 采样参数 | **temp=0.8 / top_p=0.95 / top_k=50**（模型自带，靠 context.yaml 生效） | 模型 `generation_config.json`：`do_sample=true` |
| `max_model_len` | **32768**（模型默认值，无需改） | config `max_position_embeddings=32768` |
| `max_tokens` | 自动 = `32768-8192` = 24576 → **thinking 上限 20000 封顶** | `auto_max_tokens()` |
| 算子策略 | **白名单** `silu_and_mul,rms_norm,rotary_embedding` | 与 **t-head/phi-4 的最优最小白名单一致**（同架构：Phi-4 系、GQA 40Q/10KV） |
| NV 基线 | `gpqa_diamond = 46` → 达标下限 **43.7** | `nv_baseline.yaml` |
| ⚠️ **首要风险 / 首个 A/B** | **把 `rms_norm,silu_and_mul` 移出白名单**（即完全关掉这两个算子的 FlagGems 替换） | **metax/Phi-4-mini-instruct**（同为 **GQA**）实测：这两个算子走 FlagGems 是精度退化根因，加入黑名单后 26%→44% 达标。<br>t-head/phi-4 却把它们留在白名单里拿到最好成绩——**两家结论相反，摩尔上必须 A/B 实测** |

> **本模型没有其他厂商的同名成功案例**。最近的三个参考：metax/Phi-4-mini-instruct（GQA 精度根因）、
> t-head/phi-4（最小白名单，同架构，50 题边界波动未能稳定达标）、iluvatar/Phi-4-mini-reasoning（大幅不达标，参考价值低）。
> **所以它是最需要算子 A/B 的一个。**

### 2.2 LFM2.5-1.2B-Thinking

| 项目 | 设定 | 依据 |
|------|------|------|
| thinking | ✅ **显式标 true** | 实测 `<think>`；iluvatar 侧同为 thinking 且触发过 list-content bug |
| 采样参数 | 模型 `generation_config.json` **无采样字段** → 用 thinking 默认 **temp=0.6 / top_p=0.95** | `resolve_gen_params()` thinking 分支默认值 |
| `max_model_len` | **32768** | iluvatar 采用值（模型默认 128000，KV 够但评测无需） |
| 算子策略 | **黑名单 `sort,sort_stable` 即默认，直接达标** | ✅ **iluvatar 实测 PASS**：32.0% vs NV 29.0%（+10.34%，退出码 0） |
| NV 基线 | `gpqa_diamond = 29.0` → 下限 **27.55** | iluvatar 同基线同结果，**本模型最可能一次过** |
| ⚠️ 已知坑 | thinking 模型 `message.content` 可能是 **list** 结构，触发 `detect_runaway` 的<br>`AttributeError: 'list' object has no attribute 'strip'` → **score=null** | iluvatar 实测。**分数需从 evalscope 报告恢复**：<br>`outputs/gpqa_diamond/<时间戳>/reports/<模型名>/gpqa_diamond.json` 的 `metrics[0].score` |
| 混合 SSM | 会打 `Add 2 padding layers` 告警（KV 最多浪费 20%），**不影响正确性** | 本机服务日志实测 |

### 2.3 reka-flash-3

> **这是唯一有完整成功案例（metax，198 题全量达标）的模型**，直接照抄 metax 的最终配置。

| 项目 | 设定 | 依据 |
|------|------|------|
| thinking | ✅ **标 true** | 实测输出 `<reasoning>`；metax 未标但输出确为长推理链 |
| 采样参数 | **temp=0.6 / top_p=0.95 / top_k=1024**（模型自带，**必须靠 context.yaml 生效**） | **metax 核心修复**：采样生效后同题 +6~12pt |
| `max_model_len` | **24576** ← 关键：间接得到 `max_tokens=16384`（`24576-8192`），与 NV 复现口径一致 | metax v6 配置 |
| 执行模式 | **`--enforce-eager`**（摩尔必须保留；graph 不可用，见第 0 节 #1） | 本机实测 |
| 题数 | **198 全量**（50 题 56.00% 不可外推，全量 54.04%） | metax |
| 算子策略 | **默认黑名单**（`mm,mm_out,bmm,...` 那套）+ **采样生效** | metax 验证：v1→v6 黑名单未变，唯一变量是采样参数 |
| **判定基准** | ⚠️ **不要用 `nv_baseline.yaml` 的 59** | **metax 已裁定**：改用 **NV 原生 198 题实测 53.54%**。<br>理由：59 出自 NV 失败报告，而同报告记录 NV 硬件上 plugin-FL 同样造成 12pt 退化（60→48）——**该模型对 plugin-FL 敏感是跨平台共性** |
| ⚠️ 禁令 | **不要加 `--generation-config vllm`** | 那会主动丢弃模型采样参数，让问题更严重 |
| ⚠️ 已知坑 | `fast_gpqa` 可能 `score=null`，需从 evalscope 报告补填 | metax 多轮均如此 |

> **摩尔侧可直接复用的验证命题**：如果摩尔也出现 44~46% 这个量级的低分，**先查采样参数**，
> 别去折腾算子黑名单——metax 在这条路上浪费了 v1~v5 五轮。

### 2.4 Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled

| 项目 | 设定 | 依据 |
|------|------|------|
| thinking | ✅ **标 true** | 实测输出含 **`</think>` 闭合标签**（开标签被 chat template 吃掉），确认为推理模型 |
| 采样参数 | 模型**无** `generation_config.json` → thinking 默认 **temp=0.6 / top_p=0.95** | — |
| `max_model_len` | **32768**（mthreads 已用；受 KV 限制，见修复日志） | 256 KB/token，80GB 卡上限约 65536 |
| `max_tokens` | 24576 → thinking 上限 **20000** | `auto_max_tokens()` |
| 算子策略 | 白名单 `silu_and_mul,rms_norm,rotary_embedding`（同其余模型） | 摩尔首轮统一口径 |
| NV 基线 | `gpqa_diamond = 75` → 下限 **71.25** | `nv_baseline.yaml` |
| ⚠️ **摩尔的机会** | iluvatar 实测 **70.0%（NV 75，↓6.67%，差 2.5 题）不达标**，但它的<br>`max-model-len` **只有 8192**（受 32GB 卡限制），并被记为「必要约束」 | **摩尔单卡 80GB、可给到 32768（4 倍上下文）**，且 iluvatar 那轮有 1 个 runaway（index 22）。<br>→ **摩尔重跑值得，且要留意是否因上下文变长而改变** |
| ⚠️ 已知坑 | thinking 模型 `score=null` 同 LFM2.5，需从 evalscope 报告恢复 | iluvatar 实测 |

---

## 3. 执行清单（每模型跑评测前的固定动作）

```bash
model_name=<NV key>
port=<8000|8001|8002|8003>

# ① 服务已就绪（摩尔用 --enforce-eager，graph 不可用），确认端口可访问
curl -s http://localhost:${port}/v1/models

# ② 补 context.yaml（路径与 thinking_model 按上表）
docker exec <eval容器> sh -c 'mkdir -p /flagos-workspace/shared && cat > /flagos-workspace/shared/context.yaml <<EOF
model:
  local_path: /datapool/flagrelease/fixes_models/<模型名>
  container_path: /datapool/flagrelease/fixes_models/<模型名>
  thinking_model: true
EOF'

# ③ 跑评测（先 50 题筛查；定稿跑 --limit 0 全量 198）
python3 fast_gpqa.py --model-name ${model_name} \
  --api-base http://127.0.0.1:${port}/v1 \
  --dataset gpqa_diamond \
  --output /datapool/flagrelease/release_run_logs/${model_name}/gpqa.json

# ④ 判定
python3 accuracy_compare.py \
  --v2 /datapool/flagrelease/release_run_logs/${model_name}/gpqa.json \
  --nv-baseline ${model_name} --nv-baseline-file nv_baseline.yaml \
  --metric gpqa_diamond --json \
  --output /datapool/flagrelease/release_run_logs/${model_name}/verdict.json

# ⑤ 必查三项（缺一不可）
grep '\[gen\]' <eval日志>                    # 采样参数是否生效
# gpqa.json 里：truncation_detected / runaway_detection.runaway_count 必须为 0
```

---

## 4. 与厂商案例的对应关系（一览）

| 模型 | 直接参考的成功/已定位案例 | 状态 |
|------|--------------------------|------|
| Phi-4-reasoning-plus | 无同名案例。近邻：metax/Phi-4-mini-instruct（GQA 精度根因）、t-head/phi-4（同架构最小白名单）、iluvatar/Phi-4-mini-reasoning | ⚠️ **结论冲突，须 A/B** |
| LFM2.5-1.2B-Thinking | ✅ **iluvatar 已 PASS**（32.0% vs NV 29.0，退出码 0） | 照抄 |
| reka-flash-3 | ✅ **metax 已 PASS**（198 题 54.04% vs NV 原生 53.54%） | 照抄（含基准裁定） |
| Qwen3.5-27B-Distilled | iluvatar 已定位但**未达标**（70% vs 75%，受 8192 上下文限制） | 摩尔条件更好，值得重跑 |

## 5. 相对当前状态需要改动的项（TODO）

> 更新：2026-09-20 15:30 —— 服务已按本表重启并完成「首都测试」，下列 1、2 项**已完成**。

| # | 改动 | 影响范围 | 状态 |
|---|------|----------|:----:|
| 1 | ~~4 个服务改 graph 模式重启~~ → **结论：graph 在摩尔不可用，改用 `--enforce-eager` 重启** | 全部 | ✅ 已完成（eager） |
| 2 | reka-flash-3 的 `--max-model-len` 从 32768 改为 **24576** | 使 max_tokens=16384，对齐 NV 复现口径 | ✅ 已完成 |
| 3 | 4 个模型评测前补 `context.yaml`（含 `thinking_model: true`） | 全部 | ⬜ 待做（Qwen3.5 可选） |
| 4 | 判定基准：reka-flash-3 用 **NV 原生 53.54**，不用表中 59 | 仅 reka-flash-3 | ⬜ 待做（评测时） |
| 5 | 首轮筛查用 50 题，**定稿必须 198 题全量** | 全部 | ⬜ 待做 |
| 6 | Phi-4-reasoning-plus 准备 A/B：`rms_norm,silu_and_mul` 在白名单内 vs 移出 | 仅该模型 | ⬜ 待做 |

### 当前服务状态（2026-09-20 15:30，`mthreads-25`）

| 模型 | 卡 | 端口 | max_model_len | 首都测试 | 备注 |
|------|:--:|:----:|:-------------:|:--------:|------|
| Phi-4-reasoning-plus | GPU0 | 8000 | 32768 | ✅ 答「北京」 | reasoning 啰嗦，128 token 时还在思考 |
| LFM2.5-1.2B-Thinking | GPU1 | 8001 | 32768 | ✅ 答「北京」 | 646 token 干净收尾 |
| reka-flash-3 | GPU2 | 8002 | **24576** | ✅ 答「北京」 | 答完后又自续了一轮 ` <sep> human:`，注意 |
| Qwen3.5-27B-Distilled | GPU3 | 8003 | 32768 | ✅ 答「北京」 | 63 token 就给出答案，最干脆 |

> ⚠️ reka-flash-3 在答完「北京」后**继续编造了下一轮对话**（` <sep> human:`）——
> 与 metax 记录的「响应极长」一致，评测时关注 `runaway_detection` 与截断。
