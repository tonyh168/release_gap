# T-Head/Nanbeige4.1-3B 适配与评测记录

- **日期**：`2026-09-18`
- **远端机器**：`244-pm-aliyun-wlcb-zoned-d-810e-96G`（`8.130.132.221`）
- **主机名**：`dsw-879515-f5bf65bfd-jd7bj`
- **历史容器**：`Nanbeige4.1-3B_flagos`，旧镜像，`Exited (255) 3 weeks ago`
- **历史失败报告**：`flagrelease_fail_reports/T-Head/FAILED_T-Head_Nanbeige4.1-3B_202608221700.md`
- **海光参考记录**：`workspace/hygon/fixes/Nanbeige4.1-3B.md`
- **模型来源**：`nanbeige/Nanbeige4.1-3B`
- **本次处理结论**：新镜像单卡服务正常，模型下载容器已清理；基于答案抽取修复后的评测脚本真实重跑 GPQA Diamond 50 题，格式校正分 `80.00%`，低于 NV `81.00%` 仅 1 个百分点，相对退化 `1.23%`，低于 5% 门限，精度达标

---

## 背景分析

用户要求使用统一 T-Head 新镜像部署 `Nanbeige4.1-3B`，模型下载必须在临时容器内完成并在下载后清理容器；启动后按照海光记录同口径跑 GPQA Diamond 50 题，并与 NV 精度对比。

本机曾部署过同模型旧容器：

```text
Nanbeige4.1-3B_flagos
image: harbor.baai.ac.cn/flagrelease-public/flagrelease_ppu_vllm020plugin_base:0807
status: Exited (255) 3 weeks ago
old mounts:
  /data/models/Nanbeige4.1-3B
  /data/flagos-workspace/Nanbeige/Nanbeige4.1-3B
```

本轮不复用旧容器，新建独立推理容器并使用空闲 GPU14、端口 `18087`。算子白名单参考历史 T-Head 失败报告中的 Nanbeige 记录，并补充当前 vLLM 0.24 常用融合路径。

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `244-pm-aliyun-wlcb-zoned-d-810e-96G` / `8.130.132.221` |
| 芯片 | PPU-ZW810E，16 x 96GB |
| 推理容器 | `flagrelease_thead_nanbeige4p1_3b_20260917` |
| 评测容器 | `flagrelease_thead_eval_20260915` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100` |
| 镜像 ID | `sha256:a54dcb164e0d9aad003884e6b0691400f6c8db1e56d513b03dc1c65d30f830ce` |
| vLLM / PyTorch | `vllm 0.24.0+empty` / `torch 2.10.0` |
| EvalScope | `1.5.1` |
| 模型宿主机路径 | `/mnt/workspace/models/Nanbeige4.1-3B` |
| 模型容器路径 | `/models/Nanbeige4.1-3B` |
| GPU | `CUDA_VISIBLE_DEVICES=14` |
| 服务端口 | `18087` |
| dtype | `bfloat16` |
| max_model_len | `32768` |

## Step 0：模型下载

模型下载在临时容器内完成，下载后容器由 `--rm` 清理：

```text
container: flagrelease_nanbeige4p1_3b_download_20260917
mount:     /mnt/workspace/models -> /models
target:    /models/Nanbeige4.1-3B
```

下载后核验 `docker ps -a` 中不存在该下载容器，模型文件保留在共享目录：

```text
/mnt/workspace/models/Nanbeige4.1-3B
```

主要权重文件包括：

```text
model-00001-of-00002.safetensors
model-00002-of-00002.safetensors
model.safetensors.index.json
config.json
tokenizer.model
tokenizer.json
```

## Step 1：启动 vLLM 服务

推理容器为长驻容器，vLLM 服务通过 `docker exec` 在容器内启动：

```text
network:    host
ipc:        host
privileged: true
shm-size:   512 GiB
mounts:
  /mnt/workspace/models -> /models
  /dev                  -> /dev
  /usr/local/PPU_SDK    -> /usr/local/PPU_SDK
```

该配置已经通过远端 `docker inspect` 复核。同名容器不存在时，等价创建命令为：

```bash
set -euo pipefail
test -d /dev
test -d /usr/local/PPU_SDK
test -d /mnt/workspace/models/Nanbeige4.1-3B

