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
| 开始时间 | 2026-07-29 19:33:19 |
| gems+tree版本上传时间 | 2026-07-29 23:04:51 |
| 发布时间 | 2026-07-30 08:27:00 |
| 模型 | Phi-3-medium-128k-instruct |
| 模型领域 | 语言 |
| 权重来源 | microsoft/Phi-3-medium-128k-instruct |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0+gffa2ee3eb |
| FlagGems版本 | 5.4.0dev |
| Flagtree版本 | 0.6.1 |
| FlagCX版本 | - |
| 厂商 | 海光(Hygon) |
| GPU | DCU BW1000 : 8 x -GB |
| 容器 | Phi-3-medium-128k-instruct_flagos |
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
    "copy_",
    "cos",
    "expand",
    "full",
    "index",
    "linear",
    "lt_scalar",
    "mm_out",
    "ones",
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
### 算子替换列表（txt）
替换算子数：26
```json
[
    "add",
    "arange_start",
    "argmax",
    "copy_",
    "cos",
    "expand",
    "full",
    "index",
    "linear",
    "lt_scalar",
    "mm_out",
    "ones",
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
    "add",
    "arange_start",
    "argmax",
    "copy_",
    "cos",
    "expand",
    "full",
    "index",
    "linear",
    "lt_scalar",
    "mm_out",
    "ones",
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
### 算子替换列表（txt）
替换算子数：26
```json
[
    "add",
    "arange_start",
    "argmax",
    "copy_",
    "cos",
    "expand",
    "full",
    "index",
    "linear",
    "lt_scalar",
    "mm_out",
    "ones",
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
| GPQA_Diamond | 50 | 28.0 | 27 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 28.0 | 27 |

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
| V2 VS V3 | 精度偏差 0.0%（V3 28.0% vs V2 28.0%；NV 基线 37.0%，rel_drop=24.32% 超 5% 阈值，未达标；三级递进全关算子仍 28.0%，定位为框架/模型级问题，非算子可归因） |

## 性能评测

> ⚠️ **性能基线为合成值，非实测 V1**：V2 初始性能 ×1.2（baseline_source: v2_initial_x1.2）。本报告所有以 V1 为基准的性能比均基于该合成基线。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| microsoft/Phi-3-medium-128k-instruct | Hygon | - | 8 | - | 60873.5 | 138433.08 | 332.4 | 1661.76 | 91.92 | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| microsoft/Phi-3-medium-128k-instruct | Hygon | - | 8 | - | 73048.2 | - | 274.7 | 1373.4 | 110.3 | 27 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| microsoft/Phi-3-medium-128k-instruct | Hygon | - | 8 | - | 73022.5 | - | 274.7 | 1373.4 | 110.3 | 27 | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| microsoft/Phi-3-medium-128k-instruct | Hygon | - | 8 | - | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 82.6%（V2 274.7 tok/s vs 合成基线 332.4；≥80% 达标） |
| V1 VS V3 | 性能比 82.6%（V3 274.7 tok/s vs 合成基线 332.4；≥80% 达标，但精度未达标，V3 走"不达标发布"路径） |
| V1 VS V4 | - |
| V2 VS V3 | - |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 4h 54m 25s |
| 流程消费 | 233.86 元（≈ $32.48 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/phi-3-medium-128k-instruct-hygon001-gems5.4.0-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp310-pt210-dtknone-x64-none:202607300703-v2
  - V3：harbor.baai.ac.cn/flagrelease-project/phi-3-medium-128k-instruct-hygon001-gems5.4.0-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp310-pt210-dtknone-x64-none:202607300827-v3（tag 日志无法证实，以镜像仓库为准）
  - V4：-

- ModelScope: -（V2/V3 精度均不达标（框架级），仅 Harbor 私有镜像，不对外发布）
- HuggingFace: -（V2/V3 精度均不达标（框架级），仅 Harbor 私有镜像，不对外发布）

# 结论

- 发布镜像上传正常：❌ 未达标发布（精度不达标（rel_drop 超阈值））
- 流程自动化结论：❌ 迁移失败（精度不达标（rel_drop 超阈值））

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on hygon (microsoft/Phi-3-medium-128k-instruct)
2. 【FR】Bug: vllm-plugin-FL error on hygon (microsoft/Phi-3-medium-128k-instruct)

---

报告生成时间：2026.08.05