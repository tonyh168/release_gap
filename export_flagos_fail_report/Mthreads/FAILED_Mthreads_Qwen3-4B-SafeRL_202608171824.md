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
| 开始时间 | 2026-08-17 07:25:00 |
| gems+tree版本上传时间 | 2026-08-17 10:22:24 |
| 发布时间 | 2026-08-17 10:22:56 |
| 模型 | Qwen3-4B-SafeRL |
| 模型领域 | 语言 |
| 权重来源 | Qwen/Qwen3-4B-SafeRL |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0+g8a1c299e5 |
| FlagGems版本 | 5.3.0rc2 |
| Flagtree版本 |  |
| FlagCX版本 | - |
| 厂商 | 摩尔(Mthreads) |
| GPU | MTT S5000 : 8 x -GB |
| 容器 | Qwen3-4B-SafeRL_flagos |
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
    "index",
    "le",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "pow_scalar",
    "reciprocal",
    "rms_norm_forward",
    "rsub_scalar",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
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
    "index",
    "le",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "pow_scalar",
    "reciprocal",
    "rms_norm_forward",
    "rsub_scalar",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
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
    "index",
    "le",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "pow_scalar",
    "reciprocal",
    "rms_norm_forward",
    "rsub_scalar",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
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
    "index",
    "le",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "pow_scalar",
    "reciprocal",
    "rms_norm_forward",
    "rsub_scalar",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out"
]
```

## V4
### 算子白名单
（无数据）
### 算子替换列表（txt）
替换算子数：0
（无数据）

# 评测结果

> **说明（数据补充于 2026-08-20）**：本次流程在步骤6（性能评测，V2 初始性能基线合成阶段）崩溃中断，根因为 `AttributeError: module 'torch' has no attribute 'float4_e2m1fn_x2'`（见 `logs/failure_diagnosis.txt`）。崩溃发生在步骤4（精度评测）实际开跑之前，故精度评测从未产出实测数据；性能仅在合成基线时测得一次 V2 初始吞吐（4k-1k 64并发：output 133.2 tok/s、total 665.9 tok/s、Mean TTFT 2481.7ms、P99 TTFT 2857.3ms、Mean TPOT 478.3ms，见 `scripts/output/v2_initial_performance.json`），但未完成 V1/V2 对比判定。报告首行"精度不达标/性能不达标"为流程未跑完时的默认占位判定，并非真实评测结论。容器工作区中不存在 `accuracy_compare_*.json` 可供恢复。

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

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Qwen/Qwen3-4B-SafeRL | Mthreads | - | 8 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Qwen/Qwen3-4B-SafeRL | Mthreads | - | 8 | - | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Qwen/Qwen3-4B-SafeRL | Mthreads | - | 8 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Qwen/Qwen3-4B-SafeRL | Mthreads | - | 8 | - | - | - | - | - | - | - | - |

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
| 流程耗时 | 2h 57m 56s |
| 流程消费 | 137.85 元（≈ $19.15 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：-
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/Qwen3-4B-SafeRL-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Qwen3-4B-SafeRL-FlagOS

# 结论

- 发布镜像上传正常：❌ 未达标发布（精度不达标（rel_drop 超阈值）、性能不达标）
- 流程自动化结论：❌ 迁移失败（精度不达标（rel_drop 超阈值）、性能不达标）

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 摩尔(Mthreads) (Qwen/Qwen3-4B-SafeRL)
2. 【FR】Bug: Operator performance degradation on 摩尔(Mthreads) (Qwen/Qwen3-4B-SafeRL)

---

报告生成时间：2026.08.17