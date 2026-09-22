# Reka Flash 3：NV / 沐曦 GPQA Diamond 手动复现

整理日期：2026-09-17。依据当天三轮已完成评测的实际配置、镜像摘要、逐题审计和服务日志整理。

本文覆盖 **NV 原生、沐曦 FlagOS、沐曦 reference**。先完成公共准备，再选择一组启动模型，最后执行公共评测步骤。模型服务和评测进程分别在两个终端运行；评测完成后，按本文最后的命令手动停止模型容器。

## 1. 固定参数与历史成绩

模型在两台宿主机和模型容器内均使用 `/data/models/reka-flash-3`。

| 项目 | 本次复现值 |
|---|---|
| 数据集 | `gpqa_diamond`，完整 198 题，default 子集、train split |
| few-shot / repeats | 0 / 1 |
| 评测请求并发 | **256**，198 题最多同时提交 198 个请求 |
| temperature / top_p / top_k | **0.0 / 1.0 / -1** |
| repetition_penalty / n / stream | 1.0 / 1 / false |
| 单次最大生成长度 | **16384 tokens** |
| 模型上下文长度 | **32768 tokens**，包含输入与输出 |
| TaskConfig seed | 42；没有额外指定 vLLM `--seed` 或请求级生成 seed |
| 请求 timeout | 86400 秒 |
| TP / dtype / 执行模式 | **2 / bfloat16 / eager** |
| max-num-seqs / max-num-batched-tokens | 256 / 32768 |
| prefix caching / chunked prefill | 均关闭 |
| 模型 generation_config | `--generation-config vllm`，由评测请求明确传采样参数 |

正式请求不额外设置 `enable_thinking`、`chat_template_kwargs`、system prompt、stop strings 或回答后处理。使用模型目录自带的 chat template，保留 Reka 的推理输出。配套 `task_template.json` 已保存本轮完整 GPQA 配置，不需要再读取原来的 `task_config.yaml`。

GPQA 的用户提示词为：

```text
Answer the following multiple choice question. The last line of your response should be of the following format: 'ANSWER: [LETTER]' (without quotes) where [LETTER] is one of {letters}. Think step by step before answering.

{question}

{choices}
```

| 模式 | GPU / 端口 | 显存比例 | Attention | 历史分数 | 正确 / 总数 | 达到生成上限 |
|---|---|---:|---|---:|---:|---:|
| NV origin | H20 0,1 / 9182 | 0.90 | vLLM FLASH_ATTN，实际 FA3 | 53.54 | 106/198 | 3 |
| 沐曦 FlagOS | C550 1,2 / 9185 | 0.90 | vendor:metax，实际 FA2 | 51.52 | 102/198 | 2 |
| 沐曦 reference | C550 2,3 / 9184 | **0.80** | vendor:metax，实际 FA2 | 51.01 | 101/198 | 2 |

这些是历史实测值，不是必须完全重复的验收值。三组存在硬件、底层库和内核差异；`temperature=0` 也不保证跨环境逐 token 一致。16384 是本轮生成预算，仍有少量截断，结果必须连同截断数量一起看。

**沐曦两组串行执行**：GPU 2 重叠，上一组服务停止后再启动下一组。运行前按实时占用选择空闲卡；如果改了 GPU、显存比例、长度或其他参数，请记录下来。

## 2. 配套文件与传输

本机 Downloads 中的目录：`reka-gpqa-manual-20260917/`。

- `make_config.py`：为指定模式、端口和运行目录写入固定评测配置。
- `prepare_cache.py`：检查同版 EvalScope 评分代码，把离线 JSONL 建成它需要的 Arrow 缓存。
- `run_eval.py`：调用 EvalScope，完成后核对 198 条预测和评分，汇总正确数及截断数量。
- `record_environment.py`：记录模型容器的包版本、模块路径和模型配置文件哈希。
- `task_template.json`：从本次成功运行中提取的 GPQA 完整配置。
- `gpqa_diamond.tar.gz`：本次使用的 198 题数据归档。
- `reference-bundles/`：reference 固定 wheel，仅 reference 分支安装。
- `SHA256SUMS`：配套文件校验清单。
- `VALIDATION.json`：三组配置与历史运行一致、离线缓存和 TaskConfig 校验通过的记录。

