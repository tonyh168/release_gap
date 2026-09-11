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
| 开始时间 | 2026-08-06 15:28:00 |
| gems+tree版本上传时间 | 2026-08-06 19:53:50 |
| 发布时间 | 2026-08-06 20:38:15.212859Z |
| 模型 | gpt-oss-20b |
| 模型领域 | 语言 |
| 权重来源 | openai/gpt-oss-20b |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0rc2.post1 |
| FlagGems版本 | 5.0.2 |
| Flagtree版本 | 0.6.1 |
| FlagCX版本 | - |
| 厂商 | 英伟达(Nvidia) |
| GPU | H20-3e : 8 x 140GB |
| 容器 | gpt-oss-20b_flagos |
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
    "bitwise_and",
    "bitwise_or",
    "clamp",
    "cos",
    "cumsum",
    "div",
    "eq",
    "exponential_",
    "full",
    "le",
    "lt",
    "ne",
    "ones",
    "pad",
    "rand_like",
    "reciprocal",
    "rsub",
    "scatter",
    "sin",
    "softmax",
    "sort",
    "sub",
    "where",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：32
```json
[
    "add",
    "addmm_out",
    "arange_start",
    "argmax",
    "bitwise_and_scalar",
    "bitwise_or_tensor",
    "clamp",
    "cos",
    "div_mode",
    "eq_scalar",
    "exponential_",
    "full",
    "general_mm",
    "lt_scalar",
    "ne_scalar",
    "ones",
    "pad",
    "rand_like",
    "randn",
    "reciprocal",
    "rsub_scalar",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "true_divide",
    "true_divide_",
    "trunc_divide",
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
    "bitwise_and",
    "bitwise_or",
    "clamp",
    "cos",
    "cumsum",
    "div",
    "eq",
    "exponential_",
    "full",
    "le",
    "lt",
    "ne",
    "ones",
    "pad",
    "rand_like",
    "reciprocal",
    "rsub",
    "scatter",
    "sin",
    "softmax",
    "sort",
    "sub",
    "where",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：24
```json
[
    "bitwise_and",
    "bitwise_or",
    "clamp",
    "cos",
    "cumsum",
    "div",
    "eq",
    "exponential_",
    "full",
    "le",
    "lt",
    "ne",
    "ones",
    "pad",
    "rand_like",
    "reciprocal",
    "rsub",
    "scatter",
    "sin",
    "softmax",
    "sort",
    "sub",
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
| GPQA_Diamond | 50 | 72.0 | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 70.0 | 33 |

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
| V1 VS V2 | 精度偏差 2.0% |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | - |

## 性能评测

> ⚠️ **性能基线为合成值，非实测 V1**：V2 初始性能 ×1.05（baseline_source: v2_initial_x1.05）。本报告所有以 V1 为基准的性能比均基于该合成基线。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| openai/gpt-oss-20b | 英伟达(Nvidia) | 296 | 8 | 2368 | 0.0 | 0.0 | 3736.01 | 18679.81 | 0.0 | 0 | 7.888433 |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| openai/gpt-oss-20b | 英伟达(Nvidia) | 296 | 8 | 2368 | 0.0 | 0.0 | 3576.8 | 17884.2 | 0.0 | 33 | 7.552449 |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| openai/gpt-oss-20b | 英伟达(Nvidia) | 296 | 8 | 2368 | 0.0 | 0.0 | 3788.8 | 18944.0 | 0.0 | 33 | 8.000000 |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| openai/gpt-oss-20b | 英伟达(Nvidia) | 296 | 8 | 2368 | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 95.7% |
| V1 VS V3 | 性能比 101.4% |
| V1 VS V4 | - |
| V2 VS V3 | 性能比 105.9% |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 5h 10m 15s |
| 流程消费 | 1052.00 元（≈ $146.11 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/gpt-oss-20b-nvidia003-gems5.0.2-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp312-pt211-cu130-x64-570.158.01:202608070346-v2
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/gpt-oss-20b-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/gpt-oss-20b-nvidia-FlagOS

# 结论

- 发布镜像上传正常：❌ 未达标发布（性能不达标）
- 流程自动化结论：❌ 迁移失败（性能不达标）

## 提交到 flagos 仓库的 Issue
issue 数量：3
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 英伟达(Nvidia) (openai/gpt-oss-20b)
2. 【FR】Bug: Operator performance degradation on 英伟达(Nvidia) (openai/gpt-oss-20b)
3. 【FR】Bug: vllm-plugin-FL error on 英伟达(Nvidia) (openai/gpt-oss-20b)

---

报告生成时间：2026.08.13