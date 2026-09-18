# SOLAR-10.7B-Instruct-v1.0：NV / 沐曦 GPQA Diamond 手动复现

整理日期：2026-09-17。依据 2026-09-16 已完成的四轮评测配置与逐题结果整理。

本文复现 **NV 原生**和**沐曦 reference**，支持 **50 题**与**完整 198 题**。当时没有完成 SOLAR 的沐曦 FlagOS 评测，因此本文不提供对应历史成绩。

主流程固定历史正式评测参数，通过同版 EvalScope 执行；附录保留当时未修改的 `fast_gpqa.py` 和原 SOP 调用方式。模型服务在终端 A 运行，评测在终端 B 运行，结束后手动停止专用模型容器。

## 1. 历史参数和成绩

模型在宿主机及模型容器内均位于：

```text
/data/models/SOLAR-10.7B-Instruct-v1.0
```

| 参数 | NV origin | 沐曦 reference |
|---|---|---|
| GPU | H20，卡 0 | MetaX C550，卡 2 |
| TP / dtype / 执行模式 | 1 / bfloat16 / eager | 1 / bfloat16 / eager |
| 服务端口 | 9182 | 9184 |
| max-model-len | **4096** | **4096** |
| max-num-batched-tokens | 4096 | 4096 |
| max-num-seqs | 64 | 64 |
| gpu-memory-utilization | **0.90** | **0.90** |
| prefix caching / chunked prefill | 均关闭 | 均关闭 |
| Attention | FLASH_ATTN，实际 FA3 | vendor:metax，实际 FA2 |
| 正式请求并发 | **16** | **4** |
| max_tokens | **2048** | **2048** |
| temperature / top_p | **0.0 / 1.0** | **0.0 / 1.0** |
| stream / n / timeout | **true / 1 / 120000 秒** | **true / 1 / 120000 秒** |
| TaskConfig seed | **42** | **42** |

`max-num-seqs=64` 是服务调度上限，评测并发分别为 16 和 4。SOLAR 的历史配置不是 Reka 的 TP2、并发 256、生成上限 16384。

正式生成配置没有显式设置 `top_k`、`repetition_penalty` 或请求级 seed。vLLM 使用 `--generation-config vllm`；本文保留这一行为，不追加其他采样参数。旧控制器 `config.json` 中的 `seed=1234`、`thinking=false` 仅用于连通性探测，不是正式 GPQA 请求参数。

数据集为 `gpqa_diamond` 的 default 子集、train split，0-shot、repeats=1。50 题使用该数据集顺序的前 50 题；全量使用 198 题。提示词、选项处理及评分由固定版本 EvalScope 的 GPQA adapter 提供，不额外传 `enable_thinking`、system prompt、stop strings 或回答过滤器。

| 题数 | NV origin | 沐曦 reference | NV 实际截断 | 沐曦实际截断 |
|---|---:|---:|---:|---:|
| 50 | **24.00 分，12/50** | **36.00 分，18/50** | 1 题 `max_tokens` | 1 题 `max_tokens` |
| 198 | **26.26 分，52/198** | **29.29 分，58/198** | 1 题 `model_length` + 1 题 `max_tokens` | 1 题 `model_length` |

历史成绩用于对照，不保证跨环境逐 token 或逐题完全相同。并发、软件环境和 Attention 实现本就存在差异。`model_length` 表示达到总上下文长度，`max_tokens` 表示达到生成预算；2048 生成预算与 4096 总上下文需要一起考虑。

**历史 `fast_gpqa.py` 报告里的 `truncation_detected=false` 只描述启动时样题探测。** 它不能替代完整逐题停止原因统计；上表依据实际预测文件审计。

## 2. 配套文件与传输

Downloads 中的配套目录为 `solar-gpqa-manual-20260917/`：

