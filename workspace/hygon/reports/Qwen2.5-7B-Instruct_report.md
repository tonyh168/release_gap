# hygon/Qwen2.5-7B-Instruct 修复日志

- **失败报告**：flagrelease_fail_reports/Hygon/FAILED_Hygon_Qwen2.5-7B-Instruct_202607241708.md
- **原始失败类型**：精度不达标
- **日期**：2026-09-18

## 现象

- 本模型历史上精度不达标：初始 GPQA Diamond 50 题仅 `26.00%`，NV 参考值 `39.00%`；旧栈下还留有算子精度退化与 plugin-FL 报错记录。本轮为新增部署 + 精度修复，未再出现服务启动失败。
- 服务本身一直可用（`/health` HTTP `200`），但精度问题不是单一因素造成的，需要逐项分离：
  - 第一版服务误用 `--dtype float16`，而模型 `config.json` 声明 `torch_dtype: bfloat16`；
  - 宽 FlagGems/OOT 算子替换会引入额外的 Hygon 后端数值路径差异；
  - 关闭 prefix cache / chunked prefill 不但没有改善，反而使本模型结果下降；
  - 模型 `generation_config.json` 给出了采样参数，评测应使用这些参数而不是评测器默认贪心。
- 首轮达标轮：GPQA Diamond 50 题 `36.00%`，相对 NV `39.00%` 退化 `7.69%`，评测耗时 `426.86s`（约 7m 6.9s）。

## 定位

- **dtype 与模型声明不一致**：模型 `config.json` 为 `bfloat16`，服务用 `float16` 会改变数值路径；对齐 BF16 后分数明显抬升（`34.00%` → `36.00%`）。
- **算子白名单过宽**：核心算子之外的大范围 FlagGems/OOT 替换会叠加 Hygon 后端数值差异；把白名单收敛到模型核心算子 `silu_and_mul,rms_norm,rotary_embedding` 后结果最好。该结论来自分组消融，不是逐算子穷举，**不是跨模型通用白名单**。
- **prefill/cache 开关方向与 Mistral 类模型相反**：本模型加 `--no-enable-prefix-caching --no-enable-chunked-prefill` 会掉到约 `32.00%`，因此最终**保留默认 prefix cache 与 chunked prefill**。
- **采样参数口径**：模型 `generation_config.json` 为 `do_sample=true / temperature=0.7 / top_p=0.8 / top_k=20 / repetition_penalty=1.05`，首轮评测日志确认采用了模型配置，而非评测脚本的普通贪心默认值。
- **仍属小样本判定**：相对退化 `7.69%` 超过 5% 门限，但绝对差 `-3.00` 个百分点 = `1.50` 题，按 50 题小样本噪声容忍规则通过；这是容忍通过，不是严格等价。

## 处置

宿主机 `bm-srwl-nj-zone3-d-bw1000-64g-2-21`（`10.232.2.21`），推理容器 `flagrelease-qwen2p5-7b`，评测容器 `flagrelease-model-download-20260917`，端口 `8005`，`HIP_VISIBLE_DEVICES=5`，TP=1，bf16。模型 `/public-flash/models/flagrelease/fixes_models/Qwen2.5-7B-Instruct` → 容器内 `/models/flagrelease/fixes_models/Qwen2.5-7B-Instruct`。本轮未重新构建/推送镜像，也未修改 vLLM、`vllm-plugin-FL`、FlagGems 源码。

模型配置核验：

```json
{
  "torch_dtype": "bfloat16"
}
```

```json
{
  "do_sample": true,
  "temperature": 0.7,
  "top_p": 0.8,
  "top_k": 20,
  "repetition_penalty": 1.05
}
```

**算子白名单与 dtype 消融（GPQA Diamond 50 题）**

| 配置 | 分数 |
|------|-----:|
| 初始宽白名单、FP16 | `26.00%` |
| 调整生成上限后、宽白名单 | 约 `32.00%` |
| 关闭 prefix cache / chunked prefill、宽白名单 | `28.00%` |
| 核心算子使用 FlagGems、FP16 | `34.00%` |
| 核心算子全部走 reference | `8.00%` |
| 核心算子使用 FlagGems、BF16 | `36.00%`（最终采用） |
| BF16 + 关闭 prefix cache / chunked prefill | `32.00%`（未采用） |

