# iluvatar/Qwen2.5-72B-Instruct 修复日志

- **失败报告**：无（`flagrelease_fail_reports/Iluvatar/` 下无该模型报告，2026-09-21 新增对象）
- **原始失败类型**：未开始
- **修复日期**：2026-09-21 起
- **机器**：`iluvatar-139`（原定 117，2026-09-21 当天 117 被他人占用，改用 139）

---

## 背景分析

Qwen2.5-72B-Instruct 是 Qwen2 系 dense decoder（`Qwen2ForCausalLM`），标准 GQA，**非 MLA**：

```
architectures=Qwen2ForCausalLM  model_type=qwen2
hidden_size=8192  num_hidden_layers=80  num_attention_heads=64  num_key_value_heads=8
vocab_size=152064  max_position_embeddings=32768  torch_dtype=bfloat16
```

- **不是推理模型**：名字不含 `qwen3`/`qwq` 等关键词，`fast_gpqa.detect_thinking()` 判定为 standard，
  **不套 thinking wrapper**（不加 `remove_until`，不用 0.6/0.95 那套）。这与 QwQ/TinyR1 的情况不同——
  Qwen2.5-Instruct 系列本来就该按 standard 口径评。
- **采样参数取模型自带的 `generation_config.json`**（用户 2026-09-21 明确要求）：
  `temperature=0.7 / top_p=0.8 / top_k=20 / repetition_penalty=1.05`（`do_sample=true`）。
  > 📌 这里要避免**两个方向的误判**：① 「gen config 里有温度 ≠ 它是推理模型」——它仍是 standard 分支，
  > 不加 thinking wrapper；② 「判成 standard ≠ 就必须贪心」——本模型官方 gen config 明写 `do_sample=true`，
  > 按用户要求**以模型自带生成配置为准**，而不是沿用评测脚本的贪心默认。
  > 落地方式：给 `fast_gpqa.py` 加了 `--model-dir`（见 STATUS 专节），
  > 实测确认生效：`temperature=0.7, top_p=0.8, top_k=20, repetition_penalty=1.05`。
- **attention backend**：普通 GQA → **`TRITON_ATTN`**（不能用 `TRITON_MLA`）。
- **TP 估算**：bf16 权重实测 136 GB ÷ 32 GB/卡 ≈ 4.25 → 向上取 2 的幂次 → **TP=8**（与 XingChen4 参考一致）。
  8 卡总显存 256 GB，权重占 136 GB（53%），KV cache 与激活余 ~120 GB，
  满足 SOP「每卡剩 30–40% 空余」。
- **权重来源**：`Qwen/Qwen2.5-72B-Instruct`（ModelScope 官方仓库，一次命中，无需 HF 回退）。

---

## 环境

| 项目 | 值 |
|------|----|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-qwen2.5-72b-instruct` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/Qwen2.5-72B-Instruct`（宿主 `/mnt/share/models/...`） |
| 卡号 | `CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7`（TP=8） |
| 端口 | 8015 |
| attention-backend | `TRITON_ATTN`（Qwen2 GQA，非 MLA） |
| 评测指标 | `gpqa_diamond`（NV 基线 **56.0**，`nv_baseline.yaml` 有该指标，无需回退） |
| 实际 vLLM 版本 | 0.24.0（vllm_fl 0.24.0） |

---

## Step 0：登录 + 查卡

```bash
ssh iluvatar-139
/usr/local/corex-4.5.0/bin/ixsmi          # ⚠️ 宿主机 PATH 里没有 ixsmi，必须写全路径
docker ps --format '{{.Names}}\t{{.Status}}'
```

> ⚠️ **本机两个与 SOP 不同的实测点**（已回写 `ENV.md`）：
> 1. 宿主机 `ixsmi` **不在 PATH 里**，裸敲报 `command not found` → 用 `/usr/local/corex-4.5.0/bin/ixsmi`。
> 2. **修复容器（xingchen4-0907）里根本没有 `ixsmi` 二进制**（`find / -name "*smi*"` 只有无关文件，
>    `/usr/local/corex/bin` 下是 clang/ixgdb 等编译器工具链）。容器内查卡改用 torch：
>    ```bash
>    python -c "import torch; [print(i, torch.cuda.get_device_properties(i).name, round(torch.cuda.get_device_properties(i).total_memory/1024**3,1)) for i in range(torch.cuda.device_count())]"
>    ```
>    实测：**16 × Iluvatar BI-V150 32 GB**，`torch.cuda.device_count()==16`，`is_available()==True`。