在 **macOS 终端** 执行，分别传给需要评测的服务器：

```bash
scp -r ~/Downloads/reka-gpqa-manual-20260917 baai-h20-01-clone:/data/
scp -r ~/Downloads/reka-gpqa-manual-20260917 baai-dx-mc550:/data/
```

后续命令均在 **Linux 宿主机或指定 Docker 容器内** 执行，不在 macOS 本地启动 vLLM。

## 3. 宿主机公共准备

### 3.1 登录并选择 Docker CLI

NV：

```bash
ssh baai-h20-01-clone
export REKA_DOCKER=/mnt/data/docker-binary/docker/docker
nvidia-smi
```

沐曦：

```bash
ssh baai-dx-mc550
export REKA_DOCKER=/usr/bin/docker
mx-smi
```

新机器上 Docker 若位于其他位置，把 `REKA_DOCKER` 改成 `command -v docker` 的结果。每个新开的宿主机终端都需要设置此变量。

两边都执行：

```bash
test -f /data/models/reka-flash-3/config.json
test -f /data/models/reka-flash-3/model.safetensors.index.json
ss -ltnp
cd /data/reka-gpqa-manual-20260917
sha256sum -c SHA256SUMS
```

确认目标 GPU 有足够空闲显存，所选 9182 / 9184 / 9185 端口没有其他服务。模型权重需已完整下载；配套包不含模型权重。

### 3.2 创建专用评测容器

两台宿主机各创建一个。此容器只通过 HTTP 请求模型服务，无需 GPU。

原标签：`harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope`。下面固定到本次实际镜像摘要，避免 `latest-modelscope` 更新：

```bash
export REKA_EVAL_IMAGE=harbor.baai.ac.cn/flagrelease-public/flagos-evalscope@sha256:8a2847c2b8cee9f4ccd62ae6534b46bc9b59694c6c33571e20ab34f535c2c128
"$REKA_DOCKER" pull "$REKA_EVAL_IMAGE"
"$REKA_DOCKER" run -d \
  --name reka-gpqa-eval-manual \
  --network host \
  -v /data:/data \
  "$REKA_EVAL_IMAGE" sleep infinity
```

如果这个**专用容器**已按上述镜像和挂载创建，可执行 `"$REKA_DOCKER" start reka-gpqa-eval-manual`，不用再次 `docker run`。

确认评测组件版本：

```bash
"$REKA_DOCKER" exec reka-gpqa-eval-manual /usr/bin/python3 -c \
  'import importlib.metadata as m; print({n:m.version(n) for n in ["evalscope","modelscope","datasets"]})'
```

应为 `evalscope=1.11.1`、`modelscope=1.40.0`、`datasets=4.8.4`。本流程直接使用固定 TaskConfig；没有调用 `fast_gpqa.py` 的自动并发或自动生成长度逻辑。

## 4. 选择一组：创建模型容器

以下创建的是新的专用容器，便于评测后明确释放资源。三个模型容器均把宿主机 `/data` 挂到容器 `/data`。

### A. NV origin

原标签为 `vllm/vllm-openai:v0.24.0`，固定镜像摘要如下：

```bash
export REKA_MODEL_IMAGE=vllm/vllm-openai@sha256:251eba5cc7c12fed0b75da22a9240e582b1c9e39f6fbc064f86781b963bd814f
"$REKA_DOCKER" pull "$REKA_MODEL_IMAGE"
"$REKA_DOCKER" run -d \
  --name reka-nv-origin-manual \
  --network host --ipc=host --gpus all \
  -v /data:/data \
  --entrypoint /bin/bash \
  "$REKA_MODEL_IMAGE" -lc 'sleep infinity'

export REKA_MODE=nv-origin
export REKA_MODEL_CONTAINER=reka-nv-origin-manual
export REKA_PORT=9182
```

NV 宿主机的 NVIDIA 驱动及 NVIDIA Container Toolkit 需已正常工作；容器内不安装 FlagGems 或 vllm-plugin-fl。

