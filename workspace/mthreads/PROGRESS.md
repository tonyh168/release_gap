# mthreads 工作进度快照

> 记录时间：**2026-09-21 14:30**
> 分支：`mthreads-init-0920` | 宿主机：`mthreads-25` | 镜像：`flagrelease_mthreads-gmi_vllm024plugin_base:08281629`
>
> ⚠️ **本文件是「当前该干什么」的快照**；逐模型结论看 [[STATUS]]，参数看 [[EVAL_SETTINGS]]，
> 环境看 [[EVAL_INFRA]]，**逐模型完整交付物看 `reports/`**（3 份已生成）。

---

## 🔴 正在后台运行的任务（**退出 session 不会中断**）

**4 组 reka-flash-3 的 50 题重复性评测并行跑在 `mthreads-25` 上**（2026-09-21 14:26 起跑，ETA ~17:30）。
进程由 `docker exec -d` 拉起到容器内，**不依赖本 session**，可以安全退出。

| 组 | 服务容器 / GPU / 端口 | eval 容器 | 输出目录 |
|:--:|----------------------|-----------|----------|
| r1 | `flagrelease-fix-reka-flash-3` / GPU2 / 8002 | `eval-reka-flash-3` | `release_run_logs/reka-flash-3/repeat-r1/` |
| r2 | `flagrelease-fix-reka-flash-3-r2` / GPU0 / 8004 | `eval-reka-flash-3-r2` | `release_run_logs/reka-flash-3/repeat-r2/` |
| r3 | `flagrelease-fix-reka-flash-3-r3` / GPU1 / 8005 | `eval-reka-flash-3-r3` | `release_run_logs/reka-flash-3/repeat-r3/` |
| r4 | `flagrelease-fix-reka-flash-3-r4` / GPU3 / 8006 | `eval-reka-flash-3-r4` | `release_run_logs/reka-flash-3/repeat-r4/` |

**目的**：量出 temp=0.6 采样下 50 题口径的**抖动带**，判断摩尔 50.0% 与 metax v6 56.0% 的 6pt 差距
是真实退化还是噪声。**实验设计与判定方法见 [[STATUS]] 的「🔬 reka-flash-3 重复性实验」节。**

每组产物：`gpqa_50.json`（跑完才有）、`eval_50.log`（实时）、`serve.log`（服务侧）。

**回来第一件事**：见文末「恢复工作」。

---

## 当前状态一览

### 服务（`mthreads-25`，2026-09-21 14:30）

| 服务 | 卡 | 端口 | 状态 |
|------|:--:|:----:|------|
| reka-flash-3 × 4（重复组 r1–r4） | GPU0/1/2/3 | 8002/8004/8005/8006 | 🟢 运行中 |
| Phi-4-reasoning-plus | — | — | ⏹️ **容器已停**（`docker stop`，2026-09-21） |
| LFM2.5-1.2B-Thinking | — | — | ⏹️ **容器已停** |
| Qwen3.5-27B-Distilled | — | — | ⏹️ **容器已停** |
| GPU4–7 | — | — | 空闲（4 张） |

> 三个停掉的容器**保留未删**（`Exited (137)`），`docker start <容器>` 即可原样恢复；显存已确认归零。

### 评测结果（50 题筛查，已全部出判定）

| 模型 | 得分 | NV 基线 | 判定 | 交付物 |
|------|:----:|:-------:|:----:|--------|
| Phi-4-reasoning-plus | **58.0%** | 46 | ✅ 达标 | [[reports/Phi-4-reasoning-plus]] |
| LFM2.5-1.2B-Thinking | **32.0%** | 29.0 | ✅ 达标 | [[reports/LFM2.5-1.2B-Thinking]] |
| Qwen3.5-27B-Distilled | **78.0%** | 75 | ✅ 达标 | [[reports/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled]] |
| reka-flash-3 | **50.0%** | 59 / 53.54 | ❌ 不达标 | 定性中（重复性实验） |

---

## ✅ 已完成的工作