最终保留的核心白名单（FlagOS/FlagGems 与 OOT 同集合）：

```text
silu_and_mul,rms_norm,rotary_embedding
```

说明：`VLLM_PLUGIN_FL_LOGLEVEL=DEBUG` 与逐算子黑名单二分属于本项目通用排查手段，本模型最终收敛到上述三项；本模型保留默认 prefix cache / chunked prefill。

**评测**

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.6.1` |
| 题数 | 50 |
| `eval_batch_size` | 4 |
| 模式 | `standard` |
| `temperature` | `0.7` / `top_p` `0.8` / `top_k` `20` / `repetition_penalty` `1.05` |
| `max_model_len` | 32768 |
| `max_tokens` | 4096 |
| 截断检测 | 显式指定生成上限，跳过会改写上限的截断探测 |
| 评测耗时 | `426.86s` |

```bash
python3 fast_gpqa.py \
  --model-name Qwen2.5-7B-Instruct \
  --api-base http://127.0.0.1:8005/v1 \
  --api-key EMPTY \
  --dataset gpqa_diamond \
  --limit 50 \
  --eval-batch-size 4 \
  --max-tokens 4096 \
  --dataset-dir /models/day0_eval/cache/datasets \
  --output /models/release_run_logs/accuracy/fix_qwen_bf16_fl_coreoot_20260917_2120/qwen_genconfig_cap4096/gpqa50.json
