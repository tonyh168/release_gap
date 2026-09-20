# 摩尔线程 Mthreads 迁移修复 SOP

完整流程：**宿主机 → 镜像 → 起容器 → 下模型 → 起 vLLM → 评测**。
真实环境值见 [[ENV]]（本目录），命令模板在 `_shared/templates/`，达标口径见 `_shared/EVAL.md`，踩坑经验见 `_shared/KNOWLEDGE.md`。

---

## 0. 前置

- 硬件：MTT S5000 × 8（单卡 80GB，MUSA 生态）。7B 级模型 TP=1，32B 级 TP=2~4。
- 宿主机（ssh 免密，bastion 跳板）：**`mthreads-25` / `mthreads-27`** 可用；
  **`mthreads-26` 当前不可用**（登录报 `match asset failed: No found asset`，2026-09-20 复测两次）。
  **上机第一件事：查卡占用**——这机器一般独占，但用前必须确认没有别人的进程在跑：
  ```bash
  ssh mthreads-25
  mthreads-gmi -q         # 摩尔查卡：看每卡显存/进程；有占用先问清楚再用，别抢卡
  ```
  按空闲卡数和模型大小定 TP（见第 3 节 TP 选卡原则）。
- **镜像**（✅ 已拉取并实测）：
  `harbor.baai.ac.cn/flagrelease-public/flagrelease_mthreads-gmi_vllm024plugin_base:08281629`
  —— 通用基础镜像，**vllm 0.24.0 + plugin-FL 0.3.0 + FlagGems 5.3.2 + Flagtree 0.6.0 + torch 2.9.0**，
  避开了 0.20.2 的 `torch.float4_e2m1fn_x2` 导入崩溃坑。镜像已在 `mthreads-25` 本地（27 需自行 `docker pull`）。
  完整版本表与内置环境变量见 [[ENV]]「软件栈」节。
- **共享盘**（2026-09-20 实测）：**本机型没有 `/public-flash`**。唯一跨机共享盘是
  **`/datapool`（LeoFS 网络盘，50T，剩 38T）**；容器按 **`-v /datapool:/datapool`（内外同路径）** 挂载。
  本项目落盘约定（见 [[ENV]] 存储节）：
  - 权重 → `/datapool/flagrelease/fixes_models/<模型名>`
  - 日志/结果 → `/datapool/flagrelease/release_run_logs/<模型名>/`
- **开工前还需补齐**（25/27 上实测都没有）：`flagos-evalscope` 评测镜像 + `release_评测标准/` 评测脚本。

## 1. 起容器

摩尔线程用**特权容器**透传设备，不需要显式 `--device`（`_shared/templates/01_start_container.sh` 的 mthreads 变体）：

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/flagrelease_mthreads-gmi_vllm024plugin_base:08281629
model_name=<NV表中的key，如 phi-4>       # 容器名用小写，能分辨模型即可
docker run -d \
  --name flagrelease-fix-${model_name} \
  --net=host --ipc=host --privileged \
  --shm-size 64g \
  --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
  --tmpfs /tmp:exec \
  -v /datapool:/datapool \
  ${IMAGE}
