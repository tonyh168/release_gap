# 海光 Hygon 迁移修复 SOP

完整流程：**宿主机 → 镜像 → 起容器 → 下模型 → 起 vLLM → 评测**。
真实环境值见 [[ENV]]（本目录），命令模板在 `_shared/templates/`，达标口径见 `_shared/EVAL.md`，踩坑经验见 `_shared/KNOWLEDGE.md`。

---

## 0. 前置

- 硬件：海光 HCU / DCU（DTK/ROCm 生态）× 8。默认单机 **TP=4**（参考模型 XingChen4 用 4 卡；32B 视显存可上 TP=8）。
- 宿主机（ssh 免密直连）：`hygon-30` `hygon-31` `hygon-32` `hygon-33`。
- **上机第一件事：查卡占用**。这机器一般独占，但用前必须确认没有别人的进程在跑：
  ```bash
  ssh hygon-30
  hy-smi        # 海光查卡：看每卡显存/进程；有占用先问清楚再用，别抢卡
  ```
  按空闲卡数和模型大小定 TP（见第 3 节 TP 选卡原则）。
- 镜像：`harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4`（vLLM 0.24.0，py310 / torch2.10 / dtk26.04 / flagtree3.6）。
- DTK：`/opt/dtk-26.04-DCC2602-0317`，**起服务前必须** `source /opt/dtk-26.04-DCC2602-0317/env.sh`。
- 共享存储：宿主机模型盘挂到容器 `/models`（权重目录如 `/models/XingChen4-29B-A4B-0907`）。

## 1. 起容器

参考实测（`_shared/templates/01_start_container.sh` 的 hygon 变体），透传 `/dev/kfd /dev/dri`、放开 seccomp、加 video 组：

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4
model_name=<NV表中的key，如 light-r1-7b-ds>   # 容器名用小写，能分辨模型即可
docker run -itd --name flagrelease-fix-${model_name} \
  --device=/dev/kfd --device=/dev/dri \
  --security-opt seccomp=unconfined --group-add video \
  --ipc=host --network=host --shm-size 64g \
  -v /public-flash/models:/models \
  ${IMAGE} bash
docker exec -it flagrelease-fix-${model_name} bash
# 容器内自检
source /opt/dtk-26.04-DCC2602-0317/env.sh
hy-smi
python -c "import vllm; print(vllm.__version__)"   # 此镜像应为 0.24.0
# 若报 vllm._rocm_C / vllm._C / libhydmi.so 找不到 → 该镜像编译扩展不全，换镜像。见 KNOWLEDGE 一。
```

## 2. 下模型

> ⚠ **约定**：本项目所有模型均以 **ModelScope 为唯一来源**。所有权重统一下载到共享盘 `/public-flash/models/flagrelease/fixes_models/<模型名>`（容器内路径 `/models/flagrelease/fixes_models/<模型名>`），再由 `vllm serve` 从本地路径加载；不直接用远程 URL 起服务。若某模型在 ModelScope 上搜不到，**立即停下并报告给发起人**，不自行换源替代。

**下载统一在 `eval-scope` 容器里完成**（该容器已预装 modelscope，挂载共享盘到 `/models`）：

```bash
# 宿主机：确认 eval-scope 容器是否在运行
docker ps --filter name=eval-scope --format '{{.Names}}'
# 若无输出，创建容器：
docker run -d --name eval-scope \
  --network host \
  -v /public-flash/models:/models \
  harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope \
  sleep infinity

# 进容器下载权重
docker exec -it eval-scope /bin/bash
mkdir -p /models/flagrelease/fixes_models
modelscope download --model <ModelScope仓库/模型ID，如 Qwen/Qwen2.5-7B-Instruct> \
  --local_dir /models/flagrelease/fixes_models/<模型名>