起容器前的占用检查：`ixsmi` 显示 16 张卡全部 `68MiB / 32768MiB`、零进程 → 全机空闲可用。

---

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
model_name=qwen2.5-72b-instruct
docker run -itd --name flagrelease-fix-${model_name} \
  --device=/dev/iluvatar0  --device=/dev/iluvatar1  --device=/dev/iluvatar2  --device=/dev/iluvatar3 \
  --device=/dev/iluvatar4  --device=/dev/iluvatar5  --device=/dev/iluvatar6  --device=/dev/iluvatar7 \
  --device=/dev/iluvatar8  --device=/dev/iluvatar9  --device=/dev/iluvatar10 --device=/dev/iluvatar11 \
  --device=/dev/iluvatar12 --device=/dev/iluvatar13 --device=/dev/iluvatar14 --device=/dev/iluvatar15 \
  --device=/dev/itrctl --device=/dev/itrlink --device=/dev/itr_peerm_dev0 \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  ${IMAGE} bash
docker exec -it flagrelease-fix-${model_name} bash
```

自检：`python -c "import vllm; print(vllm.__version__)"` → **0.24.0**；`torch.cuda.device_count()` → **16**。

---

## Step 2：下载模型权重

ModelScope 一次命中（无 404，**无需 HF 回退**）：

```bash
docker exec -d eval-scope bash -c "
modelscope download --model Qwen/Qwen2.5-72B-Instruct \
  --local_dir /models/flagrelease/fixes_models/Qwen2.5-72B-Instruct \
  > /models/flagrelease/fixes_models/Qwen2.5-72B-Instruct_download.log 2>&1 &
"
```

- 权重 **37 个 `model-XXXXX-of-00037.safetensors` 分片 + 37 个 `.incomplete` 影子文件**，合计 ~145 GB。
  ⚠️ **别用 `ls *.safetensors | wc -l` 判断"下完了没有"** —— `.incomplete` 文件不匹配该 glob，
  分片数是**边下边落盘**的，下载中途就会看到非零值。**唯一可靠的判据是 `modelscope download` 进程还在不在。**
- 实测下载速率受每分片并发数影响波动较大：日志里单分片速度 17–28 MB/s，
  但落盘总量速率可达 **~5 GB/min**（多分片并发）。145 GB 约 **30 分钟**下完。

---

## Step 3：起 vLLM 服务（iter1）

> **执行方式**：全过程由宿主机后台 driver 脚本 `/root/qwen25-72b-driver.sh` 无人值守串起来
> （等下载 → 起服务 → 等就绪 → 冒烟 → 评测 → verdict），日志落在
> `/mnt/share/models/release_run_logs/Qwen2.5-72B-Instruct/driver.log`。
> **服务用「graph 优先、失败回退 eager」两段式**（见下方「为什么 graph 优先」）。

### 3a. graph 模式（首选）

```bash
docker exec -d flagrelease-fix-qwen2.5-72b-instruct bash -c "
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,mm,addmm,broadcast_to
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
model_name=Qwen2.5-72B-Instruct
mkdir -p /models/release_run_logs/\${model_name}
nohup vllm serve /models/flagrelease/fixes_models/\${model_name} \
  --served-model-name \${model_name} --dtype bfloat16 \
  --tensor-parallel-size 8 --gpu-memory-utilization 0.85 \
  --max-model-len 32768 \
  --max-num-seqs 16 --cudagraph-capture-sizes 16 \
  --port 8015 --attention-backend TRITON_ATTN \
  --trust-remote-code \
  > /models/release_run_logs/\${model_name}/serve_graph.log 2>&1 &
