# Hygon SuperNova-Medius 适配与评测记录

- **日期**：`2026-09-16`
- **远端机器**：`10.232.2.33`
- **容器**：`SuperNova-Medius_flagos`
- **历史失败报告**：`flagrelease_fail_reports/Hygon/FAILED_Hygon_SuperNova-Medius_202607261152.md`
- **模型来源**：`arcee-ai/SuperNova-Medius`
- **本次处理结论**：模型在 Hygon TP2 上部署成功，native `TRITON_ATTN` 可以正常生成；198 题全量评测通过 guarded evaluator 完成，但两次精度为 `41.92%` 和 `43.43%`，运行间存在明显非确定性，暂不能宣称精度稳定或已完成严格的 5% 损失验收。

---

## 背景分析

历史 Hygon 失败报告使用 vLLM `0.20.2`、plugin-FL `0.2.0+gffa2ee3eb`、FlagGems `5.4.0dev` 和 Flagtree `0.6.1`，记录的 GPQA Diamond 结果为：

- V2：`75/198 = 37.88%`
- V3：`80/198 = 40.40%`
- V2 与 V3 的算子替换列表均为同一组 27 个算子

本次使用新 Hygon 镜像和 vLLM `0.24.0` 在 `10.232.2.33` 的物理卡 0、1 上重新部署。初期复用了历史 27 算子白名单，但新运行时出现重复生成 `batis!` 等语义错误输出，因此最终没有继续使用该历史白名单，改用 native `TRITON_ATTN`。

## 历史算子白名单

历史失败报告中的 V2/V3 27 个替换算子如下：

```text
add, addmm_out, arange_start, argmax, cat, copy_, cos, expand,
full, index, linear, lt_scalar, mm_out, ones, rand_like, reciprocal,
sin, softmax, softmax_out, sub, to_copy, true_divide, true_divide_,
where_self, where_self_out, zero_, zeros
```

在当前镜像/runtime 上继续使用这 27 个算子会产生重复 token，不能据此复现历史 V3。当前部署只保留：

```bash
VLLM_FL_FLAGOS_WHITELIST=attention_backend
VLLM_FL_USE_FLAGGEMS_ATTN=0
```

这表示保留 plugin-FL 的路由入口，但 attention 实际走 vLLM 的 native Triton backend。

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `10.232.2.33` |
| 芯片 | Hygon DCU BW1000 |
| GPU | 物理卡 `0,1` |
| 推理容器 | `SuperNova-Medius_flagos` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4` |
| vLLM / PyTorch | vLLM `0.24.0` / PyTorch `2.10.0` |
| 模型宿主机路径 | `/public-flash/models/SuperNova-Medius` |
| 模型容器路径 | `/models/SuperNova-Medius` |
| 服务端口 | `8000` |
| Tensor Parallel | `2` |
| dtype | `bfloat16` |
| 服务日志 | `/public-flash/models/release_run_logs/SuperNova-Medius-original-prefix-oot0/serve.log` |

模型权重在本次处理前已经下载完成，没有重新下载或修改权重。

## 启动参数

当前实际服务使用的核心启动命令为：

```bash
vllm serve /models/SuperNova-Medius \
  --served-model-name SuperNova-Medius \
  --dtype bfloat16 \
  --tensor-parallel-size 2 \
  --max-model-len 80000 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --attention-backend TRITON_ATTN \
  --no-enable-chunked-prefill \
  --enable-prefix-caching \
  --enforce-eager \
  --trust-remote-code
```

主要环境变量：

```bash
export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export USE_FLAGGEMS=1
export HIP_VISIBLE_DEVICES=0,1
export VLLM_FL_OOT_ENABLED=0
export VLLM_FL_FLAGOS_WHITELIST=attention_backend
export VLLM_FL_USE_FLAGGEMS_ATTN=0

export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
export VLLM_NO_USAGE_STATS=1

