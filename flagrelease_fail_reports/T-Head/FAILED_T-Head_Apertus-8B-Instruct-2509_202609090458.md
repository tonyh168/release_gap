# 迁移结果：❌ 失败

> **自动化流程产出镜像版本：**
> - V1：tree版本=基础版：只带flagtree不开启任何flagos组件
> - V2：tree+gems=Pro版：开启flaggems且性能达到V1的80%，与V1的精度误差在5%以内
> - V3：tree+gems+plugin=Max版：在V2的基础上安装使用plugin，且性能达到V1的80%，与V1的精度误差在5%以内
> - V4：tree+gems+plugin=Flag-express版：在V3的基础上，性能表现超过V1版本
>
> ⚠️ **本报告 V3 沿用 V2 结果**：V2=V3 同镜像双 tag 发布，无独立 V3 评测。

# 基本信息

| 项目 | 内容 |
|------|------|
| 项目名称 | KT2期 |
| 开始时间 | 2026-09-04 14:59:26 |
| gems+tree版本上传时间 | 2026-09-04 20:14:19 |
| 发布时间 | 2026-09-04 20:15:07 |
| 模型 | Apertus-8B-Instruct-2509 |
| 模型领域 | 语言 |
| 权重来源 | swiss-ai/Apertus-8B-Instruct-2509 |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.24.0 |
| 推理框架插件plugin-FL | 0.3.0 |
| FlagGems版本 | 5.3.4 |
| Flagtree版本 | 0.6.1 |
| FlagCX版本 | - |
| 厂商 | 平头哥(T-Head) |
| GPU | PPU-ZW810E : 16 x 96GB |
| 容器 | Apertus-8B-Instruct-2509_flagos |
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
    "alias",
    "arange_start",
    "argmax",
    "cat",
    "copy_",
    "cos",
    "true_divide",
    "true_divide_",
    "empty",
    "exp",
    "expand",
    "exponential_",
    "fill_scalar_",
    "full",
    "gt_scalar",
    "index",
    "lift_fresh",
    "linear",
    "log",
    "lt_scalar",
    "mm_out",
    "mul",
    "narrow",
    "ones",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "unbind",
    "unsqueeze",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros",
    "attention_backend"
]
```
### 算子替换列表（txt）
替换算子数：43
```json
[
    "add",
    "alias",
    "arange_start",
    "argmax",
    "cat",
    "copy_",
    "cos",
    "true_divide",
    "true_divide_",
    "empty",
    "exp",
    "expand",
    "exponential_",
    "fill_scalar_",
    "full",
    "gt_scalar",
    "index",
    "lift_fresh",
    "linear",
    "log",
    "lt_scalar",
    "mm_out",
    "mul",
    "narrow",
    "ones",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "unbind",
    "unsqueeze",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros",
    "attention_backend"
]
```

## V3（沿用 V2 结果）
### 算子白名单
```json
"include": [
    "add",
    "alias",
    "arange_start",
    "argmax",
    "cat",
    "copy_",
    "cos",
    "true_divide",
    "true_divide_",
    "empty",
    "exp",
    "expand",
    "exponential_",
    "fill_scalar_",
    "full",
    "gt_scalar",
    "index",
    "lift_fresh",
    "linear",
    "log",
    "lt_scalar",
    "mm_out",
    "mul",
    "narrow",
    "ones",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "unbind",
    "unsqueeze",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros",
    "attention_backend"
]
```
### 算子替换列表（txt）
替换算子数：43
```json
[
    "add",
    "alias",
    "arange_start",
    "argmax",
    "cat",
    "copy_",
    "cos",
    "true_divide",
    "true_divide_",
    "empty",
    "exp",
    "expand",
    "exponential_",
    "fill_scalar_",
    "full",
    "gt_scalar",
    "index",
    "lift_fresh",
    "linear",
    "log",
    "lt_scalar",
    "mm_out",
    "mul",
    "narrow",
    "ones",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "unbind",
    "unsqueeze",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros",
    "attention_backend"
]
```

## V4
### 算子白名单
（未执行 V4）
### 算子替换列表（txt）
（未执行 V4）

# 评测结果

## 精度评测

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - (V1=none, 基线 NV) |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 12.0 | 43 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 12.0（沿用 V2 结果） | 43 |

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | V1 无本地基线（V1=none，基线取 NV 参考 35.0%）；V2=12.0% |
| V1 VS V3 | V3 沿用 V2 结果（V2=V3 同镜像），V3=12.0% |
| V1 VS V4 | 未执行 V4 |
| V2 VS V3 | 一致（V2=V3 同镜像），均为 12.0% |

## 性能评测

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Apertus-8B-Instruct-2509 | T-Head | - | 16 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Apertus-8B-Instruct-2509 | T-Head | - | 16 | - | - | - | - | - | - | 43 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Apertus-8B-Instruct-2509（沿用 V2 结果） | T-Head | - | 16 | - | - | - | - | - | - | 43 | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Apertus-8B-Instruct-2509 | T-Head | - | 16 | - | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | V1 无本地基线（V1=none，用合成基线）；V2 初始 814.2 tok/s，调优后 870.8 tok/s，ratio 101.9% |
| V1 VS V3 | V3 沿用 V2 结果（V2=V3 同镜像） |
| V1 VS V4 | 未执行 V4 |
| V2 VS V3 | 一致（V2=V3 同镜像） |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 5h 15m 41s |
| 流程消费 | 248.42 元（≈ $34.50 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/apertus-8b-instruct-2509-pp001-gemsnone-treenone-cxnone-pluginnone-vllm0.23.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202609050406-v2
  - V3：harbor.baai.ac.cn/flagrelease-project/apertus-8b-instruct-2509-pp001-gemsnone-treenone-cxnone-pluginnone-vllm0.23.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202609050406-v3
  - V4：-（未执行 V4）

- ModelScope: https://modelscope.cn/models/FlagRelease/Apertus-8B-Instruct-2509-zhenwu-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Apertus-8B-Instruct-2509-zhenwu-FlagOS

# 结论

- 发布镜像上传正常：✅ 合格（发布镜像 已产出）
- 流程自动化结论：❌ 迁移失败

## 提交到 flagos 仓库的 Issue
issue 数量：1
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 平头哥(T-Head) (swiss-ai/Apertus-8B-Instruct-2509)

---

报告生成时间：2026.09.09
