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
| 开始时间 | 2026-08-28 08:55:21 |
| gems+tree版本上传时间 | 2026-08-28 14:44:12 |
| 发布时间 | 2026-08-29 00:17:00 |
| 模型 | Phi-3-vision-128k-instruct |
| 模型领域 | 语言 |
| 权重来源 | microsoft/Phi-3-vision-128k-instruct |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0+g1326a3374 |
| FlagGems版本 | 5.3.4.post1.dev128 |
| Flagtree版本 | 0.6.0 |
| FlagCX版本 | - |
| 厂商 | 华为(Ascend) |
| GPU | 910C : 16 x -GB |
| 容器 | Phi-3-vision-128k-instruct_flagos |
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
    "[DEBUG] flag_gems.ops.alias.alias: GEMS ALIAS",
    "[DEBUG] flag_gems.ops.chunk.chunk: GEMS CHUNK",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.expand.expand: GEMS EXPAND",
    "[DEBUG] flag_gems.ops.flatten.flatten: GEMS FLATTEN",
    "[DEBUG] flag_gems.ops.ge.ge_scalar: GEMS GE SCALAR",
    "[DEBUG] flag_gems.ops.log_.log_: GEMS LOG_",
    "[DEBUG] flag_gems.ops.narrow.narrow: GEMS NARROW",
    "[DEBUG] flag_gems.ops.normal.normal_: GEMS NORMAL_",
    "[DEBUG] flag_gems.ops.randn.randn: GEMS RANDN",
    "[DEBUG] flag_gems.ops.repeat.repeat: GEMS REPEAT",
    "[DEBUG] flag_gems.ops.rsqrt.rsqrt: GEMS RSQRT",
    "[DEBUG] flag_gems.ops.silu.silu: GEMS SILU FORWARD",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.transpose.transpose: GEMS TRANSPOSE",
    "[DEBUG] flag_gems.ops.unbind.unbind: GEMS UNBIND",
    "[DEBUG] flag_gems.ops.uniform.uniform_: GEMS UNIFORM",
    "[DEBUG] flag_gems.ops.unsqueeze.unsqueeze: GEMS UNSQUEEZE",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_"
]
```
### 算子替换列表（txt）
替换算子数：20
```json
[
    "_reshape_alias",
    "alias",
    "chunk",
    "cos",
    "expand",
    "flatten",
    "ge_scalar",
    "log_",
    "narrow",
    "normal_",
    "randn",
    "repeat",
    "rsqrt",
    "silu",
    "sin",
    "transpose",
    "unbind",
    "uniform_",
    "unsqueeze",
    "zero_"
]
```

## V3
### 算子白名单
```json
"include": [
    "[DEBUG] flag_gems.ops.alias.alias: GEMS ALIAS",
    "[DEBUG] flag_gems.ops.chunk.chunk: GEMS CHUNK",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.expand.expand: GEMS EXPAND",
    "[DEBUG] flag_gems.ops.flatten.flatten: GEMS FLATTEN",
    "[DEBUG] flag_gems.ops.ge.ge_scalar: GEMS GE SCALAR",
    "[DEBUG] flag_gems.ops.log_.log_: GEMS LOG_",
    "[DEBUG] flag_gems.ops.narrow.narrow: GEMS NARROW",
    "[DEBUG] flag_gems.ops.normal.normal_: GEMS NORMAL_",
    "[DEBUG] flag_gems.ops.randn.randn: GEMS RANDN",
    "[DEBUG] flag_gems.ops.repeat.repeat: GEMS REPEAT",
    "[DEBUG] flag_gems.ops.rsqrt.rsqrt: GEMS RSQRT",
    "[DEBUG] flag_gems.ops.silu.silu: GEMS SILU FORWARD",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.transpose.transpose: GEMS TRANSPOSE",
    "[DEBUG] flag_gems.ops.unbind.unbind: GEMS UNBIND",
    "[DEBUG] flag_gems.ops.uniform.uniform_: GEMS UNIFORM",
    "[DEBUG] flag_gems.ops.unsqueeze.unsqueeze: GEMS UNSQUEEZE",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_"
]
```
### 算子替换列表（txt）
替换算子数：19
```json
[
    "[DEBUG] flag_gems.ops.alias.alias: GEMS ALIAS",
    "[DEBUG] flag_gems.ops.chunk.chunk: GEMS CHUNK",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.expand.expand: GEMS EXPAND",
    "[DEBUG] flag_gems.ops.flatten.flatten: GEMS FLATTEN",
    "[DEBUG] flag_gems.ops.ge.ge_scalar: GEMS GE SCALAR",
    "[DEBUG] flag_gems.ops.log_.log_: GEMS LOG_",
    "[DEBUG] flag_gems.ops.narrow.narrow: GEMS NARROW",
    "[DEBUG] flag_gems.ops.normal.normal_: GEMS NORMAL_",
    "[DEBUG] flag_gems.ops.randn.randn: GEMS RANDN",
    "[DEBUG] flag_gems.ops.repeat.repeat: GEMS REPEAT",
    "[DEBUG] flag_gems.ops.rsqrt.rsqrt: GEMS RSQRT",
    "[DEBUG] flag_gems.ops.silu.silu: GEMS SILU FORWARD",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.transpose.transpose: GEMS TRANSPOSE",
    "[DEBUG] flag_gems.ops.unbind.unbind: GEMS UNBIND",
    "[DEBUG] flag_gems.ops.uniform.uniform_: GEMS UNIFORM",
    "[DEBUG] flag_gems.ops.unsqueeze.unsqueeze: GEMS UNSQUEEZE",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_"
]
```

## V4
### 算子白名单
```json
"include": [
    "[DEBUG] flag_gems.ops.alias.alias: GEMS ALIAS",
    "[DEBUG] flag_gems.ops.chunk.chunk: GEMS CHUNK",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.expand.expand: GEMS EXPAND",
    "[DEBUG] flag_gems.ops.flatten.flatten: GEMS FLATTEN",
    "[DEBUG] flag_gems.ops.ge.ge_scalar: GEMS GE SCALAR",
    "[DEBUG] flag_gems.ops.log_.log_: GEMS LOG_",
    "[DEBUG] flag_gems.ops.narrow.narrow: GEMS NARROW",
    "[DEBUG] flag_gems.ops.normal.normal_: GEMS NORMAL_",
    "[DEBUG] flag_gems.ops.randn.randn: GEMS RANDN",
    "[DEBUG] flag_gems.ops.repeat.repeat: GEMS REPEAT",
    "[DEBUG] flag_gems.ops.rsqrt.rsqrt: GEMS RSQRT",
    "[DEBUG] flag_gems.ops.silu.silu: GEMS SILU FORWARD",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.transpose.transpose: GEMS TRANSPOSE",
    "[DEBUG] flag_gems.ops.unbind.unbind: GEMS UNBIND",
    "[DEBUG] flag_gems.ops.uniform.uniform_: GEMS UNIFORM",
    "[DEBUG] flag_gems.ops.unsqueeze.unsqueeze: GEMS UNSQUEEZE",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_"
]
```
### 算子替换列表（txt）
替换算子数：19
```json
[
    "alias",
    "chunk",
    "cos",
    "expand",
    "flatten",
    "ge_scalar",
    "log_",
    "narrow",
    "normal_",
    "randn",
    "repeat",
    "rsqrt",
    "silu",
    "sin",
    "transpose",
    "unbind",
    "uniform_",
    "unsqueeze",
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
| GPQA_Diamond | 50 | 28.0 | 19 |

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
| microsoft/Phi-3-vision-128k-instruct | Ascend | - | 16 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| microsoft/Phi-3-vision-128k-instruct | Ascend | - | 16 | - | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| microsoft/Phi-3-vision-128k-instruct | Ascend | - | 16 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| microsoft/Phi-3-vision-128k-instruct | Ascend | - | 16 | - | - | - | - | - | - | - | - |

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
| 流程耗时 | 7h 27m 31s |
| 流程消费 | 318.23 元（≈ $44.20 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/phi-3-vision-128k-instruct-ascend001-gems5.3.4-tree0.6.0-cxnone-plugin0.2.0-vllm-ascend0.20.2-cp311-ptnpu210-cann90-a64-25.5.0:202608282154-v2
  - V3：-
  - V4：harbor.baai.ac.cn/flagrelease-public/phi-3-vision-128k-instruct-ascend001-gems5.3.4-tree0.6.0-cxnone-plugin0.2.0-vllm-ascend0.20.2-cp311-ptnpu210-cann90-a64-25.5.0:202608290017-v4

- ModelScope: https://modelscope.cn/models/FlagRelease/Phi-3-vision-128k-instruct-ascend-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Phi-3-vision-128k-instruct-ascend-FlagOS

# 结论

- 发布镜像上传正常：❌ 未完成全部达标版本（V3=Max 未产出）
- 流程自动化结论：❌ 迁移失败（V3 未产出，存在性能退化 issue）

## 提交到 flagos 仓库的 Issue
issue 数量：1
issue 标题：
1. 【FR】Bug: Operator performance degradation on 华为(Ascend) (microsoft/Phi-3-vision-128k-instruct)

---

报告生成时间：2026.08.28