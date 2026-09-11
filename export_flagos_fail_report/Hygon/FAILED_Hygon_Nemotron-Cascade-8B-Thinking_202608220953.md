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
| 开始时间 | 2026-08-21 21:05:00 |
| gems+tree版本上传时间 | 2026-08-22 01:51:48 |
| 发布时间 | 2026-08-22 01:52:45 |
| 模型 | Nemotron-Cascade-8B-Thinking |
| 模型领域 | 语言 |
| 权重来源 | nvidia/Nemotron-Cascade-8B-Thinking |
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
| 容器 | Nemotron-Cascade-8B-Thinking_flagos |
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
    "arange",
    "argmax",
    "attention_backend",
    "broadcast_to",
    "copy",
    "cos",
    "cumsum",
    "div",
    "expand",
    "full",
    "index",
    "le",
    "linear",
    "lt",
    "masked_fill",
    "mm",
    "ones",
    "rand_like",
    "reciprocal",
    "rsub",
    "scatter",
    "sin",
    "softmax",
    "sub",
    "sum",
    "to",
    "where",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：27
```json
[
"zeros",
    "full",
    "zero_",
    "arange_start",
    "true_divide",
    "reciprocal",
    "cos",
    "sin",
    "to_copy",
    "attention_backend",
    "ones",
    "copy_",
    "randn",
    "mm_out",
    "index",
    "rand_like",
    "linear",
    "argmax",
    "lt_scalar",
    "where_self",
    "where_self_out",
    "true_divide_",
    "softmax",
    "softmax_out",
    "expand",
    "add",
    "sub"
]
```

## V3
### 算子白名单
```json
"include": [
    "add",
    "arange",
    "argmax",
    "attention_backend",
    "broadcast_to",
    "copy",
    "cos",
    "cumsum",
    "div",
    "expand",
    "full",
    "index",
    "le",
    "linear",
    "lt",
    "masked_fill",
    "mm",
    "ones",
    "rand_like",
    "reciprocal",
    "rsub",
    "scatter",
    "sin",
    "softmax",
    "sub",
    "sum",
    "to",
    "where",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：29
```json
[
    "add",
    "arange",
    "argmax",
    "attention_backend",
    "broadcast_to",
    "copy",
    "cos",
    "cumsum",
    "div",
    "expand",
    "full",
    "index",
    "le",
    "linear",
    "lt",
    "masked_fill",
    "mm",
    "ones",
    "rand_like",
    "reciprocal",
    "rsub",
    "scatter",
    "sin",
    "softmax",
    "sub",
    "sum",
    "to",
    "where",
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
| math_500 | 200 | 95.5 | 29 |
| mmlu | 1140 | 85.96 | 29 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| math_500 | 200 | 95.5 | 29 |
| mmlu | 1140 | 85.96 | 29 |

> 沿用 V2 结果

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2（MATH-500） | 精度达标（vs NV96.8，rel_drop 1.34%） |
| V1 VS V2（MMLU） | 精度达标（vs NV85.02，rel_drop -1.11%） |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | - |

## 性能评测

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| nvidia/Nemotron-Cascade-8B-Thinking | Hygon | - | 8 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| nvidia/Nemotron-Cascade-8B-Thinking | Hygon | - | 8 | - | 6699.6 | - | 670.1 | 3350.6 | 84.2 | 27 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| nvidia/Nemotron-Cascade-8B-Thinking | Hygon | - | 8 | - | 6699.6 | - | 670.1 | 3350.6 | 84.2 | 27 | - |

> 沿用 V2 结果

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| nvidia/Nemotron-Cascade-8B-Thinking | Hygon | - | 8 | - | - | - | - | - | - | - | - |

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
| 流程耗时 | 4h 47m 45s |
| 流程消费 | 110.57 元（≈ $15.36 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：-
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/Nemotron-Cascade-8B-Thinking-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Nemotron-Cascade-8B-Thinking-FlagOS

# 结论

- 发布镜像上传正常：❌ 私有发布
- 流程自动化结论：❌ 迁移失败

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 海光(Hygon) (nvidia/Nemotron-Cascade-8B-Thinking)
2. 【FR】Bug: Operator performance degradation on 海光(Hygon) (nvidia/Nemotron-Cascade-8B-Thinking)

---

报告生成时间：2026.08.22