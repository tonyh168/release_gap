# hygon/Mistral-7B-OpenOrca 修复日志

- **失败报告**：flagrelease_fail_reports/Hygon/FAILED_Hygon_Mistral-7B-OpenOrca_202607241434.md
- **原始失败类型**：精度不达标（历史报告同时记录 plugin-FL 报错）
- **日期**：2026-09-16

## 现象

- 历史报告使用旧栈（vLLM `0.20.2` / plugin-FL `0.2.0` / FlagGems `5.4.0dev` / Flagtree `0.6.0+hcu`），V2/V3 均沿用 26 项 FlagGems 算子白名单，50 题 GPQA Diamond 分别为 `22%` / `24%`，低于 NV 记录值 `27%`，因此迁移失败（并留有 plugin-FL error issue）。
- 本轮换用统一 Hygon 新镜像后单卡服务正常启动，接口持续返回 HTTP `200`，`/v1/models` 返回服务名 `Mistral-7B-OpenOrca`、`max_model_len=32768`。
- 全量 GPQA Diamond 198 题结果 `25.76%`（约 51/198），NV 记录值 `27%`，绝对低 `1.24` 个百分点，相对退化 `4.59%`。
- 本轮检测到 `4` 题 runaway/复读异常，但汇总分仍在 NV 记录值的 5% 相对容差内。

## 定位

- **服务部署链路已不是瓶颈**：同一台宿主机、同一镜像下，单卡（GPU3）即可稳定提供服务，未再复现历史报告中的 plugin-FL error。
- **不能把改善归因到单一组件**：本次变化同时包含 vLLM（0.20.2 → 0.24.0）、plugin-FL、Flagtree、DTK 与注意力实现（固定 `TRITON_ATTN`）。现有证据只支持“新软件栈及当前 `TRITON_ATTN` 路径解决了本轮部署/精度门控问题”，历史失败不能继续简单归因于某一个普通 FlagGems 算子。
- **相对量纲差异**：历史失败用 50 题（22%/24%），本轮用全量 198 题（25.76%），两者不能直接横比，只能各自与 NV 记录值比。
- **NV 元数据不完整**：`nv_baseline.yaml` 只记录 NV 分数 `27%`，没有 NV 原始题目 ID、样本量、prompt、EvalScope 版本和逐题预测，因此只能确认相对仓库 NV 记录值达标，不能证明 NV 与本次 Hygon 198 题逐题同源。

## 处置

宿主机 `bm-srwl-nj-zone3-d-bw1000-64g-2-33`（`10.232.2.33`），推理容器 `day0-mistral-7b-openorca`，评测容器 `day0-eval-standard`，端口 `8001`，`HIP_VISIBLE_DEVICES=3`，TP=1，bf16。模型 `/public-flash/models/Mistral-7B-OpenOrca` → 容器内 `/models/Mistral-7B-OpenOrca`。本轮未重新构建/推送镜像，也未修改 vLLM、`vllm-plugin-FL`、FlagGems 源码。

容器运行配置（长驻容器 + `docker exec` 起服务）：

```text
cmd:      ["bash", "-lc", "sleep infinity"]
network:  host
ipc:      host
shm-size: 64 GiB
```

设备与权限：`/dev/kfd`、`/dev/dri`、`seccomp=unconfined`、`group-add=video`；挂载 `/public-flash/models -> /models`（读写）、`/opt/hyhal -> /opt/hyhal`（只读）。评测容器使用 host 网络，并挂载 `/public-flash/models/day0_eval -> /models/day0_eval`、`/public-flash/models/day0_logs -> /models/day0_logs`。

本轮修复只有一轮配置（旧栈分层 V1–V4 未复现，按项目口径直接用 plugin-FL 起服务）：

| 轮次 | 栈 / 配置 | 题数 | 分数 | 相对 NV | 判定 |
|------|-----------|-----:|-----:|--------:|------|
| 历史 V2 | vLLM `0.20.2` + FlagGems，26 算子白名单 | 50 | `22.0%` | `18.52%` | 不达标 |
| 历史 V3 | 同上 + plugin-FL `0.2.0` | 50 | `24.0%` | `11.11%` | 不达标 |
| 本轮 | 新镜像 + plugin-FL + `TRITON_ATTN`，保留同一 26 算子白名单 | 198（全量） | `25.76%` | `4.59%` | 达标 |

