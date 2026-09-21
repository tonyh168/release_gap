# hygon/MiniCPM4.1-8B 修复日志

- **失败报告**：`flagrelease_fail_reports/Hygon/FAILED_Hygon_MiniCPM4.1-8B_202607250236.md`
- **问题类型**：thinking 模型的评测生成上限与 Chat API 特殊 token 口径需要按模型校准
- **日期**：`2026-09-20`
- **依据**：[适配与评测记录](../fixes/MiniCPM4.1-8B.md)；[完整评测入口留档](../fixes/file_fixes/MiniCPM4.1-8B.md)

## 现象

同一 GPQA Diamond 50 题此前以 `temperature=0.6`、`top_p=0.95`、通用 thinking cap `max_tokens=20000` 评测为 `24/50=48%`，其中 11 题达到上限且均判错。MiniCPM4.1 的模型 README 在 vLLM Chat API 示例中要求 `add_special_tokens=True`，并使用 `max_tokens=32768`。

在不重启 Hygon 服务的情况下，以 `add_special_tokens=True`、显式 thinking 和 `max_tokens=32768` 重新生成全部 50 题，本轮得到 `34/50=68%`。评测日志显示 `0 already fully cached`，不是将两轮答案拼接。

## 定位

- 统一脚本的 `THINKING_MAX_TOKENS_CAP=20000` 是跨模型的成本防护值；MiniCPM4.1 有正常推理超过该上限。
- vLLM Chat API 的 `add_special_tokens` 默认为 `False`；本模型 README 建议显式设为 `True`。新轮相同题干的 prompt token 数比旧轮多 1，符合补入 BOS 的预期。
- 两轮 50 道题的题干及标准答案完全一致，`temperature=0.6`、`top_p=0.95` 保持不变；旧轮 11 道长度终止题，新轮 10 道自然停止、8 道答对。
- 上限和特殊 token **同时**调整；本轮结果只能证明组合配置有效，不能单独把 20 个百分点提升归因于其中之一。

## 处置

1. 保留原服务：GPU4、TP1、BF16、vLLM `0.24.0`、端口 `8002`、`TRITON_ATTN`、prefix cache 与 chunked prefill 开启。
2. 通过隔离评测入口为 `MiniCPM4.1-8B` 覆盖 `max_tokens=32768`、`temperature=0.6`、`top_p=0.95`；`extra_body` 指定 `add_special_tokens=True`、`chat_template_kwargs.enable_thinking=True`。
3. 在评测进程临时补齐 DTK 动态库搜索路径，使容器中的 PyTorch/EvalScope 正常导入；不修改镜像或原评测脚本。
4. 固定并发 4，独立工作目录完成 50 题，审计每题结束原因和索引完整性。

## 结果

| 指标 | 值 |
|------|---:|
| 本轮 Hygon GPQA Diamond | `68.00%（34/50）` |
| 仓库 NV 记录值 | `54.00%` |
| 绝对变化 | `+14` 个百分点 |
| 相对变化 | `+25.93%` |
| predictions / reviews | 各 50 条、各 50 个唯一索引 |
| 自然结束 | 48 题 |
| 达到 `max_tokens=32768` | 2 题（索引 12、22，均判错） |
| API error / runaway 检测 | `0 / 0` |
| EvalScope 原始分 / 答案提取校正分 | `68.00% / 68.00%` |
| 退出状态 | `exit=0`，`run=0` |
| 本轮精度门限 | **通过** |

结果证据（宿主机挂载）：

```text
/public-flash/models/day0_logs/accuracy/MiniCPM4.1-8B-gpqa50-fixed-thinking-20260920-env.json
/public-flash/models/day0_logs/accuracy/MiniCPM4.1-8B-gpqa50-fixed-thinking-20260920-env.log
/public-flash/models/day0_logs/accuracy/MiniCPM4.1-8B-gpqa50-fixed-thinking-20260920-env.exit
/public-flash/models/day0_logs/accuracy/MiniCPM4.1-8B-gpqa50-fixed-thinking-20260920-env.done
```

逐题预测、reviews、TaskConfig 与 HTML 报告在 `day0-eval-standard` 容器的 `/root/outputs/gpqa_diamond/20260920_065338`，当前不在宿主机挂载目录。清理容器前需另行保存这些逐题产物。本轮 `--skip-truncation-check` 跳过开测前截断探测，逐题事后审计仍发现 2 道长度终止题；runaway 检测为 0 不代表零截断。

NV 基线仅记录分数，没有保存相同的 NV 逐题预测和生成参数。这里的“通过”仅指本轮 50 题相对仓库记录值的精度门限，不等同于逐题同源 NV 对照、多轮稳定性或性能验收。

## 提炼到 KNOWLEDGE 的条目

thinking 模型的输出窗口和 Chat API 特殊 token 应按模型 README 与逐题结束原因校准；开测前核对最终 `extra_body`、`max_tokens` 和是否复用缓存，结束后同时审计 `stop_reason`、解析结果与索引完整性。评测工作目录需优先放在持久挂载中。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: openbmb/MiniCPM4.1-8B
# IMAGE: harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4
# GPU: Hygon DCU BW1000, physical GPU 4, 1 x 64GB
# TP: 1
# VERDICT: gpqa50_accuracy_pass
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 54
# SCORE_FLAGOS: 68
# CONTAINER_DEVS: --security-opt seccomp=unconfined --security-opt label=disable --device=/dev/kfd --device=/dev/dri --shm-size=64g --group-add=video -v /public-flash/models:/models -v /opt/hyhal:/opt/hyhal:ro
```

### 二、容器配置（已运行实例）

```text
name: day0-minicpm4-1-8b
cmd: bash -lc 'sleep infinity'
network: host
ipc: host
shm-size: 64 GiB
mounts:
  /public-flash/models -> /models (rw)
  /opt/hyhal -> /opt/hyhal (ro)
devices: /dev/kfd, /dev/dri
security: seccomp=unconfined, label=disable
group: video
```

这是现有容器配置留档，**不要**在 GPU4/端口8002已被占用时重复创建同名服务。

### 三、启动服务（容器内进程）

```bash
export DTK_HOME=/opt/dtk
export ROCM_PATH=/opt/dtk-26.04-DCC2602-0317
export HIP_PATH=/opt/dtk-26.04-DCC2602-0317/hip
export HSA_PATH=/opt/dtk/hsa
export DEVICE_LIB_PATH=/opt/dtk/amdgcn/bitcode
export TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18
export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export HIP_VISIBLE_DEVICES=4
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
export VLLM_FL_TRITON_CACHE_ROOT=/models/day0_logs/triton_cache/MiniCPM4.1-8B
export VLLM_FL_FLAGOS_WHITELIST=add,arange,argmax,broadcast_to,copy,cos,cumsum,div,expand,index,le,lt,masked_fill,rand_like,randn,reciprocal,rsub,scatter,sin,softmax,sub,sum,to,where

/usr/bin/python3 /usr/local/bin/vllm serve /models/MiniCPM4.1-8B \
  --served-model-name MiniCPM4.1-8B \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 65536 \
  --gpu-memory-utilization 0.90 \
  --port 8002 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code
```

评测侧额外参数和临时运行环境在 [file_fixes 留档](../fixes/file_fixes/MiniCPM4.1-8B.md)；服务进程没有为本轮重启或修改。