export TRITON_HIP_CLANG_PATH=/opt/dtk-26.04-DCC2602-0317/aillvm/bin/clang-18
```

`TRITON_HIP_CLANG_PATH` 是必须的 Hygon 适配变量。DTK 目录带版本号时，Triton 会错误判断 ROCm 目录并选择不存在或不兼容的 clang；显式指定 clang-18 后，`.amdgcn`/HSACO 编译可以正常完成。

## 容器内文件变更

本次没有重新构建、重新打 tag 或 push 镜像，也没有修改以下源码：

- vLLM 源码
- `vllm-plugin-FL` 源码
- FlagGems/Flagtree 算子实现
- 模型权重和 tokenizer

运行过程中新增或变化的内容主要是：

- 服务日志和评测日志；
- Triton 编译缓存；
- EvalScope 评测输出、predictions、reviews 和报告；
- guarded evaluator 重试前的 JSONL 备份文件。

模型服务进程没有因 runaway 处理而重启。runaway 的修复发生在评测执行层，不是通过修改容器内模型代码实现的。

## 50 题评测历史

当前服务在相同模型、镜像和主要推理配置下的 50 题 GPQA Diamond 结果曾出现：

| 轮次 | 结果 |
|------|------:|
| 首轮 | `44%` |
| 第二轮 | `40%` |
| 第三轮 | `38%` |
| 第四轮 | `38%` |

可用 NV 参考值为 `44%`，但这只能用于 50 题口径比较。历史 V3 的 `40.40%` 是 198 题结果，不能直接与 50 题 NV 分数计算相对损失。

## 198 题全量评测与 runaway 处理

### 原问题

原始全量评测使用：

- `max_tokens=32768`
- `stream=true`
- 并发 `8`
- stream read timeout `120000 ms`

某个请求进入重复生成后仍持续返回 token，因此不会触发流式读取超时，评测长期停在 `197/198`。服务本身仍然健康，显存和 KV cache 也在正常工作，判断为生成 runaway，不是 vLLM engine 死锁。

### 评测层修复

使用 guarded evaluator：

1. 将单题 `max_tokens` 限制为 `4096`，避免无限生成；
2. `stop_reason != stop`、API error 或没有有效 choices 的结果全部判为无效，不计入精度；
3. 只从 prediction/review 缓存中移除异常索引，其他正常题目通过 EvalScope cache 保留；
4. 重试前备份原始 JSONL，重试时只处理异常题；
5. 最终强制检查 predictions/reviews 都有 `0-197` 共 198 个唯一索引，且所有结果自然 `stop`；
6. 最多对异常题执行两轮局部重试。

代码：

```text
/Users/baai3333/Desktop/flagos/auto-day0/scripts/evalscope_guarded_gpqa.py
```

### 两遍全量结果

两遍评测均使用当前原始镜像、TP2、native `TRITON_ATTN`、`VLLM_FL_OOT_ENABLED=0` 和 prefix cache，期间没有重启模型服务。

| 轮次 | 首轮异常索引 | 重试结果 | 最终结果 |
|------|--------------|----------|----------:|
| Run 1 | `16, 170, 187` | 3 题均自然停止 | `83/198 = 41.92%` |
| Run 2 | `155, 187` | 2 题均自然停止 | `86/198 = 43.43%` |

最终两轮均满足：

- predictions：198 条；
- reviews：198 条；
- 索引唯一且完整；
- 所有最终结果 `stop_reason=stop`；
- EvalScope 提取答案与最后一个显式 `ANSWER:` 标记一致。

Run 1 与 Run 2 有 `56/198` 道题的最终选项发生变化，其中 17 道由错变对、14 道由对变错，净增加 3 道正确答案。这说明 runaway 已被评测层控制，但底层推理仍存在运行间非确定性。

Run 1 结果目录：

```text
/public-flash/models/release_run_logs/SuperNova-Medius-original-prefix-oot0/guarded198_20260916_run1
```

Run 2 结果目录：

```text
/public-flash/models/release_run_logs/SuperNova-Medius-original-prefix-oot0/guarded198_20260916_run2
```

## 定位结论

1. **部署问题**：已解决。clang-18 路径覆盖和 native `TRITON_ATTN` 可以稳定启动并生成正常文本。
2. **历史 27 算子白名单**：不能直接迁移到当前镜像；当前栈会出现重复 token，因此没有作为最终配置使用。
3. **单题 runaway**：已通过评测层上限、无效结果识别和局部重试解决评测阻塞，但没有根治底层偶发重复生成。
4. **精度稳定性**：未解决。两遍 198 题结果相差 3 个百分点，56 道题答案发生变化。
5. **与 V3 对比**：当前两遍结果高于历史 V3 数值，但运行时版本、TP 数、attention 路径、评测器和提示词链路不完全等价，不能直接据此认定已经复现或超过 V3。

## 当前结果

- 服务：正常，端口 `8000`，HCU 0、1，TP2；
- 镜像：原始 `xingcgen4` 镜像；
- attention：native `TRITON_ATTN`；
- OOT：`VLLM_FL_OOT_ENABLED=0`；
- prefix cache：开启；
- 198 题全量 Run 1：`41.92%`；
- 198 题全量 Run 2：`43.43%`；
- 198 题完整性：两轮均通过；
- 精度稳定性：未通过；
- 严格 5% 精度损失验收：当前缺少同口径 NV 198 题基线，不能下结论。

## 可复用规则

国产芯片模型适配应分离以下三层问题：

1. **编译层**：先固定 DTK/ROCm 路径和 clang，确保 Triton 能生成目标设备代码；
2. **算子路径层**：先用框架原生 attention 和最小 plugin 路径建立语义基线，再逐步加入历史算子白名单；
3. **评测层**：固定数据集、提示词、并发和生成参数，检测截断/runaway/API error，并对异常索引做可恢复的局部重试。

评测自动化不得把 `max_tokens` 截断结果当作普通错误答案，也不得因为某个固定题号曾经 runaway 就永久跳过该题。应基于响应状态识别异常，保留原始证据，只重试异常样本，最后校验题目索引完整性后再计算精度。

