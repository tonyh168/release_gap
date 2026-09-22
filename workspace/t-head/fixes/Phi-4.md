# T-Head/Phi-4 适配与评测记录

- **记录日期**：`2026-09-20`，仅记录当日 `16:20:11` 开始的这一轮 GPQA Diamond 50 题评测
- **远端机器**：`244-pm-aliyun-wlcb-zoned-d-810e-96G`（`8.130.132.221`）
- **主机名**：`dsw-879515-f5bf65bfd-jd7bj`
- **模型来源**：`microsoft/phi-4`
- **本次结果**：`70.0%（35/50）`；与项目 NV 参考值 `73.0%` 相比，相对退化 `4.11%`，本次单轮达到 `5%` 相对容差要求
- **记录范围**：历史单次评测快照；不代表当前在线服务配置，也不构成多轮稳定性或性能验收结论

---

## 背景分析

本次在 PPU-ZW810E 上对 Phi-4 使用 vLLM + vllm-plugin-FL 提供 OpenAI 兼容服务。影响本轮推理路径的设置集中在两层黑名单：FlagOS 和 OOT 同时排除 `rms_norm,silu_and_mul`；保留插件默认 OOT 注册，关闭 FlagGems attention 专用开关。以下参数均按当时的启动历史、服务日志和评测生成的 `task_config.yaml` 记录，不将后续配置混入本次结果。

## 环境

| 项目 | 本轮记录 |
|------|----------|
| 宿主机 / 芯片 | `8.130.132.221` / PPU-ZW810E，16 × 96GB |
| 推理容器 | `flagrelease_thead_model_dl_20260915` |
| 评测容器 | `flagrelease_thead_eval_20260915` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100` |
| 镜像 ID | `sha256:a54dcb164e0d9aad003884e6b0691400f6c8db1e56d513b03dc1c65d30f830ce` |
| vLLM / PyTorch / EvalScope | `0.24.0+empty` / `2.10.0` / `1.5.1` |
| vllm-plugin-FL / FlagGems | `0.2.0+ge2f51dcd0` / `0.0.post1.dev3060+g03bf364ed.d20260812` |
| 源码版本 | vLLM `ee0da84ab9e04ac7610e28580af62c365e898389`；plugin-FL `e2f51dcd0e03ea81e6f156b4c5cba920e5ce9d36`；FlagGems `03bf364ede763d573d5c30124d554283a209ab85` |
| 模型容器路径 / 宿主机路径 | `/models/phi-4` / `/mnt/workspace/models/phi-4` |
| 服务端口 / 并行 | `18084` / TP1 |
| 可见设备设置 | 进程显式 `CUDA_VISIBLE_DEVICES=11`、`HIP_VISIBLE_DEVICES=11`；容器级 `XPU_VISIBLE_DEVICES=all`，本次启动命令未另行覆盖 |

推理容器使用 `host` 网络、`host` IPC、`privileged=true`、`shm-size=512 GiB`；挂载 `/dev:/dev`、`/usr/local/PPU_SDK:/usr/local/PPU_SDK` 和 `/mnt/workspace/models:/models`。vLLM 在常驻容器中以 `docker exec` 启动，本次没有重新构建镜像。

远端 `docker inspect` 已确认上述三项均为读写 bind mount。以下是该共享长驻容器的等价创建命令；仅应在同名容器不存在时使用：

```bash
set -euo pipefail
test -d /dev
test -d /usr/local/PPU_SDK
test -d /mnt/workspace/models/phi-4

docker run -d \
  --name flagrelease_thead_model_dl_20260915 \
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

评测容器 `flagrelease_thead_eval_20260915` 仅绑定 `/mnt/workspace/models:/models`，未挂载 `/dev` 和 PPU SDK；这是因为评测容器只调用 OpenAI API，不执行设备侧推理。

## Step 1：启动该轮服务

以下为该轮实际记录的启动命令；同名端口如已有服务，复现前须自行检查资源占用，不能直接执行以替换现有服务：

```bash
docker exec -d flagrelease_thead_model_dl_20260915 bash -lc '
unset VLLM_FL_FLAGOS_WHITELIST VLLM_FL_OOT_WHITELIST VLLM_FL_OOT_ENABLED
export CUDA_VISIBLE_DEVICES=11 HIP_VISIBLE_DEVICES=11
export VLLM_PLUGINS=fl USE_FLAGGEMS=1 VLLM_FL_PREFER_ENABLED=true
export VLLM_FL_FLAGOS_BLACKLIST=rms_norm,silu_and_mul
export VLLM_FL_OOT_BLACKLIST=rms_norm,silu_and_mul
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_FL_TRITON_CACHE_ROOT=/models/_vllm_cache/phi4-blacklist-rms-silu-oot-20260920b
export VLLM_CACHE_ROOT=/models/_vllm_cache/phi4-blacklist-rms-silu-oot-20260920b
export FLAGGEMS_DB_URL=sqlite:///:memory:
/usr/local/bin/vllm serve /models/phi-4 \
  --served-model-name phi-4 \
  --host 0.0.0.0 --port 18084 \
  --dtype bfloat16 --tensor-parallel-size 1 \
  --max-model-len 16384 --gpu-memory-utilization 0.85 \
  --trust-remote-code --enforce-eager \
  > /models/_serve_logs/phi-4-blacklist-rms-silu-oot-20260920b.log 2>&1
'
```

插件源码 `is_oot_enabled()` 对未设置的 `VLLM_FL_OOT_ENABLED` 默认取 `1`，因此此轮 OOT 注册开启，但 OOT 对上述两个算子执行黑名单。日志核验：vLLM `0.24.0`，`Phi3ForCausalLM`，`bfloat16`，`max_seq_len=16384`，engine `seed=0`；`rms_norm` 的 IR 优先级为 native，`attention_backend` 和 `rotary_embedding` 选择 `default.flagos`。`VLLM_FL_USE_FLAGGEMS_ATTN=0` 仅表示不启用 FlagGems attention 专用路径，不能据此说整个 attention 是 native。服务启动后 `/health` 返回 HTTP `200`。

