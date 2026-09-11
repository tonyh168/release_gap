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
| 开始时间 | 2026-09-03 09:17:50+08:00 |
| gems+tree版本上传时间 | 2026-09-03 04:14:21 |
| 发布时间 | 2026-09-03 04:15:25 |
| 模型 | Apodex-1.0-4B-SFT |
| 模型领域 | 语言 |
| 权重来源 | apodex/Apodex-1.0-4B-SFT |
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
| 容器 | Apodex-1.0-4B-SFT_flagos |
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
    "_has_compatible_shallow_copy_type",
    "_reshape_alias",
    "_scaled_dot_product_flash_attention",
    "_unsafe_view",
    "add",
    "alias",
    "arange_start",
    "argmax",
    "bitwise_not",
    "broadcast_to",
    "cat",
    "chunk",
    "copy_",
    "cos",
    "cumsum",
    "embedding",
    "empty",
    "expand",
    "expand_as",
    "exponential_",
    "fill_scalar_",
    "flash_attention_forward",
    "flatten",
    "floor_divide",
    "full",
    "gelu",
    "gt_scalar",
    "index",
    "index_put_",
    "layer_norm",
    "lift_fresh",
    "lt_scalar",
    "mean_dim",
    "mean_dim_comm",
    "mul",
    "narrow",
    "native_layer_norm",
    "nonzero",
    "nonzero_numpy",
    "normal_",
    "ones",
    "pow_scalar",
    "pow_tensor_scalar",
    "rand_like",
    "randn",
    "reciprocal",
    "resolve_conj",
    "resolve_neg",
    "rsqrt",
    "scalar_tensor",
    "sigmoid",
    "silu",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "transpose",
    "true_divide",
    "true_divide_",
    "unbind",
    "unfold",
    "unsqueeze",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros",
    "zeros_like"
]
```
### 算子替换列表（txt）
替换算子数：68
```json
[
    "_has_compatible_shallow_copy_type",
    "_reshape_alias",
    "_scaled_dot_product_flash_attention",
    "_unsafe_view",
    "add",
    "alias",
    "arange_start",
    "argmax",
    "bitwise_not",
    "broadcast_to",
    "cat",
    "chunk",
    "copy_",
    "cos",
    "cumsum",
    "embedding",
    "empty",
    "expand",
    "expand_as",
    "exponential_",
    "fill_scalar_",
    "flash_attention_forward",
    "flatten",
    "floor_divide",
    "full",
    "gelu",
    "gt_scalar",
    "index",
    "index_put_",
    "layer_norm",
    "lift_fresh",
    "lt_scalar",
    "mean_dim",
    "mean_dim_comm",
    "mul",
    "narrow",
    "native_layer_norm",
    "nonzero",
    "nonzero_numpy",
    "normal_",
    "ones",
    "pow_scalar",
    "pow_tensor_scalar",
    "rand_like",
    "randn",
    "reciprocal",
    "resolve_conj",
    "resolve_neg",
    "rsqrt",
    "scalar_tensor",
    "sigmoid",
    "silu",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "transpose",
    "true_divide",
    "true_divide_",
    "unbind",
    "unfold",
    "unsqueeze",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros",
    "zeros_like"
]
```

## V3
### 算子白名单
```json
"include": [
    "_has_compatible_shallow_copy_type",
    "_reshape_alias",
    "_scaled_dot_product_flash_attention",
    "_unsafe_view",
    "add",
    "alias",
    "arange_start",
    "argmax",
    "bitwise_not",
    "broadcast_to",
    "cat",
    "chunk",
    "copy_",
    "cos",
    "cumsum",
    "embedding",
    "empty",
    "expand",
    "expand_as",
    "exponential_",
    "fill_scalar_",
    "flash_attention_forward",
    "flatten",
    "floor_divide",
    "full",
    "gelu",
    "gt_scalar",
    "index",
    "index_put_",
    "layer_norm",
    "lift_fresh",
    "lt_scalar",
    "mean_dim",
    "mean_dim_comm",
    "mul",
    "narrow",
    "native_layer_norm",
    "nonzero",
    "nonzero_numpy",
    "normal_",
    "ones",
    "pow_scalar",
    "pow_tensor_scalar",
    "rand_like",
    "randn",
    "reciprocal",
    "resolve_conj",
    "resolve_neg",
    "rsqrt",
    "scalar_tensor",
    "sigmoid",
    "silu",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "transpose",
    "true_divide",
    "true_divide_",
    "unbind",
    "unfold",
    "unsqueeze",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros",
    "zeros_like"
]
```
### 算子替换列表（txt）
替换算子数：68
```json
[
    "_has_compatible_shallow_copy_type",
    "_reshape_alias",
    "_scaled_dot_product_flash_attention",
    "_unsafe_view",
    "add",
    "alias",
    "arange_start",
    "argmax",
    "bitwise_not",
    "broadcast_to",
    "cat",
    "chunk",
    "copy_",
    "cos",
    "cumsum",
    "embedding",
    "empty",
    "expand",
    "expand_as",
    "exponential_",
    "fill_scalar_",
    "flash_attention_forward",
    "flatten",
    "floor_divide",
    "full",
    "gelu",
    "gt_scalar",
    "index",
    "index_put_",
    "layer_norm",
    "lift_fresh",
    "lt_scalar",
    "mean_dim",
    "mean_dim_comm",
    "mul",
    "narrow",
    "native_layer_norm",
    "nonzero",
    "nonzero_numpy",
    "normal_",
    "ones",
    "pow_scalar",
    "pow_tensor_scalar",
    "rand_like",
    "randn",
    "reciprocal",
    "resolve_conj",
    "resolve_neg",
    "rsqrt",
    "scalar_tensor",
    "sigmoid",
    "silu",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "transpose",
    "true_divide",
    "true_divide_",
    "unbind",
    "unfold",
    "unsqueeze",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros",
    "zeros_like"
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

> 服务启动成功（eager 模式，禁用 attention_backend，V2 启用 68 算子）。精度评测（步骤4）因硬件性能限制、评测速度过慢（~73s/题）无法完成，未产出有效分值；后续精度调优/性能评测未执行。accuracy_ok=false、performance_ok=false，release.qualified=false。

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - (评测未完成) | 0 |
| math_500 | - | - (评测未完成) | 0 |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - (评测未完成，~73s/题超时) | 68 |
| math_500 | - | - (评测未完成) | 68 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - (沿用 V2，评测未完成) | 68 |
| math_500 | - | - (沿用 V2，评测未完成) | 68 |

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - (未产出) | - |
| math_500 | - | - (未产出) | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 评测未完成（硬件过慢），无有效数据 |
| V1 VS V3 | 评测未完成（V3 沿用 V2） |
| V1 VS V4 | 未产出 |
| V2 VS V3 | 一致（同镜像双 tag） |

## 性能评测

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| apodex/Apodex-1.0-4B-SFT | Iluvatar | - | 1 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| apodex/Apodex-1.0-4B-SFT | Iluvatar | - | 1 | - | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| apodex/Apodex-1.0-4B-SFT | Iluvatar | - | 1 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| apodex/Apodex-1.0-4B-SFT | Iluvatar | - | 1 | - | - | - | - | - | - | - | - |

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
| 流程耗时 | 7h 51m 57s |
| 流程消费 | 216.02 元（≈ $30.00 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/apodex-1.0-4b-sft-iluvatar001-gems5.3.4-tree0.6.0-cxnone-plugin0.3.0-vllm0.24.0-cp312-pt210-ixml44-x64-4.5.0:202609031206-v2
  - V3：harbor.baai.ac.cn/flagrelease-project/apodex-1.0-4b-sft-iluvatar001-gems5.3.4-tree0.6.0-cxnone-plugin0.3.0-vllm0.24.0-cp312-pt210-ixml44-x64-4.5.0:202609031206-v3（与 V2 同 digest，2.2/3.2 双 tag）
  - V4：-（未产出）

- ModelScope: -（qualified=false，不对外发布）
- HuggingFace: -（qualified=false，不对外发布）

# 结论

- 发布镜像上传正常：❌ 未达发布门槛（release.qualified=false）——服务可启动（eager 模式，禁用 attention_backend），但精度评测因硬件过慢（~73s/题）无法完成、性能评测未执行；镜像已 Harbor 私有留档（-v2/-v3 双 tag），不对外传权重
- 流程自动化结论：❌ 迁移失败（精度/性能评测未完成，release.qualified=false）

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 天数(Iluvatar) (apodex/Apodex-1.0-4B-SFT)
2. 【FR】Bug: Operator performance degradation on 天数(Iluvatar) (apodex/Apodex-1.0-4B-SFT)

---

报告生成时间：2026.09.08