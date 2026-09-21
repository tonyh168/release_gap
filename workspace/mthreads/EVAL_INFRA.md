# Mthreads 评测环境（eval 容器）说明

> 更新：2026-09-21（追加 reka-flash-3 重复性实验的 3+3 个容器） | 宿主机：`mthreads-25` | 依据：本机实测
> 配套：[[EVAL_SETTINGS]]（逐模型参数）、[[SOP]] 第 4 节、[[ENV]]（存储）

---

## 设计：一模型一 eval 容器（1:1 绑定）

`fast_gpqa.py` 读取 `context.yaml` 的路径是**硬编码**的 `/flagos-workspace/shared/context.yaml`。
若多个模型共用一个 eval 容器，**每换模型都要改这个文件**——忘了改不会报错，
只会**静默退回贪心**（日志一行 INFO，极易漏看；metax/reka-flash-3 就栽在这）。

**因此本厂商采用 1:1 绑定**：每个模型一个专用 eval 容器，容器内各自维护自己的 `context.yaml`。
这样「用混」的问题从结构上消失，且**可以并行评测**。

| eval 容器 | 对应模型 | 服务端口 |
|-----------|----------|:--------:|
| `eval-phi-4-reasoning-plus` | Phi-4-reasoning-plus | 8000 |
| `eval-lfm2.5-1.2b-thinking` | LFM2.5-1.2B-Thinking | 8001 |
| `eval-reka-flash-3` | reka-flash-3 | 8002 |
| `eval-qwen3.5-27b-distilled` | Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled | 8003 |

### 追加：reka-flash-3 重复性实验的 3 个容器（2026-09-21）

为量出 temp=0.6 采样下的**抖动带**（起因与判定方法见 [[STATUS]] 的「🔬 reka-flash-3 重复性实验」节），
同一模型**再起了 3 个服务 + 3 个配套 eval 容器**，「一服务一 eval 容器」的 1:1 绑定不变：

| eval 容器 | 对应服务容器 | GPU | 服务端口 |
|-----------|--------------|:---:|:--------:|
| `eval-reka-flash-3`（复用原容器） | `flagrelease-fix-reka-flash-3` | GPU2 | 8002 |
| `eval-reka-flash-3-r2` | `flagrelease-fix-reka-flash-3-r2` | GPU0 | 8004 |
| `eval-reka-flash-3-r3` | `flagrelease-fix-reka-flash-3-r3` | GPU1 | 8005 |
| `eval-reka-flash-3-r4` | `flagrelease-fix-reka-flash-3-r4` | GPU3 | 8006 |

> 4 个容器的 `context.yaml` **内容完全相同**（都指向 reka 权重、`thinking_model: true`），
> 各自私有、不共享挂载 —— 这正是 1:1 绑定在「同模型多实例」场景下的用法。
>
> ⚠️ **`outputs/` 是共享的**：4 个 eval 容器都挂 `/datapool`，evalscope 的输出落在
> **同一个** `/datapool/flagrelease/eval_scripts/outputs/gpqa_diamond/<时间戳>/` 下，
> 靠**时间戳**区分（起跑刻意错开 6 秒）。本次时间戳对应关系记在 [[PROGRESS]]「已知会遇到的情况」。

> ⚠️ **`context.yaml` 保持容器私有**：每个容器的 `/flagos-workspace/shared/` 是在容器内 `mkdir` 建的，
> **没有从宿主机挂载**。如果哪天改成挂载共享目录，1:1 隔离就失效了。

## 建容器的命令（可复现）

```bash
IMG=harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope
BASE=/datapool/flagrelease

docker run -d --name eval-<短名> --network host \
  -v /datapool:/datapool \
  $IMG sleep infinity

docker exec eval-<短名> bash -lc "mkdir -p /flagos-workspace/shared"
docker exec -i eval-<短名> bash -lc "cat > /flagos-workspace/shared/context.yaml" <<EOF
model:
  local_path: $BASE/fixes_models/<模型名>
  container_path: $BASE/fixes_models/<模型名>
  thinking_model: true
EOF
```

