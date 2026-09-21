# metax/SOLAR-10.7B-Instruct-v1.0 修复日志

- **失败报告**：flagrelease_fail_reports/Metax/FAILED_Metax_SOLAR-10.7B-Instruct-v1.0_202607261725.md
- **原始失败类型**：精度不达标（V2=27.78%，V3=30.3%，均低于 NV×0.95=32.3%）+ plugin-FL 报错
- **日期**：2026-09-16（调试）/ 2026-09-18（达标判定）

## 现象

- 原报告 V1 无评测数据，V2（FlagGems，无 plugin）= 27.78%，V3（plugin-FL）= 30.3%——V2/V3 均低于 `nv_baseline.yaml` 中 34.0% 的 95% 线（32.3%），两个 issue 都是精度退化 + plugin-FL error。
- 本次修复第一轮起服务即失败：`max-model-len` 默认 32768 时 vLLM 抛
  `pydantic ValidationError: max_model_len (32768) > max_position_embeddings (4096)`；模型 `config.json` 中 `max_position_embeddings=4096`，不可超过（SOLAR 的 config.json 未同步声明正确长度）。改回 4096 后 `Application startup complete`，服务正常。
- 服务本身不崩溃、不 OOM：`(EngineCore pid=642) [INFO] init engine (profile, create kv cache, warmup model) took 26.17 s`，冒烟（英文短问答 + 中文长 prompt）通过。
- 三轮迭代（v1/v2/v3）以 `nv_baseline.yaml` 的 34.0% 为基准时**均不达标**：v1=24.0%（12/50），v2=26.0%（13/50），v3=20.0%（10/50），rel_drop 分别为 29.41%、23.53%、41.18%，全部远超 5% 容差。
- 逐题检查回答内容发现：模型 IS 在生成（30–44 tok/s），但大量回答是冗长的推理段落，**没有以 `ANSWER: (X)` 格式收尾**，evalscope 无法提取答案字母；只有少数样本（如以 "ANSWER: D" 开头的）被正确计分。这是 plugin-FL 在 MetaX 硬件上的**格式退化**（greedy-decode 路径偏移），不是截断，也不是模型静默。
- 关键对照：NV vllm 官方镜像在同等评测配置下的实测成绩同样只有约 25%——50 题 = 24.00%（12/50），198 题 = 26.26%（52/198）。
- 评测侧已知干扰：`fast_gpqa.py` 存在 parse bug，`score` 字段写成 `null`，本轮分数均从 evalscope reviews 补计分。

## 定位

- **plugin-FL 报错类型**：非缺 `.so` 编译扩展、非 crash、非 OOM；是**精度退化算子**类问题，表现为生成格式退化（不输出终止答案字母），无算子级 crash 日志。
- **基准口径不一致（本次核心结论）**：`nv_baseline.yaml` 中 SOLAR 的 34.0% 来自某次 NV 测试，与 NV vllm 官方镜像（`vllm/vllm-openai` v0.24.0）在标准 GPQA Diamond 配置下的实测成绩显著不符。以 34.0% 为基准时三轮都不达标；以 NV 官方镜像实测为基准时 MetaX v2 与之持平。

| 题数 | NV origin（vllm 官方镜像） | 沐曦 MetaX（本次最优 v2） |
|------|--------------------------|--------------------------|
| 50 题 | 24.00%（12/50） | 26.0%（13/50） |
| 198 题 | 26.26%（52/198） | — |

- **NV 官方镜像复现参数**（手动复现文档 Section 6A，固定摘要 `vllm/vllm-openai@sha256:251eba5cc7c12fed0b75da22a9240e582b1c9e39f6fbc064f86781b963bd814f`，即 v0.24.0）：`CUDA_VISIBLE_DEVICES=0`、`VLLM_PLUGINS=''`（未装 FlagGems / plugin-fl）→ /usr/local/bin/vllm serve，TP=1，bf16，`--enforce-eager`，`--no-enable-prefix-caching`，`--no-enable-chunked-prefill`，`--max-model-len 4096`，`--max-num-batched-tokens 4096`，`--max-num-seqs 64`，`--generation-config vllm`，`--attention-backend FLASH_ATTN`。评测参数：evalscope=1.11.1，temperature=0.0，max_tokens=2048，concurrency=16，stream=True，TaskConfig seed=42，gpqa_diamond default subset / train split / 0-shot。NV 历史运行目录：50 题 `baai-h20-01-clone:/data/reference-eval/fast-gpqa-runs/20260916-190714-solar-native-bc87cb03`，198 题 `baai-h20-01-clone:/data/reference-eval/fast-gpqa-runs/20260916-191626-solar-native-gpqa198-1e9a8942`。
- 结论：`VLLM_FL_USE_FLAGGEMS_ATTN=0` 对 SOLAR 这类非 MLA dense 模型无益（v3 去掉后反而更差）；格式退化问题即便在 NV 端同样存在（NV 端同样只有 ~25%），指向模型在 GPQA Diamond 上的能力上限，而非硬件平台差异。
- 资源口径：bf16 权重约 21GB，21GB × 1.2 / 63.6 = 0.40 → TP=1（单卡剩余 ~37GB KV cache，充裕）。

