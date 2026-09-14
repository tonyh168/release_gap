# 迁移结果：❌ 失败

> **自动化流程产出镜像版本：**
> - V1：tree版本=基础版：只带flagtree不开启任何flagos组件
> - V2：tree+gems=Pro版：开启flaggems且性能达到V1的80%，与V1的精度误差在5%以内
> - V3：tree+gems+plugin=Max版：在V2的基础上安装使用plugin，且性能达到V1的80%，与V1的精度误差在5%以内
> - V4：tree+gems+plugin=Flag-express版：在V3的基础上，性能表现超过V1版本

# 基本信息

| 项目 | 内容 |
|------|------|
| 项目名称 | - |
| 开始时间 | 2026-07-22 07:02:09 |
| gems+tree版本上传时间 | 2026-07-22 12:22:47 |
| 发布时间 |  |
| 模型 | gemma-1.1-7b-it |
| 模型领域 | 语言 |
| 权重来源 | google/gemma-1.1-7b-it |
| 权重数制 |  |
| 计算数制（默认权重数制） |  |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | installed |
| FlagGems版本 | 5.4.0dev |
| Flagtree版本 | 0.6.1 |
| FlagCX版本 | - |
| 厂商 | 海光(Hygon) |
| GPU | DCU BW1000 : 8 x -GB |
| 容器 | gemma-1.1-7b-it_flagos |
| release自动化工具版本 | v0.1.0 |

# 算子替换列表

## V1
### 算子白名单
（V1 不开启 FlagGems，无算子白名单）
### 算子替换列表（txt）
（V1 不开启 FlagGems，无算子替换）

## V2
### 算子白名单
```json
"include": [
    "[DEBUG] flag_gems.ops.add.add: GEMS ADD",
    "[DEBUG] flag_gems.ops.addmm.addmm_out: GEMS ADDMM_OUT, [shape info]: [-, 2048, 3072, 4096](batch, M, N, K), [A column-major]: False, [B column-major]: True, [bias column-major]: False",
    "[DEBUG] flag_gems.ops.arange.arange_start: GEMS ARANGE",
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.broadcast_to.broadcast_to: GEMS BROADCAST_TO",
    "[DEBUG] flag_gems.ops.copy.copy_: GEMS COPY_",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.expand.expand: GEMS EXPAND",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.index.index: GEMS INDEX",
    "[DEBUG] flag_gems.ops.linear.linear: GEMS LINEAR",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.mm.mm_out: GEMS MM_OUT",
    "[DEBUG] flag_gems.ops.rand_like.rand_like: GEMS RAND_LIKE",
    "[DEBUG] flag_gems.ops.randn.randn: GEMS RANDN",
    "[DEBUG] flag_gems.ops.reciprocal.reciprocal: GEMS RECIPROCAL",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.softmax.softmax: GEMS SOFTMAX",
    "[DEBUG] flag_gems.ops.softmax.softmax_out: GEMS SOFTMAX_OUT",
    "[DEBUG] flag_gems.ops.sub.sub: GEMS SUB",
    "[DEBUG] flag_gems.ops.to.to_copy: GEMS TO_COPY",
    "[DEBUG] flag_gems.ops.where.where_self: GEMS WHERE_SELF",
    "[DEBUG] flag_gems.ops.where.where_self_out: GEMS WHERE_SELF_OUT",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_",
    "[DEBUG] flag_gems.ops.zeros.zeros: GEMS ZEROS",
    "[DEBUG] vllm_fl.dispatch.ops.attention_backend: default.flagos"
]
```
### 算子替换列表（txt）
替换算子数：27
```json
[
    "add",
    "addmm_out",
    "arange_start",
    "argmax",
    "broadcast_to",
    "copy_",
    "cos",
    "expand",
    "full",
    "index",
    "linear",
    "lt_scalar",
    "mm_out",
    "rand_like",
    "randn",
    "reciprocal",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros"
]
```