### B. 沐曦 FlagOS

原标签为用户指定的：

`harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907`

```bash
export REKA_MODEL_IMAGE=harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6@sha256:c1c0b68f2154f162e0b4d3ba0f5401e71b05fad717b19ebc7db48c11f5166558
"$REKA_DOCKER" pull "$REKA_MODEL_IMAGE"
"$REKA_DOCKER" run -d \
  --name reka-metax-flagos-manual \
  --network host --shm-size 64g \
  --device /dev/dri:/dev/dri:rwm \
  --device /dev/mxcd:/dev/mxcd:rwm \
  -v /MXC550/share/models:/models \
  -v /data:/data \
  "$REKA_MODEL_IMAGE" sleep infinity

export REKA_MODE=metax-flagos
export REKA_MODEL_CONTAINER=reka-metax-flagos-manual
export REKA_PORT=9185
```

使用镜像自带的 FlagGems 和 plugin-fl，直接进入第 5 节。

### C. 沐曦 reference

原始基础镜像标签：

`harbor.baai.ac.cn/plugin/metax-maca3.7.0-treenone-triton3.0.0-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt280-x64:202507290700`

```bash
export REKA_MODEL_IMAGE=harbor.baai.ac.cn/plugin/metax-maca3.7.0-treenone-triton3.0.0-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt280-x64@sha256:1358058b5e58cc7adb5b6496186797016418c0be554718066131020aa1500899
"$REKA_DOCKER" pull "$REKA_MODEL_IMAGE"
"$REKA_DOCKER" run -d \
  --name reka-metax-reference-manual \
  --network host --shm-size 64g \
  --device /dev/dri:/dev/dri:rwm \
  --device /dev/mxcd:/dev/mxcd:rwm \
  -v /MXC550/share/models:/models \
  -v /data:/data \
  "$REKA_MODEL_IMAGE" sleep infinity

export REKA_MODE=metax-reference
export REKA_MODEL_CONTAINER=reka-metax-reference-manual
export REKA_PORT=9184
```

reference 固定版本在第 6C 节安装到本轮目录。

## 5. 新建运行目录并进入模型容器

继续在刚设置好 `REKA_MODE` 的**宿主机终端 A** 执行：

```bash
export REKA_RUN_DIR="/data/reka-gpqa-manual-runs/$(date +%Y%m%d-%H%M%S)-${REKA_MODE}"
mkdir -p "$REKA_RUN_DIR"
printf '%s\n' "$REKA_RUN_DIR" > "/data/reka-gpqa-manual-20260917/current-${REKA_MODE}.txt"

"$REKA_DOCKER" inspect "$REKA_MODEL_CONTAINER" reka-gpqa-eval-manual \
  --format '{{.Name}} {{.Image}} {{json .Mounts}}' > "$REKA_RUN_DIR/containers.txt"

"$REKA_DOCKER" exec -it \
  -e REKA_RUN_DIR="$REKA_RUN_DIR" \
  "$REKA_MODEL_CONTAINER" /bin/bash --noprofile --norc
```

现在已经在**模型容器内**。先清理可能从容器环境继承的路由选择，然后按第 6 节只执行对应模式的命令：

```bash
while IFS= read -r reka_env_name; do
  case "$reka_env_name" in
    VLLM_FL_*|GEMS_*|FLAGGEMS_*|USE_FLAGGEMS|CUDA_VISIBLE_DEVICES|MACA_VISIBLE_DEVICES|PYTHONPATH|VLLM_PLUGINS|VLLM_ATTENTION_BACKEND|FLAGOS_DEVICE_CONTROL_ENV_VAR)
      unset "$reka_env_name" ;;
  esac
done < <(compgen -e)
unset reka_env_name
export VLLM_USE_V2_MODEL_RUNNER=0
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export TORCH_ALLOW_TF32_CUBLAS_OVERRIDE=0
set -o pipefail
```

终端 A 将持续显示 vLLM 日志，另开终端 B 执行第 7 节。需要断开 SSH 时，可自行把两个终端放在 tmux 会话中运行。

## 6. 手动启动 vLLM：三选一

