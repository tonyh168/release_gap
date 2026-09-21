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

- **不是推理模型**：名字不含 `qwen3`/`qwq` 等关键词，`generation_config.json` 虽写 `temperature=0.7`，
  但 `fast_gpqa.detect_thinking()` 将其判定为 standard → `temperature=0.0` 贪心。
  这与 QwQ/TinyR1 的情况不同——**Qwen2.5-Instruct 系列官方推荐的就是贪心解码**，
  且历史上其他厂商（如 hygon/Qwen2.5-7B-Instruct）也是按 standard 口径评测，
  **本模型不打算套用 thinking wrapper**（见「评测参数」节）。
- **attention backend**：普通 GQA → **`TRITON_ATTN`**（不能用 `TRITON_MLA`）。
- **TP 估算**：bf16 权重 ~145 GB ÷ 32 GB/卡 ≈ 4.5 → 向上取 2 的幂次 → **TP=8**（与 XingChen4 参考一致）。
  8 卡总显存 256 GB，权重占 145 GB（57%），KV cache 与激活余 ~110 GB，
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
  --output /models/release_run_logs/Qwen2.5-72B-Instruct/gpqa.json
python3 accuracy_compare.py \
  --v2 /models/release_run_logs/Qwen2.5-72B-Instruct/gpqa.json \
  --nv-baseline Qwen2.5-72B-Instruct \
  --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/Qwen2.5-72B-Instruct/verdict_gpqa_iter1.json
"
```

达标口径：`(v2 - 56.0) / 56.0 ≥ -5%`，即 **≥ 53.2%** 判达标（50 题，另有小样本容忍：绝对差 ≤2 题）。

---

## 迭代记录

| iter | 配置 | GPQA | vs 56.0 | runaway / 截断 | 判定 |
|:----:|------|:----:|:-------:|:---:|:---:|
| 1 | graph 优先（失败回退 eager）/ TP=8 / TRITON_ATTN / mlen=32768 | *(见下)* | | | |

---

## 🔄 无人值守运行状态（2026-09-21 19:03 交接）

> **用户 19:03 退出 session，流程转为后台无人值守。**

**driver 脚本**：`/root/qwen25-72b-driver.sh`（宿主机）
**NFS 副本**：`/mnt/share/models/release_run_logs/Qwen2.5-72B-Instruct/driver.sh`（机器重启后可从这里复原）
**全程日志**：`/mnt/share/models/release_run_logs/Qwen2.5-72B-Instruct/driver.log`

**脱离会话验证（已实测）**：driver 进程 `PPID=1`、`SID=PGID=自身 PID`（`setsid` 完全脱离），
**ssh 断开 / session 结束都不会影响它**。

**交接时刻状态**：

| 项 | 状态 |
|----|------|
| driver 进程 | ✅ 存活（PID 1499720），停在 Phase 1 |
| 权重下载 | 🔄 **51 GB / ~145 GB（11/37 分片）**，`modelscope download` 运行中 |
| 端口 8015 | ⬜ 空（服务未起） |
| serve 日志 | ⬜ 未生成 |

**driver 后续自动执行**（无需人工介入）：

1. 轮询到 `modelscope download` 退出 → 校验分片数是否为 37（不足则 FATAL 停下）
2. 起 **graph** 服务（util 0.85 / max-num-seqs 16 / blacklist 含 `broadcast_to,mm,addmm`）
3. 等就绪最多 30 分钟 → 失败则**自动回退 eager**（util 0.9 / 最小黑名单 + `--enforce-eager`）
4. 冒烟（短 prompt + 256-token 单请求吞吐实测，为并发探测提供依据）
5. `fast_gpqa.py` 跑 gpqa_diamond 50 题（每 10 分钟往 driver.log 报一次进度）
6. `accuracy_compare.py` 出 `verdict_gpqa_iter1.json`（基线 56.0，达标线 ≥53.2%）

**预计时间线**：下载约 19:25 完成 → 服务就绪 19:30~20:00（graph 需图捕获，比 eager 慢）
→ 评测（graph 下预计 1~3 小时，取决于并发探测选到几路）。

**⚠️ 回来后需要做的**：
- 读 `driver.log` 的 `SERVE_MODE=` 行，确认**最终跑的是 graph 还是回退了 eager**（这个结论对后续 dense 模型有参考价值）
- 回填本文件「迭代记录 / 结果 / 提炼到 KNOWLEDGE」三节
- 更新 `STATUS.md` 的计数与状态表行
- ⚠️ 若 driver 在 FATAL 处停下（分片数 <37、或两种模式都没起来），日志尾部会有 `driver end (FAILED)`，需人工介入

---

## 结果

*(待评测完成后填写)*

---

## 提炼到 KNOWLEDGE 的条目

*(待填写)*
