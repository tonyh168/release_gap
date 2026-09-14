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
| 开始时间 | 2026-08-28 02:55:50 |
| gems+tree版本上传时间 | 2026-08-28 11:19:41 |
| 发布时间 | 2026-08-28 11:19:41 |
| 模型 | OpenReasoning-Nemotron-14B |
| 模型领域 | 语言 |
| 权重来源 | nvidia/OpenReasoning-Nemotron-14B |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0rc2.post1 |
| FlagGems版本 | 5.0.2 |
| Flagtree版本 | 0.6.0 |
| FlagCX版本 | - |
| 厂商 | 英伟达(Nvidia) |
| GPU | H20-3e : 8 x 140GB |
| 容器 | OpenReasoning-Nemotron-14B_flagos |
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
    "addmm_out",
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
    "addmm_out",
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

> 精度基线：真实 V1 实测（mmlu 86.67%，math_500 95.5%）。

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | 1140 | 86.67 | 0 |
| math_500 | 200 | 95.5 | 0 |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | 1140 | 86.67 | 23 |
| math_500 | 200 | 96.5 | 23 |

> V2 mmlu 86.67% vs V1 86.67%，rel_drop 0%，达标；math_500 96.5% vs V1 95.5%，rel_drop -1.05%（V2更好），达标。

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
| V1 VS V2 | mmlu达标(rel_drop 0%)；math_500达标(rel_drop -1.05%) |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | - |

## 性能评测

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| nvidia/OpenReasoning-Nemotron-14B | Nvidia | 296 | 8 | 2368 | - | - | - | 6382 | - | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| nvidia/OpenReasoning-Nemotron-14B | Nvidia | 296 | 8 | 2368 | - | - | - | 6871 | - | 23 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| nvidia/OpenReasoning-Nemotron-14B | Nvidia | 296 | 8 | 2368 | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| nvidia/OpenReasoning-Nemotron-14B | Nvidia | 296 | 8 | 2368 | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 107.7%，达标 |
| V1 VS V3 | - （V3 精度/性能评测 accuracy_ok=false，未产出镜像）|
| V1 VS V4 | - |
| V2 VS V3 | - |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 8h 29m 12s |
| 流程消费 | 817.57 元（≈ $113.55 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/openreasoning-nemotron-14b-nvidia003-gems5.0.2-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp312-pt211-cu130-x64-570.158.01:202608281831-v2
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/OpenReasoning-Nemotron-14B-nvidia-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/OpenReasoning-Nemotron-14B-nvidia-FlagOS

# 结论

- 发布镜像上传正常：❌ 未达标发布
- 流程自动化结论：❌ 迁移失败

## 提交到 flagos 仓库的 Issue
issue 数量：0
issue 标题：无

---

报告生成时间：2026.08.28