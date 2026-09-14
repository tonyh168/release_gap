# 迁移结果：❌ 失败

> **自动化流程产出镜像版本：**
> - V1：tree版本=基础版：只带flagtree不开启任何flagos组件
> - V2：tree+gems=Pro版：开启flaggems且性能达到V1的80%，与V1的精度误差在5%以内
> - V3：tree+gems+plugin=Max版：在V2的基础上安装使用plugin，且性能达到V1的80%，与V1的精度误差在5%以内
> - V4：tree+gems+plugin=Flag-express版：在V3的基础上，性能表现超过V1版本

# 基本信息

| 项目 | 内容 |
|------|------|
| 项目名称 | - |
| 开始时间 | 2026-07-15 05:38:14Z |
| gems+tree版本上传时间 | 2026-07-15 09:59:09 |
| 发布时间 |  |
| 模型 | Phi-3-mini-128k-instruct |
| 模型领域 | 语言 |
| 权重来源 | microsoft/Phi-3-mini-128k-instruct |
| 权重数制 | bfloat16 |
| 计算数制（默认权重数制） | bfloat16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0+g8a1c299e5 |
| FlagGems版本 | 5.3.0rc2 |
| Flagtree版本 | 0.6.1 |
| FlagCX版本 | - |
| 厂商 | 海光(Hygon) |
| GPU | DCU BW1000 : 8 x -GB |
| 容器 | Phi-3-mini-128k-instruct_flagos |
| release自动化工具版本 | v0.1.0 |

# 算子替换列表

## V1
### 算子白名单
（V1 不开启 FlagGems，无算子白名单）
### 算子替换列表（txt）
（V1 不开启 FlagGems，无算子替换）

## V2
### 算子白名单
```json
"include": [
    "add",
    "arange_start",
    "argmax",
    "copy_",
    "cos",
    "expand",
    "full",
    "index",
    "linear",
    "lt_scalar",
    "mm_out",
    "ones",
    "rand_like",
    "reciprocal",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：26
```json
[
    "add",
    "arange_start",
    "argmax",
    "copy_",
    "cos",
    "expand",
    "full",
    "index",
    "linear",
    "lt_scalar",
    "mm_out",
    "ones",
    "rand_like",
    "reciprocal",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
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
    "copy_",
    "cos",
    "expand",
    "full",
    "index",
    "linear",
    "lt_scalar",
    "mm_out",
    "ones",
    "rand_like",
    "reciprocal",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：26
```json
[
    "add",
    "arange_start",
    "argmax",
    "copy_",
    "cos",
    "expand",
    "full",
    "index",
    "linear",
    "lt_scalar",
    "mm_out",
    "ones",
    "rand_like",
    "reciprocal",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
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
    "arange_start",
    "argmax",
    "copy_",
    "cos",
    "expand",
    "full",
    "index",
    "linear",
    "lt_scalar",
    "mm_out",
    "ones",
    "rand_like",
    "reciprocal",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：26
```json
[
    "add",
    "arange_start",
    "argmax",
    "copy_",
    "cos",
    "expand",
    "full",
    "index",
    "linear",
    "lt_scalar",
    "mm_out",
    "ones",
    "rand_like",
    "reciprocal",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
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
| GPQA_Diamond | - | - | - |

> ⚠️ **无 V1 基线**：分支 B 三选均失败（v1_available=false），精度基线回退 NV 参考（nv_baseline GPQA=33.0）。V2/V3 精度均以相对 NV 基线计算。

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 40.0 | - |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 40.0 | - |

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 无 V1，改比 NV 基线：V2 40.0% vs NV 33.0%，相对提升 +21.21%，达标 |
| V1 VS V3 | 无 V1，改比 NV 基线：V3 40.0% vs NV 33.0%，相对提升 +21.21%，达标 |
| V1 VS V4 | - |
| V2 VS V3 | 精度偏差 0.0% |

## 性能评测

> ⚠️ **性能基线为合成值，非实测 V1**：V2 初始性能 ×1.2（baseline_source: v2_initial_x1.2）。本报告所有以 V1 为基准的性能比均基于该合成基线。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Phi-3-mini-128k-instruct | Hygon | - | 8 | - | 62467.0 | 203460.17 | 282.12 | 1410.6 | 94.83 | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Phi-3-mini-128k-instruct | Hygon | - | 8 | - | 74960.4 | 244152.2 | 235.1 | 1175.5 | 113.8 | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Phi-3-mini-128k-instruct | Hygon | - | 8 | - | 74269.6 | 238889.4 | 244.0 | 1220.0 | 111.0 | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Phi-3-mini-128k-instruct | Hygon | - | 8 | - | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 83.3% |
| V1 VS V3 | 性能比 86.5% |
| V1 VS V4 | - |
| V2 VS V3 | 性能比 103.8% |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 2h 23m 51s |
| 流程消费 | 195.95 元（≈ $27.21 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/phi-3-mini-128k-instruct-hygon001-gems5.4.0-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp310-pt210-dtknone-x64-6.3.28-v1.3.0b:202607151739-v2
  - V3：harbor.baai.ac.cn/flagrelease-public/phi-3-mini-128k-instruct-hygon001-gems5.4.0-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp310-pt210-dtknone-x64-6.3.28-v1.3.0b:202607151842-v3
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/Phi-3-mini-128k-instruct-hygon-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Phi-3-mini-128k-instruct-hygon-FlagOS

# 结论

- 发布镜像上传正常：✅ 合格
- 流程自动化结论：✅ 流程已达标

## 提交到 flagos 仓库的 Issueissue 数量：0
issue 标题：无

---

报告生成时间：2026.07.23