### 6A. NV origin：容器内执行

```bash
export CUDA_VISIBLE_DEVICES=0,1
export VLLM_PLUGINS=''

/usr/bin/python3 /data/reka-gpqa-manual-20260917/record_environment.py \
  --mode nv-origin --run-dir "$REKA_RUN_DIR"

/usr/local/bin/vllm serve /data/models/reka-flash-3 \
  --served-model-name reka-flash-3 \
  --tensor-parallel-size 2 \
  --distributed-executor-backend mp \
  --dtype bfloat16 \
  --enforce-eager \
  --no-enable-prefix-caching \
  --no-enable-chunked-prefill \
  --max-model-len 32768 \
  --max-num-batched-tokens 32768 \
  --max-num-seqs 256 \
  --gpu-memory-utilization 0.90 \
  --generation-config vllm \
  --attention-backend FLASH_ATTN \
  --host 0.0.0.0 --port 9182 \
  2>&1 | tee "$REKA_RUN_DIR/vllm.log"
```

### 6B. 沐曦 FlagOS：容器内执行

```bash
export MACA_VISIBLE_DEVICES=1,2
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export USE_FLAGGEMS=1
export VLLM_FL_REFERENCE_MODE=0
export VLLM_FL_PREFER_ENABLED=1
export VLLM_FL_PREFER=flagos
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
export FLAGGEMS_ENABLE_OPLIST_PATH="$REKA_RUN_DIR/flaggems_ops.log"

/opt/conda/bin/python /data/reka-gpqa-manual-20260917/record_environment.py \
  --mode metax-flagos --run-dir "$REKA_RUN_DIR"

/opt/conda/bin/vllm serve /data/models/reka-flash-3 \
  --served-model-name reka-flash-3 \
  --tensor-parallel-size 2 \
  --distributed-executor-backend mp \
  --dtype bfloat16 \
  --enforce-eager \
  --no-enable-prefix-caching \
  --no-enable-chunked-prefill \
  --max-model-len 32768 \
  --max-num-batched-tokens 32768 \
  --max-num-seqs 256 \
  --gpu-memory-utilization 0.90 \
  --generation-config vllm \
  --trust-remote-code \
  --host 0.0.0.0 --port 9185 \
  2>&1 | tee "$REKA_RUN_DIR/vllm.log"
```

**保留历史黑名单的原始写法**：此镜像 `aten.sort.stable` 的函数名为 `sort_stable`，上面传入的是 `stable_sort`，所以历史日志里仍出现 `flag_gems.ops.sort.sort_stable`。若将名称修正，需要把它当成一轮新配置，不能直接称为对 51.52 分那一轮的原样复现。

该镜像的 `metax.yaml` 将 Attention 固定到 `vendor:metax`，使用 FA2。`VLLM_FL_USE_FLAGGEMS_ATTN=0` 本身不是对所有平台通用的“选择厂商 Attention”开关。

### 6C. 沐曦 reference：容器内执行

先安装当时使用的固定 wheel，所有文件写入本轮 `runtime`：

```bash
test ! -e "$REKA_RUN_DIR/runtime"
/opt/conda/bin/python -m pip install \
  --no-index --no-deps --disable-pip-version-check --no-compile \
  --target "$REKA_RUN_DIR/runtime" \
  /data/reka-gpqa-manual-20260917/reference-bundles/vllm_plugin_fl-0.0.0+g0ace80a63-py3-none-any.whl \
  /data/reka-gpqa-manual-20260917/reference-bundles/flag_gems-5.4.0.dev606+g95ed7f9c4.d20260803-py3-none-any.whl \
  /data/reka-gpqa-manual-20260917/reference-bundles/sqlalchemy-2.0.48-py3-none-any.whl

export PYTHONPATH="$REKA_RUN_DIR/runtime"
export MACA_VISIBLE_DEVICES=2,3
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export USE_FLAGGEMS=0
export VLLM_FL_REFERENCE_MODE=1
export VLLM_FL_REFERENCE_EXCLUDE=attention
export VLLM_FL_PREFER_ENABLED=1
export VLLM_FL_PREFER=vendor
export VLLM_FL_STRICT=1
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200

/opt/conda/bin/python /data/reka-gpqa-manual-20260917/record_environment.py \
  --mode metax-reference --run-dir "$REKA_RUN_DIR"

/opt/conda/bin/vllm serve /data/models/reka-flash-3 \
  --served-model-name reka-flash-3 \
  --tensor-parallel-size 2 \
  --distributed-executor-backend mp \
  --dtype bfloat16 \
  --enforce-eager \
  --no-enable-prefix-caching \
  --no-enable-chunked-prefill \
  --max-model-len 32768 \
  --max-num-batched-tokens 32768 \
  --max-num-seqs 256 \
  --gpu-memory-utilization 0.80 \
  --generation-config vllm \
  --host 0.0.0.0 --port 9184 \
  2>&1 | tee "$REKA_RUN_DIR/vllm.log"
```

