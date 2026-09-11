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
| 开始时间 | 2026-08-08 15:24:07 |
| gems+tree版本上传时间 | - |
| 发布时间 | 2026-08-09 02:56:00 |
| 模型 | Ministral-8B-Instruct-2410 |
| 模型领域 | 语言 |
| 权重来源 | mistralai/Ministral-8B-Instruct-2410 |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0+gd1653d9ff |
| FlagGems版本 | 5.0.0 |
| Flagtree版本 | 0.6.1 |
| FlagCX版本 | - |
| 厂商 | 天数(Iluvatar) |
| GPU | BI-V150 : 16 x -GB |
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
（无数据）
### 算子替换列表（txt）
替换算子数：0
（无数据）

## V3
### 算子白名单
```json
"include": [
    "flag_gems.fused.fused_add_rms_norm",
    "flag_gems.fused.reshape_and_cache_flash",
    "flag_gems.fused.rotary_embedding",
    "flag_gems.fused.silu_and_mul",
    "flag_gems.modules.activation",
    "flag_gems.modules.normalization",
    "flag_gems.modules.rotary_embedding",
    "flag_gems.ops.add",
    "flag_gems.ops.arange",
    "flag_gems.ops.argmax",
    "flag_gems.ops.attention",
    "flag_gems.ops.cat",
    "flag_gems.ops.copy",
    "flag_gems.ops.cos",
    "flag_gems.ops.div",
    "flag_gems.ops.embedding",
    "flag_gems.ops.exponential_",
    "flag_gems.ops.fill",
    "flag_gems.ops.flash_api",
    "flag_gems.ops.full",
    "flag_gems.ops.index",
    "flag_gems.ops.lt",
    "flag_gems.ops.masked_fill",
    "flag_gems.ops.mm",
    "flag_gems.ops.mul",
    "flag_gems.ops.ones",
    "flag_gems.ops.pow",
    "flag_gems.ops.rand_like",
    "flag_gems.ops.reciprocal",
    "flag_gems.ops.rms_norm",
    "flag_gems.ops.scatter",
    "flag_gems.ops.sin",
    "flag_gems.ops.softmax",
    "flag_gems.ops.sub",
    "flag_gems.ops.to",
    "flag_gems.ops.where",
    "flag_gems.ops.zeros",
    "vllm_fl.dispatch.ops.attention_backend",
    "vllm_fl.dispatch.ops.rms_norm",
    "vllm_fl.dispatch.ops.rotary_embedding",
    "vllm_fl.dispatch.ops.silu_and_mul"
]
```
### 算子替换列表（txt）
替换算子数：41
```json
[
    "flag_gems.fused.fused_add_rms_norm",
    "flag_gems.fused.reshape_and_cache_flash",
    "flag_gems.fused.rotary_embedding",
    "flag_gems.fused.silu_and_mul",
    "flag_gems.modules.activation",
    "flag_gems.modules.normalization",
    "flag_gems.modules.rotary_embedding",
    "flag_gems.ops.add",
    "flag_gems.ops.arange",
    "flag_gems.ops.argmax",
    "flag_gems.ops.attention",
    "flag_gems.ops.cat",
    "flag_gems.ops.copy",
    "flag_gems.ops.cos",
    "flag_gems.ops.div",
    "flag_gems.ops.embedding",
    "flag_gems.ops.exponential_",
    "flag_gems.ops.fill",
    "flag_gems.ops.flash_api",
    "flag_gems.ops.full",
    "flag_gems.ops.index",
    "flag_gems.ops.lt",
    "flag_gems.ops.masked_fill",
    "flag_gems.ops.mm",
    "flag_gems.ops.mul",
    "flag_gems.ops.ones",
    "flag_gems.ops.pow",
    "flag_gems.ops.rand_like",
    "flag_gems.ops.reciprocal",
    "flag_gems.ops.rms_norm",
    "flag_gems.ops.scatter",
    "flag_gems.ops.sin",
    "flag_gems.ops.softmax",
    "flag_gems.ops.sub",
    "flag_gems.ops.to",
    "flag_gems.ops.where",
    "flag_gems.ops.zeros",
    "vllm_fl.dispatch.ops.attention_backend",
    "vllm_fl.dispatch.ops.rms_norm",
    "vllm_fl.dispatch.ops.rotary_embedding",
    "vllm_fl.dispatch.ops.silu_and_mul"
]
```