服务日志：

```text
/mnt/workspace/models/_serve_logs/phi-4-blacklist-rms-silu-oot-20260920b.log
```

## Step 2：GPQA Diamond 50 题评测

评测容器访问 `http://127.0.0.1:18084/v1`。当次实际命令：

```bash
docker exec -d flagrelease_thead_eval_20260915 bash -lc '
cd /models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods
python3 fast_gpqa.py \
  --api-base http://127.0.0.1:18084/v1 \
  --model-name phi-4 \
  --config fast_gpqa_config.yaml \
  --limit 50 --eval-batch-size 4 \
  --max-tokens 8192 --skip-truncation-check \
  --output /models/_eval_results/20260920_phi_blacklist_rms_silu_oot_50_b4_result.json \
  > /models/_eval_results/20260920_phi_blacklist_rms_silu_oot_50_b4_eval.log 2>&1
'
```

生成的 `task_config.yaml` 固定了以下口径：

| 项目 | 值 |
|------|----|
| 数据集 | `AI-ModelScope/gpqa_diamond`，`train`，`default`，50 题、0-shot、不开选项乱序 |
| EvalScope / 后端 | `1.5.1` / `Native` + `openai_api` |
| `eval_batch_size` / 评测 `seed` | `4` / `42` |
| `temperature` / `top_p` | `0.0` / `1.0` |
| `max_tokens` / 服务 `max_model_len` | `8192` / `16384` |
| 截断探测 | 显式 `--skip-truncation-check`；`truncation_detected=null`，不可据此断言无截断 |
| 提示词 | 要求逐步推理、末行使用 `ANSWER: [LETTER]` |

模型 `generation_config.json` 未配置 `temperature` 或 `top_p`；本次使用的采样参数来自评测配置快照。

结果（`2026-09-20 16:40:19`）：

```json
{
  "score": 70.0,
  "evalscope_score": 70.0,
  "total_questions": 50,
  "eval_batch_size": 4,
  "max_tokens": 8192,
  "max_model_len": 16384,
  "temperature": 0.0,
  "eval_duration_seconds": 1208.3,
  "truncation_check_skipped": true,
  "runaway_detection": {"checked": 50, "runaway_count": 0},
  "answer_extraction_audit": {
    "checked": 50,
    "explicit_answer_found": 50,
    "fallback_to_evalscope": 0,
    "format_corrected_score": 70.0,
    "parser_mismatch_count": 0,
    "invalid_evalscope_extract_count": 0
  }
}
```

本次 `score` 与 EvalScope 原始分一致，没有依赖答案后处理提高分数。评测耗时约 `20 分 08 秒`；这里只报告精度评测耗时，不作为吞吐性能验收。

## Step 3：结果与证据

项目 [NV 基线](../../../flagrelease_eval_methods/nv_baseline.yaml)记载 Phi-4 / GPQA Diamond `73.0%`。按项目相对容差 `5%`：

```text
本轮相对退化 = (73 - 70) / 73 = 4.11%
通过线       = 73 × 0.95 = 69.35%
本轮 50 题  = 35/50 = 70.0%，单轮数值达到通过线
```

这是对已保存结果和 NV 表的计算；未保存本轮单独的 `accuracy_compare.py` 退出码，不将数值计算伪装成该命令的实际执行记录。

原始证据均位于远端宿主机（容器内将 `/mnt/workspace/models` 映射为 `/models`）：

```text
/mnt/workspace/models/_eval_results/20260920_phi_blacklist_rms_silu_oot_50_b4_result.json
/mnt/workspace/models/_eval_results/20260920_phi_blacklist_rms_silu_oot_50_b4_eval.log
/mnt/workspace/models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods/outputs/gpqa_diamond/20260920_162011/configs/task_config.yaml
/mnt/workspace/models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods/outputs/gpqa_diamond/20260920_162011/predictions/phi-4/gpqa_diamond_default.jsonl
/mnt/workspace/models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods/outputs/gpqa_diamond/20260920_162011/reviews/phi-4/gpqa_diamond_default.jsonl
/mnt/workspace/models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods/outputs/gpqa_diamond/20260920_162011/reports/phi-4/gpqa_diamond.json
```

结果 JSON SHA-256：`83d01d2f831807890567ec66a5e6ec5936e50d2304e009d6672d25d76e587c8a`。详细的运行文件与修改范围见 [file_fixes/Phi-4.md](file_fixes/Phi-4.md)。

## 现象、定位与处置

- 现象：该次 50 题真实生成得到 `35/50`；50 题均能提取显式答案，解析错判 `0`，runaway `0`。
- 定位：该次结果不依赖评测后处理校分；推理路径由 FlagOS/OOT 黑名单、FlagGems attention 开关及服务参数共同决定。
- 处置：用上述运行时参数启动 Phi-4，保留服务日志和 EvalScope 原始配置、逐题预测及结果文件。

## 本轮结论与可复用步骤

该次 GPQA Diamond 50 题相对 NV `73.0%` 的退化为 `4.11%`，**单次精度数值满足 5% 容差**。本记录不声称多轮稳定达标或完成性能验收。

国产芯片适配记录可复用的核对顺序：固定镜像/代码版本与设备可见性 → 保存算子路由和真实启动环境 → 保存评测参数快照与逐题结果 → 分别核对原始分、答案抽取审计和 NV 相对退化；生成文件必须标注对应的单次运行时间和范围。
