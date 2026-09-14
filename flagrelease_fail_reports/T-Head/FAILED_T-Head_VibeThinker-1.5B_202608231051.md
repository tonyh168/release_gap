# 迁移结果：❌ 失败（精度不达标）

> **自动化流程产出镜像版本：**
> - V1：tree版本=基础版：只带flagtree不开启任何flagos组件
> - V2：tree+gems=Pro版：开启flaggems且性能达到V1的80%，与V1的精度误差在5%以内
> - V3：tree+gems+plugin=Max版：在V2的基础上安装使用plugin，且性能达到V1的80%，与V1的精度误差在5%以内
> - V4：tree+gems+plugin=Flag-express版：在V3的基础上，性能表现超过V1版本

# 基本信息

| 项目 | 内容 |
|------|------|
| 项目名称 | KT2期 |
| 开始时间 | 2026-08-22 22:47:01 |
| gems+tree版本上传时间 | 2026-08-23 02:46:42 |
| 发布时间 | 2026-08-23 02:47:41 |
| 模型 | VibeThinker-1.5B |
| 模型领域 | 语言 |
| 权重来源 | WeiboAI/VibeThinker-1.5B |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0 |
| FlagGems版本 | 5.0.2 |
| Flagtree版本 | 0.6.0+ppu.git698d4297 |
| FlagCX版本 | - |
| 厂商 | 平头哥(T-Head) |
| GPU | PPU-ZW810E : 16 x -GB |
| 容器 | VibeThinker-1.5B_flagos |
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
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "exponential_",
    "fill_scalar_",
    "full",
    "index",
    "le",
    "lt_scalar",
    "masked_fill_",
    "mm",
    "mm_out",
    "mul",
    "ones",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "rsub_scalar",
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
    "zero_",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：38
```json
[
    "add",
    "addmm_out",
    "arange_start",
    "argmax",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "exponential_",
    "fill_scalar_",
    "full",
    "index",
    "le",
    "lt_scalar",
    "masked_fill_",
    "mm",
    "mm_out",
    "mul",
    "ones",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "rsub_scalar",
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
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "exponential_",
    "fill_scalar_",
    "full",
    "index",
    "le",
    "lt_scalar",
    "masked_fill_",
    "mm",
    "mm_out",
    "mul",
    "ones",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "rsub_scalar",
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
    "zero_",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：38
```json
[
    "add",
    "addmm_out",
    "arange_start",
    "argmax",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "exponential_",
    "fill_scalar_",
    "full",
    "index",
    "le",
    "lt_scalar",
    "masked_fill_",
    "mm",
    "mm_out",
    "mul",
    "ones",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "rsub_scalar",
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
    "zero_",
    "zeros"
]
```

## V4
（沿用 V2/V3 结果：V4 减算子算子池为空，V4 等价 V3 兜底发布，算子集与 V3 一致）
### 算子白名单
```json
"include": [
    "add",
    "arange_start",
    "argmax",
    "cat",
    "copy_",
    "cos",
    "exponential_",
    "fill_scalar_",
    "full",
    "gt_scalar",
    "index",
    "lt_scalar",
    "mm",
    "mm_out",
    "mul",
    "ones",
    "pow_scalar",
    "rand_like",
    "randn",
    "reciprocal",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "vstack",
    "where_self",
    "where_self_out",
    "zero_"
]
```
### 算子替换列表（txt）
替换算子数：32
```json
[
    "add",
    "arange_start",
    "argmax",
    "cat",
    "copy_",
    "cos",
    "exponential_",
    "fill_scalar_",
    "full",
    "gt_scalar",
    "index",
    "lt_scalar",
    "mm",
    "mm_out",
    "mul",
    "ones",
    "pow_scalar",
    "rand_like",
    "randn",
    "reciprocal",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "true_divide",
    "true_divide_",
    "vstack",
    "where_self",
    "where_self_out",
    "zero_"
]
```

# 评测结果

## 精度评测

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 30 | 40.0 | 38 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 30 | 40.0 | 38 |

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

> V1=none（平头哥无裸启动基线），精度基线回退 NV=47.0%。V2 40.0% vs NV 47.0%，rel_drop 14.89%，超过 5% 阈值，精度不达标。

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | V2 40.0% vs NV 基线 47.0%（V1=none），rel_drop 14.89%，超 5% 阈值，不达标 |
| V1 VS V3 | 沿用 V2 结果（V2=V3 同镜像） |
| V1 VS V4 | 沿用 V2/V3 结果（V4 等价 V3） |
| V2 VS V3 | 同镜像，结果一致 |

## 性能评测

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| WeiboAI/VibeThinker-1.5B | T-Head | - | 16 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| WeiboAI/VibeThinker-1.5B | T-Head | - | 16 | - | 31784.6 | - | 176.3 | 881.7 | 308.9 | 38 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| WeiboAI/VibeThinker-1.5B | T-Head | - | 16 | - | 31784.6 | - | 176.3 | 881.7 | 308.9 | 38 | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| WeiboAI/VibeThinker-1.5B | T-Head | - | 16 | - | 31784.6 | - | 176.3 | 881.7 | 308.9 | 32 | - |

> 性能基线为合成基线（V1=none，取 V2 初始性能 ×1.05）。V2 性能比 95.3%（<100%，实测记录，仍达 80% 门限）。V3/V4 沿用 V2 结果（同镜像/减算子未重测）。

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 95.3%（vs 合成基线）实测值 |
| V1 VS V3 | 沿用 V2 结果（V2=V3 同镜像） |
| V1 VS V4 | 沿用 V2/V3 结果（V4 等价 V3） |
| V2 VS V3 | 同镜像，结果一致 |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 4h 0m 40s |
| 流程消费 | 146.38 元（≈ $20.33 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/vibethinker-1.5b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608231042-v2
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/VibeThinker-1.5B-zhenwu-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/VibeThinker-1.5B-zhenwu-FlagOS

# 结论

- 发布镜像上传情况：V2 私有镜像已产出（因精度不达标，未对外发布）
- 流程自动化结论：❌ 迁移失败（V2 精度 40.0%/NV47.0，rel_drop 14.89% 超 5% 阈值，精度不达标；性能比 95.3%（合成基线）实测值）

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 平头哥(T-Head) (WeiboAI/VibeThinker-1.5B)
2. 【FR】Bug: Operator performance degradation on 平头哥(T-Head) (WeiboAI/VibeThinker-1.5B)

---

报告生成时间：2026.08.23