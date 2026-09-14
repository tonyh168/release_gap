# 沐曦 Metax 迁移修复 SOP

完整流程：**宿主机 → 镜像 → 起容器 → 下模型 → 起 vLLM → 评测**。
真实环境值见 [[ENV]]（本目录），命令模板在 `_shared/templates/`，达标口径见 `_shared/EVAL.md`，踩坑经验见 `_shared/KNOWLEDGE.md`。

---

## 0. 前置

- 硬件：MetaX C550 × 8（单卡 ~63.6GB）。32B 模型用 TP=8。
- **上机第一件事：查卡占用**。这机器一般独占，但用前必须确认没有别人的进程在跑：
  ```bash
  ssh metax-57
  mx-smi        # 看每张卡的显存占用 / 进程；有占用先问清楚再用，别抢卡
  ```
  按空闲卡数和模型大小定 TP（见第 3 节 TP 选卡原则）。
- 共享存储：宿主机 `/public-flash/models` 已挂权重，容器内映射到 `/models`。
- 镜像：`harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907`（vLLM 0.24.0）。

## 1. 起容器

参考实测命令（`_shared/templates/01_start_container.sh` 的 metax 变体）：

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907
model_name=<NV表中的key，如 exaone-4.0-32b>   # 容器名用小写，能分辨模型即可
docker run -d --rm \
  --name flagrelease-fix-${model_name} \
  --network host \
  --shm-size 64g \
  --device /dev/dri:/dev/dri:rwm \
  --device /dev/mxcd:/dev/mxcd:rwm \
  -v /public-flash/models:/models \
  ${IMAGE} \
  sleep infinity
docker exec -it flagrelease-fix-${model_name} /bin/bash
# 容器内自检
mx-smi
python -c "import vllm; print(vllm.__version__)"   # 此镜像应为 0.24.0
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
modelscope download --model <ModelScope仓库/模型ID，如 LGAI-EXAONE/EXAONE-4.0-32B> \
  --local_dir /models/flagrelease/fixes_models/<模型名>
# 若命令报 404 / model not found → 停止，把模型名和报错截图报给发起人，不要换其他来源自行处理
ls /models/flagrelease/fixes_models/<模型名>   # 确认 config.json / *.safetensors / tokenizer
```

## 3. 起 vLLM 服务

> **模型名约定**：`model_name` 直接取 **NV 基线表（`nv_baseline.yaml`）里的 key**，全流程一致 —— 权重目录、`--served-model-name`、评测 `--model-name`、日志目录都用这个名字。这样评测 `--nv-baseline` 靠模型名就能自动匹配上基线，无需再显式指定。
> ```bash
> model_name=<NV表中的key>     # 如 EXAONE-4.0-32B / GLM-4-32B-0414 / Qwen3-Coder-30B-A3B-Instruct / Phi-3-mini-128k-instruct / SOLAR-10.7B-Instruct-v1.0
> ```
> 若权重落盘目录名与 NV key 不同，`vllm serve <权重路径>` 用真实路径，但 `--served-model-name ${model_name}` 仍用 NV key。

> **不必纠结 V1/V3 版本口径**：修复目标就是把服务跑起来、跑对。直接进容器用 **plugin-FL + vLLM**（`GEMS_VENDOR=metax` + `VLLM_PLUGINS=fl`）起服务、评测过关即可，无需按 V1/V2/V3 分层复现。文末的版本口径表仅作术语对照。

FlagOS 后端由环境变量启用，**不是** `VLLM_USE_FLAGGEMS`。以 xingchen4-0907 实测为参考（`GEMS_VENDOR=metax` + `VLLM_PLUGINS=fl`），按目标模型改权重路径/名称/TP：

> **TP 选卡原则**：TP 取"模型权重能装进卡内，且每张卡还剩 30–40% 显存空余"的最小整数（1/2/4/8）。
> MetaX C550 单卡 ~63.6 GB。估算：`TP = ceil(模型权重 GB × 1.2 / 63.6)`，再取 2 的幂次向上取整。
> 例：7B bf16 ~14 GB → TP=1；32B bf16 ~64 GB → TP=2（但实测跑 KV cache 会 OOM，用 TP=4 更稳）。
> 若服务 OOM，先增大 TP，再降 `--max-model-len`，再降 `--gpu-memory-utilization`。

```bash
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export MACA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7      # 用几张卡就列几张
export VLLM_WORKER_MULTIPROC_METHOD=spawn
# FlagGems 黑名单：把在 MetaX 上编译崩/不支持的算子挡回原生 aten
# eager 最小基线：mm,mm_out,sort,stable_sort,masked_fill,masked_fill_,slice
# graph / Triton3.6 需补全 bmm,bmm_out,linear（.out 变体必须写下划线，写点号不生效）
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice
export VLLM_FL_USE_FLAGGEMS_ATTN=0              # MLA prefill 走 MetaX 原生 FA，避免共享内存 OOM
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200     # 首次推理有 Triton 编译耗时，放大超时
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200

mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} \
  --dtype bfloat16 \
  --tensor-parallel-size 8 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log
```

- 日志出现 `Application startup complete` 即就绪。先跑 **eager**（`--enforce-eager`）确认能起；graph 模式去掉该 flag，但黑名单须补全 `bmm,bmm_out,linear`，否则 CUDA graph capture 崩。
- **冒烟 PASS ≠ 评测能跑**：短 prompt 只走 decode，长 prompt 才走 MLA prefill 变长注意力。起来后必须用长 prompt（下方 curl / 直接跑 GPQA）验证，别只测 `1+1`。
- **起不来（core dump / OOM）** → 见 [[KNOWLEDGE]] 一。OOM 降 `--max-model-len`；算子编译崩（`PassManager::run failed` / `shape_judge`）→ 该算子加进 `VLLM_FL_FLAGOS_BLACKLIST`。

服务存活 + 语义自检（改 port/模型名）：

```bash
curl -s http://localhost:8000/v1/models
curl -s http://localhost:8000/v1/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","prompt":"问:中国的首都是哪个城市呢？答:","max_tokens":16,"temperature":0}'
# chat + 关思考：
curl -s http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"中国的首都是哪个城市？"}],"max_tokens":64,"temperature":0,"chat_template_kwargs":{"enable_thinking":false}}'
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

- `model_name` 既是 NV 表 key，`--nv-baseline ${model_name}` 直接命中基线，无需额外映射。
- **指标回退**：退出码 3 且提示缺 `gpqa_diamond` → 该模型没 gpqa 基线，改跑 `--dataset math_500`（或 `mmlu`）出分，`accuracy_compare` 加 `--metric math_500`（或 `mmlu`）。基线覆盖 math_500/mmlu 比 gpqa 广。见 `_shared/EVAL.md`。
- 若任何数据集都无 NV 基线 → 同机先起裸 vLLM 跑一轮做 V1 基线，再与 plugin-FL 轮 `--v1/--v2` 两两对比。
- 评测输出与 serve 日志同落 `/models/release_run_logs/${model_name}/`，一个模型一个目录。
- thinking 模型（EXAONE 类）单题输出长，50 题可能数小时，勿中断。
- `truncation_detected:true` → 加大 `--max-model-len` 重跑。

## 5. 记录

每修一个模型，在 `metax/fixes/<模型名>.md` 按下方模板留档，并把可复用规律提炼进 `_shared/KNOWLEDGE.md`。

---

## 单模型修复日志模板（复制到 fixes/<模型名>.md）

```markdown
# metax/<模型名> 修复日志

- **失败报告**：release_迁移失败报告/metax/FAILED_Metax_<...>.md
- **原始失败类型**：服务启动失败 / 精度不达标 / 性能不达标 / plugin报错
- **日期**：

## 现象
（贴关键日志 / 评测分数）

## 定位
（V1/V2/V3 哪一层引入问题，涉及算子名）

## 处置
（改了什么：关算子 / 换镜像 / 调参）

## 结果
- V1 基线分：
- 修复后分 / NV 基线：
- 达标判定（accuracy_compare 退出码）：

## 提炼到 KNOWLEDGE 的条目
（一句话规律，若无则写"无新规律"）
```