docker run -d \
  --name flagrelease_thead_nanbeige4p1_3b_20260917 \
  --network host \
  --ipc host \
  --privileged \
  --shm-size=512g \
  -v /dev:/dev \
  -v /usr/local/PPU_SDK:/usr/local/PPU_SDK \
  -v /mnt/workspace/models:/models \
  harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100 \
  sleep infinity
```

评测容器只挂载 `/mnt/workspace/models:/models`；由于不执行 PPU 推理，它没有 `/dev` 和 SDK 挂载。

实际 vLLM 命令：

```bash
/usr/local/bin/vllm serve /models/Nanbeige4.1-3B \
  --served-model-name Nanbeige4.1-3B \
  --host 0.0.0.0 \
  --port 18087 \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.85 \
  --trust-remote-code \
  --enforce-eager
```

关键环境变量：

```bash
export CUDA_VISIBLE_DEVICES=14
export HIP_VISIBLE_DEVICES=14
export XPU_VISIBLE_DEVICES=14

export VLLM_PLUGINS=fl
export USE_FLAGGEMS=1
export VLLM_FL_PREFER_ENABLED=true
export FLAGGEMS_DB_URL=sqlite:///:memory:

export VLLM_FL_FLAGOS_WHITELIST=attention_backend,rms_norm,silu_and_mul,rotary_embedding

export VLLM_CACHE_ROOT=/models/_vllm_cache/nanbeige4p1-3b-min4-gpu14
export TORCHINDUCTOR_CACHE_DIR=/models/_vllm_cache/nanbeige4p1-3b-min4-gpu14/torchinductor
export TRITON_CACHE_DIR=/models/_vllm_cache/nanbeige4p1-3b-min4-gpu14/triton
export VLLM_FL_TRITON_CACHE_ROOT=/models/_vllm_cache/nanbeige4p1-3b-min4-gpu14/triton

export PPU_HOME=/usr/local/PPU_SDK
export CUDA_HOME=/usr/local/PPU_SDK/CUDA_SDK
export HF_ENDPOINT=https://hf-mirror.com
```

服务日志：

```text
/mnt/workspace/models/_serve_logs/Nanbeige4.1-3B-20260918-min4-gpu14-port18087.log
```

健康检查：

```bash
curl http://127.0.0.1:18087/health
curl http://127.0.0.1:18087/v1/models
```

结果：HTTP `200`，`/v1/models` 返回模型名 `Nanbeige4.1-3B`，`max_model_len=32768`。日志确认实际进入 FlagOS 路径的主要算子包括 `attention_backend`、`rms_norm`、`rotary_embedding`、`silu_and_mul`。

## Step 2：评测

评测服务地址：

```text
http://127.0.0.1:18087/v1
```

评测配置与海光记录保持同口径。本次使用修复后的 `fast_gpqa.py` 重新生成预测并完成真实评测，不是复用旧预测结果：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.5.1` |
| 题数 | 50 |
| `eval_batch_size` | 4 |
| `temperature` | 0.0 |
| `max_model_len` | 32768 |
| `max_tokens` | 24576 |
| 截断检测 | 通过 `--skip-truncation-check` 显式跳过，不能据此声明已排除截断 |
| 评测耗时 | `113m 7.7s` |

评测命令：

```bash
python3 fast_gpqa.py \
  --model-name Nanbeige4.1-3B \
  --api-base http://127.0.0.1:18087/v1 \
  --dataset gpqa_diamond \
  --limit 50 \
  --eval-batch-size 4 \
  --skip-truncation-check \
  --max-tokens 24576 \
  --dataset-dir /models/evalscope-datasets \
  --output /models/_eval_results/20260918_nanbeige4p1_3b_thead_min4_gpqa50_rerun_extractfix_evalenv_1644/Nanbeige4.1-3B_gpqa_result.json
```

结果文件：

```text
/models/_eval_results/20260918_nanbeige4p1_3b_thead_min4_gpqa50_rerun_extractfix_evalenv_1644/Nanbeige4.1-3B_gpqa_result.json
/models/_eval_results/20260918_nanbeige4p1_3b_thead_min4_gpqa50_rerun_extractfix_evalenv_1644/verdict.json
/models/_eval_results/20260918_nanbeige4p1_3b_thead_min4_gpqa50_rerun_extractfix_evalenv_1644/eval.log
```

EvalScope 原始输出目录：