四个容器已建好，`context.yaml` 内容见下节。脚本 `make_eval_containers.sh` 存在宿主机 `/tmp/`。
（2026-09-21 又按同一命令加了 `-r2`/`-r3`/`-r4` 三个重复组容器，见上「追加」节。）

## 共享盘上的评测资产

| 路径（宿主机 = 容器内，内外同路径） | 内容 |
|--------------------------------------|------|
| `/datapool/flagrelease/eval_scripts/` | `fast_gpqa.py`、`accuracy_compare.py`、`nv_baseline.yaml`、`fast_gpqa_config.yaml`、`datasets/`、`README.md` |
| `/datapool/flagrelease/evalscope-datasets/gpqa_diamond/` | **离线数据集**（`train.jsonl`），用 `--dataset-dir /datapool/flagrelease/evalscope-datasets` 指向其父目录，跳过联网下载 |
| `/datapool/flagrelease/release_run_logs/<模型名>/` | 评测输出（serve.log / gpqa.json / verdict.json） |
| `/datapool/flagrelease/contexts/` | 预留（当前未用，context.yaml 在容器内） |

## ⚠️ evalscope 版本：实测 1.11.1，而脚本期望 1.5.1

`flagos-evalscope:latest-modelscope` 镜像内是 **evalscope 1.11.1**，而
`fast_gpqa.py` 会打印告警 `版本 1.11.1 != 1.5.1 (统一评测版本)`。

**不阻塞**，理由：
1. 脚本对该检查只 `print("[WARN] ...")` **不退出**（`fast_gpqa.py:1457`）；
2. 脚本**已显式兼容两个版本的分数格式**（`fast_gpqa.py:861-862`）：
   - 1.5.1 → 分数在顶层 `score`/`accuracy`
   - 1.11.1（`schema_version=2`）→ 分数在 `metrics` 列表项里
3. **metax 的评测容器用的也是 1.11.1**（见 `metax/ENV.md`），且评测全部跑通。

**结论**：沿用 1.11.1，但要记得**记录版本**——跨平台比分数时口径要一致。

## 跑评测的标准命令（改 `<...>` 即可）

```bash
c=eval-<短名>; m=<模型名>; p=<端口>

docker exec $c bash -lc "cd /datapool/flagrelease/eval_scripts && python3 fast_gpqa.py \
  --model-name $m \
  --api-base http://127.0.0.1:$p/v1 \
  --dataset gpqa_diamond \
  --dataset-dir /datapool/flagrelease/evalscope-datasets \
  --output /datapool/flagrelease/release_run_logs/$m/gpqa.json"

docker exec $c bash -lc "cd /datapool/flagrelease/eval_scripts && python3 accuracy_compare.py \
  --v2 /datapool/flagrelease/release_run_logs/$m/gpqa.json \
  --nv-baseline $m \
  --nv-baseline-file nv_baseline.yaml --metric gpqa_diamond --json \
  --output /datapool/flagrelease/release_run_logs/$m/verdict.json"
```

- 加 `--limit 0` 跑全量 198 题（**定稿用**）；不加则默认 50 题（筛查用）。
- **必须先 `grep '\[gen\]' <评测输出>` 确认采样参数**，见下节。

## 验收：`[gen]` 四种输出的含义

| 日志 | 含义 | 期望出现在 |
|---|---|---|
| `采用模型 generation_config.json 采样参数: {...}` | ✅ 拿到 gc 采样值 | Phi-4-reasoning-plus（0.8/0.95/50）、reka-flash-3（0.6/0.95/1024） |
| `generation_config.json 无可用采样字段，沿用默认` | ⚠️ **正常**——定位到了模型，但它 gc 里没采样字段 | LFM2.5-1.2B-Thinking |
| `未找到模型 generation_config.json，沿用默认采样参数` | 路径对但无该文件 | Qwen3.5-27B-Distilled（**本来就没有** gc） |
| `未定位到模型目录（--model-name 非本地路径且 context.yaml 无路径）` | ❌ **context.yaml 没生效** | **不该出现** |