# 若命令报 404 / model not found → 停止，把模型名和报错截图报给发起人，不要换其他来源自行处理
ls /models/flagrelease/fixes_models/<模型名>   # 确认 config.json / *.safetensors / tokenizer
```

## 3. 起 vLLM 服务

> **模型名约定**：`model_name` 取 **NV 基线表（`nv_baseline.yaml`）里的 key**，全流程一致（权重目录、`--served-model-name`、评测 `--model-name`、日志目录）。评测 `--nv-baseline` 靠它自动命中基线。
> ```bash
> model_name=<NV表中的key>   # 如 Light-R1-7B-DS / Magistral-Small-2506 / Mistral-Small-24B-Instruct-2501 / sarvam-m / SOLAR-10.7B-Instruct-v1.0 / Phi-3-medium-128k-instruct
> ```

> **一律用 plugin-FL 起服务**：不论原始失败报告写的是 V1/V2/V3 哪个阶段失败，本轮修复只做一件事——用 **plugin-FL + vLLM**（`GEMS_VENDOR=hygon` + `VLLM_PLUGINS=fl`）起服务、评测过关。不需要先跑裸 vLLM 基线，不需要复现原始的 V1/V2/V3 分层，也不需要与原始报告的分数逐层对比。失败报告里的版本口径只是历史背景，忽略即可。

**先确认 `import vllm` 通过（第 1 步），再起服务。** FlagOS 后端由环境变量启用（`GEMS_VENDOR=hygon` + `VLLM_PLUGINS=fl`）。以 XingChen4-0907 实测为参考，按目标模型改权重/名称/TP：

> **TP 选卡原则**：TP 取"模型权重能装进卡内，且每张卡还剩 30–40% 显存空余"的最小整数（1/2/4/8）。
> 先用 `hy-smi` 确认单卡显存大小，再估算：`TP = ceil(模型权重 GB × 1.2 / 单卡显存 GB)`，取 2 的幂次向上取整。
> 例：7B bf16 ~14 GB，单卡 40 GB → TP=1；32B bf16 ~64 GB，单卡 40 GB → TP=2（建议留余量用 TP=4）。
> XingChen4-0907 参考用 TP=4。若 OOM，先增大 TP，再降 `--max-model-len`，再降 `--gpu-memory-utilization`。

```bash
source /opt/dtk-26.04-DCC2602-0317/env.sh
export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export HIP_VISIBLE_DEVICES=0,1,2,3               # 用几张卡就列几张
export VLLM_WORKER_MULTIPROC_METHOD=spawn        # spawn worker，配合 per-pid 算子注册守卫
export VLLM_FL_FLAGOS_BLACKLIST=cat,slice        # 挡回原生 aten 的算子；按模型增减
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200      # 首次推理有 Triton JIT 编译（单请求可 ~456s），放大超时
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200

mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} \
  --dtype bfloat16 \
  --tensor-parallel-size 4 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --attention-backend TRITON_MLA \
  --no-enable-chunked-prefill \
  --no-enable-prefix-caching \
  --enforce-eager \
  --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log
```

- 日志 `Application startup complete` 即就绪。先跑 **eager**（`--enforce-eager`）确认能起；graph 模式另测。
- **`import vllm` 失败 / 缺 .so** → 换镜像，见 [[KNOWLEDGE]] 一（海光高频坑）。
- **plugin-FL 报错**（Magistral/Mistral/sarvam 都遇到）→ 设 `VLLM_PLUGIN_FL_LOGLEVEL=DEBUG` 看完整栈，对应算子加 `VLLM_FL_FLAGOS_BLACKLIST`，见 KNOWLEDGE 四。
- `--no-enable-chunked-prefill --no-enable-prefix-caching` 用于规避 `gather_and_maybe_dequant_cache` 类算子问题；`--attention-backend TRITON_MLA` 是 MLA 类模型实测用值，非 MLA 模型可去掉。

服务存活 + 语义自检（改 port/模型名）：

```bash
curl -s http://localhost:8000/v1/models
curl -s http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"中国的首都是哪里？"}],"max_tokens":64,"temperature":0,"chat_template_kwargs":{"enable_thinking":false}}'
```

## 4. 评测判定

评测脚本对**已运行的 vLLM 服务**（`http://127.0.0.1:8000/v1`）跑题。评测统一在 **`eval-scope` 容器**里执行，该容器已预装 evalscope 和 modelscope，并挂载共享盘到 `/models`。

```bash
# 宿主机：确认 eval-scope 容器是否在运行
docker ps --filter name=eval-scope --format '{{.Names}}'
# 若无输出，创建容器：
docker run -d --name eval-scope \
  --network host \
  -v /public-flash/models:/models \
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
- **指标回退**：退出码 3 且提示缺 `gpqa_diamond` → 改跑 `--dataset math_500`（或 `mmlu`）出分，`accuracy_compare` 加 `--metric math_500`（或 `mmlu`）。见 `_shared/EVAL.md`。任何数据集都无基线 → 上报给发起人，不自行构造基线。
- 评测输出与 serve 日志同落 `/models/release_run_logs/${model_name}/`，一个模型一个目录。
- **精度不达标**：先看是否全关算子仍退化——若是，属 plugin 框架级退化（sarvam-m 结论），上报框架 bug；否则二分法缩白名单定位退化算子。见 KNOWLEDGE 二。
- 小样本（50 题）绝对差 ≤2 题仍判达标。

## 5. 记录

每修一个模型在 `hygon/fixes/<模型名>.md` 留档，规律提炼进 `_shared/KNOWLEDGE.md`。

---

## 单模型修复日志模板（复制到 fixes/<模型名>.md）

```markdown
# hygon/<模型名> 修复日志

- **失败报告**：release_迁移失败报告/hygon/FAILED_Hygon_<...>.md
- **原始失败类型**：服务启动失败 / 精度不达标 / 性能不达标 / plugin报错
- **日期**：

## 现象
（贴关键日志 / 评测分数）

## 定位
（plugin-FL 下的报错类型：是否缺 .so 编译扩展 / crash 算子名 / 精度退化算子）

## 处置
（换镜像 / 关算子 / 调参 / 上报框架）

## 结果
- 修复后分 / NV 基线：
- 达标判定（accuracy_compare 退出码）：

## 提炼到 KNOWLEDGE 的条目
（一句话规律，若无则写"无新规律"）
```