- `make_config.py`：选择 NV / 沐曦、50 / 198 题，写入固定历史参数。
- `prepare_cache.py`：验证同版数据及评分代码，建立 EvalScope 的离线 Arrow 缓存。
- `run_eval.py`：手动执行 EvalScope，并核对逐题数目、正确数和截断数。
- `record_environment.py`：记录模型容器的公开版本信息和模型配置哈希。
- `task_template.json`：从历史正式评测配置提取的参数模板。
- `gpqa_diamond.tar.gz`：当时使用的同一份 198 题数据。
- `reference-bundles/`：固定 reference 安装包，仅沐曦 reference 使用。
- `history/`：四轮历史配置和审计结果，不含模型回答正文。
- `source/fast_gpqa.py`：当时执行的原版 SOP 脚本，供附录使用。
- `SHA256SUMS`、`VALIDATION.json`：文件校验清单与本次文档验证记录。

在 **macOS 终端** 执行：

```bash
scp -r ~/Downloads/solar-gpqa-manual-20260917 baai-h20-01-clone:/data/
scp -r ~/Downloads/solar-gpqa-manual-20260917 baai-dx-mc550:/data/
```

以下步骤在 Linux 宿主机或明确指定的容器内执行。模型权重需已经完整下载，配套包不包含模型权重。

## 3. 宿主机准备

### 3.1 登录并设置 Docker CLI

NV 宿主机：

```bash
ssh baai-h20-01-clone
export SOLAR_DOCKER=/mnt/data/docker-binary/docker/docker
nvidia-smi
```

沐曦宿主机：

```bash
ssh baai-dx-mc550
export SOLAR_DOCKER=/usr/bin/docker
mx-smi
```

新机器按 `command -v docker` 的结果设置 `SOLAR_DOCKER`。每个新开的宿主机终端都需要设置它。

两边均执行：

```bash
test -f /data/models/SOLAR-10.7B-Instruct-v1.0/config.json
test -f /data/models/SOLAR-10.7B-Instruct-v1.0/model.safetensors.index.json
ss -ltnp
cd /data/solar-gpqa-manual-20260917
sha256sum -c SHA256SUMS
```

检查目标 GPU 的实时占用及 9182 / 9184 端口是否空闲。修改卡号或其他参数时，把变化记录到本轮目录。

### 3.2 创建专用评测容器

NV 和沐曦各执行一次。原标签为 `harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope`，这里使用当时的固定镜像摘要：

```bash
export SOLAR_EVAL_IMAGE=harbor.baai.ac.cn/flagrelease-public/flagos-evalscope@sha256:8a2847c2b8cee9f4ccd62ae6534b46bc9b59694c6c33571e20ab34f535c2c128
"$SOLAR_DOCKER" pull "$SOLAR_EVAL_IMAGE"
"$SOLAR_DOCKER" run -d \
  --name solar-gpqa-eval-manual \
  --network host \
  -v /data:/data \
  "$SOLAR_EVAL_IMAGE" sleep infinity
```

若该专用容器已按相同镜像和挂载创建，执行 `"$SOLAR_DOCKER" start solar-gpqa-eval-manual` 即可。

核对版本：

```bash
"$SOLAR_DOCKER" exec solar-gpqa-eval-manual /usr/bin/python3 -c \
  'import importlib.metadata as m; print({n:m.version(n) for n in ["evalscope","modelscope","datasets"]})'
```

应为 `evalscope=1.11.1`、`modelscope=1.40.0`、`datasets=4.8.4`。评测容器只通过 HTTP 调用模型，无需挂 GPU。

## 4. 创建对应的模型容器：二选一

### A. NV origin

原标签：`vllm/vllm-openai:v0.24.0`。

```bash
export SOLAR_MODEL_IMAGE=vllm/vllm-openai@sha256:251eba5cc7c12fed0b75da22a9240e582b1c9e39f6fbc064f86781b963bd814f
"$SOLAR_DOCKER" pull "$SOLAR_MODEL_IMAGE"
"$SOLAR_DOCKER" run -d \
  --name solar-nv-origin-manual \
  --network host --ipc=host --gpus all \
  -v /data:/data \
  --entrypoint /bin/bash \
  "$SOLAR_MODEL_IMAGE" -lc 'sleep infinity'

export SOLAR_MODE=nv-origin
export SOLAR_MODEL_CONTAINER=solar-nv-origin-manual
export SOLAR_PORT=9182
```

