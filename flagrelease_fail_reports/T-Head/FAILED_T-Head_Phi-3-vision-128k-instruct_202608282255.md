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
| 开始时间 | 2026-08-28 10:15:12 |
| gems+tree版本上传时间 | 2026-08-28 14:50:14 |
| 发布时间 | 2026-08-28 14:51:29 |
| 模型 | Phi-3-vision-128k-instruct |
| 模型领域 | 语言 |
| 权重来源 | microsoft/Phi-3-vision-128k-instruct |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0 |
| FlagGems版本 | 5.0.2 |
| Flagtree版本 | 0.6.0 |
| FlagCX版本 | - |
| 厂商 | 平头哥(T-Head) |
| GPU | PPU-ZW810E : 16 x 96GB |
| 容器 | Phi-3-vision-128k-instruct_flagos |
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
    "addmm",
    "arange_start",
    "argmax",
    "cat",
    "copy_",
    "cos",
    "embedding",
    "eq_scalar",
    "exponential_",
    "fill_scalar_",
    "flash_attention_forward",
    "floor_divide",
    "full",
    "gelu",
    "index",
    "layer_norm",
    "lt_scalar",
    "mm",
    "mm_out",
    "mul",
    "normal_",
    "ones",
    "pow_scalar",
    "rand_like",
    "randn",
    "reciprocal",
    "remainder",
    "sigmoid",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "uniform_",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：41
```json
[
    "add",
    "addmm",
    "arange_start",
    "argmax",
    "cat",
    "copy_",
    "cos",
    "embedding",
    "eq_scalar",
    "exponential_",
    "fill_scalar_",
    "flash_attention_forward",
    "floor_divide",
    "full",
    "gelu",
    "index",
    "layer_norm",
    "lt_scalar",
    "mm",
    "mm_out",
    "mul",
    "normal_",
    "ones",
    "pow_scalar",
    "rand_like",
    "randn",
    "reciprocal",
    "remainder",
    "sigmoid",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "uniform_",
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
    "addmm",
    "arange_start",
    "argmax",
    "cat",
    "copy_",
    "cos",
    "embedding",
    "eq_scalar",
    "exponential_",
    "fill_scalar_",
    "flash_attention_forward",
    "floor_divide",
    "full",
    "gelu",
    "index",
    "layer_norm",
    "lt_scalar",
    "mm",
    "mm_out",
    "mul",
    "normal_",
    "ones",
    "pow_scalar",
    "rand_like",
    "randn",
    "reciprocal",
    "remainder",
    "sigmoid",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "uniform_",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：41
```json
[
    "add",
    "addmm",
    "arange_start",
    "argmax",
    "cat",
    "copy_",
    "cos",
    "embedding",
    "eq_scalar",
    "exponential_",
    "fill_scalar_",
    "flash_attention_forward",
    "floor_divide",
    "full",
    "gelu",
    "index",
    "layer_norm",
    "lt_scalar",
    "mm",
    "mm_out",
    "mul",
    "normal_",
    "ones",
    "pow_scalar",
    "rand_like",
    "randn",
    "reciprocal",
    "remainder",
    "sigmoid",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "uniform_",
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
| GPQA_Diamond | 50 | 24.0 | 41 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 24.0 | 41 |

> V3 无独立评测（V3 镜像 = V2 同镜像双 tag 发布至 flagrelease-project），沿用 V2 结果。

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | V1=none（基线缺失），如实记录 V2=24.0% |
| V1 VS V3 | V3 沿用 V2，同 24.0% |
| V1 VS V4 | - |
| V2 VS V3 | V3 沿用 V2，同 24.0% |

## 性能评测

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| microsoft/Phi-3-vision-128k-instruct | T-Head | - | 16 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| microsoft/Phi-3-vision-128k-instruct | T-Head | - | 16 | - | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| microsoft/Phi-3-vision-128k-instruct | T-Head | - | 16 | - | - | - | - | - | - | 41 | - |

> V3 无独立评测（V3 镜像 = V2 同镜像双 tag 发布至 flagrelease-project），沿用 V2 结果。

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| microsoft/Phi-3-vision-128k-instruct | T-Head | - | 16 | - | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 93.5%（vs 合成基线） |
| V1 VS V3 | V3 沿用 V2，性能比 93.5%（vs 合成基线） |
| V1 VS V4 | - |
| V2 VS V3 | V3 沿用 V2，性能一致 |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 12h 13m 2s |
| 流程消费 | 282.34 元（≈ $39.21 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/phi-3-vision-128k-instruct-pp001-gemsnone-treenone-cxnone-pluginnone-vllm0.23.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608282244-v2
  - V3：harbor.baai.ac.cn/flagrelease-project/phi-3-vision-128k-instruct-pp001-gemsnone-treenone-cxnone-pluginnone-vllm0.23.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608282244-v3（V3 镜像 = V2 同镜像双 tag 发布）
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/Phi-3-vision-128k-instruct-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Phi-3-vision-128k-instruct-FlagOS

# 结论

- 发布镜像上传正常：❌ 私有发布（V2 精度 24.0%/基线缺失，性能比 93.5% vs 合成基线；未对外发布权重）
- 流程自动化结论：❌ 迁移失败（V2 精度 24.0%、性能比 93.5% vs 合成基线）

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 平头哥(T-Head) (microsoft/Phi-3-vision-128k-instruct)
2. 【FR】Bug: Operator performance degradation on 平头哥(T-Head) (microsoft/Phi-3-vision-128k-instruct)

---

报告生成时间：2026.08.28