# 天数 Iluvatar 迁移修复 SOP

完整流程：**宿主机 → 镜像 → 起容器 → 下模型 → 起 vLLM → 评测**。
真实环境值见 [[ENV]]（本目录），命令模板在 `_shared/templates/`，达标口径见 `_shared/EVAL.md`，踩坑经验见 `_shared/KNOWLEDGE.md`。

---

## 0. 前置

- 硬件：天数 BI 系列（corex 生态），单机多卡。参考模型 XingChen4 用 **TP=8**（`CUDA_VISIBLE_DEVICES=8..15`）。
- 宿主机（ssh 免密直连）：`iluvatar-117` `iluvatar-211`。
  ```bash
  ssh iluvatar-117
  ixsmi   # 天数查卡：看每卡显存/进程；这机器一般独占，但有占用先问清楚再用，别抢卡
  ```
- 镜像：`harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907`（corex4.5.0 / flagtree0.6.0 / triton3.6.0 / vllm_fl 0.24.0）。
- 共享存储（NFS）：iluvatar 所有机器的 NFS 挂载点均为宿主机 `/mnt/share/`，模型目录为 `/mnt/share/models/`。起容器时统一用 `-v /mnt/share/models:/models`，容器内访问路径 `/models`（如 `/models/flagrelease/fixes_models/QwQ-32B`）。

## 1. 起容器

参考实测（`_shared/templates/01_start_container.sh` 的 iluvatar 变体），透传 `/dev/iluvatar`：

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
model_name=<NV表中的key，如 qwq-32b>   # 容器名用小写，能分辨模型即可
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
# 容器内自检
ixsmi
python -c "import vllm; print(vllm.__version__)"   # 应为 0.24.0
```

> 镜像内组件安装（若需重装 / 换仓，参考 XingChen4-0907 实测）：
> ```bash
> cd /workspace/vllm-plugin-FL && pip install --no-build-isolation --no-deps -e .      # 含 corex patch
> cd /workspace/FlagGems-vllm && GEMS_VENDOR=iluvatar pip install -v -e .              # mHC pre / scaled_int8_quant
> # FlagGems 镜像预装 5.3.4.post1.dev11，通常不用换仓
> ```

## 2. 下模型

> ⚠ **约定**：本项目所有模型均以 **ModelScope 为唯一来源**。所有权重统一下载到共享盘 `/mnt/share/models/flagrelease/fixes_models/<模型名>`（宿主机 NFS 路径；容器内挂载路径 `/models/flagrelease/fixes_models/<模型名>`），再由 `vllm serve` 从本地路径加载；不直接用远程 URL 起服务。**来源优先级：ModelScope 优先，若 ModelScope 返回 404 / model not found，再从 HuggingFace 下载（见下文备用下载命令）。两个来源都没有时立即停下并报告给发起人。**

**下载统一在 `eval-scope` 容器里完成**（该容器已预装 modelscope，挂载共享盘到 `/models`）：

```bash
# 宿主机：确认 eval-scope 容器是否在运行
docker ps --filter name=eval-scope --format '{{.Names}}'
# 若无输出，创建容器：
docker run -d --name eval-scope \
  --network host \
  -v /mnt/share/models:/models \
  harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope \
  sleep infinity

# 进容器下载权重
docker exec -it eval-scope /bin/bash
mkdir -p /models/flagrelease/fixes_models
modelscope download --model <ModelScope仓库/模型ID，如 Qwen/QwQ-32B> \
  --local_dir /models/flagrelease/fixes_models/<模型名>
# 若命令报 404 / model not found → 改用 HuggingFace 备用下载（eval-scope 容器内已预装 hf CLI）：
# hf download <HuggingFace仓库/模型ID，如 qihoo360/TinyR1-32B-Preview> \
#   --local-dir /models/flagrelease/fixes_models/<模型名>
# 若 HuggingFace 也找不到 → 停止，把模型名和报错截图报给发起人
ls /models/flagrelease/fixes_models/<模型名>   # 确认 config.json / *.safetensors / tokenizer
```

## 3. 起 vLLM 服务

> **模型名约定**：`model_name` 取 **NV 基线表（`nv_baseline.yaml`）里的 key**，全流程一致。评测 `--nv-baseline` 靠它自动命中基线。
> ```bash
> model_name=<NV表中的key>   # 如 QwQ-32B / TinyR1-32B-Preview / OpenThinker-7B / MiroThinker-v1.5-30B / Phi-3-medium-128k-instruct / SOLAR-10.7B-Instruct-v1.0
> ```

> **不必纠结 V1/V3 版本口径**：修复目标就是把服务跑起来、跑对。直接进容器用 **plugin-FL + vLLM**（`GEMS_VENDOR=iluvatar` + `VLLM_PLUGINS=fl`）起服务、评测过关即可，无需按 V1/V2/V3 分层复现。文末的版本口径表仅作术语对照。

FlagOS 后端由环境变量启用（`GEMS_VENDOR=iluvatar` + `VLLM_PLUGINS=fl`）。以 XingChen4-0907 实测为参考：

> **TP 选卡原则**：TP 取"模型权重能装进卡内，且每张卡还剩 30–40% 显存空余"的最小整数（1/2/4/8）。
> 先用 `ixsmi` 确认单卡显存大小，再估算：`TP = ceil(模型权重 GB × 1.2 / 单卡显存 GB)`，取 2 的幂次向上取整。
> 例：7B bf16 ~14 GB，单卡 32 GB → TP=1；32B bf16 ~64 GB，单卡 32 GB → TP=4。
> XingChen4-0907 参考用 TP=8（CUDA_VISIBLE_DEVICES=8..15）。若 OOM，先增大 TP，再降 `--max-model-len`，再降 `--gpu-memory-utilization`。

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=8,9,10,11,12,13,14,15     # 用几张卡就列几张
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable      # ⚠ 必设，否则 hang
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200

mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} \
  --dtype bfloat16 \
  --tensor-parallel-size 8 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --attention-backend TRITON_MLA \
  --chat-template <模型目录>/chat_template.jinja \
  --enforce-eager \
  --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log
```