NV 宿主机的驱动与 NVIDIA Container Toolkit 需已可用。该容器不安装 FlagGems 或 plugin-fl。

### B. 沐曦 reference

原基础镜像标签：

`harbor.baai.ac.cn/plugin/metax-maca3.7.0-treenone-triton3.0.0-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt280-x64:202507290700`

```bash
export SOLAR_MODEL_IMAGE=harbor.baai.ac.cn/plugin/metax-maca3.7.0-treenone-triton3.0.0-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt280-x64@sha256:1358058b5e58cc7adb5b6496186797016418c0be554718066131020aa1500899
"$SOLAR_DOCKER" pull "$SOLAR_MODEL_IMAGE"
"$SOLAR_DOCKER" run -d \
  --name solar-metax-reference-manual \
  --network host --shm-size 64g \
  --device /dev/dri:/dev/dri:rwm \
  --device /dev/mxcd:/dev/mxcd:rwm \
  -v /MXC550/share/models:/models \
  -v /data:/data \
  "$SOLAR_MODEL_IMAGE" sleep infinity

export SOLAR_MODE=metax-reference
export SOLAR_MODEL_CONTAINER=solar-metax-reference-manual
export SOLAR_PORT=9184
```

reference 固定 wheel 在第 6B 节安装。

## 5. 选择 50 / 198 题，建立本轮目录

在已设置对应模式的**宿主机终端 A**执行。默认完整 198 题；如复现 GPQA50，将第一行改为 `export SOLAR_QUESTIONS=50`：

```bash
export SOLAR_QUESTIONS=198
export SOLAR_RUN_DIR="/data/solar-gpqa-manual-runs/$(date +%Y%m%d-%H%M%S)-${SOLAR_MODE}-gpqa${SOLAR_QUESTIONS}"
mkdir -p "$SOLAR_RUN_DIR"
printf '%s\n' "$SOLAR_RUN_DIR" > "/data/solar-gpqa-manual-20260917/current-${SOLAR_MODE}-${SOLAR_QUESTIONS}.txt"

"$SOLAR_DOCKER" inspect "$SOLAR_MODEL_CONTAINER" solar-gpqa-eval-manual \
  --format '{{.Name}} {{.Image}} {{json .Mounts}}' > "$SOLAR_RUN_DIR/containers.txt"

"$SOLAR_DOCKER" exec -it -e SOLAR_RUN_DIR="$SOLAR_RUN_DIR" \
  "$SOLAR_MODEL_CONTAINER" /bin/bash --noprofile --norc
```

现在位于**模型容器内**。先执行共同的环境准备：

```bash
while IFS= read -r solar_env_name; do
  case "$solar_env_name" in
    VLLM_FL_*|GEMS_*|FLAGGEMS_*|USE_FLAGGEMS|CUDA_VISIBLE_DEVICES|MACA_VISIBLE_DEVICES|PYTHONPATH|VLLM_PLUGINS|VLLM_ATTENTION_BACKEND|FLAGOS_DEVICE_CONTROL_ENV_VAR)
      unset "$solar_env_name" ;;
  esac
done < <(compgen -e)
unset solar_env_name
export VLLM_USE_V2_MODEL_RUNNER=0
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export TORCH_ALLOW_TF32_CUBLAS_OVERRIDE=0
set -o pipefail
```

终端 A 持续运行模型服务；另开宿主机终端 B 执行第 7 节。需要保持 SSH 断开后继续运行时，可将两个终端放在 tmux 会话中。

## 6. 容器内手动启动 vLLM：二选一

### 6A. NV origin