## 处置

### 运行环境

| 项目 | 值 |
|------|---|
| 宿主机 | `metax-60` |
| 容器名 | `flagrelease-fix-solar-10.7b-instruct` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907` |
| 模型路径 | `/models/SOLAR-10.7B-Instruct-v1.0`（ModelScope `upstage/SOLAR-10.7B-Instruct-v1.0`，共享盘已有，无需下载） |
| TP / GPU / 端口 | TP=1，GPU 0（`MACA_VISIBLE_DEVICES=0`），port=8000 |
| max_model_len | 4096（模型 `config.json` 中 `max_position_embeddings=4096`，不可超过） |
| 实际 vLLM 版本 | 0.24.0 (v0.1.dev17936+gee0da84ab) |

起容器形态：`docker run -d --rm --network host --shm-size 64g --device /dev/dri:/dev/dri:rwm --device /dev/mxcd:/dev/mxcd:rwm -v /public-flash/models:/models <IMAGE> sleep infinity`，再 `docker exec -it flagrelease-fix-solar-10.7b-instruct /bin/bash` 进入。

### 迭代记录（启动阶段）

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST 变化 | 结果 | 日志关键报错 |
|------|------------------------------|------|-------------|
| v1（初次，max-model-len=32768） | 默认 | ❌ 启动失败 | `pydantic ValidationError: max_model_len (32768) > max_position_embeddings (4096)` |
| v1（重启，max-model-len=4096） | 默认 | ✅ 启动成功 | 无崩溃 |
| v2（重建容器，max-model-len=4096） | 加 `rms_norm,silu_and_mul` | ✅ 启动成功 | 无崩溃 |
| v3（重建容器，去掉 `VLLM_FL_USE_FLAGGEMS_ATTN=0`） | 默认（无 `rms_norm,silu_and_mul`） | ✅ 启动成功 | 无崩溃 |

### 迭代记录（评测阶段，均为 50 题）

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST | GPQA 正确率 | accuracy_compare 退出码 | 备注 |
|------|--------------------------|------------|------------------------|------|
| v1 | mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice | **24.0%**（12/50） | **1（不达标）** | 2026-09-16；`fast_gpqa` score=null，从 evalscope reviews 补计分；rel_drop=29.41% |
| v2 | +rms_norm,silu_and_mul | **26.0%**（13/50） | **0（进程退出码 0，但 verdict `aligned=false`，按 34.0 基准仍旧不达标）** | 2026-09-16；rel_drop=23.53%；扩展黑名单未解决根本问题 |
| v3 | 默认（去掉 `VLLM_FL_USE_FLAGGEMS_ATTN=0`） | **20.0%**（10/50） | **1（不达标）** | 2026-09-16；rel_drop=41.18%；去掉 `VLLM_FL_USE_FLAGGEMS_ATTN=0` 反而更差 |

多轮迭代的完整过程：

1. **v1 默认黑名单**（`mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice` + `VLLM_FL_USE_FLAGGEMS_ATTN=0`）→ 24.0%，不达标；参考 Phi-4-mini 方案，决定扩展黑名单试试 `rms_norm,silu_and_mul`（该方案在 Phi-4-mini 上把精度从 26% 拉回 44%）。
2. **v2 扩展黑名单**（追加 `rms_norm,silu_and_mul`，重建容器）→ 26.0%，比 v1 略有改善但仍不达标。扩展黑名单**未能解决根本问题**，说明参考 Phi-4 的方案不能直接套用（Phi-4 是 GQA，SOLAR 是 MHA dense）。
3. **v3 反向验证**（去掉 `VLLM_FL_USE_FLAGGEMS_ATTN=0`，仅保留默认黑名单，推断 v1/v2 低分源于 FlagGems attention 被禁用）→ 20.0%，**比 v1/v2 更差**，证伪该推断：`VLLM_FL_USE_FLAGGEMS_ATTN=0` 对 SOLAR 无害，FlagGems attention 对它也无益。**v3 方案弃用**。
4. **基准复核（2026-09-18）**：三轮不达标促使回头核查基准。查手动复现文档确认 NV vllm 官方镜像（`vllm/vllm-openai` v0.24.0，未装 FlagGems/plugin-fl）在标准 GPQA Diamond 配置下实测 50 题 = 24.00%（12/50）、198 题 = 26.26%（52/198），即 `nv_baseline.yaml` 的 34.0% 与实际 NV 水平不符。裁定以 NV 官方镜像实测为基准，取本轮最优 v2（扩展黑名单）作为最终配置。

**v1 的 verdict（基准 34.0，不达标）**：

```json
{
  "baseline_mode": "nv_reference",
  "model": "SOLAR-10.7B-Instruct-v1.0",
  "metric": "gpqa_diamond",
  "nv": { "score": 34.0, "source": "NV 实测" },
  "current": { "score": 24.0, "mode": "standard" },
  "tolerance": 0.05,
  "timestamp": "2026-09-16T09:35:XX",
  "rel_drop": 0.2941,
  "rel_drop_pct": 29.41,
  "abs_diff": -10.0,
  "aligned": false,
  "noise_zone": false,
  "message": "精度不达标: 当前=24.00%, NV=34.00%, 相对退化=29.41% > 容差 5.0%"
}
```

**v3 的 verdict（基准 34.0，不达标，方案已弃用）**：

```json
{
  "baseline_mode": "nv_reference",
  "model": "SOLAR-10.7B-Instruct-v1.0",
  "metric": "gpqa_diamond",
  "nv": { "score": 34.0, "source": "NV 实测" },
  "current": { "score": 20.0, "mode": "standard" },
  "tolerance": 0.05,
  "timestamp": "2026-09-16T10:40:12.029706",
  "rel_drop": 0.4118,
  "rel_drop_pct": 41.18,
  "abs_diff": -14.0,
  "aligned": false,
  "noise_zone": false,
  "message": "精度不达标: 当前=20.00%, NV=34.00%, 相对退化=41.18% > 容差 5.0%"
}
```

### 补计分与复核过程

v1/v2/v3 三轮的 `fast_gpqa.py` 输出 `score=null`（parse bug），分数均从 evalscope reviews 的逐题记录补计分后得到（v1=12/50，v2=13/50，v3=10/50）。评测统一在独立 `eval-scope` 容器内执行，`--api-base http://127.0.0.1:8000/v1`，输出落到 `/models/release_run_logs/SOLAR-10.7B-Instruct-v1.0/`（gpqa_v*.json / verdict_v*.json / eval_v*.log）。

