# 迁移结果：❌ 失败

> **自动化流程产出镜像版本：**
> - V1：tree版本=基础版：只带flagtree不开启任何flagos组件
> - V2：tree+gems=Pro版：开启flaggems且性能达到V1的80%，与V1的精度误差在5%以内
> - V3：tree+gems+plugin=Max版：在V2的基础上安装使用plugin，且性能达到V1的80%，与V1的精度误差在5%以内
> - V4：tree+gems+plugin=Flag-express版：在V3的基础上，性能表现超过V1版本

# 基本信息

| 项目 | 内容 |
|------|------|
| 项目名称 | KT2期 |
| 开始时间 | - |
| gems+tree版本上传时间 | 2026-07-15 03:19:51 |
| 发布时间 | 2026-07-15 03:19:51 |
| 模型 | LFM2.5-1.2B-Thinking |
| 模型领域 | 语言 |
| 权重来源 | LiquidAI/LFM2.5-1.2B-Thinking |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0+g8a1c299e5 |
| FlagGems版本 | 5.0.0 |
| Flagtree版本 | 0.6.1 |
| FlagCX版本 | - |
| 厂商 | 摩尔(Mthreads) |
| GPU | MTT S5000 : 8 x -GB |
| 容器 | LFM2.5-1.2B-Thinking_flagos |
| release自动化工具版本 | v0.1.0 |

# 算子替换列表

## V1
### 算子白名单
（V1 不开启 FlagGems，无算子白名单）
### 算子替换列表（txt）
替换算子数：0
（V1 不开启 FlagGems，无算子替换）

## V2
### 算子白名单
```json
"include": [
    "add",
    "argmax",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "embedding",
    "exponential_",
    "fill_scalar_",
    "full",
    "gt_scalar",
    "index",
    "le",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "pow_scalar",
    "reciprocal",
    "rms_norm_forward",
    "scatter_",
    "sin",
    "softmax",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "vstack",
    "where_self",
    "where_self_out"
]
```
### 算子替换列表（txt）
替换算子数：31
```json
[
    "add",
    "argmax",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "embedding",
    "exponential_",
    "fill_scalar_",
    "full",
    "gt_scalar",
    "index",
    "le",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "pow_scalar",
    "reciprocal",
    "rms_norm_forward",
    "scatter_",
    "sin",
    "softmax",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "vstack",
    "where_self",
    "where_self_out"
]
```

## V3
### 算子白名单
```json
"include": [
    "add",
    "argmax",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "embedding",
    "exponential_",
    "fill_scalar_",
    "full",
    "gt_scalar",
    "index",
    "le",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "pow_scalar",
    "reciprocal",
    "rms_norm_forward",
    "scatter_",
    "sin",
    "softmax",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "vstack",
    "where_self",
    "where_self_out"
]
```
### 算子替换列表（txt）
替换算子数：31
```json
[
    "add",
    "argmax",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "embedding",
    "exponential_",
    "fill_scalar_",
    "full",
    "gt_scalar",
    "index",
    "le",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "pow_scalar",
    "reciprocal",
    "rms_norm_forward",
    "scatter_",
    "sin",
    "softmax",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "vstack",
    "where_self",
    "where_self_out"
]
```

## V4
### 算子白名单
（无数据）
### 算子替换列表（txt）
替换算子数：0
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
| GPQA_Diamond | 50 | 20.0 | 51 |

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
| LiquidAI/LFM2.5-1.2B-Thinking | Mthreads | - | 8 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| LiquidAI/LFM2.5-1.2B-Thinking | Mthreads | - | 8 | - | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| LiquidAI/LFM2.5-1.2B-Thinking | Mthreads | - | 8 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| LiquidAI/LFM2.5-1.2B-Thinking | Mthreads | - | 8 | - | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | - |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | - |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 5h 2m 9s |
| 流程消费 | 139.85 元（≈ $19.42 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/lfm2.5-1.2b-thinking-mthreads001-gems5.0.0-treenone-cxnone-plugin0.2.0-vllm0.20.2-cp310-pt27-musa43-x64-3.3.6-server:202607151117-v2
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/LFM2.5-1.2B-Thinking-mthreads-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/LFM2.5-1.2B-Thinking-mthreads-FlagOS

# 结论

- 发布镜像上传正常：❌ 未达标发布（精度不达标（rel_drop 超阈值））
- 流程自动化结论：❌ 迁移失败（精度不达标（rel_drop 超阈值））

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. Bug: Operator accuracy degradation on mthreads (LiquidAI/LFM2.5-1.2B-Thinking)
2. Bug: Operator crash on mthreads (LiquidAI/LFM2.5-1.2B-Thinking)

---

报告生成时间：2026.08.05