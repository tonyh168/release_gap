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
| 开始时间 | 2026-08-28 06:44:06 |
| gems+tree版本上传时间 | 2026-08-28 13:46:58 |
| 发布时间 | 2026-08-28 13:47:51 |
| 模型 | OpenMath-Nemotron-14B-Kaggle |
| 模型领域 | 语言 |
| 权重来源 | nvidia/OpenMath-Nemotron-14B-Kaggle |
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
```json
"include": [
    "add",
    "arange",
    "argmax",
    "cat",
    "cos",
    "cumsum",
    "div",
    "expand",
    "full",
    "index",
    "le",
    "linear",
    "lt",
    "masked_fill",
    "mm",
    "ones",
    "rand_like",
    "reciprocal",
    "rsub",
    "scatter",
    "sin",
    "softmax",
    "sub",
    "sum",
    "to",
    "where",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：27
```json
[
    "add",
    "arange",
    "argmax",
    "cat",
    "cos",
    "cumsum",
    "div",
    "expand",
    "full",
    "index",
    "le",
    "linear",
    "lt",
    "masked_fill",
    "mm",
    "ones",
    "rand_like",
    "reciprocal",
    "rsub",
    "scatter",
    "sin",
    "softmax",
    "sub",
    "sum",
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
    "cat",
    "cos",
    "cumsum",
    "div",
    "expand",
    "full",
    "index",
    "le",
    "linear",
    "lt",
    "masked_fill",
    "mm",
    "ones",
    "rand_like",
    "reciprocal",
    "rsub",
    "scatter",
    "sin",
    "softmax",
    "sub",
    "sum",
    "to",
    "where",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：27
```json
[
    "add",
    "arange",
    "argmax",
    "cat",
    "cos",
    "cumsum",
    "div",
    "expand",
    "full",
    "index",
    "le",
    "linear",
    "lt",
    "masked_fill",
    "mm",
    "ones",
    "rand_like",
    "reciprocal",
    "rsub",
    "scatter",
    "sin",
    "softmax",
    "sub",
    "sum",
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

> 精度基线：无独立 V1、无 NV 参考，观察记录（30 题）。
### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - (V1=none, 观察模式) | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 30 | 40.0 | 27 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 30 | 40.0 | 27 |

> V3=V2 同镜像（沿用 V2 结果）

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 无独立 V1（观察模式）：V2 GPQA_Diamond 40.0%（30题，无 NV 参考） |
| V1 VS V3 | 沿用 V2 结果：V3 GPQA_Diamond 40.0%（30题） |
| V1 VS V4 | -（未执行 V4） |
| V2 VS V3 | V2=V3 同镜像：GPQA_Diamond 40.0%（30题）（沿用 V2 结果） |

## 性能评测

> ⚠️ **性能基线为合成值，非实测 V1**：V2 初始性能 ×1.05（baseline_source: v2_initial_x1.05，target_ratio_override=1.0）。本报告所有以 V1 为基准的性能比均基于该合成基线。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| nvidia/OpenMath-Nemotron-14B-Kaggle | Hygon | - | 8 | - | - | - | - | - | - | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| nvidia/OpenMath-Nemotron-14B-Kaggle | Hygon | - | 8 | - | 77966.5 | 176830.36 | 256.8 | 1284.1 | 117.7 | 27 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| nvidia/OpenMath-Nemotron-14B-Kaggle | Hygon | - | 8 | - | 77966.5 | 176830.36 | 256.8 | 1284.1 | 117.7 | 27 | - |

> V3=V2 同镜像（沿用 V2 结果）

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| nvidia/OpenMath-Nemotron-14B-Kaggle | Hygon | - | 8 | - | - | - | - | - | - | - | - |


### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 95.8%（vs 合成基线 V2 初测×1.05） |
| V1 VS V3 | 沿用 V2 结果：性能比 95.8%（vs 合成基线） |
| V1 VS V4 | -（未执行 V4） |
| V2 VS V3 | V2=V3 同镜像（沿用 V2 结果） |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 7h 3m 45s |
| 流程消费 | 365.35 元（≈ $50.74 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/openmath-nemotron-14b-kaggle-hygon001-gems5.4.0-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp310-pt210-dtknone-x64-6.3.28-v1.3.0b:202608282141-v2
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/OpenMath-Nemotron-14B-Kaggle-hygon-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/OpenMath-Nemotron-14B-Kaggle-hygon-FlagOS

# 结论

- 发布镜像上传正常：❌ 未完成对外发布（Harbor 已推送，权重/README 未对外发布）
- 流程自动化结论：❌ 迁移失败（V2 GPQA_Diamond 40.0%（30题，无 NV 参考）；性能比 95.8%（vs 合成基线））

## 提交到 flagos 仓库的 Issue
issue 数量：3
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 海光(Hygon) (nvidia/OpenMath-Nemotron-14B-Kaggle)
2. 【FR】Bug: Operator crash: addmm, broadcast_to, copy on 海光(Hygon) (nvidia/OpenMath-Nemotron-14B-Kaggle)
3. 【FR】Bug: Operator performance degradation on 海光(Hygon) (nvidia/OpenMath-Nemotron-14B-Kaggle)

---

报告生成时间：2026.08.28
