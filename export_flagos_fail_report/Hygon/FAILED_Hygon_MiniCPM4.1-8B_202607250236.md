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
| 开始时间 | 2026-07-25 02:36:07 |
| gems+tree版本上传时间 | 2026-07-25 05:44:25 |
| 发布时间 | 2026-07-25 18:36:25 |
| 模型 | MiniCPM4.1-8B |
| 模型领域 | 语言 |
| 权重来源 | openbmb/MiniCPM4.1-8B |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0+gffa2ee3eb |
| FlagGems版本 | 5.4.0dev |
| Flagtree版本 | 0.6.1 |
| FlagCX版本 | - |
| 厂商 | 海光(Hygon) |
| GPU | DCU BW1000 : 8 x 64GB |
| 容器 | MiniCPM4.1-8B_flagos_0725_1030 |
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
    "broadcast_to",
    "copy",
    "cos",
    "cumsum",
    "div",
    "expand",
    "index",
    "le",
    "lt",
    "masked_fill",
    "rand_like",
    "randn",
    "reciprocal",
    "rsub",
    "scatter",
    "sin",
    "softmax",
    "sub",
    "sum",
    "to",
    "where"
]
```
### 算子替换列表（txt）
替换算子数：34
```json
[
    "add",
    "arange_start",
    "argmax",
    "broadcast_to",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "expand",
    "full",
    "index",
    "le",
    "linear",
    "lt_scalar",
    "masked_fill_",
    "mm_out",
    "ones",
    "rand_like",
    "randn",
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
    "arange",
    "argmax",
    "broadcast_to",
    "copy",
    "cos",
    "cumsum",
    "div",
    "expand",
    "index",
    "le",
    "lt",
    "masked_fill",
    "rand_like",
    "randn",
    "reciprocal",
    "rsub",
    "scatter",
    "sin",
    "softmax",
    "sub",
    "sum",
    "to",
    "where"
]
```
### 算子替换列表（txt）
替换算子数：30
```json
[
    "add",
    "arange_start",
    "argmax",
    "broadcast_to",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "expand",
    "index",
    "le",
    "lt_scalar",
    "masked_fill_",
    "mm_out",
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
    "zero_"
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
| GPQA_Diamond | 50 | 40.0 | 35 |

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
| openbmb/MiniCPM4.1-8B | Hygon | - | 8 | - | - | - | 1548.4 | 7741.56 | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| openbmb/MiniCPM4.1-8B | Hygon | - | 8 | - | 637.3 | - | 1497.4 | 7487.0 | 41.9 | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| openbmb/MiniCPM4.1-8B | Hygon | - | 8 | - | 840.8 | 1101.5 | 1501.2 | 7506.0 | 41.7 | 6 | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| openbmb/MiniCPM4.1-8B | Hygon | - | 8 | - | - | - | - | - | - | - | - |

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
| 流程耗时 | 16h 0m 18s |
| 流程消费 | 552.04 元（≈ $76.67 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/minicpm4.1-8b-hygon001-gems5.4.0-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp310-pt210-dtknone-x64-6.3.30-v1.4.1a:202607251322-v2
  - V3：-
  - V4：-

- ModelScope: https://www.modelscope.cn/models/FlagRelease/MiniCPM4.1-8B-hygon-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/MiniCPM4.1-8B-hygon-FlagOS

# 结论

- 发布镜像上传正常：❌ 未达标发布（精度不达标（rel_drop 超阈值））
- 流程自动化结论：❌ 迁移失败（精度不达标（rel_drop 超阈值））

## 提交到 flagos 仓库的 Issue
issue 数量：3
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on hygon (openbmb/MiniCPM4.1-8B)
2. 【FR】Bug: vllm-plugin-FL error on hygon (openbmb/MiniCPM4.1-8B)
3. 【FR】Bug: vllm-plugin-FL error: dispatch, vllm_fl on hygon (openbmb/MiniCPM4.1-8B)

---

报告生成时间：2026.08.06