```bash
export CUDA_VISIBLE_DEVICES=0
export VLLM_PLUGINS=''

/usr/bin/python3 /data/solar-gpqa-manual-20260917/record_environment.py \
  --mode nv-origin --run-dir "$SOLAR_RUN_DIR"

/usr/local/bin/vllm serve /data/models/SOLAR-10.7B-Instruct-v1.0 \
  --served-model-name SOLAR-10.7B-Instruct-v1.0 \
  --tensor-parallel-size 1 \
  --distributed-executor-backend mp \
  --dtype bfloat16 \
  --enforce-eager \
  --no-enable-prefix-caching \
  --no-enable-chunked-prefill \
  --max-model-len 4096 \
  --max-num-batched-tokens 4096 \
  --max-num-seqs 64 \
  --gpu-memory-utilization 0.90 \
  --generation-config vllm \
  --attention-backend FLASH_ATTN \
  --host 0.0.0.0 --port 9182 \
  2>&1 | tee "$SOLAR_RUN_DIR/vllm.log"
```

### 6B. 沐曦 reference

先把固定依赖安装到本轮目录，保持基础 Torch / vLLM / Triton 不变：

```bash
test ! -e "$SOLAR_RUN_DIR/runtime"
/opt/conda/bin/python -m pip install \
  --no-index --no-deps --disable-pip-version-check --no-compile \
  --target "$SOLAR_RUN_DIR/runtime" \
  /data/solar-gpqa-manual-20260917/reference-bundles/vllm_plugin_fl-0.0.0+g0ace80a63-py3-none-any.whl \
  /data/solar-gpqa-manual-20260917/reference-bundles/flag_gems-5.4.0.dev606+g95ed7f9c4.d20260803-py3-none-any.whl \
  /data/solar-gpqa-manual-20260917/reference-bundles/sqlalchemy-2.0.48-py3-none-any.whl

export PYTHONPATH="$SOLAR_RUN_DIR/runtime"
export MACA_VISIBLE_DEVICES=2
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

/opt/conda/bin/python /data/solar-gpqa-manual-20260917/record_environment.py \
  --mode metax-reference --run-dir "$SOLAR_RUN_DIR"

/opt/conda/bin/vllm serve /data/models/SOLAR-10.7B-Instruct-v1.0 \
  --served-model-name SOLAR-10.7B-Instruct-v1.0 \
  --tensor-parallel-size 1 \
  --distributed-executor-backend mp \
  --dtype bfloat16 \
  --enforce-eager \
  --no-enable-prefix-caching \
  --no-enable-chunked-prefill \
  --max-model-len 4096 \
  --max-num-batched-tokens 4096 \
  --max-num-seqs 64 \
  --gpu-memory-utilization 0.90 \
  --generation-config vllm \
  --host 0.0.0.0 --port 9184 \
  2>&1 | tee "$SOLAR_RUN_DIR/vllm.log"
```

此处固定 reference 提交 `0ace80a639d97bcd13dca20209f002460802f51e`。FlagGems 包是导入依赖，其 ATen 接管关闭；Attention 排除在 reference 外，走沐曦 FA2。

## 7. 宿主机终端 B：准备离线数据与评测

### 7.1 恢复本轮变量

重新登录对应宿主机，只选择对应的一段。

NV：

```bash
export SOLAR_DOCKER=/mnt/data/docker-binary/docker/docker
export SOLAR_MODE=nv-origin
export SOLAR_MODEL_CONTAINER=solar-nv-origin-manual
export SOLAR_PORT=9182
```

沐曦：

```bash
export SOLAR_DOCKER=/usr/bin/docker
export SOLAR_MODE=metax-reference
export SOLAR_MODEL_CONTAINER=solar-metax-reference-manual
export SOLAR_PORT=9184
```

共同部分，`SOLAR_QUESTIONS` 必须与终端 A 的选择相同：

```bash
export SOLAR_QUESTIONS=198
export SOLAR_KIT=/data/solar-gpqa-manual-20260917
export SOLAR_RUN_DIR="$(cat "$SOLAR_KIT/current-${SOLAR_MODE}-${SOLAR_QUESTIONS}.txt")"
printf '本轮目录：%s\n' "$SOLAR_RUN_DIR"
curl -fsS "http://127.0.0.1:${SOLAR_PORT}/health"
curl -fsS "http://127.0.0.1:${SOLAR_PORT}/v1/models"
```