reference 插件固定提交：`0ace80a639d97bcd13dca20209f002460802f51e`。FlagGems 包是导入依赖，ATen 接管关闭；Attention 排除在 reference 外，走沐曦 FA2。

0.80 是成功完成本轮评测的值。此前使用 0.90 时，批量 prefill 的 `SiluAndMul.forward_native` 临时张量分配发生过 OOM。

## 7. 公共步骤：准备数据并手动执行 EvalScope

### 7.1 在宿主机终端 B 选择本轮

重新 SSH 登录对应宿主机，只选一段变量设置：

NV origin：

```bash
export REKA_DOCKER=/mnt/data/docker-binary/docker/docker
export REKA_MODE=nv-origin
export REKA_MODEL_CONTAINER=reka-nv-origin-manual
export REKA_PORT=9182
```

沐曦 FlagOS：

```bash
export REKA_DOCKER=/usr/bin/docker
export REKA_MODE=metax-flagos
export REKA_MODEL_CONTAINER=reka-metax-flagos-manual
export REKA_PORT=9185
```

沐曦 reference：

```bash
export REKA_DOCKER=/usr/bin/docker
export REKA_MODE=metax-reference
export REKA_MODEL_CONTAINER=reka-metax-reference-manual
export REKA_PORT=9184
```

然后执行公共部分：

```bash
export REKA_KIT=/data/reka-gpqa-manual-20260917
export REKA_RUN_DIR="$(cat "$REKA_KIT/current-${REKA_MODE}.txt")"
printf '本轮目录：%s\n' "$REKA_RUN_DIR"
curl -fsS "http://127.0.0.1:${REKA_PORT}/health"
curl -fsS "http://127.0.0.1:${REKA_PORT}/v1/models"
```

`/health` 成功时响应体可能为空，以 HTTP 成功退出为准。若连接失败，先查看终端 A 的模型加载日志，服务就绪后再继续。不要把连接失败的请求提交给正式评测。

### 7.2 解压同版数据，写配置并准备缓存

以下仍在宿主机终端 B 执行：

```bash
mkdir -p "$REKA_RUN_DIR/datasets"
tar -xzf "$REKA_KIT/gpqa_diamond.tar.gz" -C "$REKA_RUN_DIR/datasets"

python3 "$REKA_KIT/make_config.py" \
  --mode "$REKA_MODE" --port "$REKA_PORT" --run-dir "$REKA_RUN_DIR"

"$REKA_DOCKER" exec \
  -e HF_HUB_OFFLINE=1 -e HF_DATASETS_OFFLINE=1 \
  reka-gpqa-eval-manual /usr/bin/python3 \
  "$REKA_KIT/prepare_cache.py" "$REKA_RUN_DIR"
```

检查输出中 `rows=198`、`questions_and_answers_match=true`。校验脚本会检查 EvalScope 版本和两份评分相关源码的哈希，不匹配时停止。

注意：**把 `train.jsonl` 放进目录还不够**。该版本 EvalScope 使用按数据集参数计算哈希的 Arrow 缓存，`prepare_cache.py` 正是为此准备；两边运行同一脚本即可。

### 7.3 正式评测

