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
| 开始时间 | 2026-07-25 10:45:00 |
| gems+tree版本上传时间 | 2026-07-25 12:44:21 |
| 发布时间 | 2026-07-25 13:50:04 |
| 模型 | Apertus-8B-Instruct-2509 |
| 模型领域 | 语言 |
| 权重来源 | swiss-ai/Apertus-8B-Instruct-2509 |
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
| 容器 | Apertus-8B-Instruct-2509_flagos_0725_1839 |
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
    "exp",
    "expand",
    "full",
    "gt_scalar",
    "index",
    "linear",
    "log",
    "lt_scalar",
    "mm_out",
    "ones",
    "rand_like",
    "randn",
    "reciprocal",
    "rsub_scalar",
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
替换算子数：30
```json
[
    "add",
    "arange_start",
    "argmax",
    "copy_",
    "cos",
    "exp",
    "expand",
    "full",
    "gt_scalar",
    "index",
    "linear",
    "log",
    "lt_scalar",
    "mm_out",
    "ones",
    "rand_like",
    "randn",
    "reciprocal",
    "rsub_scalar",
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
    "exp",
    "expand",
    "full",
    "gt_scalar",
    "index",
    "linear",
    "log",
    "lt_scalar",
    "mm_out",
    "ones",
    "rand_like",
    "randn",
    "reciprocal",
    "rsub_scalar",
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
替换算子数：30
```json
[
    "add",
    "arange_start",
    "argmax",
    "copy_",
    "cos",
    "exp",
    "expand",
    "full",
    "gt_scalar",
    "index",
    "linear",
    "log",
    "lt_scalar",
    "mm_out",
    "ones",
    "rand_like",
    "randn",
    "reciprocal",
    "rsub_scalar",
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
| GPQA_Diamond | 50 | 34.0 | 31 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 32.0 | 30 |

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
| V2 VS V3 | 精度偏差 2.0% |

## 性能评测

> ⚠️ **性能基线为合成值，非实测 V1**：V2 初始性能 ×1.2（baseline_source: v2_initial_x1.2）。本报告所有以 V1 为基准的性能比均基于该合成基线。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| swiss-ai/Apertus-8B-Instruct-2509 | Hygon | - | 8 | - | - | - | 968.28 | 4841.4 | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| swiss-ai/Apertus-8B-Instruct-2509 | Hygon | - | 8 | - | 874.9 | 1447.2 | 867.4 | 4337.2 | 72.7 | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| swiss-ai/Apertus-8B-Instruct-2509 | Hygon | - | 8 | - | 3845.8 | 4094.2 | 839.8 | 4198.9 | 72.5 | 30 | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| swiss-ai/Apertus-8B-Instruct-2509 | Hygon | - | 8 | - | - | - | - | - | - | - | - |

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
| 流程耗时 | 3h 5m 4s |
| 流程消费 | 356.59 元（≈ $49.53 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/apertus-8b-instruct-2509-hygon001-gems5.4.0-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp310-pt210-dtknone-x64-6.3.30-v1.4.1a:202607252013-v2
  - V3：harbor.baai.ac.cn/flagrelease-project/apertus-8b-instruct-2509-flagos-hygon-incompatible
  - V4：-

- ModelScope: https://www.modelscope.cn/models/FlagRelease/Apertus-8B-Instruct-2509-hygon-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Apertus-8B-Instruct-2509-hygon-FlagOS

# 结论

- 发布镜像上传正常：⚠️ 部分产出（V3 已产出，但未达标：Plugin/框架不适配（主流程达标，未产出达标 Max 版））
- 流程自动化结论：❌ 迁移失败（Plugin/框架不适配（主流程达标，未产出达标 Max 版））

## 提交到 flagos 仓库的 Issue
issue 数量：1
issue 标题：
1. 【FR】Bug: vllm-plugin-FL error on hygon (swiss-ai/Apertus-8B-Instruct-2509)

---

报告生成时间：2026.08.06