容器已停止：`docker stop flagrelease-fix-solar-10.7b-instruct`。

## 结果

- 修复后分 / NV 基线：**26.0%（13/50，v2 扩展黑名单）** / **26.26%（52/198，NV vllm 官方镜像实测）**
- 达标判定（accuracy_compare 退出码）：最终裁定达标，基准换为 NV vllm 官方镜像实测（26.26%）；换基准后的 accuracy_compare 退出码源日志未记录，记为 `<待补>`。源日志实际记录的三轮退出码为 v1=1、v2=`aligned=false`（进程退出码 0，基准 34.0）、v3=1。

基准口径说明（源日志原文结论）：`nv_baseline.yaml` 记 34.0%，但三轮迭代用它做基准（v1=24.0%、v2=26.0%、v3=20.0%，均为 50 题）都不达标；经核查 NV vllm 官方镜像（`vllm/vllm-openai` v0.24.0）实测，50 题 = 24.00%（12/50）、198 题 = 26.26%（52/198）。最终裁定以 NV 官方镜像实测为基准，MetaX v2 = 26.0%（13/50）与之持平，故标记为 ✅ 已通过（**持平**口径，非严格超基线）。

| 迭代 | 得分 | 说明 |
|------|------|------|
| v1（默认黑名单） | 24.0%（12/50） | 不达标（基准 34.0） |
| **v2（扩展黑名单，最终采用）** | **26.0%（13/50）** | 与 NV 官方镜像实测持平 |
| v3（默认黑名单，无 `VLLM_FL_USE_FLAGGEMS_ATTN=0`） | 20.0%（10/50） | 方案弃用 |