echo \$! > /models/release_run_logs/\${model_name}/serve_graph.pid
"
```

### 3b. eager 回退（graph 30 分钟未就绪时自动切换）

```bash
# 同上，但：--gpu-memory-utilization 0.9，去掉 --max-num-seqs/--cudagraph-capture-sizes，
# 黑名单退回 sort,sort_stable，并加回 --enforce-eager
```

**iter1 配置取舍说明：**

- **`--max-model-len 32768`（显式给满）**：模型 `max_position_embeddings=32768`，显式给满有两个好处——
  ① 避开 Phi-4-mini 那种「vLLM 自动推导出 4096 → `auto_max_tokens` 把 `max_tokens` 压到 2048 → 大量截断」的坑；
  ② standard 分支下 `auto_max_tokens = clamp(max_model_len-8192, 4096, 32768) = 24576`，
  对 GPQA 单题输出（通常 <2K token）绰绰有余。**不套用 Qwen3.5-27B 的 65536**：那是为了撑 thinking 的 20000 上限，
  Qwen2.5 是 standard 分支用不到。
- **⚠️ 为什么不用 `--enforce-eager`（与最初判断相反，最终改为 graph 优先）**：
  STATUS「新发现 0」已确认 `--enforce-eager` 同时禁用 torch.compile 与 CUDAGraph，
  在 Fathom/MiroThinker 上分别造成 **5.4× / 8.7×** 的吞吐损失。
  本模型是 **72B dense**，计算量约为 14B 的 5 倍，eager 下 50 题 GPQA 的墙钟时间会不可接受；
  而本模型**没有任何历史崩溃记录**（无失败报告），没有必须 eager 的理由。
  故改为 **graph 优先、eager 兜底**——用 ~30 分钟的最坏回退代价，换掉可能数小时的评测时间。
- **黑名单在 graph 下扩到 `sort,sort_stable,mm,addmm,broadcast_to`**：
  `broadcast_to` 是 Fathom 实测的**图捕获必崩算子**（见其 fix log「graph 模式启动」）；
  `mm,addmm` 一并挡住是防止 GEMM 类 kernel 在图捕获下编译崩（MetaX 同款坑，见 KNOWLEDGE 一）。
  eager 回退路径**退回最小黑名单 `sort,sort_stable`** —— 保住已知能起的配置，不引入未验证变量。
- **`--gpu-memory-utilization` graph 用 0.85、eager 用 0.9**：Fathom 实测残留显存未清时 0.9 会报
  `Free memory ... less than desired GPU memory utilization`，graph 模式额外要留 CUDAGraph 的内存池，
  0.85 更稳。权重占 8 卡总显存的 57%（145/256 GB），两个值都不紧张。

---

## Step 4：GPQA 评测 + 达标判定

```bash
docker exec eval-scope bash -c "
cd /workspace/eval_scripts
python3 fast_gpqa.py --model-name Qwen2.5-72B-Instruct \
  --api-base http://127.0.0.1:8015/v1 \
  --model-dir /models/flagrelease/fixes_models/Qwen2.5-72B-Instruct \
  --output /models/release_run_logs/Qwen2.5-72B-Instruct/gpqa.json
python3 accuracy_compare.py \
  --v2 /models/release_run_logs/Qwen2.5-72B-Instruct/gpqa.json \
  --nv-baseline Qwen2.5-72B-Instruct \
  --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/Qwen2.5-72B-Instruct/verdict_gpqa_iter1.json
