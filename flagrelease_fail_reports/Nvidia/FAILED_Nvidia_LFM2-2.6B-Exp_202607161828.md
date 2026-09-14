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
| gems+tree版本上传时间 | 2026-07-18 18:01:29 |
| 发布时间 | 2026-07-18 18:01:29 |
| 模型 | LFM2-2.6B-Exp |
| 模型领域 | 语言 |
| 权重来源 | LiquidAI/LFM2-2.6B-Exp |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0+g8a1c299e5 |
| FlagGems版本 | 5.0.2 |
| Flagtree版本 | 0.6.1 |
| FlagCX版本 | - |
| 厂商 | nvidia |
| GPU | H20-3e : 8 x 140GB |
| 容器 | LFM2-2.6B-Exp_flagos |
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
    "cos",
    "div",
    "full",
    "gt",
    "lt",
    "ones",
    "rand_like",
    "randn",
    "reciprocal",
    "sin",
    "softmax",
    "sub",
    "vstack",
    "where",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：24
```json
[
    "add",
    "arange_start",
    "argmax",
    "cos",
    "exponential_",
    "full",
    "general_mm",
    "gt_scalar",
    "lt_scalar",
    "ones",
    "rand_like",
    "reciprocal",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "true_divide",
    "true_divide_",
    "vstack",
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
    "argmax",
    "cos",
    "div",
    "full",
    "gt",
    "lt",
    "ones",
    "rand_like",
    "randn",
    "reciprocal",
    "sin",
    "softmax",
    "sub",
    "vstack",
    "where",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：17
```json
[
    "add",
    "argmax",
    "cos",
    "div",
    "full",
    "gt",
    "lt",
    "ones",
    "rand_like",
    "randn",
    "reciprocal",
    "sin",
    "softmax",
    "sub",
    "vstack",
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
| GPQA_Diamond | 50 | 32.0 | 25 |

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
| V1 VS V2 | 精度偏差 12.0% |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | - |

## 性能评测

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| LiquidAI/LFM2-2.6B-Exp | Nvidia | 296 | 8 | 2368 | 4895.92 | 9049.83 | 4156.2 | 20780.88 | 10.33 | 0 | 8.775709 |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| LiquidAI/LFM2-2.6B-Exp | Nvidia | 296 | 8 | 2368 | 5730.0 | 10724.0 | 3560.9 | 17804.6 | 12.2 | 25 | 7.518834 |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| LiquidAI/LFM2-2.6B-Exp | Nvidia | 296 | 8 | 2368 | 5730.0 | 10724.0 | 3560.9 | 17804.6 | 12.2 | 25 | 7.518834 |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| LiquidAI/LFM2-2.6B-Exp | Nvidia | 296 | 8 | 2368 | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 85.7% |
| V1 VS V3 | 性能比 85.7% |
| V1 VS V4 | - |
| V2 VS V3 | 性能比 100.0% |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 3h 1m 17s |
| 流程消费 | 105.97 元（≈ $14.72 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/lfm2-2.6b-exp-nvidia003-gems5.0.2-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp312-pt211-cu130-x64-570.133.20:202607190147-v2
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/LFM2-2.6B-Exp-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/LFM2-2.6B-Exp-FlagOS

# 结论

- 发布镜像上传正常：❌ 未达标发布（精度不达标（rel_drop 超阈值））
- 流程自动化结论：❌ 迁移失败（精度不达标（rel_drop 超阈值））

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on nvidia (LiquidAI/LFM2-2.6B-Exp)
2. 【FR】Bug: Operator performance degradation on nvidia (LiquidAI/LFM2-2.6B-Exp)

---

报告生成时间：2026.07.22