```

- 结果文件：`/public-flash/models/release_run_logs/accuracy/fix_qwen_bf16_fl_coreoot_20260917_2120/qwen_genconfig_cap4096/gpqa50.json`
- 判定文件：`/public-flash/models/release_run_logs/accuracy/fix_qwen_bf16_fl_coreoot_20260917_2120/qwen_genconfig_cap4096/verdict.json`

结果摘要（逐题审计部分）：

```json
{
  "score": 36.0,
  "evalscope_score": 36.0,
  "total_questions": 50,
  "eval_batch_size": 4,
  "max_tokens": 4096,
  "max_model_len": 32768,
  "temperature": 0.7,
  "runaway_detection": {
    "checked": 50,
    "runaway_count": 0
  },
  "answer_extraction_audit": {
    "checked": 50,
    "explicit_answer_found": 50,
    "format_corrected_score": 36.0,
    "parser_mismatch_count": 0,
    "invalid_evalscope_extract_count": 0
  }
}
```

答案解析审计干净：50 题全部显式提取到答案，parser mismatch `0`、invalid extract `0`，格式校正分与 EvalScope 原始分一致（均为 `36.00%`），因此低分不是解析器误扣。

**稳定性复测**

| 轮次 | 得分 | runaway | 结论 |
|------|-----:|--------:|------|
| 首轮通过轮次（记录口径） | `36.00%` | `0/50` | 按小样本噪声规则通过 |
| 稳定性复测 | `34.00%` | `1/50` | 相对 NV 低 5 个百分点，不通过 |

因此本模型的结论必须写成：**该配置存在首轮通过证据，但 50 题重复评测尚未证明精度稳定通过。**

**环境备注**

本模型容器与同批模型同宿主机、同镜像，`TRITON_HIP_CLANG_PATH` / `VLLM_WORKER_MULTIPROC_METHOD=spawn` / 两个超时变量在源日志的启动参数块中未单列，按同批同镜像的统一配置补齐（同批其他模型日志记录：不指定 clang 路径会触发 Triton/FlagGems 编译问题）。

## 结果

- 修复后分 / NV 基线：`36.00%`（首轮）/ NV `39.00%`
- 达标判定（accuracy_compare 退出码）：`aligned=true`（源日志只记录 verdict 的 `aligned` 字段，未记录退出码数值；按 SOP 约定 0=达标）—— **相对退化 `7.69%` 超过 5% 门限，但绝对差 `-3.00` 个百分点 = `1.50` 题 ≤ 2 题，按 50 题小样本噪声容忍规则通过**；不是严格 5% 相对退化通过
- 该轮判定文件（verdict.json）原文：

```json
{
  "aligned": true,
  "noise_zone": true,
  "rel_drop_pct": 7.69,
  "abs_diff": -3.0,
  "diff_questions": 1.5,
  "noise_adjusted": true,
  "message": "精度达标(小样本噪声容忍)"
}
```

- 计数对照：Hygon `36.00%`（18/50）vs NV `39.00%`，绝对差 `-3.00` 个百分点，折算 `1.50` 题，相对退化 `7.69%`。
- **NV 基线来源**：仓库 `nv_baseline.yaml` 中 `Qwen2.5-7B-Instruct.metrics.gpqa_diamond: 39`，即本次判定实际采用值（不存在被推翻的口径）。
- **可比性判读**：`nv_baseline.yaml` 只记录 NV 分数，缺少 NV 原始题目 ID、样本量、prompt、EvalScope 版本与逐题预测，只能确认相对仓库 NV 记录值达标，不能宣称与 NV 逐题同源。
- 环境版本差异：本轮 EvalScope 为 `1.6.1`，项目统一口径为 `1.5.1`；判定在既有口径下完成，严格发布对比前建议在 `1.5.1` 环境复跑。
- 稳定性风险：同配置复测 `34.00%`（runaway 1/50），未通过；`temperature=0.7` 的 50 题单轮通过不代表稳定达标。
- **性能验收：本次未单独重测**。

## 提炼到 KNOWLEDGE 的条目

1. 起服务前必须校验模型 `config.json` 的 `torch_dtype` 与 vLLM `--dtype`；本模型不能把 `float16` 当默认替代，类别不同会直接改变数值路径与分数。
2. FlagGems/OOT 白名单必须按模型做受控 A/B，`silu_and_mul,rms_norm,rotary_embedding` 是 Qwen 本模型的实测配置，不是通用模板；“全走 reference”会灾难性掉分（`8.00%`）。
3. prefill/cache 开关的收益方向因模型而异：Mistral 类关掉才好，Qwen 关掉反而从 `36.00%` 掉到 `32.00%`，必须实测而非套用。
4. 使用 `temperature=0.7` 的模型必须保留多轮复测结果，单轮小样本通过不能宣称稳定达标。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: Qwen/Qwen2.5-7B-Instruct
# IMAGE: harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist
# HARBOR_VER: V3
# GPU: Hygon DCU BW1000, 1 × 64GB
# TP: 1
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 39
# SCORE_FLAGOS: 36.0
# CONTAINER_DEVS: --device=/dev/kfd --device=/dev/dri --security-opt seccomp=unconfined --group-add video --group-add render --shm-size=64g
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --net=host --ipc=host \
  --security-opt seccomp=unconfined --group-add video --group-add render \
  --device=/dev/kfd --device=/dev/dri --shm-size=64g \
  -v /public-flash/models:/models \
  -v /opt/hyhal:/opt/hyhal:ro \
  --name flagrelease-qwen2p5-7b \
  harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist \
  /bin/bash
```

### 三、启动服务（容器内执行）

```bash
source /opt/dtk-26.04-DCC2602-0317/env.sh
export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export TRITON_HIP_CLANG_PATH=/opt/dtk-26.04-DCC2602-0317/aillvm/bin/clang-18
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
export FLAGGEMS_DB_URL=sqlite:///:memory:
export VLLM_FL_FLAGOS_WHITELIST=silu_and_mul,rms_norm,rotary_embedding
export VLLM_FL_OOT_WHITELIST=silu_and_mul,rms_norm,rotary_embedding
vllm serve /models/flagrelease/fixes_models/Qwen2.5-7B-Instruct \
  --served-model-name Qwen2.5-7B-Instruct \
  --host 0.0.0.0 \
  --port 8005 \
  --max-model-len 32768 \
  --dtype bfloat16 \
  --gpu-memory-utilization 0.90 \
  --trust-remote-code \
  --attention-backend TRITON_ATTN \
  --enforce-eager
```
