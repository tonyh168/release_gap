# 迁移结果：❌ 失败（精度不达标（rel_drop 超阈值）、性能不达标）

> **自动化流程产出镜像版本：**
> - V1：tree版本=基础版：只带flagtree不开启任何flagos组件
> - V2：tree+gems=Pro版：开启flaggems且性能达到V1的80%，与V1的精度误差在5%以内
> - V3：tree+gems+plugin=Max版：在V2的基础上安装使用plugin，且性能达到V1的80%，与V1的精度误差在5%以内
> - V4：tree+gems+plugin=Flag-express版：在V3的基础上，性能表现超过V1版本

# 基本信息

| 项目 | 内容 |
|------|------|
| 项目名称 | KT2期 |
| 开始时间 | 2026-08-15 13:20:59.010763 |
| gems+tree版本上传时间 | 2026-08-16 06:24:37 |
| 发布时间 | 2026-08-16 06:25:28 |
| 模型 | Marco-Nano-Instruct |
| 模型领域 | 语言 |
| 权重来源 | ATH-MaaS/Marco-Nano-Instruct |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0+gffa2ee3eb |
| FlagGems版本 | 5.4.0dev |
| Flagtree版本 | 0.6.0 |
| FlagCX版本 | - |
| 厂商 | Hygon |
| GPU | DCU BW1000 : 8 |
| 容器 | Marco-Nano-Instruct_flagos_0815_2117 |
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
    "apply_rotary_pos_emb",
    "arange_start",
    "argmax",
    "attention_backend",
    "copy_",
    "cos",
    "embedding",
    "expand",
    "forward",
    "full",
    "fused_add_rms_norm",
    "gems_rms_forward",
    "gems_rope_forward",
    "gems_silu_and_mul",
    "index",
    "invoke_fused_moe_triton_kernel",
    "linear",
    "lt_scalar",
    "moe_align_block_size",
    "moe_align_block_size_triton",
    "moe_sum",
    "ones",
    "rand_like",
    "reciprocal",
    "rms_norm",
    "rms_norm_forward",
    "rotary_embedding",
    "scatter_",
    "silu_and_mul",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "topk_softmax",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：26
```json
[
    "add",
    "arange_start",
    "argmax",
    "copy_",
    "cos",
    "expand",
    "full",
    "index",
    "linear",
    "lt_scalar",
    "mm_out",
    "ones",
    "rand_like",
    "randn",
    "reciprocal",
    "sin",
    "softmax",
    "softmax_out",
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
    "apply_rotary_pos_emb",
    "arange_start",
    "argmax",
    "attention_backend",
    "copy_",
    "cos",
    "embedding",
    "expand",
    "forward",
    "full",
    "fused_add_rms_norm",
    "gems_rms_forward",
    "gems_rope_forward",
    "gems_silu_and_mul",
    "index",
    "invoke_fused_moe_triton_kernel",
    "linear",
    "lt_scalar",
    "moe_align_block_size",
    "moe_align_block_size_triton",
    "moe_sum",
    "ones",
    "rand_like",
    "reciprocal",
    "rms_norm",
    "rms_norm_forward",
    "rotary_embedding",
    "scatter_",
    "silu_and_mul",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "topk_softmax",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：42
```json
[
    "add",
    "apply_rotary_pos_emb",
    "arange_start",
    "argmax",
    "attention_backend",
    "copy_",
    "cos",
    "embedding",
    "expand",
    "forward",
    "full",
    "fused_add_rms_norm",
    "gems_rms_forward",
    "gems_rope_forward",
    "gems_silu_and_mul",
    "index",
    "invoke_fused_moe_triton_kernel",
    "linear",
    "lt_scalar",
    "moe_align_block_size",
    "moe_align_block_size_triton",
    "moe_sum",
    "ones",
    "rand_like",
    "reciprocal",
    "rms_norm",
    "rms_norm_forward",
    "rotary_embedding",
    "scatter_",
    "silu_and_mul",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "to_copy",
    "topk_softmax",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros"
]
```

## V4
### 算子白名单
（无数据）
### 算子替换列表（txt）
替换算子数：0
（无数据）

# 评测结果

## 精度评测

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | 使用NV参考基线 | 0 |

> 注：V1 环境无法启动或不适用，使用 NV 参考基线（nv_baseline.yaml）作为精度基准

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 63.16 | 37 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 63.16 | 37 |

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 使用NV参考基线，V2精度 63.16% 不达标 ❌ |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | V3 优于或等于 V2 |

## 性能评测

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| ATH-MaaS/Marco-Nano-Instruct | Hygon | - | 8 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| ATH-MaaS/Marco-Nano-Instruct | Hygon | - | 8 | - | 3965.1 | 4100.7 | 405.6 | 2028.0 | 154.1 | 37 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| ATH-MaaS/Marco-Nano-Instruct | Hygon | - | 8 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| ATH-MaaS/Marco-Nano-Instruct | Hygon | - | 8 | - | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | - |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | V3 优于或等于 V2 |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 17h 4m 30s |
| 流程消费 | 529.61 元（≈ $73.56 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/marco-nano-instruct-hygon001-gems5.4.0-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp310-pt210-dtknone-x64-6.3.28-v1.3.0b:202608161419-v2
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/Marco-Nano-Instruct-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Marco-Nano-Instruct-FlagOS

# 结论

- 发布镜像上传正常：❌ 未达标发布（精度不达标（rel_drop 超阈值）、性能不达标）
- 流程自动化结论：❌ 迁移失败

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 海光(Hygon) (ATH-MaaS/Marco-Nano-Instruct)
2. 【FR】Bug: Operator performance degradation on 海光(Hygon) (ATH-MaaS/Marco-Nano-Instruct)

---

报告生成时间：2026.08.16