```bash
set -o pipefail
"$REKA_DOCKER" exec \
  -e HF_HUB_OFFLINE=1 \
  -e HF_DATASETS_OFFLINE=1 \
  -e TOKENIZERS_PARALLELISM=false \
  -e PYTHONUNBUFFERED=1 \
  -e PYTHONPATH= \
  reka-gpqa-eval-manual /usr/bin/python3 -u \
  "$REKA_KIT/run_eval.py" "$REKA_RUN_DIR" \
  2>&1 | tee "$REKA_RUN_DIR/evaluation.log"
```

终端会显示 `Evaluating[gpqa_diamond] ... /198`。实际模型配置应包含 `batch_size=256`、`max_tokens=16384`、`temperature=0.0`。

`make_config.py` 使用 `limit: null` 表示跑完整数据；不要替换成 `limit: 50` 或 `limit: 0`。模型会自然输出推理过程，不应沿用早期错误的 1228-token 上限。

需要再次测试时，从第 5 节新建运行目录，重新启动对应服务。配套配置脚本不会覆盖已有的评测输出。

## 8. 进度、最终结果与实际算子

第三个宿主机终端可读取日志；设置本轮 `REKA_RUN_DIR` 后执行：

```bash
tail -f "$REKA_RUN_DIR/evaluation.log"
```

服务运行期间也可以查看：

```bash
curl -fsS "http://127.0.0.1:${REKA_PORT}/metrics" \
  | grep -E 'vllm:(num_requests_running|num_requests_waiting|kv_cache_usage_perc)'
```

完整评测成功后：

```bash
cat "$REKA_RUN_DIR/gpqa.json"
cat "$REKA_RUN_DIR/sample_audit.json"
```

`gpqa.json` 中的 `score` 是百分制得分，`correct_count` 为正确题数，`truncated_samples` 为达到长度上限的题数。`sample_audit.json` 应显示 198 条预测、198 条评分、无预测错误、198 个评分状态 `success`。

逐题结果保存在：

- `outputs/predictions/`：完整模型输出、token 用量与停止原因。
- `outputs/reviews/`：逐题正确性及答案。
- `outputs/reports/`：EvalScope 原始汇总。

输入和答案顺序一致的本次三组，最终审计值为：

```text
input_set_hash = c1a22e9f98b220811ef9a859d32a2e2305cf7d0ac87864f5462e83ab8f8fce13
answer_key_hash = 54951c1cff34f69123f5500dfddba34f5ba1b69fde4d464ef6e364909624bfaa
```

解析预测 JSONL 时按文件的物理行迭代。不要对整个输出字符串使用 `splitlines()`：模型输出可能包含 Unicode 行分隔符。

查看算子：

```bash
# 沐曦 FlagOS：含加载、预热和正式执行，按日志调用位置去重
cat "$REKA_RUN_DIR/flaggems_ops.log"
grep "Op '" "$REKA_RUN_DIR/vllm.log"

# 沐曦 reference
grep '\[REFERENCE\]' "$REKA_RUN_DIR/vllm.log"
```

历史 FlagOS 运行确认 RMSNorm、RoPE、SiluAndMul 选择 `default.flagos`，Attention 选择 `vendor.metax`；reference 运行确认这些复合算子进入 vLLM native 路径。首见日志不能解释为逐层、逐次调用的完整追踪。

## 9. 手动释放服务和显卡

本手动流程不会像之前的自动控制器那样自行停服。`run_eval.py` 完成、结果文件已生成后，在宿主机终端 B 执行：

```bash
"$REKA_DOCKER" stop "$REKA_MODEL_CONTAINER"
"$REKA_DOCKER" inspect "$REKA_MODEL_CONTAINER" --format '{{.State.Status}}'
ss -ltnp
```

再用 `nvidia-smi` 或 `mx-smi` 确认本轮卡上的模型进程退出。此处停止的是本文创建的专用模型容器；容器和宿主机上的日志、结果仍保留。评测容器没有 GPU，可以留给下一组继续使用。

## 10. 版本与复现边界

