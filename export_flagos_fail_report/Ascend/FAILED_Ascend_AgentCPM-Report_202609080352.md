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
| 开始时间 | 2026-09-02 17:28:42 |
| gems+tree版本上传时间 | 2026-09-02 19:27:33 |
| 发布时间 | 2026-09-02 19:28:35 |
| 模型 | AgentCPM-Report |
| 模型领域 | 语言 |
| 权重来源 | openbmb/AgentCPM-Report |
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
| 容器 | AgentCPM-Report_flagos |
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
    "_reshape_alias",
    "alias",
    "chunk",
    "cos",
    "flatten",
    "narrow",
    "repeat",
    "rsqrt",
    "silu",
    "sin",
    "transpose",
    "unbind",
    "unsqueeze",
    "zero_"
]
```
### 算子替换列表（txt）
替换算子数：14
```json
[
    "_reshape_alias",
    "alias",
    "chunk",
    "cos",
    "flatten",
    "narrow",
    "repeat",
    "rsqrt",
    "silu",
    "sin",
    "transpose",
    "unbind",
    "unsqueeze",
    "zero_"
]
```

## V3
### 算子白名单
```json
"include": [
    "_reshape_alias",
    "alias",
    "chunk",
    "cos",
    "flatten",
    "narrow",
    "repeat",
    "rsqrt",
    "silu",
    "sin",
    "transpose",
    "unbind",
    "unsqueeze",
    "zero_"
]
```
### 算子替换列表（txt）
替换算子数：14
```json
[
    "_reshape_alias",
    "alias",
    "chunk",
    "cos",
    "flatten",
    "narrow",
    "repeat",
    "rsqrt",
    "silu",
    "sin",
    "transpose",
    "unbind",
    "unsqueeze",
    "zero_"
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
| openbmb/AgentCPM-Report | Ascend | - | 16 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| openbmb/AgentCPM-Report | Ascend | - | 16 | - | 2055.4 | 2514.1 | 561.4 | 2807.0 | 112.3 | 14 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| openbmb/AgentCPM-Report | Ascend | - | 16 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| openbmb/AgentCPM-Report | Ascend | - | 16 | - | - | - | - | - | - | - | - |

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
| 流程耗时 | 1h 59m 53s |
| 流程消费 | 88.59 元（≈ $12.30 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：-
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/AgentCPM-Report-ascend-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/AgentCPM-Report-ascend-FlagOS

# 结论

- 发布镜像上传正常：❌ 未产出对外镜像（精度评测被框架级 triton 编译崩溃阻断，无真实基线对比，不具备发布资格）
- 流程自动化结论：❌ 迁移失败（V1/V2 GPQA 评测在 apply_top_k_top_p_triton 处 MLIRCompilationError 崩溃，精度维度不可测；V2 性能 output 561.4 tok/s 基于合成基线，无实测 V1 对比）

## 提交到 flagos 仓库的 Issue
issue 数量：3
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 华为(Ascend) (openbmb/AgentCPM-Report)
2. 【FR】Bug: Operator crash on 华为(Ascend) (openbmb/AgentCPM-Report)
3. 【FR】Bug: Operator performance degradation on 华为(Ascend) (openbmb/AgentCPM-Report)

---

报告生成时间：2026.09.02