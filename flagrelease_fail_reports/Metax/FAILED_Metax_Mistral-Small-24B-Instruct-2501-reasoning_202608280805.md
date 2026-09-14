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
| 开始时间 | - |
| gems+tree版本上传时间 | 2026-08-28 00:02:31 |
| 发布时间 | 2026-08-28 00:03:52 |
| 模型 | Mistral-Small-24B-Instruct-2501-reasoning |
| 模型领域 | 语言 |
| 权重来源 | yentinglin/Mistral-Small-24B-Instruct-2501-reasoning |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.24.0 |
| 推理框架插件plugin-FL | 0.2.0 |
| FlagGems版本 | 5.4.0.dev606 |
| Flagtree版本 | 0.6.0 |
| FlagCX版本 | - |
| 厂商 | 沐曦(Metax) |
| GPU | MetaX C550 : 8 x 64GB |
| 容器 | Mistral-Small-24B-Instruct-2501-reasoning_flagos |
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
    "argmax",
    "broadcast_to",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "expand",
    "fill_scalar_",
    "gather",
    "le",
    "linear",
    "lt",
    "lt_scalar",
    "mul",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "resolve_neg",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sort",
    "sort_stable",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out",
    "zero_"
]
```
### 算子替换列表（txt）
替换算子数：35
```json
[
    "add",
    "argmax",
    "broadcast_to",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "expand",
    "fill_scalar_",
    "gather",
    "le",
    "linear",
    "lt",
    "lt_scalar",
    "mul",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "resolve_neg",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sort",
    "sort_stable",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out",
    "zero_"
]
```

## V3
### 算子白名单
```json
"include": [
    "add",
    "argmax",
    "broadcast_to",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "expand",
    "fill_scalar_",
    "gather",
    "le",
    "linear",
    "lt",
    "lt_scalar",
    "mul",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "resolve_neg",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sort",
    "sort_stable",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out",
    "zero_"
]
```
### 算子替换列表（txt）
替换算子数：35
```json
[
    "add",
    "argmax",
    "broadcast_to",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "expand",
    "fill_scalar_",
    "gather",
    "le",
    "linear",
    "lt",
    "lt_scalar",
    "mul",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "resolve_neg",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sort",
    "sort_stable",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out",
    "zero_"
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
| GPQA_Diamond | - | - | - |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

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
| V2 VS V3 | - |

## 性能评测

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| yentinglin/Mistral-Small-24B-Instruct-2501-reasoning | Metax | - | 8 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| yentinglin/Mistral-Small-24B-Instruct-2501-reasoning | Metax | - | 8 | - | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| yentinglin/Mistral-Small-24B-Instruct-2501-reasoning | Metax | - | 8 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| yentinglin/Mistral-Small-24B-Instruct-2501-reasoning | Metax | - | 8 | - | - | - | - | - | - | - | - |

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
| 流程耗时 | 15h 16m 39s |
| 流程消费 | 3217.79 元（≈ $446.92 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/mistral-small-24b-instruct-2501-reasoning-metax001-gems5.4.0-tree0.6.0-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt28-maca37-x64-3.3.12:202608280752-v2
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/Mistral-Small-24B-Instruct-2501-reasoning-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Mistral-Small-24B-Instruct-2501-reasoning-FlagOS

# 结论

- 发布镜像上传正常：❌ 未达标发布（精度不达标（rel_drop 超阈值）、性能不达标）
- 流程自动化结论：❌ 迁移失败（精度不达标（rel_drop 超阈值）、性能不达标）

## 提交到 flagos 仓库的 Issue
issue 数量：4
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on unknown platform
2. 【FR】Bug: Operator crash: libentry, mm on 沐曦(Metax) (yentinglin/Mistral-Small-24B-Instruct-2501-reasoning)
3. 【FR】Bug: Operator crash on unknown platform
4. 【FR】Bug: Operator performance degradation on 沐曦(Metax) (yentinglin/Mistral-Small-24B-Instruct-2501-reasoning)

---

报告生成时间：2026.08.28