# iluvatar/Qwen2.5-72B-Instruct 修复日志

- **失败报告**：暂无（`flagrelease_fail_reports/Iluvatar/` 下无该模型报告；本模型为 2026-09-21 新增对象，历史上未评测过）
- **原始失败类型**：无（新增对象，从零走 SOP）
- **日期**：2026-09-21

## 现象

- 本模型**不在任何厂商的失败报告里**（`flagrelease_fail_reports/` 与 578 KB 的 zip 内均无该模型），
  属"未开始"类新对象，没有可参照的原始失败类型，按 SOP 从零完成"起容器 → 下权重 → 起服务 → 评测"。
- 本轮**未出现算子 crash、未出现精度退化、未出现 OOM**，首轮评测即达标：
  GPQA Diamond 50 题 **`56.0%`**，与 NV 基线 `56.0%` **完全相等**（28/50），
  相对退化 `0.00%`，`accuracy_compare` 退出码 `0`，`aligned=true`。
- 评测过程**干净**：`runaway 0/50`、`truncation_detected=false`、`mode=standard`，
  评测耗时 `579.25s`（约 9 分 39 秒，并发 8）。
- 唯一"故障"来自**自建的无人值守 driver 脚本**（共 5 个脚本 bug），表现为
  "服务看起来起不来 / 评测看起来卡住"，实际与模型、算子、平台均无关 —— 详见「处置」。

## 定位

- **架构定位（决定 attention backend）**：`Qwen2ForCausalLM`，`num_attention_heads=64` /
  `num_key_value_heads=8`，是**标准 GQA 而非 MLA**，因此用 `TRITON_ATTN`，**不能用 `TRITON_MLA`**。

  ```json
  {"architectures": ["Qwen2ForCausalLM"], "model_type": "qwen2",
   "hidden_size": 8192, "num_hidden_layers": 80,
   "num_attention_heads": 64, "num_key_value_heads": 8,
   "vocab_size": 152064, "max_position_embeddings": 32768, "torch_dtype": "bfloat16"}
  ```

- **TP 定位**：bf16 权重实测 `136 GB`（37 个 safetensors 分片）。单卡 32 GB →
  `136 / 32 ≈ 4.25`，向上取 2 的幂次 → **TP=8**。8 卡合计 256 GB，权重占 53%，
  实测 KV cache `222,352 tokens`（32768 token/请求下最大并发 6.79×），余量满足 SOP「每卡剩 30–40%」。

- **采样口径定位（本轮唯一的"真问题"）**：模型 `generation_config.json` 声明
  `do_sample=true / temperature=0.7 / top_p=0.8 / top_k=20 / repetition_penalty=1.05`。
  但 `fast_gpqa.py` 的 `resolve_gen_params()` 虽有"采纳模型 gen config"的逻辑，
  其 `_resolve_model_dir()` **只在 `--model-name` 是本地目录路径时才生效**；
  流水线里 `--model-name` 传的是 NV 表 key（`Qwen2.5-72B-Instruct`）→ **定位不到模型目录 →
  静默回退成贪心 `temperature=0.0`**，且只打印一行"沿用默认采样参数"，不报错。
  这与 `detect_thinking()` 误判是**两个方向相反**的坑：本模型判 `standard` 是对的
  （Qwen2.5-Instruct 是普通 instruct 模型，不是推理模型），**但 standard ≠ 必须贪心**。

- **服务模式定位（graph vs eager）**：本模型无任何历史崩溃记录，
  且 72B dense 计算量约为 14B 的 5 倍，eager 下评测墙钟时间不可接受 →
  **无需 `--enforce-eager`**，改为 graph 优先、失败回退 eager。
  实测 graph 模式**图捕获顺利通过**，全程没有 `Enforce eager set, disabling torch.compile and CUDAGraphs`。

- **无人值守 driver 定位**：5 个 bug 形状完全一致 —— **失败被伪装成"还在进行中"**：
  ① `docker exec` 内用**宿主机路径**做重定向（容器只挂了 `/mnt/share/models -> /models`，
  容器内没有 `/mnt/share`）→ 重定向失败 → **整条 `vllm serve` 根本没执行**；
  ② `pgrep -f "vllm serve"` **自匹配**父 `bash -c` 的 cmdline → 存活检查恒为真；
  ③ `kill -0 $PID` 对**僵尸进程**仍返回 0 → 评测算死了也测不出来；
  ④ `docker exec` **不带 `-i`** → heredoc 的 stdin 被静默吞掉；
  ⑤ 部署版 `_split_datasets(None)` 返回 `['None']` → `or 默认值` 兜底永不触发 → 评测秒退。

