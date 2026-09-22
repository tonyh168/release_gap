# t-head/Magistral-Small-2506 修复日志

- **失败报告**：历史报告参考 `flagrelease_fail_reports/Nvidia/FAILED_Nvidia_Magistral-Small-2506_202607301822.md`
- **原始失败类型**：精度不达标、reasoning 配置错配、长输出/runaway
- **日期**：2026-09-20

## 现象

- T-Head 初始 GPQA 50 题 `40.00%`，全量 198 题 `47.47%`；
- 多轮 Mistral 格式与采样消融集中在 `40.00%–48.00%`；
- README 推荐 `temperature=0.7`、`top_p=0.95`，但 `generation_config.json` 未携带这些字段；
- 原评测脚本没有将 `magistral` 识别为 thinking 模型；
- 8 题小样本在 `37.50%–87.50%` 波动，不能作为正式结论。

## 定位

- 主要问题不是服务不可用，而是评测模式与模型训练口径不一致；
- 贪心解码容易使 reasoning 模型锁定错误或重复路径；
- 缺少 reasoning prompt 时不能稳定触发推理—总结结构；
- `rms_norm`、`silu_and_mul`、`rotary_embedding` 的数值差异会在长链中累积；
- 输出窗口过小限制推理，过大又放大 runaway。

## 处置

1. 在 `fast_gpqa.py` 中增加 Magistral thinking 模型识别；
2. 固定 `temperature=0.7`、`top_p=0.95`；
3. 注入 reasoning system prompt；
4. 正式评测使用 `max_tokens=16384`、`eval_batch_size=2`；
5. 关闭 prefix cache 和 chunked prefill；
6. 核心三个算子避开 FlagGems，`attention_backend` 保留 FlagOS；
7. 使用 50 题正式结果而不是 8 题消融值判定。

| 项目 | 值 |
|------|---|
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100` |
| 模型路径 | `/models/Magistral-Small-2506` |
| GPU / 端口 / TP | `12,13` / `18088` / `2` |
| 服务参数 | bf16、`max_model_len=40960`、Mistral tokenizer/config/load format、关闭 prefix/chunked |
| 评测参数 | EvalScope `1.5.1`、50 题、0.7/0.95、16384 tokens、batch=2 |
| 结果文件 | `/models/_eval_results/20260920_magistral_fix/50_readme_prompt_16384/Magistral-Small-2506_gpqa_result.json` |
| 脚本备份 | `/models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods/fast_gpqa.py.bak_20260920_magistral_fix` |

## 结果

- 修复后 / NV：`68.00%`（34/50） / `62.00%`
- 绝对差：`+6` 个百分点
- 相对退化：`-9.68%`，实际提升
- 判定：✅ 通过
- 原始分 / 格式校正分：`68.00%` / `68.00%`
- 答案解析错判：`0`
- runaway：`3/50`，两题撞到 `max_tokens`

```json
{
  "score": 68.0,
  "evalscope_score": 68.0,
  "total_questions": 50,
  "temperature": 0.7,
  "max_tokens": 16384,
  "eval_batch_size": 2,
  "runaway_count": 3,
  "parser_mismatch_count": 0
}
```

限定说明：本次完成精度修复与验证，未重新进行完整性能验收；精度通过，但生成稳定性仍需继续优化。

## 提炼到 KNOWLEDGE 的条目

Reasoning 模型必须显式对齐模型卡采样参数和 prompt；配置文件缺字段不等于应使用贪心解码。长链任务还应消融核心算子、prefix/chunked 路径与窗口，并以至少 50 题加答案/runaway 审计作为结论。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: mistralai/Magistral-Small-2506
# IMAGE: harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100
# HARBOR_VER: V3
# GPU: PPU-ZW810E, 16 × 96GB
# TP: 2
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 62.0
# SCORE_FLAGOS: 68.0
# CONTAINER_DEVS: -v /dev:/dev -v /usr/local/PPU_SDK:/usr/local/PPU_SDK -v /mnt/workspace/models:/models --privileged --net=host --ipc=host --shm-size=512g
```

### 二、启动服务（容器内执行）

```bash
export CUDA_VISIBLE_DEVICES=12,13
export HIP_VISIBLE_DEVICES=12,13
export VLLM_PLUGINS=fl
export USE_FLAGGEMS=1
export VLLM_FL_PREFER_ENABLED=true
export FLAGGEMS_DB_URL=sqlite:///:memory:
export VLLM_FL_FLAGOS_WHITELIST=arange_start,argmax,exponential_,lt_scalar,rand_like,randn,softmax,softmax_out,where_self,where_self_out,attention_backend
export VLLM_FL_OOT_BLACKLIST=silu_and_mul,rms_norm,rotary_embedding

/usr/local/bin/vllm serve /models/Magistral-Small-2506 \
  --served-model-name Magistral-Small-2506 \
  --host 0.0.0.0 --port 18088 \
  --dtype bfloat16 --tensor-parallel-size 2 \
  --max-model-len 40960 --gpu-memory-utilization 0.90 \
  --trust-remote-code --enforce-eager \
  --tokenizer-mode mistral --config-format mistral --load-format mistral \
  --tool-call-parser mistral --enable-auto-tool-choice \
  --no-enable-prefix-caching --no-enable-chunked-prefill
```

### 三、评测参数

```text
model: Magistral-Small-2506
api_base: http://127.0.0.1:18088/v1
dataset: gpqa_diamond
limit: 50
temperature: 0.7
top_p: 0.95
max_tokens: 16384
eval_batch_size: 2
```
