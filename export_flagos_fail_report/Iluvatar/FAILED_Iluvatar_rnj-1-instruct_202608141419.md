# 迁移结果：❌ 失败（精度不达标（rel_drop 超阈值）、性能不达标）

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
| gems+tree版本上传时间 | 2026-08-14 06:17:20 |
| 发布时间 | 2026-08-14 06:17:52 |
| 模型 | rnj-1-instruct |
| 模型领域 | 语言 |
| 权重来源 | EssentialAI/rnj-1-instruct |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0+gd1653d9ff |
| FlagGems版本 | 5.0.0 |
| Flagtree版本 |  |
| FlagCX版本 |  |
| 厂商 | 天数(Iluvatar) |
| GPU | BI-V150 : 16 x -GB |
| 容器 | rnj-1-instruct_flagos_0813_2250 |
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
    "cat",
    "clamp",
    "copy_",
    "cos",
    "embedding",
    "exponential_",
    "fill_scalar_",
    "flash_attn_varlen_func",
    "full",
    "general_mm",
    "index",
    "index_select",
    "lt_scalar",
    "masked_fill_",
    "mean_dim",
    "mean_dim_comm",
    "mha_varlan_fwd",
    "mul",
    "pow_scalar",
    "pow_tensor_scalar",
    "rand_like",
    "reciprocal",
    "rsqrt",
    "scatter_",
    "sin",
    "softmax",
    "sub",
    "tanh",
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
替换算子数：16
```json
[
    "add",
    "arange_start",
    "cat",
    "clamp",
    "cos",
    "fill_scalar_",
    "full",
    "mul",
    "pow_scalar",
    "reciprocal",
    "sin",
    "sub",
    "to_copy",
    "true_divide",
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
    "cat",
    "clamp",
    "copy_",
    "cos",
    "embedding",
    "exponential_",
    "fill_scalar_",
    "flash_attn_varlen_func",
    "full",
    "general_mm",
    "index",
    "index_select",
    "lt_scalar",
    "masked_fill_",
    "mean_dim",
    "mean_dim_comm",
    "mha_varlan_fwd",
    "mul",
    "pow_scalar",
    "pow_tensor_scalar",
    "rand_like",
    "reciprocal",
    "rsqrt",
    "scatter_",
    "sin",
    "softmax",
    "sub",
    "tanh",
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
替换算子数：38
```json
[
    "add",
    "arange_start",
    "argmax",
    "cat",
    "clamp",
    "copy_",
    "cos",
    "embedding",
    "exponential_",
    "fill_scalar_",
    "flash_attn_varlen_func",
    "full",
    "general_mm",
    "index",
    "index_select",
    "lt_scalar",
    "masked_fill_",
    "mean_dim",
    "mean_dim_comm",
    "mha_varlan_fwd",
    "mul",
    "pow_scalar",
    "pow_tensor_scalar",
    "rand_like",
    "reciprocal",
    "rsqrt",
    "scatter_",
    "sin",
    "softmax",
    "sub",
    "tanh",
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
| GPQA_Diamond | 50 | 28.0 | 17 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

### 结果对比
> 说明：本次无实测 V1，精度基线为 NV 实测（GPQA_Diamond = 37.0%）。「V1 VS V2」按 NV 基线计相对退化。
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 相对退化 24.32%（NV=37.0%，V2=28.0%，超阈值） |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | - |

## 性能评测

> 注：下表 V2 行为算子调优后（flagos_optimized）实测。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| EssentialAI/rnj-1-instruct | 天数(Iluvatar) | - | 16 | - | - | - | 100.91 | 504.63 | - | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| EssentialAI/rnj-1-instruct | 天数(Iluvatar) | - | 16 | - | - | - | 100.70 | 503.50 | - | 16 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| EssentialAI/rnj-1-instruct | 天数(Iluvatar) | - | 16 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| EssentialAI/rnj-1-instruct | 天数(Iluvatar) | - | 16 | - | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 99.8% |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | - |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 15h 18m 40s |
| 流程消费 | 666.34 元（≈ $92.55 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/rnj-1-instruct-iluvatar001-gems5.0.0-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp312-pt210-ixml44-x64-4.5.0:202608141412-v2
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/rnj-1-instruct-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/rnj-1-instruct-FlagOS

# 结论

- 发布镜像上传正常：❌ 未达标发布（精度不达标（rel_drop 超阈值）、性能不达标）
- 流程自动化结论：❌ 迁移失败（精度不达标（rel_drop 超阈值）、性能不达标）

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 天数(Iluvatar) (EssentialAI/rnj-1-instruct)
2. 【FR】Bug: Operator performance degradation on 天数(Iluvatar) (EssentialAI/rnj-1-instruct)

---

报告生成时间：2026.08.14