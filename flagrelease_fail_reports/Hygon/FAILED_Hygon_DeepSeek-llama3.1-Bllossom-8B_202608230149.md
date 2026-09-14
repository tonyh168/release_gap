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
| 开始时间 | 2026-08-22 01:56:13 |
| gems+tree版本上传时间 | 2026-08-22 17:47:10 |
| 发布时间 | 2026-08-22 17:47:36 |
| 模型 | DeepSeek-llama3.1-Bllossom-8B |
| 模型领域 | 语言 |
| 权重来源 | UNIVA-Bllossom/DeepSeek-llama3.1-Bllossom-8B |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0 |
| FlagGems版本 | 5.4.0dev |
| Flagtree版本 | 0.6.0 |
| FlagCX版本 | - |
| 厂商 | 海光(Hygon) |
| GPU | DCU BW1000 : 8 x 64GB |
| 容器 | DeepSeek-llama3.1-Bllossom-8B_flagos |
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
    "arange_start",
    "argmax",
    "attention_backend",
    "broadcast_to",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "expand",
    "full",
    "gt_scalar",
    "index",
    "le",
    "linear",
    "lt_scalar",
    "masked_fill_",
    "mm_out",
    "ones",
    "rand_like",
    "reciprocal",
    "rsub_scalar",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "sum_dim",
    "to_copy",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：35
```json
[
    "add",
    "arange_start",
    "argmax",
    "attention_backend",
    "broadcast_to",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "expand",
    "full",
    "gt_scalar",
    "index",
    "le",
    "linear",
    "lt_scalar",
    "masked_fill_",
    "mm_out",
    "ones",
    "rand_like",
    "reciprocal",
    "rsub_scalar",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "sum_dim",
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
    "add",
    "arange_start",
    "argmax",
    "attention_backend",
    "broadcast_to",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "expand",
    "full",
    "gt_scalar",
    "index",
    "le",
    "linear",
    "lt_scalar",
    "masked_fill_",
    "mm_out",
    "ones",
    "rand_like",
    "reciprocal",
    "rsub_scalar",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "sum_dim",
    "to_copy",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：35
```json
[
    "add",
    "arange_start",
    "argmax",
    "attention_backend",
    "broadcast_to",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "expand",
    "full",
    "gt_scalar",
    "index",
    "le",
    "linear",
    "lt_scalar",
    "masked_fill_",
    "mm_out",
    "ones",
    "rand_like",
    "reciprocal",
    "rsub_scalar",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "sum_dim",
    "to_copy",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros"
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
| math_500 | 200 | 71.5 | 35 |
| mmlu | 1140 | 54.82 | 35 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| math_500 | 200 | 71.5 | 35 |
| mmlu | 1140 | 54.82 | 35 |

> 沿用 V2 结果

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2（MATH-500） | 精度不达标（vs NV84.6，rel_drop 15.48%） |
| V1 VS V2（MMLU） | 精度不达标（vs NV69.9，rel_drop 21.57%） |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | - |

## 性能评测

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| UNIVA-Bllossom/DeepSeek-llama3.1-Bllossom-8B | Hygon | - | 8 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| UNIVA-Bllossom/DeepSeek-llama3.1-Bllossom-8B | Hygon | - | 8 | - | 8829.2 | - | 831.3 | 4156.6 | 69.5 | 35 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| UNIVA-Bllossom/DeepSeek-llama3.1-Bllossom-8B | Hygon | - | 8 | - | 8829.2 | - | 831.3 | 4156.6 | 69.5 | 35 | - |

> 沿用 V2 结果

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| UNIVA-Bllossom/DeepSeek-llama3.1-Bllossom-8B | Hygon | - | 8 | - | - | - | - | - | - | - | - |

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
| 流程耗时 | 15h 51m 23s |
| 流程消费 | 388.36 元（≈ $53.94 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：-
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/DeepSeek-llama3.1-Bllossom-8B-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/DeepSeek-llama3.1-Bllossom-8B-FlagOS

# 结论

- 发布镜像上传正常：❌ 私有发布）
- 流程自动化结论：❌ 迁移失败）

## 提交到 flagos 仓库的 Issue
issue 数量：1
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 海光(Hygon) (UNIVA-Bllossom/DeepSeek-llama3.1-Bllossom-8B)

---

报告生成时间：2026.08.22