# mthreads 工作进度快照

> 记录时间：**2026-09-20 17:05**（session 退出前）
> 分支：`mthreads-init-0920` | 最后提交：`1b9165e`
> 宿主机：`mthreads-25` | 镜像：`flagrelease_mthreads-gmi_vllm024plugin_base:08281629`

---

## 🔴 正在后台运行的任务（**退出 session 不会中断**）

**4 个模型正在并行跑 gpqa_diamond 50 题评测**，全部跑在宿主机 `mthreads-25` 上，
进程由 `docker exec -d` 拉起到容器内，**不依赖本 session**，可以安全退出。

| 模型 | eval 容器 | 端口 | 进度（17:05） |
|------|-----------|:----:|---------------|
| Phi-4-reasoning-plus | `eval-phi-4-reasoning-plus` | 8000 | 评测中 0/50（刚进入答题） |
| LFM2.5-1.2B-Thinking | `eval-lfm2.5-1.2b-thinking` | 8001 | 评测中 **4/50**（约 28s/题，ETA ~22min） |
| reka-flash-3 | `eval-reka-flash-3` | 8002 | 并发探测完成（并发 2），即将答题 |
| Qwen3.5-27B-Distilled | `eval-qwen3.5-27b-distilled` | 8003 | 并发探测完成（并发 2），即将答题 |

**输出位置**（宿主机 = 容器内，内外同路径）：

```
/datapool/flagrelease/release_run_logs/<模型名>/eval_50.log    ← 实时日志
/datapool/flagrelease/release_run_logs/<模型名>/gpqa_50.json   ← 跑完产出
```

**回来第一件事**：用下面的命令查进度和结果（见文末「恢复工作」）。

---

## 当前状态一览

### 服务（4 个，均 `--enforce-eager`）

| 模型 | 卡 | 端口 | max_model_len | 状态 |
|------|:--:|:----:|:-------------:|------|
| Phi-4-reasoning-plus | GPU0 | 8000 | 32768 | 🟢 运行中 |
| LFM2.5-1.2B-Thinking | GPU1 | 8001 | 32768 | 🟢 运行中 |
| reka-flash-3 | GPU2 | 8002 | **24576** | 🟢 运行中 |
| Qwen3.5-27B-Distilled | GPU3 | 8003 | 32768 | 🟢 运行中 |
| GPU4–7 | — | — | — | 空闲（4 张） |

### eval 容器（4 个，1:1 绑定）

`eval-phi-4-reasoning-plus` / `eval-lfm2.5-1.2b-thinking` / `eval-reka-flash-3` / `eval-qwen3.5-27b-distilled`，
各挂 `/datapool:/datapool`，各有一份**容器私有**的 `/flagos-workspace/shared/context.yaml`。

### 权重（`/datapool/flagrelease/fixes_models/`）

Phi-4-reasoning-plus 28GB / LFM2.5-1.2B-Thinking 2.2GB / reka-flash-3 39GB / Qwen3.5-27B-Distilled 52GB —— 全部下完。

---

## ✅ 本次已完成的工作

| # | 工作 | 产出 |
|---|------|------|
| 1 | 初始化 mthreads 厂商目录（对齐 metax/iluvatar 结构） | `mthreads/{SOP,ENV,STATUS,EVAL_SETTINGS,EVAL_INFRA}.md` + `fixes/` |
| 2 | 环境实测（宿主机、共享盘、镜像、版本） | 见 [[ENV]] |
| 3 | 4 个模型起服务 + 冒烟（短/长 prompt） | `fixes/*.md` |
| 4 | **SOP 端到端验证** | Phi-4-reasoning-plus 首跑即通 |
| 5 | 评测设置定稿（横比 metax/iluvatar/t-head 案例） | [[EVAL_SETTINGS]] 含参数总表 |
| 6 | 评测环境搭建 | 4 个 eval 容器 + 脚本 + 离线数据集，见 [[EVAL_INFRA]] |
| 7 | 首都测试 4/4 通过 | 记录在 [[EVAL_SETTINGS]] |
| 8 | 启动 50 题评测 | **进行中**（本文档第 1 节） |

---

## 📌 遗留未决事项

| # | 事项 | 状态 |
|---|------|------|
| 1 | **`mthreads-26` 连不上** | ❌ 等你确认（bastion 报 `match asset failed: No found asset`） |
| 2 | **未提交的改动** | 无——最后一次提交 `1b9165e` 已包含全部文档与脚本 |
| 3 | Phi-4-reasoning-plus 的算子 A/B | ⬜ 未做（`rms_norm,silu_and_mul` 在白名单内 vs 移出，[[EVAL_SETTINGS]] 2.1） |
| 4 | 50 题只是筛查，**定稿要 198 题全量** | ⬜ 待做 |
| 5 | reka-flash-3 判定基准裁定（用 NV 原生 53.54 而非表中 59） | ⬜ 评测判定时执行 |

---

## ⚠️ 本次踩过的坑（都记进 [[KNOWLEDGE]] 了）