# 注：镜像 Cmd 已是 sleep infinity，末尾不必再写。MTHREADS_VISIBLE_DEVICES=all /
#     MTHREADS_DRIVER_CAPABILITIES=all / VLLM_PLUGINS=fl 都已内置，无需 -e 传。
docker exec -it flagrelease-fix-${model_name} /bin/bash
# 容器内自检（以下为 2026-09-20 实测值，可直接对照）
mthreads-gmi                                       # 应看到 8 张 MTT S5000，驱动 3.3.5-server
python -c "import vllm; print(vllm.__version__)"   # 0.24.0，且会打印 Platform plugin fl is activated
pip show vllm-plugin-fl flagtree torch             # 0.3.0 / 0.6.0+mthreads.gitb97f8214 / 2.9.0
python -c "import flag_gems; print(flag_gems.__version__)"   # 5.3.2.post1.dev22+...
```

> ⚠ **起服务前先验 `import vllm`**。若报
> `AttributeError: module 'torch' has no attribute 'float4_e2m1fn_x2'`（栈在 `vllm/ir/tolerances.py`），
> 说明镜像是 vllm 0.20.2 + torch_musa 2.7.1 组合（**本镜像不会如此，出现即说明拿错镜像**）：换 0.24.0 口径镜像，
> 或临时把 `tolerances.py` 里含该 dtype 的条目注释掉再起。见 [[KNOWLEDGE]] 一、服务启动失败。

> ⚠ **别用 `--rm` 起修复容器**：模型下载/评测可能跨天，容器被清掉会丢工作区。确认无用后再手动 `docker rm -f`。
> （上面示例已去掉 `--rm`，与前几版 SOP 不同。）

## 2. 下模型

> ⚠ **约定**：本项目所有模型均以 **ModelScope 为唯一来源**。所有权重统一下载到共享盘
> `/datapool/flagrelease/fixes_models/<模型名>`（容器内**同路径**），再由 `vllm serve` 从本地路径加载；
> 不直接用远程 URL 起服务。来源优先级：**ModelScope 优先，404 再退 HuggingFace**；
> 两个来源都没有 → 立即停下并报告给发起人，不自行换源。

**直接复用第 1 步起的修复容器下载**（镜像已预装 `modelscope` / `hf`，实测均有）：

```bash
docker exec -it flagrelease-fix-${model_name} /bin/bash
mkdir -p /datapool/flagrelease/fixes_models
modelscope download --model <ModelScope仓库/模型ID，如 microsoft/phi-4> \
  --local_dir /datapool/flagrelease/fixes_models/<模型名>
# 若报 404 / model not found → 改用 HuggingFace 备用下载：
# hf download <HuggingFace仓库/模型ID> \
#   --local-dir /datapool/flagrelease/fixes_models/<模型名>
# 若 HuggingFace 也找不到 → 停止，把模型名和报错截图报给发起人
ls /datapool/flagrelease/fixes_models/<模型名>   # 确认 config.json / *.safetensors / tokenizer
```

> 备用：若修复容器不便，也可用独立的 `eval-scope` 容器下载（同样挂 `/datapool`）：
> ```bash
> docker run -d --name eval-scope --network host -v /datapool:/datapool \
>   harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope sleep infinity
> ```

> ⚠ 失败的 50 个模型里，`Hermes-2-Pro-Llama-3-8B` 就是**权重下载超时**折在步骤 1；下载时长异常时先 `ls -lh` 看落盘进度，别盲目重试。
>
> `/datapool/models` 里已有若干现成权重（`aya-23-8B`、`Phi-3-mini-128k-instruct`、`Qwen2.5-7B-Instruct`、`gemma-1.1-7b-it` 等），
> **可省一次下载**——但请先核对与 ModelScope 源一致（`config.json` / 权重完整性）再用，别直接拿来当另一来源。

## 3. 起 vLLM 服务

> **模型名约定**：`model_name` 取 **NV 基线表（`nv_baseline.yaml`）里的 key**，全流程一致（权重目录、`--served-model-name`、评测 `--model-name`、日志目录）。
> ```bash
> model_name=<NV表中的key>   # 如 phi-4 / reka-flash-3 / Qwen2.5-7B-Instruct / Seed-OSS-36B-Instruct / Phi-3-mini-128k-instruct
> ```
> 评测 `--nv-baseline ${model_name}` 靠它自动命中基线（49/50 个摩尔失败模型都有基线）。

> **一律用 plugin-FL 起服务**：不论原始失败报告写的是 V1/V2/V3 哪个阶段失败，本轮修复只做一件事——用 **plugin-FL + vLLM**（本镜像已内置 `VLLM_PLUGINS=fl`）起服务、评测过关。不需要先跑裸 vLLM 基线，不需要复现原始的 V1/V2/V3 分层。

> ✅ **摩尔侧的 FlagOS 开关机制（已实测，别照搬其他厂商）**：本镜像**不用** `GEMS_VENDOR`，
> `VLLM_PLUGINS=fl` 也已**内置在镜像里**（实测启动即打印 `Platform plugin fl is activated`，无需 export）。
> plugin-FL 的 dispatch 层用下面这套变量控制（读自 `vllm_fl/utils.py`）：
> - `VLLM_FL_PREFER_ENABLED`（默认 `true`）—— 全局总开关
> - `USE_FLAGGEMS`（默认 `true`，**即已开**）—— FlagGems 开关
> - `VLLM_FL_FLAGOS_WHITELIST` / `VLLM_FL_FLAGOS_BLACKLIST` —— 算子白/黑名单（互斥，白名单优先）
> - `VLLM_FL_PER_OP`、`VLLM_FL_ALLOW_VENDORS`、`VLLM_FL_OOT_*` —— 细粒度控制
>
> 完整表见容器内 `/usr/local/lib/python3.10/dist-packages/vllm_fl/dispatch/README.md`，摘要见 [[ENV]]「软件栈」节。

> **TP 选卡原则**：TP 取"模型权重能装进卡内，且每张卡还剩 30–40% 显存空余"的最小整数（1/2/4/8）。
> MTT S5000 单卡 **80 GB**（实测 81920 MiB）。估算：`TP = ceil(模型权重 GB × 1.2 / 80)`，再取 2 的幂次向上取整。
> 例：7B bf16 ~14 GB → TP=1；14B ~28 GB → TP=1；32B ~64 GB → TP=1（建议留余量用 TP=2）。
> 若 OOM，先增大 TP，再降 `--max-model-len`，再降 `--gpu-memory-utilization`。

> ⚠ **算子先收窄再放开，别一上来全量**：摩尔的失败报告里，17 个精度不达标 + 16 个性能不达标高度重合，
> 且 long-CoT / reasoning 模型在**全量算子 + 超长输出**下会把评测拖过预算（OpenReasoning-Nemotron-7B 的 mmlu 跑到 427/1140 即触顶）。
> 首轮建议 `VLLM_FL_FLAGOS_WHITELIST` 只留 `silu_and_mul,rms_norm,rotary_embedding` 这类安全算子（Hygon 实测口径，**摩尔尚待验证**），
> 跑通后再按需放开；出现复读/runaway（FluentlyQwen2.5-32B 即此症）先减算子再看采样参数。

```bash
export MUSA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7    # 用几张卡就列几张（TP 与之一致）
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_WHITELIST=silu_and_mul,rms_norm,rotary_embedding   # 首轮收窄；确认后再放开
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
# 注：VLLM_PLUGINS=fl 已内置，GEMS_VENDOR 在此镜像中无作用，均不必设置。

