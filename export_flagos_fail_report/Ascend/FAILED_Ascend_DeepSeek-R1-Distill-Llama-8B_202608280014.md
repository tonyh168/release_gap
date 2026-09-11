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
| gems+tree版本上传时间 | 2026-08-27 15:36:11 |
| 发布时间 | 2026-08-28 00:14:00 |
| 模型 | DeepSeek-R1-Distill-Llama-8B |
| 模型领域 | 语言 |
| 权重来源 | deepseek-ai/DeepSeek-R1-Distill-Llama-8B |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0+g1326a3374 |
| FlagGems版本 | 5.3.4.post1.dev128 |
| Flagtree版本 | 0.6.0 |
| FlagCX版本 | - |
| 厂商 | 华为(Ascend) |
| GPU | 910C : 8 x 64GB |
| 容器 | DeepSeek-R1-Distill-Llama-8B_flagos |
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
    "cumsum_out",
    "expand",
    "flatten",
    "ge_scalar",
    "gt_scalar",
    "le",
    "log_",
    "lt_scalar",
    "narrow",
    "rsqrt",
    "rsub_scalar",
    "scalar_tensor",
    "silu",
    "sin",
    "transpose",
    "unbind",
    "uniform_",
    "unsqueeze",
    "zero_"
]
```
### 算子替换列表（txt）
替换算子数：23
```json
[
    "_reshape_alias",
    "alias",
    "chunk",
    "cos",
    "cumsum_out",
    "expand",
    "flatten",
    "ge_scalar",
    "gt_scalar",
    "le",
    "log_",
    "lt_scalar",
    "narrow",
    "rsqrt",
    "rsub_scalar",
    "scalar_tensor",
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
    "[DEBUG] flag_gems.ops._reshape_alias._reshape_alias: GEMS _RESHAPE_ALIAS",
    "[DEBUG] flag_gems.ops.alias.alias: GEMS ALIAS",
    "[DEBUG] flag_gems.ops.chunk.chunk: GEMS CHUNK",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.cumsum.cumsum_out: GEMS CUMSUM_OUT",
    "[DEBUG] flag_gems.ops.expand.expand: GEMS EXPAND",
    "[DEBUG] flag_gems.ops.flatten.flatten: GEMS FLATTEN",
    "[DEBUG] flag_gems.ops.ge.ge_scalar: GEMS GE SCALAR",
    "[DEBUG] flag_gems.ops.gt.gt_scalar: GEMS GT SCALAR",
    "[DEBUG] flag_gems.ops.le.le: GEMS LE",
    "[DEBUG] flag_gems.ops.log_.log_: GEMS LOG_",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.narrow.narrow: GEMS NARROW",
    "[DEBUG] flag_gems.ops.rsqrt.rsqrt: GEMS RSQRT",
    "[DEBUG] flag_gems.ops.rsub.rsub_scalar: GEMS RSUB_SCALAR",
    "[DEBUG] flag_gems.ops.scalar_tensor.scalar_tensor: GEMS SCALAR_TENSOR",
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
替换算子数：23
```json
[
    "[DEBUG] flag_gems.ops._reshape_alias._reshape_alias: GEMS _RESHAPE_ALIAS",
    "[DEBUG] flag_gems.ops.alias.alias: GEMS ALIAS",
    "[DEBUG] flag_gems.ops.chunk.chunk: GEMS CHUNK",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.cumsum.cumsum_out: GEMS CUMSUM_OUT",
    "[DEBUG] flag_gems.ops.expand.expand: GEMS EXPAND",
    "[DEBUG] flag_gems.ops.flatten.flatten: GEMS FLATTEN",
    "[DEBUG] flag_gems.ops.ge.ge_scalar: GEMS GE SCALAR",
    "[DEBUG] flag_gems.ops.gt.gt_scalar: GEMS GT SCALAR",
    "[DEBUG] flag_gems.ops.le.le: GEMS LE",
    "[DEBUG] flag_gems.ops.log_.log_: GEMS LOG_",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.narrow.narrow: GEMS NARROW",
    "[DEBUG] flag_gems.ops.rsqrt.rsqrt: GEMS RSQRT",
    "[DEBUG] flag_gems.ops.rsub.rsub_scalar: GEMS RSUB_SCALAR",
    "[DEBUG] flag_gems.ops.scalar_tensor.scalar_tensor: GEMS SCALAR_TENSOR",
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
    "[DEBUG] flag_gems.ops._reshape_alias._reshape_alias: GEMS _RESHAPE_ALIAS",
    "[DEBUG] flag_gems.ops.alias.alias: GEMS ALIAS",
    "[DEBUG] flag_gems.ops.chunk.chunk: GEMS CHUNK",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.cumsum.cumsum_out: GEMS CUMSUM_OUT",
    "[DEBUG] flag_gems.ops.expand.expand: GEMS EXPAND",
    "[DEBUG] flag_gems.ops.flatten.flatten: GEMS FLATTEN",
    "[DEBUG] flag_gems.ops.ge.ge_scalar: GEMS GE SCALAR",
    "[DEBUG] flag_gems.ops.gt.gt_scalar: GEMS GT SCALAR",
    "[DEBUG] flag_gems.ops.le.le: GEMS LE",
    "[DEBUG] flag_gems.ops.log_.log_: GEMS LOG_",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.narrow.narrow: GEMS NARROW",
    "[DEBUG] flag_gems.ops.rsqrt.rsqrt: GEMS RSQRT",
    "[DEBUG] flag_gems.ops.rsub.rsub_scalar: GEMS RSUB_SCALAR",
    "[DEBUG] flag_gems.ops.scalar_tensor.scalar_tensor: GEMS SCALAR_TENSOR",
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
替换算子数：23
```json
[
    "_reshape_alias",
    "alias",
    "chunk",
    "cos",
    "cumsum_out",
    "expand",
    "flatten",
    "ge_scalar",
    "gt_scalar",
    "le",
    "log_",
    "lt_scalar",
    "narrow",
    "rsqrt",
    "rsub_scalar",
    "scalar_tensor",
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
| GPQA_Diamond | 30 | 40.0 | 23 |

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
| deepseek-ai/DeepSeek-R1-Distill-Llama-8B | Ascend | - | 8 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| deepseek-ai/DeepSeek-R1-Distill-Llama-8B | Ascend | - | 8 | - | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| deepseek-ai/DeepSeek-R1-Distill-Llama-8B | Ascend | - | 8 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| deepseek-ai/DeepSeek-R1-Distill-Llama-8B | Ascend | - | 8 | - | - | - | - | - | - | 23 | - |

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
| 流程耗时 | 6h 36m 46s |
| 流程消费 | 448.49 元（≈ $62.29 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/deepseek-r1-distill-llama-8b-ascend001-gems5.3.4-tree0.6.0-cxnone-plugin0.2.0-vllm-ascend0.20.2-cp311-ptnpu210-cann90-a64-25.5.0:202608272319-v2
  - V3：-
  - V4：harbor.baai.ac.cn/flagrelease-public/deepseek-r1-distill-llama-8b-ascend001-gems5.3.4-tree0.6.0-cxnone-plugin0.2.0-vllm-ascend0.20.2-cp311-ptnpu210-cann90-a64-25.5.0:202608280014-v4

- ModelScope: https://modelscope.cn/models/FlagRelease/DeepSeek-R1-Distill-Llama-8B-ascend-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/DeepSeek-R1-Distill-Llama-8B-ascend-FlagOS

# 结论

- 发布镜像上传正常：❌ 未产出达标镜像（服务输出乱码，未通过冒烟验证）
- 流程自动化结论：❌ 迁移失败（vLLM 服务输出乱码，tokenizer 解码异常，未通过冒烟测试）

## 提交到 flagos 仓库的 Issue
issue 数量：1
issue 标题：
1. 【FR】Bug: Garbled service output (tokenizer decode error) on 华为(Ascend) (deepseek-ai/DeepSeek-R1-Distill-Llama-8B)

---

报告生成时间：2026.08.27