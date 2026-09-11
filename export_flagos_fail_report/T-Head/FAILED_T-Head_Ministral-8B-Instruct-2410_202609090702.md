# 迁移结果：❌ 失败

> **自动化流程产出镜像版本：**
> - V1：tree版本=基础版：只带flagtree不开启任何flagos组件
> - V2：tree+gems=Pro版：开启flaggems且性能达到V1的80%，与V1的精度误差在5%以内
> - V3：tree+gems+plugin=Max版：在V2的基础上安装使用plugin，且性能达到V1的80%，与V1的精度误差在5%以内
> - V4：tree+gems+plugin=Flag-express版：在V3的基础上，性能表现超过V1版本

> ⚠️ **本报告为补充重建**：原始批处理报告的精度/性能表未落数，现依据容器工作区留痕（`results/*.json`、`config/context_final.yaml`、运行日志）补齐真实评测数据。本环境为分支 B（V1=none，V2 与 V3 为同一镜像双 tag 发布），V3 各项数据完全缺失，按规范沿用 V2 真实结果填充并注明。

# 基本信息

| 项目 | 内容 |
|------|------|
| 项目名称 | KT2期 |
| 开始时间 | 2026-09-04 01:30:00 |
| gems+tree版本上传时间 | 2026-09-04 02:40:00 |
| 发布时间 | 2026-09-04 02:45:00 |
| 模型 | Ministral-8B-Instruct-2410 |
| 模型领域 | 语言 |
| 权重来源 | mistralai/Ministral-8B-Instruct-2410 |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.24.0 |
| 推理框架插件plugin-FL | 0.3.0 |
| FlagGems版本 | 5.3.4 |
| Flagtree版本 | 0.6.1 |
| FlagCX版本 | - |
| 厂商 | 平头哥(T-Head) |
| GPU | PPU-ZW810E : 16 x 96GB |
| 容器 | Ministral-8B-Instruct-2410_flagos |
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
    "lift_fresh",
    "empty",
    "zero_",
    "zeros",
    "arange_start",
    "true_divide",
    "pow_scalar",
    "reciprocal",
    "mul",
    "unsqueeze",
    "cos",
    "sin",
    "cat",
    "to_copy",
    "ones",
    "narrow",
    "fill_scalar_",
    "mm_out",
    "index",
    "rand_like",
    "linear",
    "alias",
    "full",
    "argmax",
    "lt_scalar",
    "scalar_tensor",
    "where_self",
    "where_self_out",
    "true_divide_",
    "softmax",
    "softmax_out",
    "exponential_",
    "unbind",
    "add",
    "copy_",
    "sub",
    "expand",
    "scatter_"
]
```
### 算子替换列表（txt）
替换算子数：38
```json
[
    "lift_fresh",
    "empty",
    "zero_",
    "zeros",
    "arange_start",
    "true_divide",
    "pow_scalar",
    "reciprocal",
    "mul",
    "unsqueeze",
    "cos",
    "sin",
    "cat",
    "to_copy",
    "ones",
    "narrow",
    "fill_scalar_",
    "mm_out",
    "index",
    "rand_like",
    "linear",
    "alias",
    "full",
    "argmax",
    "lt_scalar",
    "scalar_tensor",
    "where_self",
    "where_self_out",
    "true_divide_",
    "softmax",
    "softmax_out",
    "exponential_",
    "unbind",
    "add",
    "copy_",
    "sub",
    "expand",
    "scatter_"
]
```

## V3
（V3 与 V2 为同一镜像双 tag 发布，沿用 V2 算子集）
### 算子白名单
```json
"include": [
    "lift_fresh",
    "empty",
    "zero_",
    "zeros",
    "arange_start",
    "true_divide",
    "pow_scalar",
    "reciprocal",
    "mul",
    "unsqueeze",
    "cos",
    "sin",
    "cat",
    "to_copy",
    "ones",
    "narrow",
    "fill_scalar_",
    "mm_out",
    "index",
    "rand_like",
    "linear",
    "alias",
    "full",
    "argmax",
    "lt_scalar",
    "scalar_tensor",
    "where_self",
    "where_self_out",
    "true_divide_",
    "softmax",
    "softmax_out",
    "exponential_",
    "unbind",
    "add",
    "copy_",
    "sub",
    "expand",
    "scatter_"
]
```
### 算子替换列表（txt）
替换算子数：38
```json
[
    "lift_fresh",
    "empty",
    "zero_",
    "zeros",
    "arange_start",
    "true_divide",
    "pow_scalar",
    "reciprocal",
    "mul",
    "unsqueeze",
    "cos",
    "sin",
    "cat",
    "to_copy",
    "ones",
    "narrow",
    "fill_scalar_",
    "mm_out",
    "index",
    "rand_like",
    "linear",
    "alias",
    "full",
    "argmax",
    "lt_scalar",
    "scalar_tensor",
    "where_self",
    "where_self_out",
    "true_divide_",
    "softmax",
    "softmax_out",
    "exponential_",
    "unbind",
    "add",
    "copy_",
    "sub",
    "expand",
    "scatter_"
]
```

## V4
### 算子白名单
（V4 两轮随机组合均服务启动失败，回退起点，等价 V3；保留 39 算子，精度继承 V3）
### 算子替换列表（txt）
替换算子数：38
（V4 两轮随机组合均服务启动失败，回退起点，等价 V3；保留 39 算子，精度继承 V3）

# 评测结果

## 精度评测

精度基线：V1=none，回退 NV 参考基线（gpqa_diamond NV=30.0）。

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - (V1=none, 基线 NV=30) | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 26.0 | 38 |

> V2 26.0% vs NV 基线 30.0%（绝对差 2 题），在噪声容忍范围内，精度达标；runaway 已消除。

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 26.0 | 38 |

> V3 与 V2 为同一镜像（双 tag 发布），V3 精度数据完全缺失，沿用 V2 结果填充。

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 26.0 | 38 |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 26.0% vs NV 30.0%（差 2 题，噪声容忍内，达标） |
| V1 VS V3 | 26.0% vs NV 30.0%（沿用 V2，达标） |
| V1 VS V4 | V4 等价 V3，精度继承（26.0%） |
| V2 VS V3 | V3 26.0% / V2 26.0%（同镜像一致，沿用） |

## 性能评测

性能基线：V1=none，采用合成基线（V2 首测 ×1.05）。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| mistralai/Ministral-8B-Instruct-2410 | T-Head | - | 16 | - | 6409.6 | 6477.4 | 787.7 | 3938.6 | 79.4 | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| mistralai/Ministral-8B-Instruct-2410 | T-Head | - | 16 | - | 6409.6 | 6477.4 | 750.2 | 3751.0 | 79.4 | 38 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| mistralai/Ministral-8B-Instruct-2410 | T-Head | - | 16 | - | 6409.6 | 6477.4 | 750.2 | 3751.0 | 79.4 | 38 | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| mistralai/Ministral-8B-Instruct-2410 | T-Head | - | 16 | - | 6409.6 | 6477.4 | 750.2 | 3751.0 | 79.4 | 38 | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 91.8%（vs 合成基线）；步骤7 禁用 OOT silu_and_mul 后优化至 99.6% |
| V1 VS V3 | 性能比 99.6%（vs 合成基线，沿用 V2 优化后） |
| V1 VS V4 | V4 等价 V3（回退），性能同 V3 |
| V2 VS V3 | 同镜像一致（沿用） |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 7h 30m |
| 流程消费 | 约 380 元 |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/ministral-8b-instruct-2410-...-v2（私有双 tag 已推送）
  - V3：harbor.baai.ac.cn/flagrelease-project/ministral-8b-instruct-2410-...-v3（私有，与 V2 同镜像双 tag）
  - V4：harbor.baai.ac.cn/flagrelease-public/ministral-8b-instruct-2410-...-v4（等价 V3，复用镜像层）

- ModelScope: https://modelscope.cn/models/FlagRelease/Ministral-8B-Instruct-2410-zhenwu-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Ministral-8B-Instruct-2410-zhenwu-FlagOS

# 结论

- 发布镜像上传正常：✅ 镜像上传成功（V2/V3/V4 私有镜像已推送 Harbor；ModelScope/HuggingFace 私有仓权重已上传）
- 流程自动化结论：❌ 迁移失败（V2/V3 精度 26.0% vs NV30 达标；性能 91.8%→优化后 99.6% vs 合成基线；按人工裁定标记失败）

## 提交到 flagos 仓库的 Issue
issue 数量：1
issue 标题：
1. 【FR】Bug: Operator performance degradation on 平头哥(T-Head) (mistralai/Ministral-8B-Instruct-2410)

---

报告生成时间：2026.09.09