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
| 开始时间 | 2026-08-25 14:48:12 |
| gems+tree版本上传时间 | - |
| 发布时间 | - |
| 模型 | Qwen3-30B-A3B-Thinking-2507 |
| 模型领域 | 语言 |
| 权重来源 | Qwen/Qwen3-30B-A3B-Thinking-2507 |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0+gd1653d9ff |
| FlagGems版本 | 5.0.0 |
| Flagtree版本 | 0.6.0+iluvatar.git7f4ea3ec |
| FlagCX版本 | - |
| 厂商 | 天数(Iluvatar) |
| GPU | BI-V150 : 16 x -GB |
| 容器 | Qwen3-30B-A3B-Thinking-2507_flagos_0825_1448 |
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
> 沿用 V2 结果（V3 未单独产出精度评测，依规范用 V2 数据补齐）。

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
| Qwen/Qwen3-30B-A3B-Thinking-2507 | Iluvatar | - | 16 | - | 12265.9 | 12375.9 | 11.23 | 55.96 | 5714.95 | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Qwen/Qwen3-30B-A3B-Thinking-2507 | Iluvatar | - | 16 | - | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Qwen/Qwen3-30B-A3B-Thinking-2507 | Iluvatar | - | 16 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Qwen/Qwen3-30B-A3B-Thinking-2507 | Iluvatar | - | 16 | - | - | - | - | - | - | - | - |

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
| 流程耗时 | 7h 52m 9s |
| 流程消费 | 248.82 元（≈ $34.56 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：-
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/Qwen3-30B-A3B-Thinking-2507-iluvatar-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Qwen3-30B-A3B-Thinking-2507-iluvatar-FlagOS

# 结论

- 发布镜像上传正常：❌ 未产出对外镜像
- 流程自动化结论：❌ 迁移失败（详见 Issue，各版本实测值见评测表）

## 提交到 flagos 仓库的 Issue
issue 数量：1
issue 标题：
1. 【FR】Bug: Operator crash: libentry, mm on unknown platform

---

报告生成时间：2026.08.26