mkdir -p /datapool/flagrelease/release_run_logs/${model_name}
/usr/local/bin/vllm serve /datapool/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --enforce-eager \
  --trust-remote-code \
  2>&1 | tee /datapool/flagrelease/release_run_logs/${model_name}/serve.log
```

- 日志出现 `Application startup complete` 即就绪。先跑 **eager**（`--enforce-eager`）确认能起；确认后再评估 graph 模式（graph 吞吐显著更高，见 KNOWLEDGE 六）。
- **冒烟 PASS ≠ 评测能跑**：短 prompt 只走 decode，长 prompt 才走 prefill 变长注意力。起来后必须用长 prompt（直接跑几题 GPQA）验证，别只测 `1+1`。
- **起不来**：`float4_e2m1fn_x2` → 拿错镜像了，换 0.24 口径（见第 1 节）；算子编译崩 / OOM → 见 [[KNOWLEDGE]] 一。
- ✅ **vllm 路径**：本镜像里 vllm 在 **`/usr/local/bin/vllm`**，**没有 `/opt/conda`**
  （其他厂商镜像的 `/opt/conda/bin/vllm` 口径在此不适用）。
  `docker exec -d` / 脚本等非交互方式 PATH 可能不同，**统一写绝对路径 `/usr/local/bin/vllm`**。

服务存活 + 语义自检（改 port/模型名）：

```bash
curl -s http://localhost:8000/v1/models
curl -s http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"中国的首都是哪个城市？"}],"max_tokens":64,"temperature":0}'
```

## 4. 评测判定

评测脚本对**已运行的 vLLM 服务**（`http://127.0.0.1:8000/v1`）跑题，在 **`eval-scope` 容器**里执行。

