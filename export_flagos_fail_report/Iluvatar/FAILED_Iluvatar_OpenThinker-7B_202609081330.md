# 迁移结果：❌ 失败（精度/性能评测未完成）

> **自动化流程产出镜像版本：**
> - V1：tree版本=基础版：只带flagtree不开启任何flagos组件
> - V2：tree+gems=Pro版：开启flaggems且性能达到V1的80%，与V1的精度误差在5%以内
> - V3：tree+gems+plugin=Max版：在V2的基础上安装使用plugin，且性能达到V1的80%，与V1的精度误差在5%以内
> - V4：tree+gems+plugin=Flag-express版：在V3的基础上，性能表现超过V1版本

# 基本信息

| 项目 | 内容 |
|------|------|
| 项目名称 | KT2期 |
| 开始时间 | 2026-09-03 21:04:42 |
| gems+tree版本上传时间 | 2026-09-04 05:33:13 |
| 发布时间 | 2026-09-04 13:30:00 |
| 模型 | OpenThinker-7B |
| 模型领域 | 语言 |
| 权重来源 | open-thoughts/OpenThinker-7B |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.24.0 |
| 推理框架插件plugin-FL | 0.3.0 |
| FlagGems版本 | 5.3.4 |
| Flagtree版本 | 0.6.0 |
| FlagCX版本 | - |
| 厂商 | 天数(Iluvatar) |
| GPU | BI-V150 : 1 x 32GB |
| 容器 | OpenThinker-7B_flagos |
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
    "_reshape_alias",
    "add",
    "alias",
    "arange_start",
    "argmax",
    "bitwise_or_tensor",
    "cat",
    "chunk",
    "copy_",
    "cos",
    "cumsum_out",
    "embedding",
    "empty",
    "eq_scalar",
    "expand",
    "exponential_",
    "fill_scalar_",
    "flatten",
    "full",
    "gather",
    "gt_scalar",
    "index",
    "le",
    "lift_fresh",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "mul_",
    "narrow",
    "ones",
    "ones_like",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "rms_norm_forward",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "scatter_add_0",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "sub_",
    "to_copy",
    "true_divide",
    "true_divide_",
    "unbind",
    "unsqueeze",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：54
```json
[
    "_reshape_alias",
    "add",
    "alias",
    "arange_start",
    "argmax",
    "bitwise_or_tensor",
    "cat",
    "chunk",
    "copy_",
    "cos",
    "cumsum_out",
    "embedding",
    "empty",
    "eq_scalar",
    "expand",
    "exponential_",
    "fill_scalar_",
    "flatten",
    "full",
    "gather",
    "gt_scalar",
    "index",
    "le",
    "lift_fresh",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "mul_",
    "narrow",
    "ones",
    "ones_like",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "rms_norm_forward",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "scatter_add_0",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "sub_",
    "to_copy",
    "true_divide",
    "true_divide_",
    "unbind",
    "unsqueeze",
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
    "_reshape_alias",
    "add",
    "alias",
    "arange_start",
    "argmax",
    "bitwise_or_tensor",
    "cat",
    "chunk",
    "copy_",
    "cos",
    "cumsum_out",
    "embedding",
    "empty",
    "eq_scalar",
    "expand",
    "exponential_",
    "fill_scalar_",
    "flatten",
    "full",
    "gather",
    "gt_scalar",
    "index",
    "le",
    "lift_fresh",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "mul_",
    "narrow",
    "ones",
    "ones_like",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "rms_norm_forward",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "scatter_add_0",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "sub_",
    "to_copy",
    "true_divide",
    "true_divide_",
    "unbind",
    "unsqueeze",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：54
```json
[
    "_reshape_alias",
    "add",
    "alias",
    "arange_start",
    "argmax",
    "bitwise_or_tensor",
    "cat",
    "chunk",
    "copy_",
    "cos",
    "cumsum_out",
    "embedding",
    "empty",
    "eq_scalar",
    "expand",
    "exponential_",
    "fill_scalar_",
    "flatten",
    "full",
    "gather",
    "gt_scalar",
    "index",
    "le",
    "lift_fresh",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "mul_",
    "narrow",
    "ones",
    "ones_like",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "rms_norm_forward",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "scatter_add_0",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "sub_",
    "to_copy",
    "true_divide",
    "true_divide_",
    "unbind",
    "unsqueeze",
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

> 服务启动成功（flagos，65 算子，TP=1）。精度评测（步骤4）运行至 V2 mmlu 145/1140 时流程中断（workflow_complete=false），未产出完整分值；后续精度调优/性能评测未执行。accuracy_ok=false、performance_ok=false，release.qualified=false。

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - (评测未完成) | 0 |
| math_500 | - | - (评测未完成) | 0 |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - (评测中断，145/1140 未完成) | 65 |
| math_500 | - | - (评测未完成) | 65 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - (沿用 V2，评测未完成) | 65 |
| math_500 | - | - (沿用 V2，评测未完成) | 65 |

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - (未产出) | - |
| math_500 | - | - (未产出) | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 评测中断（145/1140），无有效数据 |
| V1 VS V3 | 评测未完成（V3 沿用 V2） |
| V1 VS V4 | 未产出 |
| V2 VS V3 | 一致（同镜像双 tag） |

## 性能评测

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| open-thoughts/OpenThinker-7B | Iluvatar | - | 1 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| open-thoughts/OpenThinker-7B | Iluvatar | - | 1 | - | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| open-thoughts/OpenThinker-7B | Iluvatar | - | 1 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| open-thoughts/OpenThinker-7B | Iluvatar | - | 1 | - | - | - | - | - | - | - | - |

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
| 流程耗时 | 8h 30m 53s |
| 流程消费 | 428.05 元（≈ $59.45 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/openthinker-7b-iluvatar001-gems5.3.4-tree0.6.0-cxnone-plugin0.3.0-vllm0.24.0-cp312-pt210-ixml44-x64-4.5.0:202609041330-v2
  - V3：harbor.baai.ac.cn/flagrelease-project/openthinker-7b-iluvatar001-gems5.3.4-tree0.6.0-cxnone-plugin0.3.0-vllm0.24.0-cp312-pt210-ixml44-x64-4.5.0:202609041330-v3
  - V4：-

- ModelScope: -（qualified=false，不对外发布）
- HuggingFace: -（qualified=false，不对外发布）

# 结论

- 发布镜像上传正常：❌ 未达发布门槛（release.qualified=false）——服务可启动（flagos 65 算子 TP=1），但精度评测运行至 mmlu 145/1140 时中断、性能评测未执行；镜像已 Harbor 私有留档（-v2/-v3 双 tag），不对外传权重
- 流程自动化结论：❌ 迁移失败（精度/性能评测未完成，workflow_complete=false，release.qualified=false）

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 天数(Iluvatar) (open-thoughts/OpenThinker-7B)
2. 【FR】Bug: Operator performance degradation on 天数(Iluvatar) (open-thoughts/OpenThinker-7B)

---

报告生成时间：2026.09.08