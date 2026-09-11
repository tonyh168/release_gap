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
| 开始时间 | 2026-07-16 13:38:06Z |
| gems+tree版本上传时间 | 2026-07-16 23:58:34 |
| 发布时间 |  |
| 模型 | VibeThinker-1.5B |
| 模型领域 | 语言 |
| 权重来源 | WeiboAI/VibeThinker-1.5B |
| 权重数制 |  |
| 计算数制（默认权重数制） |  |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | installed |
| FlagGems版本 | 5.4.0dev |
| Flagtree版本 | 0.6.1 |
| FlagCX版本 | - |
| 厂商 | 海光(Hygon) |
| GPU | DCU BW1000 : 8 x -GB |
| 容器 | VibeThinker-1.5B_flagos |
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
    "addmm_out",
    "arange_start",
    "argmax",
    "attention_backend",
    "cat",
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
替换算子数：29
```json
[
    "add",
    "addmm_out",
    "arange_start",
    "argmax",
    "attention_backend",
    "cat",
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
（无数据，模型未达标，流程提前终止）
### 算子替换列表（txt）
（无数据，模型未达标，流程提前终止）

## V4
### 算子白名单
（无数据，模型未达标，流程提前终止）
### 算子替换列表（txt）
（无数据，模型未达标，流程提前终止）

# 评测结果

## 精度评测

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 42.0 | - |

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

> ⚠️ **性能基线为合成值，非实测 V1**：V2 初始性能 ×1.2（baseline_source: v2_initial_x1.2）。本报告所有以 V1 为基准的性能比均基于该合成基线。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| WeiboAI/VibeThinker-1.5B | Hygon | - | 8 | - | 981.42 | 1310.67 | 4097.52 | 20487.36 | 14.42 | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| WeiboAI/VibeThinker-1.5B | Hygon | - | 8 | - | 1080.3 | 1512.5 | 3440.1 | 17200.3 | 17.2 | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| WeiboAI/VibeThinker-1.5B | Hygon | - | 8 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| WeiboAI/VibeThinker-1.5B | Hygon | - | 8 | - | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 84.0% |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | - |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 2h 47m 10s |
| 流程消费 | 317.51 元（≈ $44.10 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/vibethinker-1.5b-hygon001-gems5.4.0-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp310-pt210-dtknone-x64-6.3.28-v1.3.0b:202607170752-v2
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/VibeThinker-1.5B-hygon-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/VibeThinker-1.5B-hygon-FlagOS

# 结论

- 发布镜像上传正常：❌ 不合格
- 流程自动化结论：❌ 未达标 (精度不达标)

## 提交到 flagos 仓库的 Issueissue 数量：2
1. Bug: Operator accuracy degradation on hygon (WeiboAI/VibeThinker-1.5B)（flagos-ai/FlagGems）
2. Bug: Operator crash: addmm, broadcast_to, copy on hygon (WeiboAI/VibeThinker-1.5B)（flagos-ai/FlagGems）

---

报告生成时间：2026.07.23