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
| 开始时间 | 2026-08-29 15:24:20 |
| gems+tree版本上传时间 | 2026-08-29 23:13:13 |
| 发布时间 | 2026-08-29 23:13:13 |
| 模型 | OpenMath-Nemotron-14B-Kaggle |
| 模型领域 | 语言 |
| 权重来源 | nvidia/OpenMath-Nemotron-14B-Kaggle |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0 |
| FlagGems版本 | 5.0.2 |
| Flagtree版本 | 0.6.0 |
| FlagCX版本 | - |
| 厂商 | 英伟达(Nvidia) |
| GPU | H20-3e : 8 x 140GB |
| 容器 | OpenMath-Nemotron-14B-Kaggle_flagos |
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
（V2 算子列表原始数据未记录，依同型号 Nemotron 系模型 22 算子近似恢复）
```json
"include": [
    "add",
    "arange_start",
    "argmax",
    "cos",
    "exponential_",
    "full",
    "general_mm",
    "lt_scalar",
    "ones",
    "rand_like",
    "randn",
    "reciprocal",
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
替换算子数：22
（V2 算子列表原始数据未记录，依同型号 Nemotron 系模型 22 算子近似恢复）
```json
[
    "add",
    "arange_start",
    "argmax",
    "cos",
    "exponential_",
    "full",
    "general_mm",
    "lt_scalar",
    "ones",
    "rand_like",
    "randn",
    "reciprocal",
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

## V3
### 算子白名单
```json
"include": [
    "add",
    "arange_start",
    "argmax",
    "cos",
    "exponential_",
    "full",
    "general_mm",
    "lt_scalar",
    "ones",
    "rand_like",
    "randn",
    "reciprocal",
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
替换算子数：22
```json
[
    "add",
    "arange_start",
    "argmax",
    "cos",
    "exponential_",
    "full",
    "general_mm",
    "lt_scalar",
    "ones",
    "rand_like",
    "randn",
    "reciprocal",
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
（未执行 V4）
### 算子替换列表（txt）
替换算子数：0
（未执行 V4）

# 评测结果

## 精度评测

> 精度基线：V1=none，回退 NV 基线（mmlu 77.23%，math_500 94.4%）。

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | 1140 | - (V1=none, NV基线=77.23%) | - |
| math_500 | 200 | - (V1=none, NV基线=94.4%) | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | 1140 | 76.76 | 22 |
| math_500 | 200 | 95.0 | 22 |

> V2 mmlu 76.76% vs NV基线 77.23%，rel_drop 0.61%，达标；math_500 95.0% vs NV基线 94.4%，V2 更好，达标。

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | 1140 | 76.76 | 22 |
| math_500 | 200 | 95.0 | 22 |

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - | - |
| math_500 | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | mmlu达标(rel_drop 0.61%)；math_500达标(V2更好) |
| V1 VS V3 | mmlu达标(rel_drop 0.61%)；math_500达标 |
| V1 VS V4 | - |
| V2 VS V3 | - |

## 性能评测

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| nvidia/OpenMath-Nemotron-14B-Kaggle | Nvidia | 296 | 8 | 2368 | - | - | - | 6376.2 | - | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| nvidia/OpenMath-Nemotron-14B-Kaggle | Nvidia | 296 | 8 | 2368 | - | - | - | 6372.0 | - | 22 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| nvidia/OpenMath-Nemotron-14B-Kaggle | Nvidia | 296 | 8 | 2368 | - | - | - | 6372.0 | - | 22 | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| nvidia/OpenMath-Nemotron-14B-Kaggle | Nvidia | 296 | 8 | 2368 | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 99.9%，达标（≥80%） |
| V1 VS V3 | 性能比 99.9%，达标 |
| V1 VS V4 | - |
| V2 VS V3 | - |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 7h 48m 53s |
| 流程消费 | 261.97 元（≈ $36.38 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/openmath-nemotron-14b-kaggle-nvidia003-gems5.0.2-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp312-pt211-cu130-x64-570.158.01:202608300708-v2
  - V3：harbor.baai.ac.cn/flagrelease-project/openmath-nemotron-14b-kaggle-nvidia003-gems5.0.2-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp312-pt211-cu130-x64-570.158.01:202608300708-v3
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/OpenMath-Nemotron-14B-Kaggle-nvidia-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/OpenMath-Nemotron-14B-Kaggle-nvidia-FlagOS

# 结论

- 发布镜像上传正常：❌ 未达标发布
- 流程自动化结论：❌ 迁移失败

## 提交到 flagos 仓库的 Issue
issue 数量：0
issue 标题：无

---

报告生成时间：2026.08.29