## 处置

机器 `iluvatar-139`（原定 117，当日 117 被他人占用改用 139），推理容器
`flagrelease-fix-qwen2.5-72b-instruct`，评测容器 `eval-scope`，端口 `8015`，TP=8，bf16。
模型 `/mnt/share/models/flagrelease/fixes_models/Qwen2.5-72B-Instruct`
→ 容器内 `/models/flagrelease/fixes_models/Qwen2.5-72B-Instruct`。
本轮**未重新构建/推送镜像**，未修改 vLLM、`vllm-plugin-FL`、FlagGems 源码。

权重来源 `Qwen/Qwen2.5-72B-Instruct`（ModelScope 官方仓库，一次命中，无 404，无需 HF 回退）。

**服务配置（最终达标配置）**

| 项目 | 值 |
|------|---|
| 启动模式 | **graph**（`--max-num-seqs 16 --cudagraph-capture-sizes 16`，**不加** `--enforce-eager`） |
| 黑名单 | `VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,mm,addmm,broadcast_to` |
| `--gpu-memory-utilization` | `0.85` |
| `--max-model-len` | `32768`（= `max_position_embeddings`，显式给满，避开自动推导→截断的坑） |
| `--attention-backend` | `TRITON_ATTN` |
| 启动耗时 | `5m10s`（加载 37 分片约 2min + `torch.compile` 36.65s + 图捕获 22s） |

**采样口径修复（本轮唯一的脚本层改动）**

给 `fast_gpqa.py` 新增 `--model-dir` 选项，显式指定模型权重目录（容器内路径），
优先级高于 `--model-name`，从而打通 `_resolve_model_dir()`。**纯增量，不传时行为与改动前完全一致**，
因此不动其它模型已出分数的可比性。评测命令改为：

```bash
python3 fast_gpqa.py --model-name Qwen2.5-72B-Instruct \
  --api-base http://127.0.0.1:8015/v1 \
  --dataset gpqa_diamond \
  --model-dir /models/flagrelease/fixes_models/Qwen2.5-72B-Instruct \
  --output /models/release_run_logs/Qwen2.5-72B-Instruct/gpqa.json
```

生效判据为评测日志出现 `[gen] 采用模型 generation_config.json 采样参数: {...}`。
**三层验证**（不只信脚本自报）：

| 层 | 证据 |
|----|------|
| ① 脚本自报 | `[gen] 采用模型 generation_config.json 采样参数: {'temperature': 0.7, 'top_p': 0.8, 'top_k': 20, 'repetition_penalty': 1.05}` |
| ② evalscope 实际任务配置 | `outputs/gpqa_diamond/20260921_141748/configs/task_config.yaml` 内 `temperature: 0.7 / top_p: 0.8 / top_k: 20 / repetition_penalty: 1.05 / max_tokens: 24576 / eval_batch_size: 8` |
| ③ 与模型自带配置比对 | 与 `generation_config.json` 逐字段一致（`pad/bos/eos` 除外） |

**无人值守 driver 的 5 个 bug 及修复（v2 → v3 → v4）**

| 轮次 | 现象 | 根因 | 修复 |
|------|------|------|------|
| v2 | graph 与 eager 都"超时未就绪"，`driver end (FAILED)`；但 8 张卡全程 68MiB、serve 日志从未生成 | ① 容器内用了宿主机路径重定向 → 整条命令静默不执行；② `pgrep` 自匹配 → 存活检查恒为真 | 容器内一律写 `/models/...`；判活改 `pgrep -f "[v]llm serve"`；启动后加 **90 秒硬校验**（进程在 + 日志非空），实测 5 秒通过 |
| v3 | 服务起来了（`SERVE_MODE=graph`），但评测阶段秒退/空等 | ③ `kill -0` 测不出僵尸进程；④ `docker exec` 缺 `-i` 吞 heredoc；⑤ `_split_datasets` 缺 None 守卫 → `[ERROR] 未知数据集: ['None']` | 判活改 `pgrep -f "[f]ast_gpqa"` 并用"输出文件是否写出"区分跑完/崩溃；改 `docker exec -i`；`fast_gpqa.py` 补回 None 守卫（NFS + eval-scope + 仓库三处同步），driver 侧同时显式传 `--dataset` |
| v4 | — | — | **复用 v3 已起的 graph 服务、不重启服务**；新增"启动宽限 60s + 进程消失即判定结果"；新增 4a 小样本 `--limit 2` 先验。**一次通过** |

