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
| 开始时间 | 2026-09-02 22:46:18 |
| gems+tree版本上传时间 | 2026-09-03 00:30:50 |
| 发布时间 | 2026-09-03 00:30:50 |
| 模型 | Olmo-3.1-32B-Instruct |
| 模型领域 | 语言 |
| 权重来源 | allenai/Olmo-3.1-32B-Instruct |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.24.0 |
| 推理框架插件plugin-FL | 0.2.0+gf4319bd2a |
| FlagGems版本 | 5.4.0 |
| Flagtree版本 | 0.6.0 |
| FlagCX版本 | - |
| 厂商 | 英伟达(Nvidia) |
| GPU | H20-3e : 2 x 140GB |
| 容器 | Olmo-3.1-32B-Instruct_flagos |
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
    "[DEBUG] flag_gems.ops.add.add: GEMS ADD",
    "[DEBUG] flag_gems.ops.arange.arange_start: GEMS ARANGE",
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.cat.cat: GEMS CAT",
    "[DEBUG] flag_gems.ops.clamp.clamp: GEMS CLAMP",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.empty.empty: GEMS EMPTY",
    "[DEBUG] flag_gems.ops.expand.expand: GEMS EXPAND",
    "[DEBUG] flag_gems.ops.exponential_.exponential_: GEMS EXPONENTIAL_",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.lift_fresh.lift_fresh: GEMS LIFT_FRESH",
    "[DEBUG] flag_gems.ops.linear.linear: GEMS LINEAR",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.mul.mul: GEMS MUL",
    "[DEBUG] flag_gems.ops.narrow.narrow: GEMS NARROW",
    "[DEBUG] flag_gems.ops.ones.ones: GEMS ONES",
    "[DEBUG] flag_gems.ops.pow.pow_scalar: GEMS POW_SCALAR",
    "[DEBUG] flag_gems.ops.rand_like.rand_like: GEMS RAND_LIKE",
    "[DEBUG] flag_gems.ops.randn.randn: GEMS RANDN",
    "[DEBUG] flag_gems.ops.reciprocal.reciprocal: GEMS RECIPROCAL",
    "[DEBUG] flag_gems.ops.rsub.rsub_scalar: GEMS RSUB_SCALAR",
    "[DEBUG] flag_gems.ops.scalar_tensor.scalar_tensor: GEMS SCALAR_TENSOR",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.softmax.softmax: GEMS SOFTMAX",
    "[DEBUG] flag_gems.ops.softmax.softmax_out: GEMS SOFTMAX_OUT",
    "[DEBUG] flag_gems.ops.sub.sub: GEMS SUB",
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
替换算子数：34
```json
[
    "add",
    "arange_start",
    "argmax",
    "cat",
    "clamp",
    "cos",
    "empty",
    "expand",
    "exponential_",
    "full",
    "lift_fresh",
    "linear",
    "lt_scalar",
    "mul",
    "narrow",
    "ones",
    "pow_scalar",
    "rand_like",
    "randn",
    "reciprocal",
    "rsub_scalar",
    "scalar_tensor",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
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
    "[DEBUG] flag_gems.ops.add.add: GEMS ADD",
    "[DEBUG] flag_gems.ops.arange.arange_start: GEMS ARANGE",
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.cat.cat: GEMS CAT",
    "[DEBUG] flag_gems.ops.clamp.clamp: GEMS CLAMP",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.empty.empty: GEMS EMPTY",
    "[DEBUG] flag_gems.ops.expand.expand: GEMS EXPAND",
    "[DEBUG] flag_gems.ops.exponential_.exponential_: GEMS EXPONENTIAL_",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.lift_fresh.lift_fresh: GEMS LIFT_FRESH",
    "[DEBUG] flag_gems.ops.linear.linear: GEMS LINEAR",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.mul.mul: GEMS MUL",
    "[DEBUG] flag_gems.ops.narrow.narrow: GEMS NARROW",
    "[DEBUG] flag_gems.ops.ones.ones: GEMS ONES",
    "[DEBUG] flag_gems.ops.pow.pow_scalar: GEMS POW_SCALAR",
    "[DEBUG] flag_gems.ops.rand_like.rand_like: GEMS RAND_LIKE",
    "[DEBUG] flag_gems.ops.randn.randn: GEMS RANDN",
    "[DEBUG] flag_gems.ops.reciprocal.reciprocal: GEMS RECIPROCAL",
    "[DEBUG] flag_gems.ops.rsub.rsub_scalar: GEMS RSUB_SCALAR",
    "[DEBUG] flag_gems.ops.scalar_tensor.scalar_tensor: GEMS SCALAR_TENSOR",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.softmax.softmax: GEMS SOFTMAX",
    "[DEBUG] flag_gems.ops.softmax.softmax_out: GEMS SOFTMAX_OUT",
    "[DEBUG] flag_gems.ops.sub.sub: GEMS SUB",
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
替换算子数：35
```json
[
    "[DEBUG] flag_gems.ops.add.add: GEMS ADD",
    "[DEBUG] flag_gems.ops.arange.arange_start: GEMS ARANGE",
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.cat.cat: GEMS CAT",
    "[DEBUG] flag_gems.ops.clamp.clamp: GEMS CLAMP",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.empty.empty: GEMS EMPTY",
    "[DEBUG] flag_gems.ops.expand.expand: GEMS EXPAND",
    "[DEBUG] flag_gems.ops.exponential_.exponential_: GEMS EXPONENTIAL_",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.lift_fresh.lift_fresh: GEMS LIFT_FRESH",
    "[DEBUG] flag_gems.ops.linear.linear: GEMS LINEAR",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.mul.mul: GEMS MUL",
    "[DEBUG] flag_gems.ops.narrow.narrow: GEMS NARROW",
    "[DEBUG] flag_gems.ops.ones.ones: GEMS ONES",
    "[DEBUG] flag_gems.ops.pow.pow_scalar: GEMS POW_SCALAR",
    "[DEBUG] flag_gems.ops.rand_like.rand_like: GEMS RAND_LIKE",
    "[DEBUG] flag_gems.ops.randn.randn: GEMS RANDN",
    "[DEBUG] flag_gems.ops.reciprocal.reciprocal: GEMS RECIPROCAL",
    "[DEBUG] flag_gems.ops.rsub.rsub_scalar: GEMS RSUB_SCALAR",
    "[DEBUG] flag_gems.ops.scalar_tensor.scalar_tensor: GEMS SCALAR_TENSOR",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.softmax.softmax: GEMS SOFTMAX",
    "[DEBUG] flag_gems.ops.softmax.softmax_out: GEMS SOFTMAX_OUT",
    "[DEBUG] flag_gems.ops.sub.sub: GEMS SUB",
    "[DEBUG] flag_gems.ops.unbind.unbind: GEMS UNBIND",
    "[DEBUG] flag_gems.ops.unsqueeze.unsqueeze: GEMS UNSQUEEZE",
    "[DEBUG] flag_gems.ops.where.where_self: GEMS WHERE_SELF",
    "[DEBUG] flag_gems.ops.where.where_self_out: GEMS WHERE_SELF_OUT",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_",
    "[DEBUG] flag_gems.ops.zeros.zeros: GEMS ZEROS",
    "[DEBUG] vllm_fl.dispatch.ops.attention_backend: default.flagos"
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

> 本模型无 V1 基线（分支B 三选=none，NV 基线无 Olmo 条目），故未计算 rel_drop（accuracy_ok 判为 null），V2/V3 原始分数良好。流程未完整跑完（性能门未过，V3 math_500 与 V4 未完成）。数据集 mmlu + math_500。

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - (无 V1/NV 基线) | - |
| math_500 | - | - (无 V1/NV 基线) | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | 1140 | 84.91 | 35 |
| math_500 | 200 | 95.5 | 35 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | 1140 | 84.39 | 35 |
| math_500 | - | - (V3 math_500 未完成) | - |

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - (未执行 V4) | - |
| math_500 | - | - (未执行 V4) | - |

> V3 为 plugin 模式实测（mmlu 84.39% = 962/1140，日志补录）；V3 math_500 与 V4 未完成（流程因性能门未过提前结束）。无基线故未判 rel_drop。

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | -（无 V1/NV 基线，未计算 rel_drop；V2 原始 mmlu 84.91 / math_500 95.5）|
| V1 VS V3 | -（无基线；V3 原始 mmlu 84.39）|
| V1 VS V4 | -（未执行 V4）|
| V2 VS V3 | mmlu 84.91→84.39（-0.52pt）；math_500 V3 未完成 |

## 性能评测

> V2 为实测（合成基线口径，ratio 95.2% 结构性天花板，performance_ok=false，非阻断）。V1（合成基线延迟未留档）、V3、V4 性能未测（流程提前结束）。TFLOPS（单卡）=296，卡数=2。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| allenai/Olmo-3.1-32B-Instruct | Nvidia | 296 | 2 | 592 | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| allenai/Olmo-3.1-32B-Instruct | Nvidia | 296 | 2 | 592 | 72252.2 | - | 277.3 | 1386.3 | 145.6 | 35 | 2.341 |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| allenai/Olmo-3.1-32B-Instruct | Nvidia | 296 | 2 | 592 | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| allenai/Olmo-3.1-32B-Instruct | Nvidia | 296 | 2 | 592 | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 95.2%（vs 合成基线，结构性天花板）|
| V1 VS V3 | -（V3 性能未测）|
| V1 VS V4 | -（未执行 V4）|
| V2 VS V3 | -（V3 性能未测）|

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 1h 53m 34s |
| 流程消费 | 167.13 元（≈ $23.21 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：-
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/Olmo-3.1-32B-Instruct-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Olmo-3.1-32B-Instruct-FlagOS

# 结论

- 发布镜像上传正常：❌ 未达标发布（性能不达标）
- 流程自动化结论：❌ 迁移失败（性能不达标）

## 提交到 flagos 仓库的 Issue
issue 数量：1
issue 标题：
1. 【FR】Bug: Operator performance degradation on 英伟达(Nvidia) (allenai/Olmo-3.1-32B-Instruct)

---

报告生成时间：2026.09.03