处置步骤：

1. 使用统一 Hygon 新镜像和单卡 GPU3；
2. 保留历史失败报告的 26 项 FlagGems 白名单（不新增、不删减）；
3. 固定 `TRITON_ATTN`、BF16、TP=1 和 eager 模式；
4. 沿用 Triton 默认缓存目录；
5. 使用 EvalScope `1.5.1`、固定并发 4，执行 GPQA Diamond **全量 198 题**；
6. 记录 runaway 数量，并与 NV 记录值按同一比较脚本判定。
7. 环境变量沿用本机实测的 DTK/FlagOS 组合（`DTK_HOME`/`ROCM_PATH`/`HIP_PATH`/`HSA_PATH`/`DEVICE_LIB_PATH`/`TRITON_HIP_CLANG_PATH` + `GEMS_VENDOR=hygon` + `VLLM_PLUGINS=fl` + spawn + 7200s 超时）；未显式设置 `VLLM_FL_OOT_ENABLED`、`VLLM_FL_OOT_BLACKLIST`、`VLLM_FL_FLAGOS_BLACKLIST`，沿用镜像默认 OOT 行为。

关键日志：

```text
/public-flash/models/day0_logs/Mistral-7B-OpenOrca-deploy-20260914-173759-exact-md.log
/public-flash/models/day0_logs/Mistral-7B-OpenOrca-serve-20260914-173759-exact-md.log
```

评测配置：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.5.1` |
| 题数 | 198（全量） |
| `eval_batch_size` | 4 |
| `temperature` | 0 |
| `max_model_len` | 32768 |
| `max_tokens` | 24576（标准模型自动计算值） |
| 截断检测 | `--skip-truncation-check` 显式跳过 |

- 结果文件：`/public-flash/models/day0_logs/accuracy/Mistral-7B-OpenOrca-gpqa198-full-standard-20260915-rerun2.json`（该文件内嵌 `score` / `nv_score` / `rel_drop_pct` / `aligned` / `runaway_detection` 字段，原文见「## 结果」）

## 结果

- 修复后分 / NV 基线：`25.76%`（约 51/198）/ NV `27.0%`
- 达标判定（accuracy_compare 退出码）：`aligned=true`（源日志只记录 verdict 的 `aligned` 字段，未记录退出码数值；按 SOP 约定 0=达标）—— 相对退化 `4.59%`，未超 5% 门限，**严格达标**（198 题全量，不涉及小样本噪声容忍）
- 该轮判定结果（结果文件内嵌判定字段，原文）：

```json
{
  "score": 25.76,
  "total_questions": 198,
  "runaway_detection": {
    "runaway_count": 4
  },
  "nv_score": 27.0,
  "rel_drop_pct": 4.59,
  "aligned": true
}
```

- 计数对照：Hygon `25.76%`（约 51/198）vs NV `27.0%`，绝对差 `-1.24` 个百分点，相对退化 `4.59%`，未超 5% 门限。
- **NV 基线来源**：仓库 `nv_baseline.yaml` 中 `Mistral-7B-OpenOrca.metrics.gpqa_diamond: 27`，即本次判定实际采用值（与旧失败报告记录的 NV 27.0% 一致，不存在被推翻的口径）。
- **可比性判读**：`nv_baseline.yaml` 只记录 NV 分数，没有 NV 原始题目 ID、样本量、prompt、EvalScope 版本与逐题预测，因此只能确认**相对仓库 NV 记录值达标**，不能宣称 NV 与本次 198 题逐题同源。
- 结果质量：runaway `4` 题，需作为质量风险保留；截断检测被显式跳过，不能据此声明已排除截断。
- **性能验收：本次未重测**，不能据此宣称完整 V1–V3 性能门控通过。

## 提炼到 KNOWLEDGE 的条目

1. 历史精度失败模型应优先复用原算子白名单，在新镜像上固定注意力后端、并发、评测器版本后重测；本轮在 26 算子白名单不变的前提下，仅换软件栈 + 固定 `TRITON_ATTN` 即进入门限，说明“历史失败算子”结论不能跨栈直接沿用。
2. 达标表述必须绑定数据量：历史 50 题的 22%/24% 与本轮 198 题的 25.76% 不可横比，只能各自与 NV 记录值比较。
3. 只有分数、没有 NV 原始评测产物时，不得宣称已完成逐题严格对齐；同时 runaway 数量与截断检测状态必须随分数一起记录。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: Open-Orca/Mistral-7B-OpenOrca
# IMAGE: harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4
# HARBOR_VER: V3
# GPU: Hygon DCU BW1000, 1 × 64GB
# TP: 1
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 27
# SCORE_FLAGOS: 25.76
# CONTAINER_DEVS: --device=/dev/kfd --device=/dev/dri --security-opt seccomp=unconfined --group-add video --shm-size=64g
```