- 日志 `Application startup complete` 即就绪。
- **`VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable` 必设**，否则服务 hang（天数实测强坑）。
- **服务启动失败**（QwQ/TinyR1/Phi-3-medium/MiroThinker 都栽在这）→ 抓栈定位缺实现的算子，加进 `VLLM_FL_FLAGOS_BLACKLIST` 挡回原生，或先关 plugin 跑通再逐步开。见 [[KNOWLEDGE]] 一。
- **`--attention-backend` 选择规则**：
  - MLA 架构（DeepSeek 系、QwQ、TinyR1 等，config.json 有 `q_lora_rank`/`kv_lora_rank` 字段）→ `TRITON_MLA`
  - 普通 MHA/GQA transformer（Qwen、Gemma、Mistral、OpenThinker 等）→ `TRITON_ATTN`
  - SSM/Hybrid 模型（LFM2.5 等）→ `TRITON_ATTN`（不要指定 TRITON_MLA，否则报 MLACommonImpl 参数错）
- `--chat-template` 仅当模型目录带 `chat_template.jinja` 时加。
- 大模型崩溃优先加大 TP 降单卡压力。

服务存活自检：

```bash
curl -s http://localhost:8000/v1/models
curl -s http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"中国的首都是哪里？"}],"max_tokens":64,"temperature":0}'
```

## 4. 评测判定

评测脚本对**已运行的 vLLM 服务**（`http://127.0.0.1:8000/v1`）跑题。评测统一在 **`eval-scope` 容器**里执行，该容器已预装 evalscope 和 modelscope，并挂载共享盘到 `/models`。

```bash
# 宿主机：确认 eval-scope 容器是否在运行
docker ps --filter name=eval-scope --format '{{.Names}}'
# 若无输出，创建容器：
docker run -d --name eval-scope \
  --network host \
  -v /mnt/share/models:/models \
  harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope \
  sleep infinity

# 进容器跑评测
docker exec -it eval-scope /bin/bash
cd /workspace/release_评测标准

model_name=<与起服务时相同的 NV key>
# 指标默认 gpqa_diamond；若该模型无 gpqa 基线，换 --dataset math_500 / mmlu 并同步 --metric
python3 fast_gpqa.py --model-name ${model_name} \
  --api-base http://127.0.0.1:8000/v1 \
  --output /models/release_run_logs/${model_name}/gpqa.json
python3 accuracy_compare.py \
  --v2 /models/release_run_logs/${model_name}/gpqa.json \
  --nv-baseline ${model_name} \
  --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict.json
# 退出码 0=达标 1=不达标 2=参数/文件错 3=NV表无此模型或缺该指标
```

- `model_name` 既是 NV 表 key，`--nv-baseline ${model_name}` 直接命中，无需额外映射。
- **指标回退**：退出码 3 且提示缺 `gpqa_diamond` → 改跑 `--dataset math_500`（或 `mmlu`）出分，`accuracy_compare` 加 `--metric math_500`（或 `mmlu`）。见 `_shared/EVAL.md`。任何数据集都无基线 → 同机起裸 vLLM 做 V1 基线两轮对比。
- 评测输出与 serve 日志同落 `/models/release_run_logs/${model_name}/`，一个模型一个目录。
- **评测中途中断**（OpenThinker-7B 跑到 mmlu 145/1140 停）→ 先 `--limit 20` 小样本验稳定，查 serve 日志有无 OOM/CUDA error，再跑全量。见 KNOWLEDGE 五。
- thinking 模型（QwQ 等）50 题可能 6h+，勿中断。

## 5. 记录

每修一个模型在 `iluvatar/fixes/<模型名>.md` 留档，规律提炼进 `_shared/KNOWLEDGE.md`。

> 注：0910 CSV 列本厂商 48 个失败模型，zip 仅 8 份报告。修无报告的模型时，先补取报告或按同类失败类型套用本 SOP。

---

## 单模型修复日志模板（复制到 fixes/<模型名>.md）

```markdown
# iluvatar/<模型名> 修复日志

- **失败报告**：release_迁移失败报告/iluvatar/FAILED_Iluvatar_<...>.md（无则注明）
- **原始失败类型**：服务启动失败 / 精度不达标 / 性能不达标 / 评测中断
- **日期**：

## 现象
（贴关键日志 / 评测分数 / 中断位置）

## 定位
（缺实现的算子名 / V1V2V3 哪层 / 是否 OOM）

## 处置
（关算子 / 调 TP / 调参 / 上报）

## 结果
- V1 基线分：
- 修复后分 / NV 基线：
- 达标判定（accuracy_compare 退出码）：

## 提炼到 KNOWLEDGE 的条目
（一句话规律，若无则写"无新规律"）
```