## V4
### 算子白名单
```json
"include": [
    "flag_gems.fused.fused_add_rms_norm",
    "flag_gems.fused.reshape_and_cache_flash",
    "flag_gems.fused.rotary_embedding",
    "flag_gems.fused.silu_and_mul",
    "flag_gems.modules.activation",
    "flag_gems.modules.normalization",
    "flag_gems.modules.rotary_embedding",
    "flag_gems.ops.add",
    "flag_gems.ops.arange",
    "flag_gems.ops.argmax",
    "flag_gems.ops.attention",
    "flag_gems.ops.cat",
    "flag_gems.ops.copy",
    "flag_gems.ops.cos",
    "flag_gems.ops.div",
    "flag_gems.ops.embedding",
    "flag_gems.ops.exponential_",
    "flag_gems.ops.fill",
    "flag_gems.ops.flash_api",
    "flag_gems.ops.full",
    "flag_gems.ops.index",
    "flag_gems.ops.lt",
    "flag_gems.ops.masked_fill",
    "flag_gems.ops.mm",
    "flag_gems.ops.mul",
    "flag_gems.ops.ones",
    "flag_gems.ops.pow",
    "flag_gems.ops.rand_like",
    "flag_gems.ops.reciprocal",
    "flag_gems.ops.rms_norm",
    "flag_gems.ops.scatter",
    "flag_gems.ops.sin",
    "flag_gems.ops.softmax",
    "flag_gems.ops.sub",
    "flag_gems.ops.to",
    "flag_gems.ops.where",
    "flag_gems.ops.zeros",
    "vllm_fl.dispatch.ops.attention_backend",
    "vllm_fl.dispatch.ops.rms_norm",
    "vllm_fl.dispatch.ops.rotary_embedding",
    "vllm_fl.dispatch.ops.silu_and_mul"
]
```
### 算子替换列表（txt）
替换算子数：41
```json
[
    "flag_gems.fused.fused_add_rms_norm",
    "flag_gems.fused.reshape_and_cache_flash",
    "flag_gems.fused.rotary_embedding",
    "flag_gems.fused.silu_and_mul",
    "flag_gems.modules.activation",
    "flag_gems.modules.normalization",
    "flag_gems.modules.rotary_embedding",
    "flag_gems.ops.add",
    "flag_gems.ops.arange",
    "flag_gems.ops.argmax",
    "flag_gems.ops.attention",
    "flag_gems.ops.cat",
    "flag_gems.ops.copy",
    "flag_gems.ops.cos",
    "flag_gems.ops.div",
    "flag_gems.ops.embedding",
    "flag_gems.ops.exponential_",
    "flag_gems.ops.fill",
    "flag_gems.ops.flash_api",
    "flag_gems.ops.full",
    "flag_gems.ops.index",
    "flag_gems.ops.lt",
    "flag_gems.ops.masked_fill",
    "flag_gems.ops.mm",
    "flag_gems.ops.mul",
    "flag_gems.ops.ones",
    "flag_gems.ops.pow",
    "flag_gems.ops.rand_like",
    "flag_gems.ops.reciprocal",
    "flag_gems.ops.rms_norm",
    "flag_gems.ops.scatter",
    "flag_gems.ops.sin",
    "flag_gems.ops.softmax",
    "flag_gems.ops.sub",
    "flag_gems.ops.to",
    "flag_gems.ops.where",
    "flag_gems.ops.zeros",
    "vllm_fl.dispatch.ops.attention_backend",
    "vllm_fl.dispatch.ops.rms_norm",
    "vllm_fl.dispatch.ops.rotary_embedding",
    "vllm_fl.dispatch.ops.silu_and_mul"
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
| GPQA_Diamond | 50 | 28.0 | - |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 28.0 | 41 |

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
| V2 VS V3 | 精度偏差 0.0% |

## 性能评测

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| mistralai/Ministral-8B-Instruct-2410 | 天数(Iluvatar) | - | 16 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| mistralai/Ministral-8B-Instruct-2410 | 天数(Iluvatar) | - | 16 | - | 11967.1 | 15437.3 | 342.0 | 1709.9 | 175.6 | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| mistralai/Ministral-8B-Instruct-2410 | 天数(Iluvatar) | - | 16 | - | 675.1 | 855.2 | 365.9 | 1829.5 | 174.3 | 41 | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| mistralai/Ministral-8B-Instruct-2410 | 天数(Iluvatar) | - | 16 | - | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | - |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | 性能比 107.0% |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 11h 38m 6s |
| 流程消费 | 722.67 元（≈ $100.37 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：-
  - V3：harbor.baai.ac.cn/flagrelease-project/ministral-8b-instruct-2410-iluvatar001-gems5.0.0-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp312-pt210-ixml44-x64-4.5.0:202608090256-v3
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/Ministral-8B-Instruct-2410-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Ministral-8B-Instruct-2410-FlagOS

# 结论

- 发布镜像上传正常：✅ 合格（V3 已产出）
- 流程自动化结论：✅ 流程已达标

## 提交到 flagos 仓库的 Issue
issue 数量：0
issue 标题：无

---

报告生成时间：2026.08.13