## ✅ 验收：4 个容器的 context.yaml 全部生效（实测）

用**真实的脚本函数**（`importlib` 加载 `fast_gpqa.py`，直接调 `detect_thinking()` /
`_resolve_model_dir()` / `resolve_gen_params()`）在容器内逐个验证：

| eval 容器 | `detect_thinking` | `_resolve_model_dir` | `[gen]` 结果 | **最终 temperature / top_p / top_k** |
|-----------|:-----------------:|----------------------|--------------|:------------------------------------:|
| `eval-phi-4-reasoning-plus` | ✅ True | ✅ 正确路径 | 采用 gc 采样参数 | **0.8 / 0.95 / 50** |
| `eval-lfm2.5-1.2b-thinking` | ✅ True | ✅ 正确路径 | gc 无采样字段，沿用默认 | **0.6 / 0.95 / —** |
| `eval-reka-flash-3` | ✅ True | ✅ 正确路径 | 采用 gc 采样参数 | **0.6 / 0.95 / 1024** |
| `eval-qwen3.5-27b-distilled` | ✅ True | ✅ 正确路径 | 未找到 gc，沿用默认 | **0.6 / 0.95 / —** |

**结论**：4 个都与 [[EVAL_SETTINGS]] 的「评测参数总表」**逐项一致**，且
**4 个 `detect_thinking` 全为 True** —— 其中 3 个（Phi-4 / LFM2.5 / reka）是**靠 context.yaml 才成立的**
（名字不含 `THINKING_PATTERNS` 关键词），证明这套 1:1 配置确实在起作用。

> ⚠️ 上表 `[gen]` 一列里 **reka-flash-3 的 `max_tokens` 是 16384 而非 20000**：
> 真实运行时 `max_tokens` 由 `auto_max_tokens()` 按**服务端 `max_model_len`** 反算
> （reka 服务是 24576 → 24576-8192 = **16384**）。上面的验证脚本为了隔离变量传了固定值，
> 所以那一格不代表真实取值。**以 [[EVAL_SETTINGS]] 总表为准。**

复现该验证（脚本已放在各容器 `/root/verify_ctx.py`）：

```bash
docker exec -e M=<模型名> eval-<短名> bash -lc "python3 /root/verify_ctx.py 2>&1 | grep -vE '^(INFO|WARNING)'"
```

## 踩坑记录

1. **`python3` 重定向到文件会块缓冲**，`> xxx.log` 后日志长时间为空、看不到任何进度。
   要实时看输出得加 `-u`（`python3 -u fast_gpqa.py ...`），或用 `tee` 配合 `stdbuf`。
2. **`docker cp` 到容器的 `/tmp` 可能失败**：本镜像的 `/tmp` 是 `--tmpfs`，
   写入后 `docker exec` 又看不到（实测出现过）。**改用 `/root/`** 就正常。
3. **`pkill -f "vllm serve"` 杀不干净**：EngineCore 是子进程，残留会占显存，
   导致新服务报 `Free memory ... less than desired GPU memory utilization`。
   可靠做法是 `docker restart <容器>` 或 `pkill -9` 后确认 `mthreads-gmi` 显存归零。

---

## 注意事项

1. **并行评测**：多个容器可同时跑（2026-09-21 实测 **4 组同模型评测并行**正常），
   但**评测期间不要同时跑性能测试**（抢 GPU 会污染精度，见 `_shared/EVAL.md`）。
   ⚠️ **受控对照实验必须显式传 `--eval-batch-size`**：不传则脚本自动探测，各组可能探到不同并发，
   实验就不可比了（reka 重复性实验固定 `--eval-batch-size 1`）。
2. **换模型时**：由于 1:1 绑定，只需改**对应容器**的 `context.yaml`；容器名与模型的对应关系见上表。
3. **容器重启后** `context.yaml` 仍在（写在容器可写层，非 tmpfs）。但若 `docker rm` 重建，需重新写入。
4. **`--model-name` 必须是 served name**，不能传路径——它同时是 API 请求的 model 字段。