1. **摩尔 graph 模式不可用** —— 去掉 `--enforce-eager` 后 4 个模型全部启动失败
   （`MUSA driver error: operation not permitted when stream is capturing`）。
   metax「graph 快 10 倍」的经验**在摩尔不适用**，必须保留 `--enforce-eager`。
2. **`pkill -f "vllm serve"` 杀不掉 EngineCore 子进程**，残留占显存 →
   新服务报 `Free memory ... less than desired`。要 `docker restart <容器>`。
3. **`python3` 输出重定向到文件是块缓冲**，日志长时间空白 —— 评测要用 `python3 -u`。
4. **`docker cp` 到本镜像的 `/tmp` 会失效**（tmpfs），要用 `/root/`。
5. **`context.yaml` 用混不会报错，只会静默退回贪心** —— 这是采用 1:1 容器的根本原因。
6. **评测前必查 `[gen]` 行**：4 个模型启动时都确认了 `模式: thinking` 和采样参数。

---

## 🔄 恢复工作（下次接续的步骤）

### 1. 查评测进度 / 结果

```bash
ssh mthreads-25
# 进度
for m in Phi-4-reasoning-plus LFM2.5-1.2B-Thinking reka-flash-3 \
         Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled; do
  printf "%-48s %s\n" "$m" "$([ -f /datapool/flagrelease/release_run_logs/$m/gpqa_50.json ] && echo 完成 || echo 进行中)"
  tail -c 200 /datapool/flagrelease/release_run_logs/$m/eval_50.log | tr '\r' '\n' | tail -1
done
# 进程是否还在
docker exec eval-lfm2.5-1.2b-thinking pgrep -af fast_gpqa
```

### 2. 跑判定（每个模型）

```bash
c=eval-<短名>; m=<模型名>
docker exec $c bash -lc "cd /datapool/flagrelease/eval_scripts && python3 accuracy_compare.py \
  --v2 /datapool/flagrelease/release_run_logs/$m/gpqa_50.json \
  --nv-baseline $m --nv-baseline-file nv_baseline.yaml \
  --metric gpqa_diamond --json \
  --output /datapool/flagrelease/release_run_logs/$m/verdict_50.json"
# 退出码 0=达标 1=不达标 2=参数错 3=缺NV基线
```

### 3. 必查三项（缺一不可）

```bash
# ① 采样参数是否生效（补看 Phi-4 / Qwen3.5，另外两个已确认）
grep -E "\[gen\]" /datapool/flagrelease/release_run_logs/<模型名>/eval_50.log
# ② 服务器端是否报错
grep -iE "error|Traceback" /datapool/flagrelease/release_run_logs/<模型名>/serve.log | grep -v "forked subprocess"
# ③ 结果 JSON 的红旗字段
python3 -c "import json;d=json.load(open('/datapool/flagrelease/release_run_logs/<模型名>/gpqa_50.json'));print({k:d.get(k) for k in ('score','truncation_detected','runaway_detection','total_questions')})"
```

### 4. 已知会遇到的情况

- **`score=null`**：thinking 模型 `content` 是 list 时 `detect_runaway` 会崩。
  **不是失败**，从 evalscope 报告恢复：`outputs/gpqa_diamond/<时间戳>/reports/<模型名>/gpqa_diamond.json` 的 `metrics[0].score`。
  （iluvatar 的 LFM2.5 / Qwen3.5 都遇到过。）
- **evalscope 版本告警**：镜像内 1.11.1 vs 脚本期望 1.5.1，**仅 WARN 不阻塞**，脚本已兼容两版分数格式。
- **reka-flash-3 可能 runaway**：首都测试时它答完自续了一轮对话（` <sep> human:`），
  若 `runaway_count` 非零则分数不可直接采信。

### 5. 下一步（50 题之后）

若 50 题结果合理 → 跑 **198 题全量定稿**（`--limit 0`，去掉 `--limit 50`）；
若不达标 → 按 [[EVAL_SETTINGS]] 的逐模型「首个 A/B」排查
（Phi-4 优先试算子去留，reka 优先查采样参数，Qwen3.5 优先查算子策略）。

---

## 文档索引

| 文档 | 内容 |
|------|------|
| [[SOP]] | 起容器→下模型→起服务→评测→记录 全流程 |
| [[ENV]] | 硬件/软件栈/镜像/存储/运行时的实测值 |
| [[STATUS]] | 50 个失败模型清单 + 进度 + 待办 |
| [[EVAL_SETTINGS]] | **逐模型评测参数总表**（温度/top_p/top_k/is-think）+ 与厂商案例的对应 |
| [[EVAL_INFRA]] | **评测环境**：4 个 eval 容器、context.yaml、离线数据集、跑评测命令 |
| `fixes/*.md` | 逐模型修复日志（4 个已起服务的） |
| `_shared/KNOWLEDGE.md` | 跨厂商经验库（含本次新增的 10+ 条摩尔相关） |
