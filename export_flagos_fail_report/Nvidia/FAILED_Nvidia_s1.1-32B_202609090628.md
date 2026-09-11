# 迁移结果：❌ 失败（性能不达标）

> **自动化流程产出镜像版本：**
> - V1：tree版本=基础版：只带flagtree不开启任何flagos组件
> - V2：tree+gems=Pro版：开启flaggems且性能达到V1的80%，与V1的精度误差在5%以内
> - V3：tree+gems+plugin=Max版：在V2的基础上安装使用plugin，且性能达到V1的80%，与V1的精度误差在5%以内
> - V4：tree+gems+plugin=Flag-express版：在V3的基础上，性能表现超过V1版本

# 基本信息

| 项目 | 内容 |
|------|------|
| 项目名称 | KT2期 |
| 开始时间 | 2026-09-03 22:29:00 |
| gems+tree版本上传时间 | 2026-09-04 06:29:39 |
| 发布时间 | 2026-09-04 06:29:39 |
| 模型 | s1.1-32B |
| 模型领域 | 语言 |
| 权重来源 | simplescaling/s1.1-32B |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.24.0 |
| 推理框架插件plugin-FL | 0.2.0 |
| FlagGems版本 | 5.4.0 |
| Flagtree版本 | 0.6.0 |
| FlagCX版本 | - |
| 厂商 | 英伟达(Nvidia) |
| GPU | H20-3e : 2 x 140GB |
| 容器 | s1.1-32B_flagos |
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
    "[DEBUG] flag_gems.ops.addmm.addmm_out: GEMS ADDMM_OUT, [shape info]: [-, 8192, 3584, 5120](batch, M, N, K), [A column-major]: False, [B column-major]: True, [bias column-major]: True",
    "[DEBUG] flag_gems.ops.alias.alias: GEMS ALIAS",
    "[DEBUG] flag_gems.ops.arange.arange_start: GEMS ARANGE",
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.broadcast_to.broadcast_to: GEMS BROADCAST_TO",
    "[DEBUG] flag_gems.ops.cat.cat: GEMS CAT",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.empty.empty: GEMS EMPTY",
    "[DEBUG] flag_gems.ops.eq.eq_scalar: GEMS EQ SCALAR",
    "[DEBUG] flag_gems.ops.expand.expand: GEMS EXPAND",
    "[DEBUG] flag_gems.ops.expand_as.expand_as: GEMS EXPAND_AS",
    "[DEBUG] flag_gems.ops.exponential_.exponential_: GEMS EXPONENTIAL_",
    "[DEBUG] flag_gems.ops.flatten.flatten: GEMS FLATTEN",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.gt.gt_scalar: GEMS GT SCALAR",
    "[DEBUG] flag_gems.ops.lift_fresh.lift_fresh: GEMS LIFT_FRESH",
    "[DEBUG] flag_gems.ops.linear.linear: GEMS LINEAR",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.masked_fill.masked_fill_: GEMS MASKED FILL",
    "[DEBUG] flag_gems.ops.mul.mul: GEMS MUL",
    "[DEBUG] flag_gems.ops.narrow.narrow: GEMS NARROW",
    "[DEBUG] flag_gems.ops.ones.ones: GEMS ONES",
    "[DEBUG] flag_gems.ops.ones_like.ones_like: GEMS ONES_LIKE",
    "[DEBUG] flag_gems.ops.pow.pow_scalar: GEMS POW_SCALAR",
    "[DEBUG] flag_gems.ops.rand_like.rand_like: GEMS RAND_LIKE",
    "[DEBUG] flag_gems.ops.randn.randn: GEMS RANDN",
    "[DEBUG] flag_gems.ops.reciprocal.reciprocal: GEMS RECIPROCAL",
    "[DEBUG] flag_gems.ops.scalar_tensor.scalar_tensor: GEMS SCALAR_TENSOR",
    "[DEBUG] flag_gems.ops.scatter_add.scatter_add_0: GEMS SCATTER_ADD_0",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.softmax.softmax: GEMS SOFTMAX",
    "[DEBUG] flag_gems.ops.softmax.softmax_out: GEMS SOFTMAX_OUT",
    "[DEBUG] flag_gems.ops.sub.sub: GEMS SUB",
    "[DEBUG] flag_gems.ops.sub.sub_: GEMS SUB_",
    "[DEBUG] flag_gems.ops.unbind.unbind: GEMS UNBIND",
    "[DEBUG] flag_gems.ops.unsqueeze.unsqueeze: GEMS UNSQUEEZE",
    "[DEBUG] flag_gems.ops.where.where_self: GEMS WHERE_SELF",
    "[DEBUG] flag_gems.ops.where.where_self_out: GEMS WHERE_SELF_OUT",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_",
    "[DEBUG] flag_gems.ops.zeros.zeros: GEMS ZEROS",
    "[DEBUG] vllm_fl.dispatch.ops.attention_backend: default.flagos"
]
```
### 算子替换列表（txt）
替换算子数：44
```json
[
    "_unsafe_view",
    "add",
    "addmm_out",
    "alias",
    "arange_start",
    "argmax",
    "broadcast_to",
    "cat",
    "cos",
    "empty",
    "eq_scalar",
    "expand",
    "expand_as",
    "exponential_",
    "flatten",
    "full",
    "gt_scalar",
    "lift_fresh",
    "linear",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "narrow",
    "ones",
    "ones_like",
    "pow_scalar",
    "rand_like",
    "randn",
    "reciprocal",
    "scalar_tensor",
    "scatter_add_0",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "sub_",
    "true_divide",
    "true_divide_",
    "unbind",
    "unsqueeze",
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
    "_unsafe_view",
    "add",
    "addmm_out",
    "alias",
    "arange_start",
    "argmax",
    "broadcast_to",
    "cat",
    "cos",
    "empty",
    "eq_scalar",
    "expand",
    "expand_as",
    "exponential_",
    "full",
    "gt_scalar",
    "lift_fresh",
    "linear",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "narrow",
    "ones",
    "ones_like",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "scalar_tensor",
    "scatter_",
    "scatter_add_0",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "sub_",
    "true_divide",
    "true_divide_",
    "unbind",
    "unsqueeze",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：43
```json
[
    "_unsafe_view",
    "add",
    "addmm_out",
    "alias",
    "arange_start",
    "argmax",
    "broadcast_to",
    "cat",
    "cos",
    "empty",
    "eq_scalar",
    "expand",
    "expand_as",
    "exponential_",
    "full",
    "gt_scalar",
    "lift_fresh",
    "linear",
    "lt_scalar",
    "masked_fill_",
    "mul",
    "narrow",
    "ones",
    "ones_like",
    "pow_scalar",
    "rand_like",
    "reciprocal",
    "scalar_tensor",
    "scatter_",
    "scatter_add_0",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "sub_",
    "true_divide",
    "true_divide_",
    "unbind",
    "unsqueeze",
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

> 无实测 V1（V1=none），精度以 NV 参考基线判定：mmlu 60.68、math_500 93.6。thinking 模型。V3 为 plugin 模式实测（日志补录）；V4=V3 等价回退。判据 rel_drop=(基线-当前)/基线 ≤ 5%。

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - (V1=none，基线 NV=60.68) | - |
| math_500 | - | - (V1=none，基线 NV=93.6) | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | 1140 | 59.47 | 44 |
| math_500 | 200 | 95.5 | 44 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | 1140 | 61.32 | 43 |
| math_500 | 200 | 93.5 | 43 |

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | 1140 | 61.32 | 43 |
| math_500 | 200 | 93.5 | 43 |

> V3 为 plugin 模式实测（日志补录，43 算子）；V4=V3 等价回退，继承 V3 精度。

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | mmlu 59.47 vs 60.68（rel 1.99%）、math_500 95.5 vs 93.6（rel -2.03%，反超）→ 全达标 |
| V1 VS V3 | mmlu 61.32 vs 60.68（rel -1.05%，反超）、math_500 93.5 vs 93.6（rel 0.11%）→ 全达标 |
| V1 VS V4 | =V3（继承）→ 全达标 |
| V2 VS V3 | mmlu 59.47→61.32、math_500 95.5→93.5（均达标）|

## 性能评测

> V1 为合成基线（synthetic = V2初始×1.05，无实测V1；仅吞吐留档，延迟未单独留档记为 -），达标线 = 基线×1.0，ratio 结构性 <100% 非阻断。V3 未单独测性能，沿用 V2；V4=V3 等价回退。TFLOPS（单卡）=296，卡数=2。

### V1（合成基线，V2初始×1.05）
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| simplescaling/s1.1-32B | Nvidia | 296 | 2 | 592 | - | - | 1420.02 | 7099.99 | - | 0 | 11.993 |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| simplescaling/s1.1-32B | Nvidia | 296 | 2 | 592 | 513.5 | 883.3 | 1400.40 | 7002.00 | 45.1 | 44 | 11.827703 |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| simplescaling/s1.1-32B | Nvidia | 296 | 2 | 592 | 513.5 | 883.3 | 1400.40 | 7002.00 | 45.1 | 43 | 11.827703 |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| simplescaling/s1.1-32B | Nvidia | 296 | 2 | 592 | 513.5 | 883.3 | 1400.40 | 7002.00 | 45.1 | 43 | 11.827703 |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 98.6%（vs 合成基线）|
| V1 VS V3 | 沿用 V2 结果（V3 未单独测性能）|
| V1 VS V4 | 沿用 V2 结果（同上）|
| V2 VS V3 | 沿用 V2（V3 未单独测性能）|

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 11h 6m 26s |
| 流程消费 | 333.92 元（≈ $46.38 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/s1.1-32b-nvidia003-gems5.4.0-tree0.6.0-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt211-cu130-x64-570.133.20:202609041342-v2
  - V3：-
  - V4：-

- ModelScope: https://www.modelscope.cn/models/FlagRelease/s1.1-32B-nvidia-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/s1.1-32B-FlagOS

# 结论

- 发布镜像上传正常：❌ 未达标发布（性能不达标）
- 流程自动化结论：❌ 迁移失败（性能不达标）

## 提交到 flagos 仓库的 Issue
issue 数量：1
issue 标题：
1. 【FR】Bug: Operator performance degradation on 英伟达(Nvidia) (simplescaling/s1.1-32B)

---

报告生成时间：2026.09.04