`/health` 成功响应体可能为空，以 HTTP 成功退出为准。连接失败时先看终端 A 日志，服务就绪后继续。

### 7.2 配置题数和缓存

```bash
mkdir -p "$SOLAR_RUN_DIR/datasets"
tar -xzf "$SOLAR_KIT/gpqa_diamond.tar.gz" -C "$SOLAR_RUN_DIR/datasets"

python3 "$SOLAR_KIT/make_config.py" \
  --mode "$SOLAR_MODE" --questions "$SOLAR_QUESTIONS" \
  --port "$SOLAR_PORT" --run-dir "$SOLAR_RUN_DIR"

"$SOLAR_DOCKER" exec \
  -e HF_HUB_OFFLINE=1 -e HF_DATASETS_OFFLINE=1 \
  solar-gpqa-eval-manual /usr/bin/python3 \
  "$SOLAR_KIT/prepare_cache.py" "$SOLAR_RUN_DIR"
```

配置脚本固定 NV 并发 16、沐曦并发 4。`--questions 50` 生成 `limit: 50`；`--questions 198` 生成 `limit: null`。离线缓存始终包含完整 198 题，因此缓存输出 `rows=198` 是正常的，取 50 题发生在 EvalScope 评测阶段。

`prepare_cache.py` 不只是检查 JSONL：它建立 EvalScope 1.11.1 需要的哈希路径 Arrow 缓存，并验证数据内容与评分代码哈希。

### 7.3 正式执行

```bash
set -o pipefail
"$SOLAR_DOCKER" exec \
  -e HF_HUB_OFFLINE=1 \
  -e HF_DATASETS_OFFLINE=1 \
  -e TOKENIZERS_PARALLELISM=false \
  -e PYTHONUNBUFFERED=1 \
  -e PYTHONPATH= \
  solar-gpqa-eval-manual /usr/bin/python3 -u \
  "$SOLAR_KIT/run_eval.py" "$SOLAR_RUN_DIR" \
  2>&1 | tee "$SOLAR_RUN_DIR/evaluation.log"
```

观察 `Evaluating[gpqa_diamond] ... /50` 或 `... /198`。模型请求配置中应看到 `max_tokens=2048`、`temperature=0.0`、`stream=True`，以及对应的 `batch_size=16` 或 `4`。

主流程直接重放历史正式评测参数，省略自动并发探测请求。它没有修改评测容器内的 GPQA adapter 或评分规则。若要重放包括探测过程在内的原 SOP，使用附录；两种路径每次分别新建运行目录，不在同一目录连跑。

## 8. 结果、进度与停止

### 8.1 查看进度和最终结果

其他宿主机终端设置好 `SOLAR_RUN_DIR` 后可以查看：

```bash
tail -f "$SOLAR_RUN_DIR/evaluation.log"
```

完成后：

```bash
cat "$SOLAR_RUN_DIR/gpqa.json"
cat "$SOLAR_RUN_DIR/sample_audit.json"
```

核对 `total_questions`、`correct_count`、`score`、`finish_reasons` 和 `truncated_samples`。预测数与评分数应等于所选 50 / 198，`prediction_errors` 应为空，所有评分状态应为 `success`。

逐题输出、评分和 EvalScope 原始报告分别在 `outputs/predictions/`、`outputs/reviews/`、`outputs/reports/`。可在不重新请求模型的情况下再次汇总已有结果：

```bash
python3 "$SOLAR_KIT/run_eval.py" "$SOLAR_RUN_DIR" --audit-only
```

审计按 JSONL 的物理行读取。不要对整份模型输出文本调用 `splitlines()`，因为输出可能包含 Unicode 行分隔符。

沐曦 reference 的实际路由记录在：

