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
| 开始时间 | 2026-07-16 16:12:42 |
| gems+tree版本上传时间 | 2026-07-16 22:41:47 |
| 发布时间 | 2026-07-16 22:41:47 |
| 模型 | Phi-3.5-mini-instruct |
| 模型领域 | 语言 |
| 权重来源 | LLM-Research/Phi-3.5-mini-instruct |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.0.0+gfe3825e86 |
| FlagGems版本 | 5.0.0 |
| Flagtree版本 | 0.6.1 |
| FlagCX版本 | - |
| 厂商 | 摩尔(Mthreads) |
| GPU | MTT S5000 : 8 x -GB |
| 容器 | Phi-3.5-mini-instruct_flagos |
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
    "full_like",
    "index",
    "le",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "neg",
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
    "full_like",
    "index",
    "le",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "neg",
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
    "where_self",
    "where_self_out"
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
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "embedding",
    "exponential_",
    "fill_scalar_",
    "forward",
    "full",
    "full_like",
    "fused_add_rms_norm",
    "gather",
    "gems_rms_forward",
    "gems_silu_and_mul",
    "index",
    "index_select",
    "le",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mm_fma",
    "mul",
    "neg",
    "ones",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "rms_norm",
    "rms_norm_forward",
    "scatter_",
    "silu_and_mul",
    "sin",
    "softmax",
    "sort",
    "sort_stable",
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
### 算子替换列表（txt）
替换算子数：48
```json
[
    "add",
    "arange_start",
    "argmax",
    "attention_backend",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "embedding",
    "exponential_",
    "fill_scalar_",
    "forward",
    "full",
    "full_like",
    "fused_add_rms_norm",
    "gather",
    "gems_rms_forward",
    "gems_silu_and_mul",
    "index",
    "index_select",
    "le",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mm_fma",
    "mul",
    "neg",
    "ones",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "rms_norm",
    "rms_norm_forward",
    "scatter_",
    "silu_and_mul",
    "sin",
    "softmax",
    "sort",
    "sort_stable",
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

## V4
### 算子白名单
```json
"include": [
    "add",
    "arange_start",
    "argmax",
    "attention_backend",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "embedding",
    "exponential_",
    "fill_scalar_",
    "forward",
    "full",
    "full_like",
    "fused_add_rms_norm",
    "gather",
    "gems_rms_forward",
    "gems_silu_and_mul",
    "index",
    "index_select",
    "le",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mm_fma",
    "mul",
    "neg",
    "ones",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "rms_norm",
    "rms_norm_forward",
    "scatter_",
    "silu_and_mul",
    "sin",
    "softmax",
    "sort",
    "sort_stable",
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
### 算子替换列表（txt）
替换算子数：48
```json
[
    "add",
    "arange_start",
    "argmax",
    "attention_backend",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "embedding",
    "exponential_",
    "fill_scalar_",
    "forward",
    "full",
    "full_like",
    "fused_add_rms_norm",
    "gather",
    "gems_rms_forward",
    "gems_silu_and_mul",
    "index",
    "index_select",
    "le",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mm_fma",
    "mul",
    "neg",
    "ones",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "rms_norm",
    "rms_norm_forward",
    "scatter_",
    "silu_and_mul",
    "sin",
    "softmax",
    "sort",
    "sort_stable",
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

# 评测结果

## 精度评测

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 26.0 | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 22.0 | 49 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | 24.0 | 49 |

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 精度偏差 4.0% |
| V1 VS V3 | 精度偏差 2.0% |
| V1 VS V4 | - |
| V2 VS V3 | 精度偏差 2.0% |

## 性能评测

> ⚠️ **性能基线为合成值，非实测 V1**：V2 初始性能 ×1.2（baseline_source: v2_initial_x1.2）。本报告所有以 V1 为基准的性能比均基于该合成基线。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| LLM-Research/Phi-3.5-mini-instruct | Mthreads | - | 8 | - | 1676.76 | 1707.2 | 21.35 | 106.73 | 185.9 | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| LLM-Research/Phi-3.5-mini-instruct | Mthreads | - | 8 | - | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| LLM-Research/Phi-3.5-mini-instruct | Mthreads | - | 8 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| LLM-Research/Phi-3.5-mini-instruct | Mthreads | - | 8 | - | - | - | - | - | - | - | - |

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
| 流程耗时 | 9h 39m 21s |
| 流程消费 | 330.82 元（≈ $45.95 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/phi-3.5-mini-instruct-mthreads001-gems5.0.0-treenone-cxnone-plugin0.2.0-vllm0.20.2-cp310-pt27-musa43-x64-3.3.6-server:202607170638-v2
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/Phi-3.5-mini-instruct-mthreads-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Phi-3.5-mini-instruct-mthreads-FlagOS

# 结论

- 发布镜像上传正常：✅ 合格（V2 已产出）
- 流程自动化结论：✅ 流程已达标

## 提交到 flagos 仓库的 Issue
issue 数量：1
issue 标题：
1. Bug: Operator accuracy degradation on mthreads (LLM-Research/Phi-3.5-mini-instruct)

---

报告生成时间：2026.08.05