> ⚠️ bug ⑤ 影响面最大：**SOP 第 4 节的评测命令模板本身就没写 `--dataset`**，照抄即踩。
> 已同步修正 `SOP.md` 的命令模板（补 `--dataset` 与 `--model-dir`）。
>
> 通用教训：无人值守脚本里**每一个"等待/判断"都必须有能证伪的快速路径**；
> 凡等待，都要同时校验**进程存在 + 日志非空 + 输出文件写出**这类互相独立的证据，
> 而不是只信单一返回值。已沉淀进 `_shared/KNOWLEDGE.md` 第七节与第七之二节。

**评测参数**

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | evalscope（评测容器 `eval-scope` 内置） |
| 题数 | 50 |
| `eval_batch_size` | 8（自动探测） |
| 模式 | `standard`（**不套 thinking wrapper**） |
| `temperature` / `top_p` / `top_k` / `repetition_penalty` | `0.7` / `0.8` / `20` / `1.05`（模型自带 `generation_config.json`） |
| `max_model_len` | `32768` |
| `max_tokens` | `24576`（`clamp(32768-8192, 4096, 32768)`） |
| 截断检测 | `truncation_detected=false` |
| 复读检测 | `runaway 0/50` |
| 评测耗时 | `eval_duration=579.25s`，`total_duration=594.89s` |

## 结果

- **修复后分 / NV 基线**：GPQA Diamond **`56.0%`** / NV **`56.0%`**，相对退化 **`0.00%`**（`abs_diff=0.0`）
- **达标判定（accuracy_compare 退出码）**：**`0`（达标）**，`aligned=true`，`noise_zone=false`
- 判定原文：`精度达标: 当前=56.00%, NV=56.00%, 相对退化=0.00% (容差 5.0%)`
- 附加健康指标：`runaway 0/50`、`truncation_detected=false`、`mode=standard` —— **一次干净达标**
  （不同于 MiroThinker 那种 runaway 70%、达标全靠能收尾题目的勉强情形）

**历次对比**

| 轮次 | 配置 | GPQA | 判定 |
|:----:|------|:----:|:----:|
| — | v2 driver（脚本 bug，vLLM 从未启动） | — | ❌ 空跑，与模型无关 |
| — | v3 driver（服务成功，评测阶段脚本 bug） | — | ✅ 确认 `SERVE_MODE=graph` |
| **1** | **graph + `--model-dir` 采样（最终配置）** | **56.0%** | ✅ **达标** |

**本轮最有价值的副产品（对后续 dense 模型）**

| 模型 | 单请求解码吞吐（graph 模式） |
|------|:---:|
| Fathom-R1-14B（14B dense） | 18.97 tok/s |
| **Qwen2.5-72B-Instruct（72B dense）** | **约 18 tok/s（仅慢 7%）** |

72B dense 在 graph 模式 + 扩黑名单（`sort,sort_stable,mm,addmm,broadcast_to`）下
**能顺利图捕获并按 5 分钟级启动**，说明「去掉 `--enforce-eager`」这条经验
**对更大的 dense 模型同样成立**，不是小模型专属。若回退 eager（按 5.4~8.7× 损失估）
单请求约 2 tok/s，50 题评测需数天 —— graph 优先换来的是"当天出分"与"跑不完"的差别。

## 提炼到 KNOWLEDGE 的条目

1. **`fast_gpqa.py` 的 `generation_config.json` 采纳逻辑需要 `--model-dir` 才在流水线里生效**
   （`--model-name` 传 NV key 时 `_resolve_model_dir()` 两条路径都不通 → **静默回退贪心**）。
   已新增该选项（纯增量）。判据：评测日志出现 `[gen] 采用模型 generation_config.json 采样参数:`。