```bash
grep '\[REFERENCE\]' "$SOLAR_RUN_DIR/vllm.log"
```

这类日志包含加载、预热和正式执行时首次见到的调用，不是逐层逐次完整追踪。

### 8.2 释放模型服务

本手动流程由用户停服。确认评测结束后，在宿主机终端 B 执行：

```bash
"$SOLAR_DOCKER" stop "$SOLAR_MODEL_CONTAINER"
"$SOLAR_DOCKER" inspect "$SOLAR_MODEL_CONTAINER" --format '{{.State.Status}}'
ss -ltnp
```

再用 `nvidia-smi` 或 `mx-smi` 确认模型进程和显存释放。本文创建的是专用模型容器，停止后容器和宿主机上的数据仍保留。评测容器无需 GPU，可以继续留用。

换另一种题数时，重新启动对应专用模型容器，从第 5 节新建运行目录再执行。

## 9. 附录：原 SOP 的自动探测流程

这一节是第 7.3 节的替代方式。它使用原版 `source/fast_gpqa.py`，会先探测最大生成预算、样题截断和并发，再进行正式评测。历史 SOLAR 的结果为 max_tokens=2048、NV 并发 16、沐曦并发 4；重新探测可能选择不同并发，应以这轮日志为准。

先完成第 7.2 节的数据和缓存准备，并确认本轮目录还没有评测输出。然后在宿主机终端 B 执行：

```bash
# 此处是上游 fast_gpqa.py 的参数语义：0 表示完整 198 题
export SOLAR_SOP_LIMIT=0
# 复现 50 题时，将上一行改为 export SOLAR_SOP_LIMIT=50

set -o pipefail
"$SOLAR_DOCKER" exec \
  -w "$SOLAR_RUN_DIR" \
  -e HF_HUB_OFFLINE=1 -e HF_DATASETS_OFFLINE=1 \
  -e TOKENIZERS_PARALLELISM=false -e PYTHONUNBUFFERED=1 -e PYTHONPATH= \
  solar-gpqa-eval-manual /usr/bin/python3 -u \
  "$SOLAR_KIT/source/fast_gpqa.py" \
  --model-name SOLAR-10.7B-Instruct-v1.0 \
  --api-base "http://127.0.0.1:${SOLAR_PORT}/v1" \
  --dataset gpqa_diamond \
  --limit "$SOLAR_SOP_LIMIT" \
  --dataset-dir "$SOLAR_RUN_DIR/datasets" \
  --output "$SOLAR_RUN_DIR/gpqa-sop.json" \
  2>&1 | tee "$SOLAR_RUN_DIR/evaluation-sop.log"
```

保持 `--model-name` 为上述服务名称，不改成模型本地路径；历史脚本的模型采样参数探测逻辑会区分名称与目录。该原始流程还可能读取 `/flagos-workspace/shared/context.yaml`，专用新评测容器应保持本次镜像的默认状态，不混入其他模型流水线配置。

原 SOP 输出在 `gpqa-sop.json` 以及 `outputs/gpqa_diamond/<时间戳>/` 下，其目录布局和主流程不同。主流程的 `--audit-only` 针对 `outputs/predictions/` 布局，不能直接用于附录输出。附录运行时仍需检查原始预测停止原因，不只看 `truncation_detected`。

附录流程结束后，可在宿主机用以下命令统计实际停止原因：

```bash
python3 - "$SOLAR_RUN_DIR" <<'PY'
import collections, json, sys
from pathlib import Path
root = Path(sys.argv[1])
files = list(root.glob('outputs/gpqa_diamond/*/predictions/**/gpqa_diamond_default.jsonl'))
assert len(files) == 1, '每个运行目录应只包含一轮 SOP 评测'
with files[0].open() as stream:
    rows = [json.loads(line) for line in stream if line.strip()]
reasons = collections.Counter(choice['stop_reason']
    for row in rows for choice in row['model_output']['choices'])
print(json.dumps({'samples': len(rows), 'finish_reasons': dict(reasons),
    'truncated_samples': sum(n for reason, n in reasons.items()
        if reason in ['max_tokens', 'model_length', 'length'])}, indent=2))
PY
```

