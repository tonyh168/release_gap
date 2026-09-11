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
| 开始时间 | 2026-08-26 09:57:38 |
| gems+tree版本上传时间 | 2026-08-26 15:57:09 |
| 发布时间 | 2026-08-26 15:57:56 |
| 模型 | Arcee-Blitz |
| 模型领域 | 语言 |
| 权重来源 | arcee-ai/Arcee-Blitz |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0 |
| FlagGems版本 | 5.4.0dev |
| Flagtree版本 | 0.6.0 |
| FlagCX版本 | - |
| 厂商 | 海光(Hygon) |
| GPU | DCU BW1000 : 8 x 64GB |
| 容器 | Arcee-Blitz_flagos |
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
    "arange",
    "argmax",
    "attention_backend",
    "copy",
    "cos",
    "div",
    "expand",
    "full",
    "index",
    "linear",
    "lt",
    "mm",
    "ones",
    "rand_like",
    "randn",
    "reciprocal",
    "sin",
    "softmax",
    "sub",
    "to",
    "where",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：23
```json
[
    "add",
    "arange",
    "argmax",
    "attention_backend",
    "copy",
    "cos",
    "div",
    "expand",
    "full",
    "index",
    "linear",
    "lt",
    "mm",
    "ones",
    "rand_like",
    "randn",
    "reciprocal",
    "sin",
    "softmax",
    "sub",
    "to",
    "where",
    "zeros"
]
```


## V3
### 算子白名单
```json
"include": [
    "add",
    "arange",
    "argmax",
    "attention_backend",
    "copy",
    "cos",
    "div",
    "expand",
    "full",
    "index",
    "linear",
    "lt",
    "mm",
    "ones",
    "rand_like",
    "randn",
    "reciprocal",
    "sin",
    "softmax",
    "sub",
    "to",
    "where",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：23
```json
[
    "add",
    "arange",
    "argmax",
    "attention_backend",
    "copy",
    "cos",
    "div",
    "expand",
    "full",
    "index",
    "linear",
    "lt",
    "mm",
    "ones",
    "rand_like",
    "randn",
    "reciprocal",
    "sin",
    "softmax",
    "sub",
    "to",
    "where",
    "zeros"
]
```
（V3=V2 同镜像，沿用 V2 结果）

## V4
### 算子白名单
（未执行 V4）
### 算子替换列表（txt）
替换算子数：0
（未执行 V4）

# 评测结果

## 精度评测

> 精度基线：无独立 V1，与 NV 参考（官方 HF 模型卡）对比，观察记录（50 题）。
### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - (V1=none, 观察模式) | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 36.0 | 23 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 36.0 | 23 |

> V3=V2 同镜像（沿用 V2 结果）

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 无独立 V1（观察模式）：V2 GPQA_Diamond 36.0%（50题，NV 参考 43.1，rel_drop 16.47%） |
| V1 VS V3 | 沿用 V2 结果：V3 GPQA_Diamond 36.0%（50题） |
| V1 VS V4 | -（未执行 V4） |
| V2 VS V3 | V2=V3 同镜像：GPQA_Diamond 36.0%（50题）（沿用 V2 结果） |

## 性能评测

> ⚠️ **性能基线为合成值，非实测 V1**：V2 初始性能 ×1.05（baseline_source: v2_initial_x1.05，target_ratio_override=1.0）。本报告所有以 V1 为基准的性能比均基于该合成基线。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| arcee-ai/Arcee-Blitz | Hygon | - | 8 | - | - | - | - | - | - | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| arcee-ai/Arcee-Blitz | Hygon | - | 8 | - | 137576.9 | 338779.45 | 168.1 | 840.6 | 102.7 | 23 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| arcee-ai/Arcee-Blitz | Hygon | - | 8 | - | 137576.9 | 338779.45 | 168.1 | 840.6 | 102.7 | 23 | - |

> V3=V2 同镜像（沿用 V2 结果）

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| arcee-ai/Arcee-Blitz | Hygon | - | 8 | - | - | - | - | - | - | - | - |


### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 95.0%（vs 合成基线 V2 初测×1.05）（调优后） |
| V1 VS V3 | 沿用 V2 结果：性能比 95.0%（vs 合成基线） |
| V1 VS V4 | -（未执行 V4） |
| V2 VS V3 | V2=V3 同镜像（沿用 V2 结果） |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 6h 0m 18s |
| 流程消费 | 250.35 元（≈ $34.77 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：-
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/Arcee-Blitz-hygon-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Arcee-Blitz-hygon-FlagOS

# 结论

- 发布镜像上传正常：❌ 未完成对外发布（Harbor 已推送，权重/README 未对外发布）
- 流程自动化结论：❌ 迁移失败（V2 GPQA_Diamond 36.0%（50题，NV 参考 43.1，rel_drop 16.47%）；性能比 95.0%（vs 合成基线））

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 海光(Hygon) (arcee-ai/Arcee-Blitz)
2. 【FR】Bug: Operator performance degradation on 海光(Hygon) (arcee-ai/Arcee-Blitz)

---

报告生成时间：2026.08.26