## V3
### 算子白名单
```json
"include": [
    "[DEBUG] flag_gems.ops.add.add: GEMS ADD",
    "[DEBUG] flag_gems.ops.addmm.addmm_out: GEMS ADDMM_OUT, [shape info]: [-, 2048, 3072, 4096](batch, M, N, K), [A column-major]: False, [B column-major]: True, [bias column-major]: False",
    "[DEBUG] flag_gems.ops.arange.arange_start: GEMS ARANGE",
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.broadcast_to.broadcast_to: GEMS BROADCAST_TO",
    "[DEBUG] flag_gems.ops.copy.copy_: GEMS COPY_",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.expand.expand: GEMS EXPAND",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.index.index: GEMS INDEX",
    "[DEBUG] flag_gems.ops.linear.linear: GEMS LINEAR",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.mm.mm_out: GEMS MM_OUT",
    "[DEBUG] flag_gems.ops.rand_like.rand_like: GEMS RAND_LIKE",
    "[DEBUG] flag_gems.ops.randn.randn: GEMS RANDN",
    "[DEBUG] flag_gems.ops.reciprocal.reciprocal: GEMS RECIPROCAL",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.softmax.softmax: GEMS SOFTMAX",
    "[DEBUG] flag_gems.ops.softmax.softmax_out: GEMS SOFTMAX_OUT",
    "[DEBUG] flag_gems.ops.sub.sub: GEMS SUB",
    "[DEBUG] flag_gems.ops.to.to_copy: GEMS TO_COPY",
    "[DEBUG] flag_gems.ops.where.where_self: GEMS WHERE_SELF",
    "[DEBUG] flag_gems.ops.where.where_self_out: GEMS WHERE_SELF_OUT",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_",
    "[DEBUG] flag_gems.ops.zeros.zeros: GEMS ZEROS",
    "[DEBUG] vllm_fl.dispatch.ops.attention_backend: default.flagos"
]
```
### 算子替换列表（txt）
替换算子数：28
```json
[
    "[DEBUG] flag_gems.ops.add.add: GEMS ADD",
    "[DEBUG] flag_gems.ops.addmm.addmm_out: GEMS ADDMM_OUT, [shape info]: [-, 2048, 3072, 4096](batch, M, N, K), [A column-major]: False, [B column-major]: True, [bias column-major]: False",
    "[DEBUG] flag_gems.ops.arange.arange_start: GEMS ARANGE",
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.broadcast_to.broadcast_to: GEMS BROADCAST_TO",
    "[DEBUG] flag_gems.ops.copy.copy_: GEMS COPY_",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.expand.expand: GEMS EXPAND",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.index.index: GEMS INDEX",
    "[DEBUG] flag_gems.ops.linear.linear: GEMS LINEAR",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.mm.mm_out: GEMS MM_OUT",
    "[DEBUG] flag_gems.ops.rand_like.rand_like: GEMS RAND_LIKE",
    "[DEBUG] flag_gems.ops.randn.randn: GEMS RANDN",
    "[DEBUG] flag_gems.ops.reciprocal.reciprocal: GEMS RECIPROCAL",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.softmax.softmax: GEMS SOFTMAX",
    "[DEBUG] flag_gems.ops.softmax.softmax_out: GEMS SOFTMAX_OUT",
    "[DEBUG] flag_gems.ops.sub.sub: GEMS SUB",
    "[DEBUG] flag_gems.ops.to.to_copy: GEMS TO_COPY",
    "[DEBUG] flag_gems.ops.where.where_self: GEMS WHERE_SELF",
    "[DEBUG] flag_gems.ops.where.where_self_out: GEMS WHERE_SELF_OUT",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_",
    "[DEBUG] flag_gems.ops.zeros.zeros: GEMS ZEROS",
    "[DEBUG] vllm_fl.dispatch.ops.attention_backend: default.flagos"
]
```

## V4
### 算子白名单
（无数据）
### 算子替换列表（txt）
（无数据）

# 评测结果

## 精度评测

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 32.0 | 28 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | - |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | - |

## 性能评测

> ⚠️ **性能基线为合成值，非实测 V1**：V2 初始性能 ×1.2（baseline_source: v2_initial_x1.2）。本报告所有以 V1 为基准的性能比均基于该合成基线。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| google/gemma-1.1-7b-it | Hygon | - | 8 | - | 164480.33 | 332306.0 | 134.88 | 674.16 | 151.08 | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| google/gemma-1.1-7b-it | Hygon | - | 8 | - | 196110.1 | 396114.5 | 113.0 | 564.9 | 180.4 | 28 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| google/gemma-1.1-7b-it | Hygon | - | 8 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| google/gemma-1.1-7b-it | Hygon | - | 8 | - | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 83.9%（禁用 silu_and_mul 后；≥80% 达标） |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | - |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 5h 24m 12s |
| 流程消费 | 53.57 元（≈ $7.44 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/gemma-1.1-7b-it-hygon001-gems5.4.0-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp310-pt210-dtknone-x64-6.3.28-v1.3.0b:202607221938-v2
  - V3：-（未进入，V2 精度不达标）
  - V4：-（未到达）

- ModelScope: https://modelscope.cn/models/FlagRelease/gemma-1.1-7b-it-hygon-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/gemma-1.1-7b-it-hygon-FlagOS

# 结论

- 发布镜像上传正常：❌ 不合格
- 流程自动化结论：❌ 未达标（V2 精度不达标：32.0 vs NV 37.0，退化 +13.51% 超 5% 阈值；V3/V5 未产出）

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. [精度下降 accuracy-degraded] 【FR】Bug: Operator accuracy degradation on hygon (google/gemma-1.1-7b-it) —— 目标组件 FlagGems，精度退化 >5%，4 轮累积禁用测试精度恒定 32.0（对算子完全不敏感），判定非单一算子问题，疑为模型-硬件数值兼容层面问题；产出于 V2 精度调优。
2. [性能下降 performance-degraded] 【FR】Bug: Operator performance degradation on hygon (google/gemma-1.1-7b-it) —— 目标组件 FlagGems，V2/V1=57.7%<80%，禁用 OOT 算子 silu_and_mul 后升至 83.9% 达标；涉及算子 silu_and_mul，产出于 V2 性能调优。

---

报告生成时间：2026.07.23