```bash
docker exec -it eval-scope /bin/bash
cd /datapool/release_评测标准        # 评测脚本需先传到共享盘（25/27 上尚无，见第 0 节）

model_name=<与起服务时相同的 NV key>
# 指标默认 gpqa_diamond；若该模型无 gpqa 基线，换 --dataset math_500 / mmlu 并同步 --metric
python3 fast_gpqa.py --model-name ${model_name} \
  --api-base http://127.0.0.1:8000/v1 \
  --output /datapool/flagrelease/release_run_logs/${model_name}/gpqa.json
python3 accuracy_compare.py \
  --v2 /datapool/flagrelease/release_run_logs/${model_name}/gpqa.json \
  --nv-baseline ${model_name} \
  --nv-baseline-file nv_baseline.yaml --json \
  --output /datapool/flagrelease/release_run_logs/${model_name}/verdict.json
# 退出码 0=达标 1=不达标 2=参数/文件错 3=NV表无此模型或缺该指标
```

- `model_name` 既是 NV 表 key，`--nv-baseline ${model_name}` 直接命中，无需额外映射。
- **指标回退**：退出码 3 且提示缺 `gpqa_diamond` → 改跑 `--dataset math_500`（或 `mmlu`），`accuracy_compare` 加 `--metric math_500`（或 `mmlu`）。见 `_shared/EVAL.md`。**摩尔 49/50 个模型有基线**；`Darwin-9B-NEG-FINAL` 无任何基线 → 走两轮对比或上报发起人，不自行构造基线。
- **评测前必查采样参数**：`grep '\[gen\]' <eval日志>`——出现"未定位到模型目录…沿用默认采样参数"说明**模型 `generation_config.json` 被忽略、正在用贪心**。摩尔这批模型里 `reka-flash-3`、`Magistral-Small-2506` 都属这类（贪心会确定性复读），按 KNOWLEDGE 二的处理补 `context.yaml`。
- **runaway / 截断红旗**：结果 JSON 的 `truncation_detected` / `runaway_detection.runaway_count` 非零时分数不可信。摩尔已有 `FluentlyQwen2.5-32B` 因 FlagGems 下 mmlu 生成失控而无法评测——先查这两项再谈分数。
- **long-CoT 模型**（OpenReasoning-Nemotron-7B、Apodex-1.0-4B-SFT 等）单题输出是普通模型 10 倍：显式固定 `--max-tokens`、`--eval-batch-size` 锁定并发，避免重演"mmlu 跑到 427/1140 超预算"。
- 评测输出与 serve 日志同落 `/datapool/flagrelease/release_run_logs/${model_name}/`，一个模型一个目录。
- **别把合成基线当实测**：摩尔历史报告的 V1 性能基线多为 `v2_initial_x1.2` 合成值；本轮判定只认 `accuracy_compare` 的退出码，精度以 NV 基线为准。
- 小样本（50 题）绝对差 ≤2 题仍判达标。

## 5. 记录

每修一个模型在 `mthreads/fixes/<模型名>.md` 按下方模板留档（可直接复制 `fixes/_TEMPLATE.md`），并把可复用规律提炼进 `_shared/KNOWLEDGE.md`。
整体进度维护在 `mthreads/STATUS.md`（50 个失败模型的清单与状态已在其中）。

> **优先修哪批**：①7 个「流程中断」模型（从未真正评测过，见 [[ENV]] 末节）→ ②9 个「服务启动失败」→ ③17 个「精度不达标」。
> 3 个已达标模型（Nanbeige4.1-3B、Phi-3-mini-128k-instruct、Phi-3.5-mini-instruct）复核后可直接划掉。

---

## 单模型修复日志模板（复制到 fixes/<模型名>.md）

```markdown
# mthreads/<模型名> 修复日志

- **失败报告**：flagrelease_fail_reports/Mthreads/FAILED_Mthreads_<...>.md
- **原始失败类型**：服务启动失败 / 精度不达标 / 性能不达标 / 评测中断 / 生成失控
- **日期**：

## 现象
（贴关键日志 / 评测分数 / 中断位置）

## 定位
（plugin-FL 下的报错类型：缺失 dtype / crash 算子名 / 精度退化算子 / OOM / runaway）

## 处置
（换镜像 / 关算子 / 调 TP / 调参 / 采样参数 context.yaml / 上报）

## 结果
- 修复后分 / NV 基线：
- 达标判定（accuracy_compare 退出码）：

## 提炼到 KNOWLEDGE 的条目
（一句话规律，若无则写"无新规律"）
```
