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
| 开始时间 | 2026-08-06 12:54:40 |
| gems+tree版本上传时间 | - |
| 发布时间 | - |
| 模型 | GLM-4.7-Flash |
| 模型领域 | 语言 |
| 权重来源 | zai-org/GLM-4.7-Flash |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0+g8a1c299e5 |
| FlagGems版本 | 5.3.0rc2 |
| Flagtree版本 | 0.6.1 |
| FlagCX版本 | - |
| 厂商 | 摩尔(Mthreads) |
| GPU | MTT S5000 : 8 x -GB |
| 容器 | GLM-4.7-Flash_flagos |
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
    "):",
    "^",
    "for base in range(",
    "for base in range(pid * BLOCK_TOKENS, numel_expert_ids, NUM_BLOCKS * BLOCK_TOKENS):",
    "grid distributed_barrier requires TLE builder support",
    "if pid == 0:",
    "offs = base + token_offsets",
    "offs = base + token_offsets",
    "pid * BLOCK_TOKENS, numel_sorted_token_ids, NUM_BLOCKS * BLOCK_TOKENS",
    "tl.store(cumsum_ptr + expert_offsets, 0, mask=expert_mask)",
    "tl.store(expert_ids_ptr + offs, 0, mask=offs < numel_expert_ids)",
    "tl.store(sorted_token_ids_ptr + offs, numel, mask=offs < numel_sorted_token_ids)",
    "tle.distributed_barrier(mesh)"
]
```
### 算子替换列表（txt）
替换算子数：47
```json
[
    "):",
    "^",
    "add",
    "argmax",
    "bmm_out",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "embedding",
    "exponential_",
    "fill_scalar_",
    "for base in range(",
    "for base in range(pid * block_tokens, numel_expert_ids, num_blocks * block_tokens):",
    "full",
    "grid distributed_barrier requires tle builder support",
    "if pid == 0:",
    "index",
    "le",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "mul_",
    "offs = base + token_offsets",
    "pid * block_tokens, numel_sorted_token_ids, num_blocks * block_tokens",
    "pow_scalar",
    "reciprocal",
    "rms_norm_forward",
    "rsub_scalar",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "tanh",
    "tl.store(cumsum_ptr + expert_offsets, 0, mask=expert_mask)",
    "tl.store(expert_ids_ptr + offs, 0, mask=offs < numel_expert_ids)",
    "tl.store(sorted_token_ids_ptr + offs, numel, mask=offs < numel_sorted_token_ids)",
    "tle.distributed_barrier(mesh)",
    "to_copy",
    "true_divide",
    "true_divide_",
    "uniform_",
    "where_self",
    "where_self_out"
]
```

## V3
### 算子白名单
```json
"include": [
    "):",
    "^",
    "for base in range(",
    "for base in range(pid * BLOCK_TOKENS, numel_expert_ids, NUM_BLOCKS * BLOCK_TOKENS):",
    "grid distributed_barrier requires TLE builder support",
    "if pid == 0:",
    "offs = base + token_offsets",
    "offs = base + token_offsets",
    "pid * BLOCK_TOKENS, numel_sorted_token_ids, NUM_BLOCKS * BLOCK_TOKENS",
    "tl.store(cumsum_ptr + expert_offsets, 0, mask=expert_mask)",
    "tl.store(expert_ids_ptr + offs, 0, mask=offs < numel_expert_ids)",
    "tl.store(sorted_token_ids_ptr + offs, numel, mask=offs < numel_sorted_token_ids)",
    "tle.distributed_barrier(mesh)"
]
```
### 算子替换列表（txt）
替换算子数：13
```json
[
    "):",
    "^",
    "for base in range(",
    "for base in range(pid * BLOCK_TOKENS, numel_expert_ids, NUM_BLOCKS * BLOCK_TOKENS):",
    "grid distributed_barrier requires TLE builder support",
    "if pid == 0:",
    "offs = base + token_offsets",
    "offs = base + token_offsets",
    "pid * BLOCK_TOKENS, numel_sorted_token_ids, NUM_BLOCKS * BLOCK_TOKENS",
    "tl.store(cumsum_ptr + expert_offsets, 0, mask=expert_mask)",
    "tl.store(expert_ids_ptr + offs, 0, mask=offs < numel_expert_ids)",
    "tl.store(sorted_token_ids_ptr + offs, numel, mask=offs < numel_sorted_token_ids)",
    "tle.distributed_barrier(mesh)"
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

> ⚠️ **性能基线为合成值，非实测 V1**：V2 初始性能 ×1.05（baseline_source: v2_initial_x1.05）。本报告所有以 V1 为基准的性能比均基于该合成基线。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| zai-org/GLM-4.7-Flash | 摩尔(Mthreads) | - | 8 | - | 107507.14 | 619840.57 | 8.72 | 288.54 | 4501.9 | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| zai-org/GLM-4.7-Flash | 摩尔(Mthreads) | - | 8 | - | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| zai-org/GLM-4.7-Flash | 摩尔(Mthreads) | - | 8 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| zai-org/GLM-4.7-Flash | 摩尔(Mthreads) | - | 8 | - | - | - | - | - | - | - | - |

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
| 流程耗时 | 18h 10m 0s |
| 流程消费 | 477.56 元（≈ $66.33 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/glm-4.7-flash-mthreads001-gems5.3.0-tree0.6.1-cxnone-plugin0.2.0-vllm0.20.2-cp310-pt27-musa43-x64-3.3.6-server:202608070613-v2
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/GLM-4.7-Flash-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/GLM-4.7-Flash-FlagOS

# 结论

- 发布镜像上传正常：❌ 未达标发布（精度不达标（rel_drop 超阈值）、性能不达标）
- 流程自动化结论：❌ 迁移失败（精度不达标（rel_drop 超阈值）、性能不达标）

## 提交到 flagos 仓库的 Issue
issue 数量：3
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 摩尔(Mthreads) (zai-org/GLM-4.7-Flash)
2. 【FR】Bug: Operator performance degradation on 摩尔(Mthreads) (zai-org/GLM-4.7-Flash)
3. 【FR】Bug: vllm-plugin-FL error: vllm-plugin-FL on 摩尔(Mthreads) (zai-org/GLM-4.7-Flash)

---

报告生成时间：2026.08.06