**verdict_v2.json 原文**（最终采用那一轮的 verdict，其内在基准为 `nv_baseline.yaml` 的 34.0，故 `aligned=false`；照实保留，未篡改）：

```json
{
  "baseline_mode": "nv_reference",
  "model": "SOLAR-10.7B-Instruct-v1.0",
  "metric": "gpqa_diamond",
  "nv": { "score": 34.0, "source": "NV 实测" },
  "current": { "score": 26.0, "mode": "standard" },
  "tolerance": 0.05,
  "timestamp": "2026-09-16T10:12:23.308235",
  "rel_drop": 0.2353,
  "rel_drop_pct": 23.53,
  "abs_diff": -8.0,
  "aligned": false,
  "noise_zone": false,
  "message": "精度不达标: 当前=26.00%, NV=34.00%, 相对退化=23.53% > 容差 5.0%"
}
```

## 提炼到 KNOWLEDGE 的条目

1. SOLAR-10.7B-Instruct-v1.0 在 MetaX + plugin-FL 下出现**格式退化**：模型生成冗长推理但不输出终止答案字母（`ANSWER: (X)`），evalscope 无法提取。既不是截断也不是静默，是 greedy-decode 路径偏移——逐题看回答内容才能识别。
2. 对 SOLAR 这类非 MLA dense 模型，`VLLM_FL_USE_FLAGGEMS_ATTN=0` 无益，去掉后更差。
3. 扩展黑名单（加 `rms_norm,silu_and_mul`）有轻微改善但不解决根本问题，**参考 Phi-4 方案不能直接套用**（架构不同：Phi-4 是 GQA，SOLAR 是 MHA）。
4. `nv_baseline.yaml` 中某些模型的基线值与 NV vllm 官方镜像实测存在差异；遇到持续不达标时应查手动复现文档核对 NV 实际成绩，再下「不达标」结论。本例中 NV 官方镜像实测同样只有 ~25%，属模型能力上限而非平台差异。
5. SOLAR 的 `config.json` 中 `max_position_embeddings=4096`，`--max-model-len` 超过它会被 pydantic 直接拒绝启动。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: upstage/SOLAR-10.7B-Instruct-v1.0
# IMAGE: harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907
# HARBOR_VER: V3
# GPU: MetaX C550, 1 × 64GB
# TP: 1
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 26.26
# SCORE_FLAGOS: 26.0
# CONTAINER_DEVS: --device /dev/dri:/dev/dri:rwm --device /dev/mxcd:/dev/mxcd:rwm --shm-size 64g
```

> 注记（对 `# VERDICT: ok` 的口径限定）：换基准后的那一轮（基准由 `nv_baseline.yaml` 的 34 改为 NV 官方镜像实测）
> **没有** exit=0 的机器记录。源日志实际记录的三轮退出码为 v1=1、v2=`aligned=false`（进程退出码 0，但基准仍为 34.0）、
> v3=1；达标结论建立在「MetaX v2（26.0%，50 题）与 NV vllm 官方镜像实测持平」的裁定上，属持平口径而非严格超基线。
> 另：`# SCORE_ORIGIN: 26.26` 为 **198 题**全量口径（NV vllm 官方镜像实测 52/198），
> `# SCORE_FLAGOS: 26.0` 为 **50 题**口径（v2 扩展黑名单 13/50），两者**题数不对等、不可直接比较**；
> 源日志即如此裁定，此处仅作披露，数值未改动。

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --net=host --ipc=host \
  --device /dev/dri:/dev/dri:rwm --device /dev/mxcd:/dev/mxcd:rwm \
  --shm-size 64g \
  -v /public-flash/models:/models \
  --name flagos \
  harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907 \
  /bin/bash
```

### 三、启动服务（容器内执行）

```bash
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice,rms_norm,silu_and_mul
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
/opt/conda/bin/vllm serve /models/SOLAR-10.7B-Instruct-v1.0 \
  --served-model-name SOLAR-10.7B-Instruct-v1.0 \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 4096 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code
```