## 10. 版本、数据来源与历史记录

| 项目 | NV origin | 沐曦 reference |
|---|---|---|
| vLLM | 0.24.0 | 0.24.0+empty |
| Torch | 2.11.0+cu130 | 2.8.0+metax3.7.0.7 |
| Triton | 3.6.0 | 3.0.0+metax3.7.0.7 |
| Transformers | 5.12.1 | 5.9.0 |
| plugin-fl | 未安装 | 0ace80a639d97bcd13dca20209f002460802f51e |
| FlagGems | 未安装 | 5.4.0.dev606+g95ed7f9c4.d20260803，ATen 接管关闭 |

固定镜像摘要仍需配合宿主机驱动和同版模型使用。`environment.json` 记录版本、模块路径及模型配置文件哈希；它不包含所有 safetensors 权重的哈希。正式评测用模型目录自带的 tokenizer / chat template。

数据及原 SOP 来源为 [release_gap 的固定提交](https://github.com/tonyh168/release_gap/tree/fa6aa727f54323b17a7826b69b44dba292fb915a/flagrelease_eval_methods)。归档 SHA256 为 `ffd2a0547e70d09c26efe8bf130705f0584b5d95ae9d4e641a759042abd1bdc5`；JSONL SHA256 为 `514eb956ff0f47448621996533cfd30882130cec57984e267846c0e1d58fc50f`。

原 `fast_gpqa.py` SHA256 为 `ae47615a03064ee170353320662159acb2109e5735080d22252e79d97473f1e1`。reference wheel 来自 [auto-fl-reference 固定版本](https://github.com/JiaryCoder/auto-fl-reference/tree/513a459e7f623a192527d3274f4babee2290a898)；许可与打包说明见 `THIRD_PARTY.md`。

四轮历史运行目录：

| 主机 | 题数 | `/data/reference-eval/fast-gpqa-runs/` 下的目录 |
|---|---:|---|
| baai-h20-01-clone | 50 | `20260916-190714-solar-native-bc87cb03` |
| baai-h20-01-clone | 198 | `20260916-191626-solar-native-gpqa198-1e9a8942` |
| baai-dx-mc550 | 50 | `20260916-184840-solar-reference-2321ab4c` |
| baai-dx-mc550 | 198 | `20260916-191626-solar-reference-gpqa198-a83d09ba` |

同一题数的两组历史输出，规范化后的输入和答案哈希一致：

```text
50 题 input_set_hash:
ad2158c39a68ae68eb7cfa0776cfbfc07752c7da874fbdad8f282cb0ce988e2a
50 题 answer_key_hash:
b185ae2800b626f877aa781a8ca3b9fb8294982705150383753d3ebc803f5305

198 题 input_set_hash:
c1a22e9f98b220811ef9a859d32a2e2305cf7d0ac87864f5462e83ab8f8fce13
198 题 answer_key_hash:
54951c1cff34f69123f5500dfddba34f5ba1b69fde4d464ef6e364909624bfaa
```

`history/` 保留四轮实际生成参数、结果计数和哈希，便于核对。主流程生成 `gpqa.json` 与 `sample_audit.json`；不会生成旧自动评测控制器的 `REPORT.zh-CN.md`。

### 文档交付校验

已检查所有 Bash 代码块和 Python 文件的语法。在 NV 和沐曦的实际 EvalScope 容器内，验证四种组合的 TaskConfig 与历史配置一致（忽略 API 地址、目录、密钥显示方式及运行时生成的标识字段），并验证完整 198 题离线缓存与评分代码哈希。

配套审计代码还读取四轮已保存的回答，复算得到 NV 的 12/50、52/198 和沐曦的 18/50、58/198，停止原因及输入、答案哈希均与历史审计一致。原 SOP 脚本已通过原始 SHA256 校验。此次文档验证发送的模型请求数为 0，没有重新跑完整模型评测。
