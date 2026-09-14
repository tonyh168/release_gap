# 迁移结果：❌ 失败（精度评测未产出结果，V2/V3 数据不完整）

> **自动化流程产出镜像版本：**
> - V1：tree版本=基础版：只带flagtree不开启任何flagos组件
> - V2：tree+gems=Pro版：开启flaggems且性能达到V1的80%，与V1的精度误差在5%以内
> - V3：tree+gems+plugin=Max版：在V2的基础上安装使用plugin，且性能达到V1的80%，与V1的精度误差在5%以内
> - V4：tree+gems+plugin=Flag-express版：在V3的基础上，性能表现超过V1版本

# 基本信息

| 项目 | 内容 |
|------|------|
| 项目名称 | KT2期 |
| 开始时间 | 2026-09-03 11:11:14+08:00 |
| gems+tree版本上传时间 | - |
| 发布时间 | - |
| 模型 | Darwin-28B-Coder |
| 模型领域 | 语言 |
| 权重来源 | FINAL-Bench/Darwin-28B-Coder |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.24.0 |
| 推理框架插件plugin-FL | 0.3.0 |
| FlagGems版本 | 5.3.2 |
| Flagtree版本 | 0.6.0 |
| FlagCX版本 | - |
| 厂商 | 摩尔(Mthreads) |
| GPU | MTT S5000 : 4 x 80GB |
| 容器 | Darwin-28B-Coder_flagos |
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
    "_unsafe_view",
    "add",
    "argmax",
    "attention_backend",
    "broadcast_to",
    "cat",
    "copy",
    "cos",
    "cumsum",
    "div",
    "embedding",
    "expand",
    "exponential_",
    "fill",
    "full",
    "index",
    "le",
    "linear",
    "lt",
    "masked_fill",
    "mean",
    "mul",
    "narrow",
    "pow",
    "reciprocal",
    "resolve_neg",
    "rsqrt",
    "rsub",
    "scalar_tensor",
    "scatter",
    "sigmoid",
    "silu",
    "silu_and_mul",
    "sin",
    "softmax",
    "sub",
    "to",
    "unbind",
    "unsqueeze",
    "where"
]
```
### 算子替换列表（txt）
替换算子数：40
```json
[
    "_unsafe_view",
    "add",
    "argmax",
    "attention_backend",
    "broadcast_to",
    "cat",
    "copy",
    "cos",
    "cumsum",
    "div",
    "embedding",
    "expand",
    "exponential_",
    "fill",
    "full",
    "index",
    "le",
    "linear",
    "lt",
    "masked_fill",
    "mean",
    "mul",
    "narrow",
    "pow",
    "reciprocal",
    "resolve_neg",
    "rsqrt",
    "rsub",
    "scalar_tensor",
    "scatter",
    "sigmoid",
    "silu",
    "silu_and_mul",
    "sin",
    "softmax",
    "sub",
    "to",
    "unbind",
    "unsqueeze",
    "where"
]
```

## V3
### 算子白名单
（沿用 V2 结果）
```json
"include": [
    "_unsafe_view",
    "add",
    "argmax",
    "attention_backend",
    "broadcast_to",
    "cat",
    "copy",
    "cos",
    "cumsum",
    "div",
    "embedding",
    "expand",
    "exponential_",
    "fill",
    "full",
    "index",
    "le",
    "linear",
    "lt",
    "masked_fill",
    "mean",
    "mul",
    "narrow",
    "pow",
    "reciprocal",
    "resolve_neg",
    "rsqrt",
    "rsub",
    "scalar_tensor",
    "scatter",
    "sigmoid",
    "silu",
    "silu_and_mul",
    "sin",
    "softmax",
    "sub",
    "to",
    "unbind",
    "unsqueeze",
    "where"
]
```
### 算子替换列表（txt）
替换算子数：40（沿用 V2 结果）
```json
[
    "_unsafe_view",
    "add",
    "argmax",
    "attention_backend",
    "broadcast_to",
    "cat",
    "copy",
    "cos",
    "cumsum",
    "div",
    "embedding",
    "expand",
    "exponential_",
    "fill",
    "full",
    "index",
    "le",
    "linear",
    "lt",
    "masked_fill",
    "mean",
    "mul",
    "narrow",
    "pow",
    "reciprocal",
    "resolve_neg",
    "rsqrt",
    "rsub",
    "scalar_tensor",
    "scatter",
    "sigmoid",
    "silu",
    "silu_and_mul",
    "sin",
    "softmax",
    "sub",
    "to",
    "unbind",
    "unsqueeze",
    "where"
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

> 精度基线：V1=none（不开启 flaggems 无法起服务），精度基线回退 NV 参考值。**本次流程精度评测未产出有效结果数据**（V2/V3 精度评测缺失），故无法判定精度是否达标。

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - | - |
| math_500 | - | - | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | -（评测未产出结果） | 40 |
| math_500 | - | -（评测未产出结果） | 40 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | -（沿用 V2 结果，评测未产出） | 40 |
| math_500 | - | -（沿用 V2 结果，评测未产出） | 40 |

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - | - |
| math_500 | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | -（精度评测未产出结果） |
| V1 VS V3 | -（精度评测未产出结果） |
| V1 VS V4 | - |
| V2 VS V3 | 一致（V3 沿用 V2 结果） |

## 性能评测

> ⚠️ **性能基线为合成值，非实测 V1**：V2 初始性能 ×1.05（baseline_source: v2_initial_x1.05）。本报告所有以 V1 为基准的性能比均基于该合成基线。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| FINAL-Bench/Darwin-28B-Coder | Mthreads | - | 4 | - | 1879857.62 | 2941921.33 | 17.54 | 87.78 | 832.67 | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| FINAL-Bench/Darwin-28B-Coder | Mthreads | - | 4 | - | 1887112.1 | 2855907.1 | 17.3 | 86.5 | 863.6 | 40 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| FINAL-Bench/Darwin-28B-Coder | Mthreads | - | 4 | - | 1887112.1 | 2855907.1 | 17.3 | 86.5 | 863.6 | 40 | - |

> V3 性能沿用 V2 结果（V3 算子集与 V2 一致）。

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| FINAL-Bench/Darwin-28B-Coder | Mthreads | - | 4 | - | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 98.5%（vs 合成基线） |
| V1 VS V3 | 性能比 98.5%（沿用 V2 结果） |
| V1 VS V4 | - |
| V2 VS V3 | 一致（V3 沿用 V2 结果） |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 23h 12m 25s |
| 流程消费 | 659.10 元（≈ $91.54 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：-（失败模型，未对外发布）
  - V3：-（失败模型，未对外发布）
  - V4：-

- ModelScope: -（未对外发布：精度评测未产出结果，V2/V3 数据不完整）
- HuggingFace: -（未对外发布：精度评测未产出结果，V2/V3 数据不完整）

# 结论

- 发布镜像上传正常：❌ 未对外发布（精度评测未产出结果，V2/V3 数据不完整，不满足对外发布门控）
- 流程自动化结论：❌ 迁移失败（V2/V3 精度评测缺失有效结果，数据不完整无法达标判定；性能实测 V2/合成基线 98.5%，仅供参考）

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 摩尔(Mthreads) (FINAL-Bench/Darwin-28B-Coder)
2. 【FR】Bug: Operator performance degradation on 摩尔(Mthreads) (FINAL-Bench/Darwin-28B-Coder)

---

报告生成时间：2026.09.09
