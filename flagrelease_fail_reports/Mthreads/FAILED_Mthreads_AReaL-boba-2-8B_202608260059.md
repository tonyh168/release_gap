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
| gems+tree版本上传时间 | 2026-08-26 00:52:00 |
| 发布时间 | 2026-08-26 00:59:00 |
| 模型 | AReaL-boba-2-8B |
| 模型领域 | 语言 |
| 权重来源 | inclusionAI/AReaL-boba-2-8B |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0+g8a1c299e5 |
| FlagGems版本 | 5.3.0rc2 |
| Flagtree版本 | 0.6.1a2+mthreads3.6 |
| FlagCX版本 | - |
| 厂商 | 摩尔(Mthreads) |
| GPU | MTT S5000 : 8 x 80GB |
| 容器 | AReaL-boba-2-8B_flagos |
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
    "cat",
    "copy",
    "cos",
    "cumsum",
    "div",
    "embedding",
    "exponential_",
    "fill",
    "full",
    "fused_add_rms_norm",
    "gather",
    "index",
    "le",
    "lt",
    "masked_fill",
    "mm",
    "mul",
    "ones",
    "pow",
    "rand_like",
    "reciprocal",
    "rms_norm",
    "rotary_embedding",
    "rsub",
    "scatter",
    "silu_and_mul",
    "sin",
    "softmax",
    "sort",
    "sub",
    "to",
    "where",
    "zeros",
    "copy_",
    "cumsum_out",
    "fill_scalar_",
    "lt_scalar",
    "masked_fill_",
    "pow_scalar",
    "rms_norm_forward",
    "rsub_scalar",
    "scatter_",
    "softmax_out",
    "to_copy",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out"
]
```
### 算子替换列表（txt）
替换算子数：52
```json
[
    "add",
    "arange",
    "argmax",
    "attention_backend",
    "cat",
    "copy",
    "cos",
    "cumsum",
    "div",
    "embedding",
    "exponential_",
    "fill",
    "full",
    "fused_add_rms_norm",
    "gather",
    "index",
    "le",
    "lt",
    "masked_fill",
    "mm",
    "mul",
    "ones",
    "pow",
    "rand_like",
    "reciprocal",
    "rms_norm",
    "rotary_embedding",
    "rsub",
    "scatter",
    "silu_and_mul",
    "sin",
    "softmax",
    "sort",
    "sub",
    "to",
    "where",
    "zeros",
    "copy_",
    "cumsum_out",
    "fill_scalar_",
    "lt_scalar",
    "masked_fill_",
    "pow_scalar",
    "rms_norm_forward",
    "rsub_scalar",
    "scatter_",
    "softmax_out",
    "to_copy",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out"
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
    "cat",
    "copy",
    "cos",
    "cumsum",
    "div",
    "embedding",
    "exponential_",
    "fill",
    "full",
    "fused_add_rms_norm",
    "gather",
    "index",
    "le",
    "lt",
    "masked_fill",
    "mm",
    "mul",
    "ones",
    "pow",
    "rand_like",
    "reciprocal",
    "rms_norm",
    "rotary_embedding",
    "rsub",
    "scatter",
    "silu_and_mul",
    "sin",
    "softmax",
    "sort",
    "sub",
    "to",
    "where",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：37
```json
[
    "add",
    "arange",
    "argmax",
    "attention_backend",
    "cat",
    "copy",
    "cos",
    "cumsum",
    "div",
    "embedding",
    "exponential_",
    "fill",
    "full",
    "fused_add_rms_norm",
    "gather",
    "index",
    "le",
    "lt",
    "masked_fill",
    "mm",
    "mul",
    "ones",
    "pow",
    "rand_like",
    "reciprocal",
    "rms_norm",
    "rotary_embedding",
    "rsub",
    "scatter",
    "silu_and_mul",
    "sin",
    "softmax",
    "sort",
    "sub",
    "to",
    "where",
    "zeros"
]
```

## V4
### 算子白名单
（未执行 V4）
### 算子替换列表（txt）
替换算子数：0
（未执行 V4）

# 评测结果

## 精度评测

无精度数据(容器无results)。以下各版本精度表按实测情况如实填写，无数据以 - 占位。

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| - | - | - | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| - | - | - | - |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| - | - | - | - |

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | - |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | - |

## 性能评测

性能数据来源于 4k-1k 64 并发 benchmark；无实测数据的单元格以 - 占位。

> 性能调优2轮：disabled silu_and_mul→88.60%, rms_norm→88.50%

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|------|------|------|------|------|------|------|------|------|------|------|------|
| inclusionAI/AReaL-boba-2-8B | Mthreads | - | 8 | - | 3701.71 | 3958.86 | 113.09 | 565.53 | 562.67 | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|------|------|------|------|------|------|------|------|------|------|------|------|
| inclusionAI/AReaL-boba-2-8B | Mthreads | - | 8 | - | - | - | - | - | - | 52 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|------|------|------|------|------|------|------|------|------|------|------|------|
| inclusionAI/AReaL-boba-2-8B | Mthreads | - | 8 | - | - | - | - | - | - | 52 | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|------|------|------|------|------|------|------|------|------|------|------|------|
| inclusionAI/AReaL-boba-2-8B | Mthreads | - | 8 | - | - | - | - | - | - | - | - |

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
| 流程耗时 | 5h 50m 55s |
| 流程消费 | 382.08 元（≈ $53.07 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/areal-boba-2-8b-mthreads001-gems5.3.0-tree0.6.1-cxnone-plugin0.2.0-vllm0.20.2-cp310-pt27-musa43-x64-3.3.6-server:202608260052-v2
  - V3：-
  - V4：-

- ModelScope: -
- HuggingFace: -

# 结论

- 发布镜像上传正常：❌ 未对外发布（无精度基线，精度数据缺失无法验证达标）
- 流程自动化结论：❌ 迁移失败（无精度基线，精度数据缺失无法验证达标）

## 提交到 flagos 仓库的 Issue
issue 数量：0

---

报告生成时间：2026.09.01