| 组件 | NV origin | 沐曦 FlagOS | 沐曦 reference |
|---|---|---|---|
| vLLM 包版本 | 0.24.0 | 0.1.dev17936+gee0da84ab.empty | 0.24.0+empty |
| Torch | 2.11.0+cu130 | 2.8.0+metax3.7.0.7 | 2.8.0+metax3.7.0.7 |
| Triton 导入版本 | 3.6.0 | 3.6.0 | 3.0.0+metax3.7.0.7 |
| Transformers | 5.12.1 | 5.9.0 | 5.9.0 |
| FlagGems | 未安装 | 5.3.2+g1ede19338 | 5.4.0.dev606+g95ed7f9c4.d20260803 |
| plugin-fl | 未安装 | aaae9bf71cd1e3082590a1f92ecc61add128fbfb | 0ace80a639d97bcd13dca20209f002460802f51e |

沐曦 FlagOS 镜像标签虽然写着 `vllm-0.24.0`，实际包版本是上表中的开发版本，vLLM 源码提交为 `ee0da84ab9e04ac7610e28580af62c365e898389`。它的 Triton 通过镜像的 FlagTree 提供，发行包名未必是 `triton`；若元数据查询显示 null，可在该容器中用 `python -c 'import triton; print(triton.__version__)'` 查看导入版本。

镜像摘要固定了镜像内容；历史容器的可写层、宿主机驱动以及本地模型也属于运行环境。以 `environment.json` 与本表核对版本，不要仅凭镜像标签判断两个环境完全相同。该文件记录模型配置文件哈希，不是全部 safetensors 权重的哈希。

本教程保持当时的模型和 tokenizer 配置，没有额外添加 `fix_mistral_regex` 参数。更换 tokenizer、修正黑名单、改变并发、Attention 或生成预算后，应另建目录并记录为新配置。

### 数据与软件来源

- 数据来自 [release_gap 的评测目录](https://github.com/tonyh168/release_gap/tree/fa6aa727f54323b17a7826b69b44dba292fb915a/flagrelease_eval_methods)，固定提交 `fa6aa727f54323b17a7826b69b44dba292fb915a`。
- 数据归档 SHA256：`ffd2a0547e70d09c26efe8bf130705f0584b5d95ae9d4e641a759042abd1bdc5`。
- `train.jsonl` SHA256：`514eb956ff0f47448621996533cfd30882130cec57984e267846c0e1d58fc50f`。
- 固定 reference wheel 来源于 [auto-fl-reference](https://github.com/JiaryCoder/auto-fl-reference/tree/513a459e7f623a192527d3274f4babee2290a898) 的 bundles；版本说明和包许可见配套 `THIRD_PARTY.md`、`reference-bundles/manifest.json`。
- 本文配套评测代码沿用本次成功运行的 EvalScope 调用和逐题审计逻辑；服务创建、启动与停止由本文命令手动完成。

### 文档交付时完成的检查

全部 25 个 Bash 代码块通过语法检查，4 份 Python 文件通过语法检查。在 NV 和沐曦的实际评测容器内，验证了三组 TaskConfig、198 题离线缓存和评分代码哈希。去除端口、数据缓存目录和结果目录这些运行位置字段后，生成的完整评测配置与对应历史成功运行完全一致。评分入口 `run_eval.py` 与历史脚本逐字节一致。

另外用三份基础模型镜像做了不加载 GPU 模型的包版本检查，与上表对应。此次文档校验没有重新进行完整模型推理评测，历史分数仍来自前述三轮。

### 历史结果目录

NV 宿主机：

```text
/data/reference-eval/fast-gpqa-runs/20260917-130704-reka-h20_native-gpqa198-c256-g16384-63d28ad9
```

沐曦 FlagOS：

```text
/data/reference-eval/fast-gpqa-runs/20260917-142642-reka-metax_flagos-gpqa198-c256-g16384-2d75e460
```

沐曦 reference：

```text
/data/reference-eval/fast-gpqa-runs/20260917-131331-reka-metax_reference-gpqa198-c256-g16384-58eb883e
```

以上三个目录均含历史 `gpqa.json`、`sample_audit.json`、`REPORT.zh-CN.md` 和日志。按本文新建的手动运行目录由 `run_eval.py` 生成 JSON 结果，不生成旧自动控制器的 `REPORT.zh-CN.md`。