```text
/models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods/outputs/gpqa_diamond/20260918_164410
```

结果摘要：

```json
{
  "score": 80.0,
  "evalscope_score": 74.0,
  "total_questions": 50,
  "eval_batch_size": 4,
  "temperature": 0.0,
  "max_tokens": 24576,
  "max_model_len": 32768,
  "truncation_check_skipped": true,
  "runaway_detection": {
    "checked": 50,
    "runaway_count": 0,
    "runaway_indices": []
  },
  "answer_extraction_audit": {
    "checked": 50,
    "explicit_answer_found": 42,
    "fallback_to_evalscope": 3,
    "format_corrected_score": 80.0,
    "parser_mismatch_count": 3,
    "parser_false_negative_count": 3,
    "parser_false_positive_count": 0,
    "invalid_evalscope_extract_count": 8,
    "mismatches": [
      {
        "index": 5,
        "target": "B",
        "evalscope_prediction": null,
        "explicit_prediction": "B",
        "official_correct": false,
        "corrected_correct": true
      },
      {
        "index": 14,
        "target": "C",
        "evalscope_prediction": null,
        "explicit_prediction": "C",
        "official_correct": false,
        "corrected_correct": true
      },
      {
        "index": 44,
        "target": "C",
        "evalscope_prediction": null,
        "explicit_prediction": "C",
        "official_correct": false,
        "corrected_correct": true
      }
    ]
  }
}
```

NV 对比：

```json
{
  "baseline_mode": "nv_reference",
  "model": "Nanbeige4.1-3B",
  "metric": "gpqa_diamond",
  "nv": {
    "score": 81.0,
    "source": "NV 实测"
  },
  "current": {
    "score": 80.0,
    "mode": "standard"
  },
  "tolerance": 0.05,
  "rel_drop_pct": 1.23,
  "abs_diff": -1.0,
  "aligned": true,
  "noise_zone": false,
  "message": "精度达标: 当前=80.00%, NV=81.00%, 相对退化=1.23% (容差 5.0%)"
}
```

## Step 4：评测精度修复

前两轮 GPQA 50 题格式校正分均为 `76.00%`。分析发现，Nanbeige4.1-3B 经常输出很长的 reasoning，部分请求吃满 `24576` 个输出 token，导致没有标准的 `ANSWER: [LETTER]` 结尾；EvalScope 原始抽取还会把推理正文中的单字母误当答案。

本次只修改评测后处理脚本，没有修改模型权重、vLLM 服务、镜像或算子实现：

```text
/models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods/fast_gpqa.py
```

仓库留存修复版的完整脚本已嵌入 [file_fixes/Nanbeige4.1-3B.md](file_fixes/Nanbeige4.1-3B.md)。现已定位远端脚本并完成 SHA-256 核对；仓库快照、修复前备份、后续 Magistral 修改前备份及当前远端脚本的哈希均不同，因此该代码块只能作为逻辑留档，不能宣称与本轮运行文件逐字节一致。具体哈希见修改文件说明，复现时必须先做 diff。

修改函数：

```text
_extract_explicit_mcq_answer
```

修复内容：

- 保留 `ANSWER: [C]`、`The correct answer is option D` 等明确格式；
- 新增 `So answer A`、`Therefore, option B` 等行级结论的保守抽取；
- 不再从普通推理正文中按单字母猜测答案；
- 原脚本备份：

```text
/models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods/fast_gpqa.py.bak_20260918_nanbeige_extract
```

仓库中留存的修复版实现见 [fast_gpqa.py](fast_gpqa.py) 的 `_extract_explicit_mcq_answer`。复现时替换该函数的具体逻辑如下（此为仓库逻辑快照；已确认它与现存远端脚本及两份备份都不是逐字节相同文件）：

