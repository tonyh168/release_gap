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
| 开始时间 |  |
| gems+tree版本上传时间 | 2026-08-04T04:30:28 |
| 发布时间 | 2026-08-04T04:53:30 |
| 模型 | SuperNova-Medius |
| 模型领域 | 语言 |
| 权重来源 | arcee-ai/SuperNova-Medius |
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
| 容器 | SuperNova-Medius_flagos |
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
    "cos",
    "sin",
    "attention_backend",
    "ones",
    "randn",
    "addmm_out",
    "general_mm",
    "rand_like",
    "argmax",
    "lt_scalar",
    "where_self",
    "where_self_out",
    "true_divide_",
    "softmax",
    "softmax_out",
    "exponential_",
    "add",
    "sub"
]
```
### 算子替换列表（txt）
替换算子数：24
```json
[
    "zeros",
    "full",
    "zero_",
    "arange_start",
    "true_divide",
    "reciprocal",
    "cos",
    "sin",
    "attention_backend",
    "ones",
    "randn",
    "addmm_out",
    "general_mm",
    "rand_like",
    "argmax",
    "lt_scalar",
    "where_self",
    "where_self_out",
    "true_divide_",
    "softmax",
    "softmax_out",
    "exponential_",
    "add",
    "sub"
]
```

## V3
### 算子白名单
```json
"include": [
    "add",
    "addmm_out",
    "arange_start",
    "argmax",
    "cos",
    "exponential_",
    "full",
    "lt_scalar",
    "mm",
    "ones",
    "rand_like",
    "reciprocal",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：23
```json
[
    "add",
    "addmm_out",
    "arange_start",
    "argmax",
    "cos",
    "exponential_",
    "full",
    "lt_scalar",
    "mm",
    "ones",
    "rand_like",
    "reciprocal",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros"
]
```

## V4
### 算子白名单
```json
"include": [
    "add",
    "addmm_out",
    "arange_start",
    "argmax",
    "cos",
    "exponential_",
    "full",
    "lt_scalar",
    "mm",
    "ones",
    "rand_like",
    "reciprocal",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：23
```json
[
    "add",
    "addmm_out",
    "arange_start",
    "argmax",
    "cos",
    "exponential_",
    "full",
    "lt_scalar",
    "mm",
    "ones",
    "rand_like",
    "reciprocal",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros"
]
```

# 评测结果

## 精度评测

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 40.0 | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 42.0 | 24 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 38.0 | 23 |

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | Δ=2.0 个百分点 |
| V1 VS V3 | Δ=-2.0 个百分点 |
| V1 VS V4 | - |
| V2 VS V3 | Δ=-4.0 个百分点 |

## 性能评测

> ✅ **性能基线为实测 V1**（baseline_mode: local_v1，v1_variant: v1.1）：V1 native 实测吞吐 1276.7 tok/s。本报告以 V1 为基准的性能比均基于该实测基线。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| arcee-ai/SuperNova-Medius | Nvidia | - | 8 | - | 758.8 | - | 1276.7 | 6383.3 | 49.2 | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| arcee-ai/SuperNova-Medius | Nvidia | - | 8 | - | 754.3 | - | 1276.7 | 6383.5 | 49.2 | 24 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| arcee-ai/SuperNova-Medius | Nvidia | - | 8 | - | 725.3 | 942.3 | 1374.8 | 6874.2 | 45.7 | 23 | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| arcee-ai/SuperNova-Medius | Nvidia | - | 8 | - | - | - | - | - | - | 23 | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | ratio=100.0% |
| V1 VS V3 | ratio=107.7% |
| V1 VS V4 | - |
| V2 VS V3 | ratio=107.7% |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 0h 52m 7s |
| 流程消费 | 348.29 元（≈ $48.37 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布 / 基线阶段无镜像）
  - V2：harbor.baai.ac.cn/flagrelease-public/supernova-medius-nvidia003-gems5.0.2-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp312-pt211-cu130-x64-570.158.01:202608041156-v2
  - V3：harbor.baai.ac.cn/flagrelease-project/supernova-medius-nvidia003-gems5.0.2-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp312-pt211-cu130-x64-570.158.01:202608041253-v3
  - V4：（无 / V4 等价 V3 交付）

- ModelScope: https://www.modelscope.cn/models/FlagRelease/SuperNova-Medius-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/SuperNova-Medius-FlagOS

# 结论

- 发布镜像上传正常：✅ 合格
- V2（FlagGems）阶段达标：✅ 达标
- V3（plugin）精度达标（相对 NV 退化 ≤ 5%）：✅ 达标
- V3（plugin）性能达标（≥ 基线 80%）：✅ 达标
- 交付结论：V3（plugin）双达标，对外三端交付
- 流程自动化结论：✅ 流程已达标

## 提交到 flagos 仓库的 Issue
issue 数量：0
issue 标题：无

---

报告生成时间：2026-08-05
数据来源：/data/flagos-workspace/arcee-ai/SuperNova-Medius/shared/context.yaml, /data/flagos-workspace/arcee-ai/SuperNova-Medius/results/*.json, /data/flagos-workspace/arcee-ai/SuperNova-Medius/logs/seg*_cost.txt