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
| 开始时间 | 2026-09-04 02:30:45 |
| gems+tree版本上传时间 | 2026-09-04 10:44:06 |
| 发布时间 | 2026-09-04 10:46:28 |
| 模型 | iFlow-ROME |
| 模型领域 | 语言 |
| 权重来源 | FutureLivingLab/iFlow-ROME |
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
| 容器 | iFlow-ROME_flagos |
| release自动化工具版本 | v0.1.0 |

# 算子替换列表

> 说明：运行时 dispatch 日志共 57 条记录，其中 vllm_fl.dispatch 与 flag_gems 实现对同一逻辑算子存在重复登记；下表按逻辑算子去重后为 47 个。

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
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "embedding",
    "expand",
    "exponential_",
    "fill_scalar_",
    "full",
    "fused_add_rms_norm",
    "index",
    "invoke_fused_moe_triton_kernel",
    "le",
    "linear",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "moe_align_block_size",
    "moe_sum",
    "mul",
    "narrow",
    "pow_scalar",
    "reciprocal",
    "rms_norm",
    "rms_norm_forward",
    "rotary_embedding",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "silu_and_mul",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "topk_softmax",
    "true_divide",
    "true_divide_",
    "unbind",
    "unsqueeze",
    "where_self",
    "where_self_out"
]
```
### 算子替换列表（txt）
替换算子数：47
```json
[
    "_unsafe_view",
    "add",
    "argmax",
    "attention_backend",
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
    "fused_add_rms_norm",
    "index",
    "invoke_fused_moe_triton_kernel",
    "le",
    "linear",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "moe_align_block_size",
    "moe_sum",
    "mul",
    "narrow",
    "pow_scalar",
    "reciprocal",
    "rms_norm",
    "rms_norm_forward",
    "rotary_embedding",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "silu_and_mul",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "topk_softmax",
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
（沿用 V2 结果）
```json
"include": [
    "_unsafe_view",
    "add",
    "argmax",
    "attention_backend",
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
    "fused_add_rms_norm",
    "index",
    "invoke_fused_moe_triton_kernel",
    "le",
    "linear",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "moe_align_block_size",
    "moe_sum",
    "mul",
    "narrow",
    "pow_scalar",
    "reciprocal",
    "rms_norm",
    "rms_norm_forward",
    "rotary_embedding",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "silu_and_mul",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "topk_softmax",
    "true_divide",
    "true_divide_",
    "unbind",
    "unsqueeze",
    "where_self",
    "where_self_out"
]
```
### 算子替换列表（txt）
替换算子数：47（沿用 V2 结果）
```json
[
    "_unsafe_view",
    "add",
    "argmax",
    "attention_backend",
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
    "fused_add_rms_norm",
    "index",
    "invoke_fused_moe_triton_kernel",
    "le",
    "linear",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "moe_align_block_size",
    "moe_sum",
    "mul",
    "narrow",
    "pow_scalar",
    "reciprocal",
    "rms_norm",
    "rms_norm_forward",
    "rotary_embedding",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "silu_and_mul",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "topk_softmax",
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
| mmlu | - | -（评测未产出结果） | 47 |
| math_500 | - | -（评测未产出结果） | 47 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | -（沿用 V2 结果，评测未产出） | 47 |
| math_500 | - | -（沿用 V2 结果，评测未产出） | 47 |

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

> 说明：V1 无实测基线（不开启 flaggems 无法起服务），亦无合成基线；下表 V2 为使能 FlagGems 后的实测值（v2_initial），无 V1 参照故不计算性能比。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| FutureLivingLab/iFlow-ROME | Mthreads | - | 4 | - | - | - | - | - | - | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| FutureLivingLab/iFlow-ROME | Mthreads | - | 4 | - | 12704.4 | 17126.0 | 264.8 | 1323.8 | 225.8 | 47 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| FutureLivingLab/iFlow-ROME | Mthreads | - | 4 | - | 12704.4 | 17126.0 | 264.8 | 1323.8 | 225.8 | 47 | - |

> V3 性能沿用 V2 结果（V3 算子集与 V2 一致）。

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| FutureLivingLab/iFlow-ROME | Mthreads | - | 4 | - | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | -（V1 无基线） |
| V1 VS V3 | -（V1 无基线） |
| V1 VS V4 | - |
| V2 VS V3 | 一致（V3 沿用 V2 结果） |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 8h 15m 43s |
| 流程消费 | 538.47 元（≈ $74.79 × 7.2） |

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
- 流程自动化结论：❌ 迁移失败（V2/V3 精度评测缺失有效结果，数据不完整无法达标判定；V1 无基线，性能仅有 V2 实测值供参考）

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 摩尔(Mthreads) (FutureLivingLab/iFlow-ROME)
2. 【FR】Bug: Operator performance degradation on 摩尔(Mthreads) (FutureLivingLab/iFlow-ROME)

---

报告生成时间：2026.09.09