```python
def _extract_explicit_mcq_answer(text: str) -> Optional[str]:
    normalized = (text or "").replace("*", "").replace("_", "")
    patterns = (
        r"(?im)^\s*[-+>]?\s*(?:final\s+)?answer\s*:\s*(?:is\s+)?[\(\[]?\s*([A-D])(?=\s*[\)\]\.,:;-]|\s|$)",
        r"(?im)^\s*[-+>]?\s*(?:the\s+)?(?:correct\s+)?answer\s+is\s+(?:option\s*)?[\(\[]?\s*([A-D])(?=\s*[\)\]\.,:;-]|\s|$)",
        r"(?im)^\s*(?:therefore|thus|so|hence|conclusion)[:,]?\s*(?:the\s+)?(?:final\s+)?answer\s+(?:should\s+be|is)\s+(?:option\s*)?[\(\[]?\s*([A-D])(?=\s*[\)\]\.,:;-]|\s|$)",
        r"(?im)^\s*(?:therefore|thus|so|hence|conclusion)[:,]?\s*(?:answer|option)\s+[\(\[]?\s*([A-D])(?=\s*[\)\]\.,:;-]|\s|$)",
    )
    matches = [(m.start(), m.group(1))
               for pattern in patterns for m in re.finditer(pattern, normalized)]
    return sorted(matches)[-1][1].upper() if matches else None
```

关键约束：`^` 与 `re.MULTILINE` 只匹配行首结论，`[A-D]` 限定四选一，后视断言阻止从单词开头误取字母；有多条明确结论时按文本位置选最后一条。无匹配时返回 `None`，由 `analyze_mcq_answer_extraction` 仅在 EvalScope 结果本身是 A/B/C/D 时回退，不能从正文随意猜测。注意这改变的是判分后处理，不会自动使模型生成更短的答案；仍需保留 `finish_reason` 和长输出审计。

修复后使用 `flagrelease_thead_eval_20260915` 中的 `evalscope 1.5.1` 环境，对同一服务重新真实生成 50 题预测，再执行后处理和 NV 对比。

## 现象

- 服务启动稳定，`18087` 健康检查 HTTP `200`；
- 本次真实重跑 50 题，EvalScope 原始分为 `74.00%`；
- 答案抽取审计后格式校正分为 `80.00%`，比原始分高 6 个百分点；
- NV 基线为 `81.00%`，当前格式校正分低 1 个百分点，相对退化 `1.23%`，低于 5% 门限；
- `runaway_count=0`；
- 本轮评测耗时 `113m 7.7s`，长思考导致单题耗时波动明显；
- `answer_extraction_audit.invalid_evalscope_extract_count=8`，相比旧轮次的 `12` 有改善；
- 本轮未检测到 runaway 复读。

## 定位

部署链路已打通，当前主要问题不是服务可用性。此前的主要精度缺口来自 EvalScope 对 Nanbeige 非标准长输出的答案抽取；修复后，与 NV 基线的差距已进入容差范围。与海光同模型同口径结果相比：

| 环境 | 格式校正分 | EvalScope 原始分 | NV 基线 | 结论 |
|------|-----------:|-----------------:|--------:|------|
| Hygon | `84.00%` | `78.00%` | `81.00%` | 通过 |
| T-Head 旧轮 | `76.00%` | `70.00%` | `81.00%` | 未通过 |
| T-Head 本次真实重跑 | `80.00%` | `74.00%` | `81.00%` | 通过 |

本次结果使用同一 T-Head 服务 `18087`、同一模型和同一 GPQA 50 题配置重新生成，不能简单归因于旧预测复用。当前 T-Head 结果距离 NV 仅 1 题，按项目 5% 相对退化口径达标。

## 后续定位方向

1. 保留当前服务作为复现场景：`flagrelease_thead_nanbeige4p1_3b_20260917`，GPU14，端口 `18087`；
2. 后续评测继续使用修复后的 `fast_gpqa.py`，并保留 `evalscope_score`、`score`、`answer_extraction_audit` 和 `runaway_detection`；
3. 若要继续提升到 NV 以上，再对比本轮逐题预测与 NV/海光结果，定位剩余 1 题的模型输出差异；
4. 评测前确认使用具有 `evalscope 1.5.1` 的评测环境，例如 `flagrelease_thead_eval_20260915`；
5. 对 GPQA 长思考任务保留评测耗时和生成 token 信息，避免只看单一精度字段。

## 当前结果

- 部署：完成
- 临时下载容器：已清理
- 服务：正常，端口 `18087`，GPU14
- GPQA Diamond 50 题真实重跑：`80.00%`
- EvalScope 原始分：`74.00%`
- NV 参考值：`81.00%`
- 相对退化：`1.23%`
- 绝对差：少 1 题
- 精度判定：✅ 通过
- 长输出：明显，本轮评测耗时约 `113m 7.7s`
