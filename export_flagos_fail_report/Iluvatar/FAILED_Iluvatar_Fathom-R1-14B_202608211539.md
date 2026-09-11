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
| 开始时间 | 2026-08-20 20:41:15 |
| gems+tree版本上传时间 | 2026-08-21 07:34:24 |
| 发布时间 | 2026-08-21 07:37:15 |
| 模型 | Fathom-R1-14B |
| 模型领域 | 语言 |
| 权重来源 | FractalAIResearch/Fathom-R1-14B |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | - |
| FlagGems版本 | 5.0.0 |
| Flagtree版本 | - |
| FlagCX版本 | - |
| 厂商 | 天数(Iluvatar) |
| GPU | BI-V150 : 16 x 32GB |
| 容器 | Fathom-R1-14B_flagos |
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
    "addmm",
    "arange_start",
    "argmax",
    "cat",
    "copy_",
    "cos",
    "embedding",
    "exponential_",
    "fill_scalar_",
    "flash_attn_varlen_func",
    "full",
    "general_mm",
    "index",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "ones",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "rms_norm_forward",
    "sin",
    "softmax",
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
替换算子数：32
```json
[
    "add",
    "addmm",
    "arange_start",
    "argmax",
    "cat",
    "copy_",
    "cos",
    "embedding",
    "exponential_",
    "fill_scalar_",
    "flash_attn_varlen_func",
    "full",
    "general_mm",
    "index",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "ones",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "rms_norm_forward",
    "sin",
    "softmax",
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
    "add",
    "addmm",
    "arange_start",
    "argmax",
    "cat",
    "copy_",
    "cos",
    "embedding",
    "exponential_",
    "fill_scalar_",
    "flash_attn_varlen_func",
    "full",
    "general_mm",
    "index",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "ones",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "rms_norm_forward",
    "sin",
    "softmax",
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
替换算子数：32
```json
[
    "add",
    "addmm",
    "arange_start",
    "argmax",
    "cat",
    "copy_",
    "cos",
    "embedding",
    "exponential_",
    "fill_scalar_",
    "flash_attn_varlen_func",
    "full",
    "general_mm",
    "index",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "ones",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "rms_norm_forward",
    "sin",
    "softmax",
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
| GPQA_Diamond | - | - | - |

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

> ⚠️ **性能基线为合成值，非实测 V1**：V2 初始性能 ×1.05（baseline_source: v2_initial_x1.05）。本报告所有以 V1 为基准的性能比均基于该合成基线。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| FractalAIResearch/Fathom-R1-14B | Iluvatar | - | 16 | - | 244727.52 | 579341.33 | 88.2 | 440.89 | 338.67 | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| FractalAIResearch/Fathom-R1-14B | Iluvatar | - | 16 | - | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| FractalAIResearch/Fathom-R1-14B | Iluvatar | - | 16 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| FractalAIResearch/Fathom-R1-14B | Iluvatar | - | 16 | - | - | - | - | - | - | - | - |

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
| 流程耗时 | 10h 56m 0s |
| 流程消费 | 357.59 元（≈ $49.66 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/fathom-r1-14b-iluvatar001-gems5.0.0-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp312-pt210-ixml44-x64-4.5.0:202608211533-v2
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/Fathom-R1-14B-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Fathom-R1-14B-FlagOS

# 结论

- 发布镜像上传正常：❌ 未对外发布（仅保留私有镜像）
- 流程自动化结论：❌ 迁移失败（详见上方精度/性能实测数据及所提 issue）

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 天数(Iluvatar) (FractalAIResearch/Fathom-R1-14B)
2. 【FR】Bug: Operator performance degradation on 天数(Iluvatar) (FractalAIResearch/Fathom-R1-14B)

---

报告生成时间：2026.08.21