| # | 工作 | 产出 |
|---|------|------|
| 1 | 初始化 mthreads 厂商目录（对齐 metax/iluvatar 结构） | `mthreads/{SOP,ENV,STATUS,EVAL_SETTINGS,EVAL_INFRA}.md` + `fixes/` |
| 2 | 环境实测（宿主机、共享盘、镜像、版本） | [[ENV]] |
| 3 | 4 个模型起服务 + 冒烟 | `fixes/*.md` |
| 4 | SOP 端到端验证 | Phi-4-reasoning-plus 首跑即通 |
| 5 | 评测设置定稿（横比 metax/iluvatar/t-head 案例） | [[EVAL_SETTINGS]] |
| 6 | 评测环境搭建（4 个 eval 容器 + 脚本 + 离线数据集） | [[EVAL_INFRA]] |
| 7 | **50 题筛查跑完 4/4 并出判定** | **3 达标 / 1 不达标**，见 [[STATUS]] |
| 8 | **逐模型实测算子列表**（取自容器 `/tmp/flaggems_enable_oplist.txt`） | 写入 4 份 `fixes/*.md`，**发现 Qwen3.5 白名单 3 个只触达 1 个** |
| 9 | **生成 3 份发布报告**（照 `workspace/report_template.md`） | `mthreads/reports/*.md`，含发布字段四块（已做格式自检） |
| 10 | 释放显存：停掉 3 个非 reka 服务容器 | GPU0/1/3 归零 |
| 11 | 起 3 个 reka 容器 + 3 个配套 eval 容器，启动 4 组重复性评测 | 本文档第 1 节 |

---

## 📌 遗留未决事项

| # | 事项 | 状态 |
|---|------|------|
| 1 | **reka-flash-3 定性**（重复性实验） | 🔄 进行中，4 组并行 |
| 2 | **3 个达标模型的 198 题全量定稿** | ⬜ 待做 —— **需要先 `docker start` 恢复服务容器**（已停） |
| 3 | **`mthreads-26` 连不上** | ❌ 等发起人确认（bastion 报 `match asset failed: No found asset`） |
| 4 | Phi-4-reasoning-plus 的算子 A/B | ⬜ 未做（留白名单就已达标 +12pt，故未做） |
| 5 | Qwen3.5 算子覆盖面窄（白名单 3 个只触达 1 个） | ⬜ 原因未定位，已记录；**不影响达标** |
| 6 | **本次改动未提交 git** | ⬜ 4 改 3 新增（`STATUS.md` / 3 份 `fixes` / `reports/`） |

---

## ⚠️ 已踩过的坑（都记进 [[KNOWLEDGE]] 了）

1. **摩尔 graph 模式不可用** —— 去掉 `--enforce-eager` 后 4 个模型全部启动失败
   （`MUSA driver error: operation not permitted when stream is capturing`）。
2. **`pkill -f "vllm serve"` 杀不掉 EngineCore 子进程**，残留占显存 → 新服务报 `Free memory ... less than desired`。
   可靠做法是 `docker restart` / `docker stop`。
3. **`python3` 输出重定向到文件是块缓冲** —— 评测要用 `python3 -u`。
4. **`docker cp` 到本镜像的 `/tmp` 会失效**（tmpfs），要用 `/root/`。
5. **`context.yaml` 用混不会报错，只会静默退回贪心** —— 这是采用 1:1 eval 容器的根本原因。
6. **评测前必查 `[gen]` 行**：确认「采用模型 generation_config.json 采样参数」或「沿用默认」，
   若见「未定位到模型目录」则 `context.yaml` 没生效、分数不可信。
7. **`flaggems_enable_oplist.txt` 是实测算子列表的唯一可信来源**（注意 `oplist` 连写）——
   白名单写了不等于生效。**OpList ≠ 白名单**（Qwen3.5：白名单 3、实测 1）。
8. **受控对照实验必须显式 `--eval-batch-size`**：不传则脚本自动探测，各组可能探到不同并发。

---

## 🔄 恢复工作

### 1. 查重复性实验进度 / 结果

