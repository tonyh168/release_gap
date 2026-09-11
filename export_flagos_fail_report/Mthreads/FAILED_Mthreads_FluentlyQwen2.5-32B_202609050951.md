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
| 开始时间 | 2026-09-04 17:25:36 |
| gems+tree版本上传时间 | 2026-09-05 01:45:40 |
| 发布时间 | 2026-09-05 01:46:45 |
| 模型 | FluentlyQwen2.5-32B |
| 模型领域 | 语言 |
| 权重来源 | fluently/FluentlyQwen2.5-32B |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.24.0 |
| 推理框架插件plugin-FL | 0.3.0 |
| FlagGems版本 | 5.3.2 |
| Flagtree版本 | 0.6.0 |
| FlagCX版本 | - |
| 厂商 | 摩尔(Mthreads) |
| GPU | MTT S5000 : 2 x 80GB |
| 容器 | FluentlyQwen2.5-32B_flagos |
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
    "broadcast_to",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "embedding",
    "expand",
    "exponential_",
    "fill_scalar_",
    "full",
    "index",
    "le",
    "linear",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "narrow",
    "pow_scalar",
    "reciprocal",
    "rms_norm_forward",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "unbind",
    "unsqueeze",
    "where_self",
    "where_self_out"
]
```
### 算子替换列表（txt）
替换算子数：39
```json
[
    "_unsafe_view",
    "add",
    "argmax",
    "broadcast_to",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "embedding",
    "expand",
    "exponential_",
    "fill_scalar_",
    "full",
    "index",
    "le",
    "linear",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "narrow",
    "pow_scalar",
    "reciprocal",
    "rms_norm_forward",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "unbind",
    "unsqueeze",
    "where_self",
    "where_self_out"
]
```

## V3
### 算子白名单
```json
"include": [
    "_unsafe_view",
    "add",
    "argmax",
    "broadcast_to",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "embedding",
    "expand",
    "exponential_",
    "fill_scalar_",
    "full",
    "index",
    "le",
    "linear",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "narrow",
    "pow_scalar",
    "reciprocal",
    "rms_norm_forward",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "unbind",
    "unsqueeze",
    "where_self",
    "where_self_out"
]
```
### 算子替换列表（txt）
替换算子数：39
```json
[
    "_unsafe_view",
    "add",
    "argmax",
    "broadcast_to",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "embedding",
    "expand",
    "exponential_",
    "fill_scalar_",
    "full",
    "index",
    "le",
    "linear",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "narrow",
    "pow_scalar",
    "reciprocal",
    "rms_norm_forward",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "unbind",
    "unsqueeze",
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

## 精度评测

> 精度基线：V1 = none（分支 B v1.3），以 NV 参考值为基线。
> 评测未完成：服务启动失败，精度/性能数据均无实测结果。

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - | - |
| math_500 | - | - | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - | - |
| math_500 | - | - | - |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - | - |
| math_500 | - | - | - |

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - | - |
| math_500 | - | - | - |

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
| fluently/FluentlyQwen2.5-32B | Mthreads | - | 2 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| fluently/FluentlyQwen2.5-32B | Mthreads | - | 2 | - | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| fluently/FluentlyQwen2.5-32B | Mthreads | - | 2 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| fluently/FluentlyQwen2.5-32B | Mthreads | - | 2 | - | - | - | - | - | - | - | - |

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
| 流程耗时 | 8h 21m 9s |
| 流程消费 | 168.01 元（≈ $23.33 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/fluentlyqwen2.5-32b-mthreads001-gems5.3.2-tree0.6.0-cxnone-plugin0.3.0-vllm0.24.0-cp310-pt29-musa43-x64-3.3.5-server:202609050940-v2
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/FluentlyQwen2.5-32B-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/FluentlyQwen2.5-32B-FlagOS

# 结论

- 发布镜像上传正常：❌ Harbor 私有发布（V2 镜像已上传，精度/性能数据缺失，未发布 ModelScope/HuggingFace）
- 流程自动化结论：❌ FlagGems mmlu 生成失控（runaway），精度无法评测，标记为待人工介入

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 摩尔(Mthreads) (fluently/FluentlyQwen2.5-32B)
2. 【FR】Bug: Operator performance degradation on 摩尔(Mthreads) (fluently/FluentlyQwen2.5-32B)

---

报告生成时间：2026.09.05