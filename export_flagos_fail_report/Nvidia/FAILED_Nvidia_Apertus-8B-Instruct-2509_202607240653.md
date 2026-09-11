# 迁移结果：❌ 失败

> **自动化流程产出镜像版本：**
> - V1：tree版本=基础版：只带flagtree不开启任何flagos组件
> - V2：tree+gems=Pro版：开启flaggems且性能达到V1的80%，与V1的精度误差在5%以内
> - V3：tree+gems+plugin=Max版：在V2的基础上安装使用plugin，且性能达到V1的80%，与V1的精度误差在5%以内
> - V4：tree+gems+plugin=Flag-express版：在V3的基础上，性能表现超过V1版本

# 基本信息

| 项目 | 内容 |
|------|------|
| 项目名称 | FlagOS NVIDIA 批量迁移 |
| 开始时间 | now |
| gems+tree版本上传时间 | 2026-07-24T00:28:00 |
| 发布时间 | 2026-07-24T01:03:56 |
| 模型 | Apertus-8B-Instruct-2509 |
| 模型领域 | 语言 |
| 权重来源 | swiss-ai/Apertus-8B-Instruct-2509 |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0rc2.post1 |
| FlagGems版本 | 5.0.2 |
| Flagtree版本 | 0.6.1 |
| FlagCX版本 | - |
| 厂商 | nvidia |
| GPU | H20-3e : 8 x 140GB |
| 容器 | Apertus-8B-Instruct-2509_flagos |
| release自动化工具版本 | - |

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
    "zeros",
    "full",
    "zero_",
    "arange_start",
    "true_divide",
    "reciprocal",
    "sub",
    "lt_scalar",
    "gt_scalar",
    "rsub_scalar",
    "add",
    "where_self",
    "where_self_out",
    "cos",
    "sin",
    "attention_backend",
    "ones",
    "exp",
    "log",
    "general_mm",
    "rand_like",
    "argmax",
    "true_divide_",
    "softmax",
    "softmax_out",
    "exponential_",
    "scatter_"
]
```
### 算子替换列表（txt）
替换算子数：27
```json
[
    "zeros",
    "full",
    "zero_",
    "arange_start",
    "true_divide",
    "reciprocal",
    "sub",
    "lt_scalar",
    "gt_scalar",
    "rsub_scalar",
    "add",
    "where_self",
    "where_self_out",
    "cos",
    "sin",
    "attention_backend",
    "ones",
    "exp",
    "log",
    "general_mm",
    "rand_like",
    "argmax",
    "true_divide_",
    "softmax",
    "softmax_out",
    "exponential_",
    "scatter_"
]
```

## V3
### 算子白名单
```json
"include": [
    "zeros",
    "full",
    "zero_",
    "arange_start",
    "true_divide",
    "reciprocal",
    "sub",
    "lt_scalar",
    "gt_scalar",
    "rsub_scalar",
    "add",
    "where_self",
    "where_self_out",
    "cos",
    "sin",
    "attention_backend",
    "ones",
    "exp",
    "log",
    "general_mm",
    "rand_like",
    "argmax",
    "true_divide_",
    "softmax",
    "softmax_out",
    "exponential_",
    "scatter_"
]
```
### 算子替换列表（txt）
替换算子数：27
```json
[
    "zeros",
    "full",
    "zero_",
    "arange_start",
    "true_divide",
    "reciprocal",
    "sub",
    "lt_scalar",
    "gt_scalar",
    "rsub_scalar",
    "add",
    "where_self",
    "where_self_out",
    "cos",
    "sin",
    "attention_backend",
    "ones",
    "exp",
    "log",
    "general_mm",
    "rand_like",
    "argmax",
    "true_divide_",
    "softmax",
    "softmax_out",
    "exponential_",
    "scatter_"
]
```

## V4
### 算子白名单
```json
"include": [
    "zeros",
    "full",
    "zero_",
    "arange_start",
    "true_divide",
    "reciprocal",
    "sub",
    "lt_scalar",
    "gt_scalar",
    "rsub_scalar",
    "add",
    "where_self",
    "where_self_out",
    "cos",
    "sin",
    "attention_backend",
    "ones",
    "exp",
    "log",
    "general_mm",
    "rand_like",
    "argmax",
    "true_divide_",
    "softmax",
    "softmax_out",
    "exponential_",
    "scatter_"
]
```
### 算子替换列表（txt）
替换算子数：27
```json
[
    "zeros",
    "full",
    "zero_",
    "arange_start",
    "true_divide",
    "reciprocal",
    "sub",
    "lt_scalar",
    "gt_scalar",
    "rsub_scalar",
    "add",
    "where_self",
    "where_self_out",
    "cos",
    "sin",
    "attention_backend",
    "ones",
    "exp",
    "log",
    "general_mm",
    "rand_like",
    "argmax",
    "true_divide_",
    "softmax",
    "softmax_out",
    "exponential_",
    "scatter_"
]
```

# 评测结果

## 精度评测

> 精度基线模式：nv_reference；NV 参考分（NV）= 35.0%；交付版本相对退化 = 37.14%；对齐(≤5%容差)：否

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 20.0 | 27 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 22.0 | 27 |
> 相对 NV 退化 = 37.14%；对齐(≤5%容差)：否

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
| V2 VS V3 | Δ=2.0 个百分点 |

## 性能评测

> ⚠️ **性能基线为合成值，非实测 V1**：V2 初始性能 ×1.2（baseline_source: v2_initial_x1.2）。本报告以 V1 为基准的性能比均基于该合成基线。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| swiss-ai/Apertus-8B-Instruct-2509 | Nvidia | - | 8 | - | - | - | - | - | - | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| swiss-ai/Apertus-8B-Instruct-2509 | Nvidia | - | 8 | - | - | - | - | - | - | 27 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| swiss-ai/Apertus-8B-Instruct-2509 | Nvidia | - | 8 | - | - | - | - | - | - | 27 | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| swiss-ai/Apertus-8B-Instruct-2509 | Nvidia | - | 8 | - | - | - | - | - | - | 27 | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 89.3% |
| V1 VS V3 | 性能比 89.3% |
| V1 VS V4 | - |
| V2 VS V3 | - |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 1h 38m 40s |
| 流程消费 | 76.15 元（≈ $10.58 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布 / 基线阶段无镜像）
  - V2：harbor.baai.ac.cn/flagrelease-public/apertus-8b-instruct-2509-nvidia003-gems5.0.2-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp312-pt211-cu130-x64-570.158.01:202607240826-v2
  - V3：harbor.baai.ac.cn/flagrelease-project/apertus-8b-instruct-2509-nvidia003-gems5.0.2-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp312-pt211-cu130-x64-570.158.01:202607240859-v3
  - V4：（无 / V4 等价 V3 交付）

- ModelScope: （无）
- HuggingFace: （无）

# 结论

- 发布镜像上传正常：✅ 合格
- V2（FlagGems）阶段达标：⚠️ 未达标
- V3（plugin）精度达标（相对 NV 退化 ≤ 5%）：⚠️ 未达标（框架/精度天花板）
- V3（plugin）性能达标（≥ 基线 80%）：✅ 达标
- 交付结论：V2/V3 均未双达标（Harbor 私有 / 不达标发布）
- 流程自动化结论：⚠️ 流程未完全达标

## 提交到 flagos 仓库的 Issue
issue 数量：2
- issue_accuracy-degraded_flagos-ai_FlagGems_20260723_232701.md
- issue_accuracy-degraded_flagos-ai_FlagGems_20260724_001412.md

---

报告生成时间：2026-08-05
数据来源：/data/flagos-workspace/swiss-ai/Apertus-8B-Instruct-2509/shared/context.yaml, /data/flagos-workspace/swiss-ai/Apertus-8B-Instruct-2509/results/*.json, /data/flagos-workspace/swiss-ai/Apertus-8B-Instruct-2509/logs/seg*_cost.txt