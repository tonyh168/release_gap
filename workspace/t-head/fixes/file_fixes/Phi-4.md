# Phi-4 修改文件说明（2026-09-20 单次 70% 评测）

> 本文件只区分程序文件、运行配置和评测产物。推理容器必须绑定 `/dev:/dev`、`/usr/local/PPU_SDK:/usr/local/PPU_SDK`、`/mnt/workspace/models:/models`；完整、已核验的 `docker run`、历史 `docker exec` 和健康检查命令见 [适配记录](../Phi-4.md) 与 [发布报告](../../reports/Phi-4_report.md)。评测容器只调用 API，仅绑定 `/mnt/workspace/models:/models`。

## 来源与范围

本文件只对应 [Phi-4 的 2026-09-20 50 题记录](../Phi-4.md)。这轮可核验的适配措施是**启动环境变量和 vLLM 参数切换**，并运行现有 `fast_gpqa.py` 生成评测产物；没有留存可归因于这轮 70% 的 Phi-4 专属模型权重或 vLLM、vllm-plugin-FL、FlagGems 源码补丁。因此不虚构源码 diff，不把生成的日志/结果写成“代码修复”。

## 涉及文件与状态

| 路径（除 `/workspace/...` 为推理容器内路径外，其余为远端宿主机路径；容器内 `/mnt/workspace/models` 映射为 `/models`） | 在本轮的用途与状态 |
|------|------|
| `/mnt/workspace/models/phi-4/config.json`、`generation_config.json`、模型权重 | 输入文件；无本轮 Phi-4 专属修改记录；`generation_config.json` 未配置温度或 top_p |
| `/workspace/vllm`、`/workspace/vllm-plugin-FL`、`/workspace/FlagGems` | 使用现有环境中已安装的实现；本轮操作记录无对应源码补丁 |
| `/mnt/workspace/models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods/fast_gpqa_config.yaml` | 已有配置；当次通过命令行指定模型、API、50 题、batch=4、max_tokens=8192 |
| `/mnt/workspace/models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods/fast_gpqa.py` | 当次调用的共享评测脚本；无本轮 Phi-4 专属脚本修改记录，不能把脚本后来的更新追认为当次变更 |
| `/mnt/workspace/models/_serve_logs/phi-4-blacklist-rms-silu-oot-20260920b.log` | 当次启动及路由日志；运行产物，非源码 |
| `/mnt/workspace/models/_eval_results/20260920_phi_blacklist_rms_silu_oot_50_b4_result.json` | 当次评测结果：`70.0%（35/50）`；运行产物，非源码 |
| `/mnt/workspace/models/_eval_results/20260920_phi_blacklist_rms_silu_oot_50_b4_eval.log` | 当次评测过程日志；运行产物，非源码 |
| `/mnt/workspace/models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods/outputs/gpqa_diamond/20260920_162011/` | 自动生成的 `configs/task_config.yaml`、`predictions/`、`reviews/`、`reports/`；评测证据，非手工源码修改 |

## 实际配置变更：进程级，不是文件补丁

```bash
unset VLLM_FL_FLAGOS_WHITELIST VLLM_FL_OOT_WHITELIST VLLM_FL_OOT_ENABLED
export CUDA_VISIBLE_DEVICES=11 HIP_VISIBLE_DEVICES=11
export VLLM_PLUGINS=fl USE_FLAGGEMS=1 VLLM_FL_PREFER_ENABLED=true
export VLLM_FL_FLAGOS_BLACKLIST=rms_norm,silu_and_mul
export VLLM_FL_OOT_BLACKLIST=rms_norm,silu_and_mul
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_FL_TRITON_CACHE_ROOT=/models/_vllm_cache/phi4-blacklist-rms-silu-oot-20260920b
export VLLM_CACHE_ROOT=/models/_vllm_cache/phi4-blacklist-rms-silu-oot-20260920b
export FLAGGEMS_DB_URL=sqlite:///:memory:
```

vLLM 启动参数为 `--dtype bfloat16 --tensor-parallel-size 1 --max-model-len 16384 --gpu-memory-utilization 0.85 --trust-remote-code --enforce-eager`，模型 `/models/phi-4`，端口 `18084`。推理容器自身设置 `XPU_VISIBLE_DEVICES=all`，上述历史进程命令没有显式收窄 XPU 可见性。

`VLLM_FL_OOT_ENABLED` 不设置时，已安装插件源码默认启用 OOT；`rms_norm,silu_and_mul` 在 FlagOS 与 OOT 两层黑名单中。服务日志确认 `rms_norm` 的 native IR 优先级，以及 `attention_backend`、`rotary_embedding` 选择 `default.flagos`。这些均为当次路由证据，不等于修改了相应算子的实现文件。

## 评测脚本版本注意事项

结果文件时间为 `2026-09-20 16:40:19`；远端现存 `fast_gpqa.py` 修改时间为当日 `21:23:13`，**晚于本次评测**。当晚留存的修改前备份是：

```text
/mnt/workspace/models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods/fast_gpqa.py.bak_20260920_magistral_fix
SHA-256: 122b4dcce66f21f4f3ab8d6e70b2828d5eae4e9f91ea5d24aef11ea7582ac3bb
```

该备份可供核对旧版脚本，但未保存本次评测启动时的脚本哈希，不能仅凭备份时间证明与本轮运行文件逐字节相同。复现时应以本轮 `task_config.yaml`、结果 JSON、逐题输出与服务日志为准，并单独核对拟使用的脚本版本。

## 结果校验与可复用规则

本轮结果 JSON SHA-256：`83d01d2f831807890567ec66a5e6ec5936e50d2304e009d6672d25d76e587c8a`；EvalScope 原始分、答案审计分均为 `70.0%`，parser mismatch `0`、runaway `0`。命令行显式跳过截断检查，因此不宣称截断已排除。

通用记录方式：将“修改的源码文件”“进程级算子/采样配置”“自动生成的日志与评测产物”分开列示；仅给有历史 diff 的代码文件写补丁说明，避免把后续脚本更新错误归因于此前的模型精度结果。