```bash
ssh mthreads-25
cd /datapool/flagrelease/release_run_logs/reka-flash-3
for r in r1 r2 r3 r4; do
  printf "%-10s %s  " "repeat-$r" "$([ -s repeat-$r/gpqa_50.json ] && echo 完成 || echo 进行中)"
  [ -s repeat-$r/gpqa_50.json ] && python3 -c "import json;print(json.load(open('repeat-$r/gpqa_50.json'))['score'])"
  echo
done
# 进程是否还在
docker exec eval-reka-flash-3-r2 pgrep -af fast_gpqa
```

### 2. 出判定（每组一个 verdict，再看散布）

```bash
for r in r1 r2 r3 r4; do
  c=eval-reka-flash-3$([ $r = r1 ] && echo "" || echo "-$r")
  d=/datapool/flagrelease/release_run_logs/reka-flash-3/repeat-$r
  docker exec $c bash -lc "cd /datapool/flagrelease/eval_scripts && python3 accuracy_compare.py \
    --v2 $d/gpqa_50.json --nv-baseline reka-flash-3 --nv-baseline-file nv_baseline.yaml \
    --metric gpqa_diamond --json --output $d/verdict_50.json"; echo "$r exit=$?"
done
# 注意：reka 的判定基准按 metax 裁定应为 NV 原生 53.54（表内 59 口径不符）→ 两种都算，见 STATUS
```

### 3. 必查三项（缺一不可）

```bash
grep -E "\[gen\]" repeat-r*/eval_50.log          # 4 组必须都是 temp=0.6/top_p=0.95/top_k=1024
grep -iE "error|Traceback" repeat-r*/serve.log | grep -v "forked subprocess"
python3 -c "import json;d=json.load(open('repeat-r2/gpqa_50.json'));print({k:d.get(k) for k in ('score','truncation_detected','runaway_detection','total_questions','eval_batch_size')})"
```

### 4. 已知会遇到的情况

- **`score=null`**：thinking 模型 `content` 是 list 时 `detect_runaway` 会崩。**不是失败**，
  从 evalscope 报告恢复：`outputs/gpqa_diamond/<时间戳>/reports/reka-flash-3/gpqa_diamond.json` 的 `metrics[0].score`。
  ⚠️ **本次 4 组的 `outputs/` 目录都在共享盘 `/datapool/flagrelease/eval_scripts/outputs/`**（同机同路径），
  靠 **时间戳**区分：r4=`20260921_062551`、r2=`20260921_062602`、r1=`20260921_062606`、r3=`20260921_062621`。
- **evalscope 版本告警**：镜像内 1.11.1 vs 脚本期望 1.5.1，**仅 WARN 不阻塞**。
- **reka 可能 runaway**：若 `runaway_count` 非零，分数需加注说明。

### 5. 下一步（重复性实验之后）

- **若 4 组散布窄（都 ~50%）** → 6pt 差距是真的 → 按 [[EVAL_SETTINGS]] 2.3 的「首个 A/B」继续定位
  （**先查采样口径与 `max_tokens`，别折腾算子黑名单** —— metax 在这条路上耗了 v1~v5）。
- **若出现 ≥56% 的组** → 50% 那轮落在抖动下沿 → **按全量 198 题重新判定**。
- **无论哪种，3 个达标模型的 198 题全量定稿都要做**：先 `docker start` 恢复那 3 个服务容器。

---

## 文档索引

| 文档 | 内容 |
|------|------|
| [[SOP]] | 起容器→下模型→起服务→评测→记录 全流程 |
| [[ENV]] | 硬件/软件栈/镜像/存储/运行时的实测值 |
| [[STATUS]] | 50 个失败模型清单 + 进度 + 待办 + **50 题筛查结果** + **重复性实验** |
| [[EVAL_SETTINGS]] | **逐模型评测参数总表**（温度/top_p/top_k/is-think） |
| [[EVAL_INFRA]] | **评测环境**：eval 容器、context.yaml、离线数据集、跑评测命令 |
| `fixes/*.md` | 逐模型修复日志（含**实测算子列表**专节） |
| **`reports/*.md`** | **逐模型发布报告**（照 `workspace/report_template.md`，含发布字段） |
| `_shared/KNOWLEDGE.md` | 跨厂商经验库（含本次新增的摩尔相关条目） |