### 二、容器创建（宿主机执行）

```bash
set -euo pipefail

MODEL_ROOT="${MODEL_ROOT:-/public-flash/models}"
HYHAL_ROOT="${HYHAL_ROOT:-/opt/hyhal}"
[[ -d "$MODEL_ROOT" ]] || { echo "ERROR: model root not found: $MODEL_ROOT" >&2; exit 1; }
[[ -d "$HYHAL_ROOT/lib" ]] || { echo "ERROR: Hygon driver library not found: $HYHAL_ROOT/lib" >&2; exit 1; }
[[ -d "$HYHAL_ROOT/lib/cmake/rocm_smi" ]] || echo "WARNING: rocm_smi CMake directory not found under $HYHAL_ROOT; verify the host driver version" >&2

docker run --init -d --net=host --ipc=host \
  --security-opt seccomp=unconfined --security-opt label=disable --group-add video \
  --device=/dev/kfd --device=/dev/dri --shm-size=64g \
  --mount type=bind,src="$MODEL_ROOT",dst=/models \
  --mount type=bind,src="$HYHAL_ROOT",dst=/opt/hyhal,readonly \
  --name day0-mistral-7b-openorca \
  harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4 \
  bash -lc 'sleep infinity'
```

### 三、启动服务（容器内执行）

```bash
set -euo pipefail

MODEL_DIR="${MODEL_DIR:-/models/Mistral-7B-OpenOrca}"
DTK_ENV="${DTK_ENV:-/opt/dtk/env.sh}"
if [[ ! -r "$DTK_ENV" ]]; then
  DTK_ENV="$(find /opt -maxdepth 4 -type f -path '*/dtk*/env.sh' -print -quit 2>/dev/null || true)"
fi
[[ -r "$DTK_ENV" ]] || { echo "ERROR: DTK env.sh not found; check the selected image" >&2; exit 1; }
source "$DTK_ENV"

if [[ -z "${TRITON_HIP_CLANG_PATH:-}" ]]; then
  if [[ -x /opt/dtk/aillvm/bin/clang-18 ]]; then
    TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18
  else
    TRITON_HIP_CLANG_PATH="$(find /opt -maxdepth 6 -type f -path '*/aillvm/bin/clang-18' -perm -111 -print -quit 2>/dev/null || true)"
  fi
fi
[[ -x "${TRITON_HIP_CLANG_PATH:-}" ]] || { echo "ERROR: clang-18 not found in the container" >&2; exit 1; }
export TRITON_HIP_CLANG_PATH
[[ -d "$MODEL_DIR" ]] || { echo "ERROR: model directory not found: $MODEL_DIR" >&2; exit 1; }
export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
export FLAGGEMS_DB_URL=sqlite:///:memory:
export VLLM_FL_FLAGOS_WHITELIST=add,arange_start,argmax,copy_,cos,expand,full,index,linear,lt_scalar,mm_out,ones,rand_like,randn,reciprocal,sin,softmax,softmax_out,sub,to_copy,true_divide,true_divide_,where_self,where_self_out,zero_,zeros
vllm serve "$MODEL_DIR" \
  --served-model-name Mistral-7B-OpenOrca \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.90 \
  --port 8001 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code
```