2. **「是不是推理模型」与「用什么采样」是两件事，不能互相推导**：
   判是否 thinking 看**模型卡/README**（不看 `generation_config.json` 里有没有温度）；
   判采样优先按**模型自带 `generation_config.json`**。本模型判 `standard` 正确，
   但采样仍是 `0.7/0.8/20/1.05`，**不是贪心**。
3. **graph 模式对 72B dense 同样有效**，不因模型变大而失效（72B 与 14B 单请求吞吐仅差 7%）。
   **起服务前先确认是否真的需要 `--enforce-eager`。**
4. **无人值守 driver 的失败会伪装成"还在进行中"**（本轮一次踩 5 个）：
   重定向失败=静默不执行 / `pgrep` 自匹配=永远活着 / 僵尸进程=永远活着 /
   `docker exec` 缺 `-i`=静默无输出 / `_split_datasets` 缺 None 守卫=静默走错分支。
   **对策：凡等待都要校验能证伪的独立正向证据（进程在 + 日志非空 + 输出文件写出）。**
5. ⚠️ **SOP 第 4 节的评测命令模板没写 `--dataset`，照抄会踩**
   `_split_datasets(None) → ['None'] → [ERROR] 未知数据集` 的坑（脚本已修，模板已补）。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: Qwen/Qwen2.5-72B-Instruct
# IMAGE: harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
# HARBOR_VER: V3
# VLLM_VER: 0.24.0
# PLUGIN_FL_VER: 0.2.0+g0f61b3d76
# FLAGGEMS_VER: 5.3.4.post1.dev11+gbc6d9426c
# FLAGTREE_VER: 0.6.0+iluvatar.git3821582d
# FLAGCX_VER: -
# GPU: Iluvatar BI-V150, 8 x 32GB
# TP: 8
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 56.0
# SCORE_FLAGOS: 56.0
# CONTAINER_DEVS: --device=/dev/iluvatar0..15 --device=/dev/itrctl --device=/dev/itrlink --device=/dev/itr_peerm_dev0 --ipc=host --network=host --shm-size=64g
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --net=host --ipc=host \
  --device=/dev/iluvatar0  --device=/dev/iluvatar1  --device=/dev/iluvatar2  --device=/dev/iluvatar3 \
  --device=/dev/iluvatar4  --device=/dev/iluvatar5  --device=/dev/iluvatar6  --device=/dev/iluvatar7 \
  --device=/dev/iluvatar8  --device=/dev/iluvatar9  --device=/dev/iluvatar10 --device=/dev/iluvatar11 \
  --device=/dev/iluvatar12 --device=/dev/iluvatar13 --device=/dev/iluvatar14 --device=/dev/iluvatar15 \
  --device=/dev/itrctl --device=/dev/itrlink --device=/dev/itr_peerm_dev0 \
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
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,mm,addmm,broadcast_to
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
vllm serve /models/flagrelease/fixes_models/Qwen2.5-72B-Instruct \
  --served-model-name Qwen2.5-72B-Instruct \
  --dtype bfloat16 \
  --tensor-parallel-size 8 \
  --gpu-memory-utilization 0.85 \
  --max-model-len 32768 \
  --max-num-seqs 16 \
  --cudagraph-capture-sizes 16 \
  --port 8015 \
  --attention-backend TRITON_ATTN \
  --trust-remote-code
```

### 四、开启算子列表

```json
[
  "_unsafe_view",
  "add",
  "alias",
  "arange_start",
  "argmax",
  "bitwise_or_tensor",
  "cat",
  "copy_",
  "cos",
  "cumsum_out",
  "empty",
  "eq_scalar",
  "expand",
  "expand_as",
  "exponential_",
  "fill_scalar_",
  "flatten",
  "full",
  "gather",
  "gt_scalar",
  "index",
  "le",
  "lift_fresh",
  "lt",
  "lt_scalar",
  "masked_fill_",
  "mul",
  "mul_",
  "narrow",
  "ones",
  "ones_like",
  "pow_scalar",
  "rand_like",
  "randn",
  "reciprocal",
  "rsub_scalar",
  "scalar_tensor",
  "scatter_",
  "scatter_add_0",
  "sin",
  "softmax",
  "softmax_out",
  "sub",
  "sub_",
  "to_copy",
  "true_divide",
  "true_divide_",
  "unbind",
  "unsqueeze",
  "where_self",
  "where_self_out",
  "zero_",
  "zeros"
]
```
