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
| 开始时间 | - |
| gems+tree版本上传时间 | - |
| 发布时间 | 2026.09.02 |
| 模型 | Fathom-R1-14B |
| 模型领域 | 语言 |
| 权重来源 | FractalAIResearch/Fathom-R1-14B |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0 |
| FlagGems版本 | 5.3.4 |
| Flagtree版本 | 0.6.0 |
| FlagCX版本 | - |
| 厂商 | 华为(Ascend) |
| GPU | 910C : 16 x 61GB |
| 容器 | Fathom-R1-14B_flagos |
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
    "zero_",
    "unsqueeze",
    "cos",
    "sin",
    "narrow",
    "rsqrt",
    "transpose",
    "flatten",
    "unbind",
    "chunk",
    "alias",
    "_reshape_alias",
    "silu",
    "uniform_",
    "ge_scalar",
    "expand",
    "log_"
]
```
### 算子替换列表（txt）
替换算子数：17
```json
[
    "zero_",
    "unsqueeze",
    "cos",
    "sin",
    "narrow",
    "rsqrt",
    "transpose",
    "flatten",
    "unbind",
    "chunk",
    "alias",
    "_reshape_alias",
    "silu",
    "uniform_",
    "ge_scalar",
    "expand",
    "log_"
]
```

## V3
### 算子白名单
```json
"include": [
    "zero_",
    "unsqueeze",
    "cos",
    "sin",
    "narrow",
    "rsqrt",
    "transpose",
    "flatten",
    "unbind",
    "chunk",
    "alias",
    "_reshape_alias",
    "silu",
    "uniform_",
    "ge_scalar",
    "expand",
    "log_"
]
```
### 算子替换列表（txt）
替换算子数：17
```json
[
    "zero_",
    "unsqueeze",
    "cos",
    "sin",
    "narrow",
    "rsqrt",
    "transpose",
    "flatten",
    "unbind",
    "chunk",
    "alias",
    "_reshape_alias",
    "silu",
    "uniform_",
    "ge_scalar",
    "expand",
    "log_"
]
```
> **说明**：V3 数据沿用 V2 结果（原始产物已回收，V3 与 V2 算子集一致）

## V4
### 算子白名单
（未执行 V4）

# 评测结果

## 精度评测

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| gpqa_diamond | - | - (无本地V1，基线NV) | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| gpqa_diamond | 50 | 0.0 | 17 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| gpqa_diamond | 50 | 0.0 | 17 |

> **说明**：V3 精度数据沿用 V2 结果（V2=V3 同镜像）

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| gpqa_diamond | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 精度不达标（V2=0.0% vs NV基线） |
| V1 VS V3 | 精度不达标（V3沿用V2结果） |
| V1 VS V4 | - |
| V2 VS V3 | V3 沿用 V2 结果 |

## 性能评测

> ⚠️ **性能基线为合成值，非实测 V1**：V2 初始性能 ×1.05（baseline_source: v2_initial_x1.05）。本报告所有以 V1 为基准的性能比均基于该合成基线。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| FractalAIResearch/Fathom-R1-14B | Ascend | - | 16 | - | - | - | - | 合成基线 | - | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| FractalAIResearch/Fathom-R1-14B | Ascend | - | 16 | - | - | - | - | - | - | 17 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| FractalAIResearch/Fathom-R1-14B | Ascend | - | 16 | - | - | - | - | - | - | 17 | - |

> **说明**：V3 性能数据沿用 V2 结果（V2=V3 同镜像）

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| FractalAIResearch/Fathom-R1-14B | Ascend | - | 16 | - | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 0.0% (vs 合成基线) |
| V1 VS V3 | V3 沿用 V2 结果 |
| V1 VS V4 | - |
| V2 VS V3 | V3 沿用 V2 结果 |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | - |
| 流程消费 | - |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：
  - V3：
  - V4：-

- ModelScope: 
- HuggingFace: 

# 结论

- 发布镜像上传正常：❌ 部分发布
- 流程自动化结论：❌ 迁移失败（V2 精度0.0%，精度不达标；性能比0.0%，性能不达标）

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 华为(Ascend) (FractalAIResearch/Fathom-R1-14B)
2. 【FR】Bug: Operator performance degradation on 华为(Ascend) (FractalAIResearch/Fathom-R1-14B)

---

报告生成时间：2026.09.02
