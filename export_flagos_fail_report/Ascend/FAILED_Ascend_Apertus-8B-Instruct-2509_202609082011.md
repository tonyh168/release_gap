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
| gems+tree版本上传时间 | 2026-09-03 11:36:39+00:00 |
| 发布时间 | 2026-09-03 11:36:39+00:00 |
| 模型 | Apertus-8B-Instruct-2509 |
| 模型领域 | 语言 |
| 权重来源 | swiss-ai/Apertus-8B-Instruct-2509 |
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
| 容器 | Apertus-8B-Instruct-2509_flagos |
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
    "exp",
    "expm1",
    "flatten",
    "gt_scalar",
    "lt_scalar",
    "minimum",
    "narrow",
    "rsqrt",
    "rsub_scalar",
    "sin",
    "softplus",
    "transpose",
    "unbind",
    "unsqueeze",
    "zero_"
]
```
### 算子替换列表（txt）
替换算子数：19
```json
[
    "_reshape_alias",
    "alias",
    "chunk",
    "cos",
    "exp",
    "expm1",
    "flatten",
    "gt_scalar",
    "lt_scalar",
    "minimum",
    "narrow",
    "rsqrt",
    "rsub_scalar",
    "sin",
    "softplus",
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
    "exp",
    "expm1",
    "flatten",
    "gt_scalar",
    "lt_scalar",
    "minimum",
    "narrow",
    "rsqrt",
    "rsub_scalar",
    "sin",
    "softplus",
    "transpose",
    "unbind",
    "unsqueeze",
    "zero_"
]
```
### 算子替换列表（txt）
替换算子数：19
```json
[
    "_reshape_alias",
    "alias",
    "chunk",
    "cos",
    "exp",
    "expm1",
    "flatten",
    "gt_scalar",
    "lt_scalar",
    "minimum",
    "narrow",
    "rsqrt",
    "rsub_scalar",
    "sin",
    "softplus",
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
| GPQA_Diamond | 50 | 22.0 | 19 |

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
| swiss-ai/Apertus-8B-Instruct-2509 | Ascend | - | 16 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| swiss-ai/Apertus-8B-Instruct-2509 | Ascend | - | 16 | - | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| swiss-ai/Apertus-8B-Instruct-2509 | Ascend | - | 16 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| swiss-ai/Apertus-8B-Instruct-2509 | Ascend | - | 16 | - | - | - | - | - | - | - | - |

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
| 流程耗时 | 3h 52m 39s |
| 流程消费 | 305.78 元（≈ $42.47 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：-
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/Apertus-8B-Instruct-2509-ascend-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Apertus-8B-Instruct-2509-ascend-FlagOS

# 结论

- 发布镜像上传正常：❌ 未产出对外镜像（V1 未产出精度基线，V2 精度相对 NV 参考基线 rel_drop 超阈值，性能未采集，不具备发布资格）
- 流程自动化结论：❌ 迁移失败（V1=none 无实测基线，V2 GPQA 22.0% 相对 NV 参考 rel_drop 超阈值；性能维度未产出数据）

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 华为(Ascend) (swiss-ai/Apertus-8B-Instruct-2509)
2. 【FR】Bug: Operator performance degradation on 华为(Ascend) (swiss-ai/Apertus-8B-Instruct-2509)

---

报告生成时间：2026.09.03