"
```

> ⚠️ **`--model-dir` 是本轮新加的选项**（2026-09-21）：不传它时 `_resolve_model_dir()` 定位不到模型目录，
> 采样会**静默回退成贪心**（temp 0.0）——本模型就必须传，否则又变回「贪心误评」。
> 评测日志里出现 `[gen] 采用模型 generation_config.json 采样参数: {...}` 才算生效。

达标口径：`(v2 - 56.0) / 56.0 ≥ -5%`，即 **≥ 53.2%** 判达标（50 题，另有小样本容忍：绝对差 ≤2 题）。

---

## 迭代记录

| iter | 配置 | GPQA | vs 56.0 | runaway / 截断 | 判定 |
|:----:|------|:----:|:-------:|:---:|:---:|
| — | **v2 driver（作废）** | — | — | — | ❌ **空跑失败，非服务问题**：脚本 bug 导致 vLLM 从未启动，见下节 |
| 1 | v3 driver：graph 优先（失败回退 eager）/ TP=8 / TRITON_ATTN / mlen=32768 / **采样取 generation_config.json** | *(待出)* | | | |

---

## ⚠️ 首轮（v2 driver）空跑失败：两个脚本 bug，vLLM 从未启动（2026-09-21 19:26~20:27）

**现象**：driver 日志显示 graph 超时未就绪 → 回退 eager → 又超时 → `driver end (FAILED)`。
**看起来**像"两种模式都起不来 / 平台不稳"。**实际**：**vLLM 一次都没被启动过**。

排查证据（全部指向"从未启动"，而非"启动失败"）：

| 检查 | 结果 |
|------|------|
| `ixsmi` 8 张目标卡 | **全程 68MiB / 32768MiB，0% util** —— 没人跑过 |
| 容器内 `ps -ef \| grep vllm` | 无进程 |
| `serve_graph.log` / `serve_eager.log` | **从未生成**（driver 自己 `tail` 时报 `No such file or directory`） |
| 权重 | ✅ 完好：**37/37 分片，136 GB**（19:26 就下完了，不是下载问题） |

**根因 1（致命）：宿主机路径当容器路径用。**
`start_serve()` 里执行的是

```bash
docker exec -d $CT bash -c "... nohup vllm serve ... > $RUNLOG/serve_$MODE.log 2>&1 &"
```

而 `RUNLOG=/mnt/share/models/release_run_logs/$MODEL` 是**宿主机路径**。
修复容器只挂了 `-v /mnt/share/models:/models`，**容器内没有 `/mnt/share`** →
bash 打开重定向失败 → **整条 `nohup vllm serve` 根本没执行**（也没有任何报错）。

**根因 2：存活检查自匹配。**
`docker exec $CT bash -c 'pgrep -f "vllm serve"'` —— pgrep 只排除自己，
不排除父 `bash -c`，而后者的 cmdline 里就含 `vllm serve` 这串 → **恒返回 0**。
后果：本该第 1 轮就报"进程消失、快速失败"，实际 `grep -c 进程消失` = **0 次**，硬等满 30 分钟 ×2。

**结论**：这两条都是 driver 脚本自身的 bug，**与模型、算子、平台无关**；
「graph 能不能起」这个原本要回答的问题，**本轮没有拿到任何数据**。

**修复（v3）**：

1. 容器内一律用 `/models/release_run_logs/$MODEL`（两个容器都挂了同一目录），宿主机侧只用 `/mnt/share/...` 读日志
2. 存活检查改 `pgrep -f "[v]llm serve"`（字符类让模式串自身不命中）
3. **启动后 90 秒硬校验**：进程在 **且** 日志文件非空，不合格立刻 FAIL 并打印 serve 日志 —— 不再空等 30 分钟
4. 评测加 `--model-dir`；评测命令内部的 `--output` 也全部改成容器内路径
5. 新增 **4a 小样本（`--limit 2`）先验**：先确认整条链路 + `[gen]` 采样参数行，再跑 50 题全量

**实测**：v3 启动后 **5 秒**即通过硬校验（`[graph] 进程与日志均已就位（5s）`），服务真起来了。

---

## 🔄 无人值守运行状态（v3，2026-09-21 21:57 重启）

> **v2 空跑失败（见上节）后，2026-09-21 21:57 用修好的 v3 driver 重启，仍然全程无人值守。**

| 项 | 值 |
|----|----|
| driver 脚本 | `/root/qwen25-72b-driver.sh`（宿主机） |
| NFS 副本 | `/mnt/share/models/release_run_logs/Qwen2.5-72B-Instruct/driver_v3.sh` |
| 全程日志 | `/mnt/share/models/release_run_logs/Qwen2.5-72B-Instruct/driver.log` |
| 脱离验证 | ✅ 进程 `PPID=1`、`SID=PGID=自身 PID`（`setsid`），ssh 断开不影响 |
| 起点 | Phase 1 权重检查直接通过（37/37 分片，136 GB） |
| 硬校验 | ✅ 5 秒通过（进程 + 日志都就位） |

**v3 自动执行链**：起 graph（util 0.85 / max-num-seqs 16 / cudagraph-capture-sizes 16 /
blacklist `sort,sort_stable,mm,addmm,broadcast_to`，超时 **60 分钟**）
→ 失败回退 eager（util 0.9 / 最小黑名单 + `--enforce-eager`，超时 **45 分钟**）
→ 冒烟 + 单请求吞吐实测 → **4a 小样本 `--limit 2`（验证链路与 `[gen]` 采样行）**
→ 4b gpqa_diamond 50 题（最多 12h）→ verdict（基线 56.0，达标线 ≥53.2%）。

**⚠️ 回来后先看这三样**：

1. `driver.log` 的 **`SERVE_MODE=`** 行 —— 确认最终跑的是 **graph** 还是**回退 eager**
   （这个结论对后续 dense 模型有参考价值；v2 那一轮没拿到）
2. **`[gen] 采用模型 generation_config.json 采样参数:`** 行 —— 确认采样口径真的生效
   （temp 0.7 / top_p 0.8 / top_k 20 / rp 1.05），否则评测又变回贪心，分数不可用
3. 尾部若无 `driver end` 而是 `FATAL` / `driver end (FAILED)` → 需人工介入

---

## 结果

*(待评测完成后填写)*

---

## 提炼到 KNOWLEDGE 的条目

*(待填写)*
