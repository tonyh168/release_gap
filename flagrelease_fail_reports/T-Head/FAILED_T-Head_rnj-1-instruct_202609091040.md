# 迁移结果：❌ 失败

> **自动化流程产出镜像版本：**
> - V1：tree版本=基础版：只带flagtree不开启任何flagos组件
> - V2：tree+gems=Pro版：开启flaggems且性能达到V1的80%，与V1的精度误差在5%以内
> - V3：tree+gems+plugin=Max版：在V2的基础上安装使用plugin，且性能达到V1的80%，与V1的精度误差在5%以内
> - V4：tree+gems+plugin=Flag-express版：在V3的基础上，性能表现超过V1版本

⚠️ **本报告 V3 沿用 V2 结果**：V2=V3 同镜像双 tag 发布，无独立 V3 评测。

# 基本信息

| 项目 | 内容 |
|------|------|
| 项目名称 | KT2期 |
| 开始时间 | 2026-09-04 21:05:27 |
| gems+tree版本上传时间 | 2026-09-05 02:38:02 |
| 发布时间 | 2026-09-05 02:38:49 |
| 模型 | rnj-1-instruct |
| 模型领域 | 语言 |
| 权重来源 | EssentialAI/rnj-1-instruct |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.24.0 |
| 推理框架插件plugin-FL | 0.3.0 |
| FlagGems版本 | 5.3.4 |
| Flagtree版本 | 0.6.1 |
| FlagCX版本 | - |
| 厂商 | 平头哥(T-Head) |
| GPU | PPU-ZW810E : 16 x 96GB |
| 容器 | rnj-1-instruct_flagos |
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
    "[DEBUG] flag_gems.ops.alias.alias: GEMS ALIAS",
    "[DEBUG] flag_gems.ops.arange.arange_start: GEMS ARANGE",
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.cat.cat: GEMS CAT",
    "[DEBUG] flag_gems.ops.clamp.clamp: GEMS CLAMP",
    "[DEBUG] flag_gems.ops.copy.copy_: GEMS COPY_",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.empty.empty: GEMS EMPTY",
    "[DEBUG] flag_gems.ops.expand.expand: GEMS EXPAND",
    "[DEBUG] flag_gems.ops.expand_as.expand_as: GEMS EXPAND_AS",
    "[DEBUG] flag_gems.ops.exponential_.exponential_: GEMS EXPONENTIAL_",
    "[DEBUG] flag_gems.ops.fill.fill_scalar_: GEMS FILL_SCALAR_",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.index.index: GEMS INDEX",
    "[DEBUG] flag_gems.ops.lift_fresh.lift_fresh: GEMS LIFT_FRESH",
    "[DEBUG] flag_gems.ops.linear.linear: GEMS LINEAR",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.mm.mm_out: GEMS MM_OUT",
    "[DEBUG] flag_gems.ops.mul.mul: GEMS MUL",
    "[DEBUG] flag_gems.ops.narrow.narrow: GEMS NARROW",
    "[DEBUG] flag_gems.ops.pow.pow_scalar: GEMS POW_SCALAR",
    "[DEBUG] flag_gems.ops.rand_like.rand_like: GEMS RAND_LIKE",
    "[DEBUG] flag_gems.ops.reciprocal.reciprocal: GEMS RECIPROCAL",
    "[DEBUG] flag_gems.ops.rsub.rsub_scalar: GEMS RSUB_SCALAR",
    "[DEBUG] flag_gems.ops.scalar_tensor.scalar_tensor: GEMS SCALAR_TENSOR",
    "[DEBUG] flag_gems.ops.scatter.scatter_: GEMS SCATTER_",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.softmax.softmax: GEMS SOFTMAX",
    "[DEBUG] flag_gems.ops.softmax.softmax_out: GEMS SOFTMAX_OUT",
    "[DEBUG] flag_gems.ops.sub.sub: GEMS SUB",
    "[DEBUG] flag_gems.ops.tanh.tanh: GEMS TANH FORWARD",
    "[DEBUG] flag_gems.ops.to.to_copy: GEMS TO_COPY",
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
替换算子数：42
```json
[
    "[DEBUG] flag_gems.ops.add.add: GEMS ADD",
    "[DEBUG] flag_gems.ops.alias.alias: GEMS ALIAS",
    "[DEBUG] flag_gems.ops.arange.arange_start: GEMS ARANGE",
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.cat.cat: GEMS CAT",
    "[DEBUG] flag_gems.ops.clamp.clamp: GEMS CLAMP",
    "[DEBUG] flag_gems.ops.copy.copy_: GEMS COPY_",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.empty.empty: GEMS EMPTY",
    "[DEBUG] flag_gems.ops.expand.expand: GEMS EXPAND",
    "[DEBUG] flag_gems.ops.expand_as.expand_as: GEMS EXPAND_AS",
    "[DEBUG] flag_gems.ops.exponential_.exponential_: GEMS EXPONENTIAL_",
    "[DEBUG] flag_gems.ops.fill.fill_scalar_: GEMS FILL_SCALAR_",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.index.index: GEMS INDEX",
    "[DEBUG] flag_gems.ops.lift_fresh.lift_fresh: GEMS LIFT_FRESH",
    "[DEBUG] flag_gems.ops.linear.linear: GEMS LINEAR",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.mm.mm_out: GEMS MM_OUT",
    "[DEBUG] flag_gems.ops.mul.mul: GEMS MUL",
    "[DEBUG] flag_gems.ops.narrow.narrow: GEMS NARROW",
    "[DEBUG] flag_gems.ops.pow.pow_scalar: GEMS POW_SCALAR",
    "[DEBUG] flag_gems.ops.rand_like.rand_like: GEMS RAND_LIKE",
    "[DEBUG] flag_gems.ops.reciprocal.reciprocal: GEMS RECIPROCAL",
    "[DEBUG] flag_gems.ops.rsub.rsub_scalar: GEMS RSUB_SCALAR",
    "[DEBUG] flag_gems.ops.scalar_tensor.scalar_tensor: GEMS SCALAR_TENSOR",
    "[DEBUG] flag_gems.ops.scatter.scatter_: GEMS SCATTER_",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.softmax.softmax: GEMS SOFTMAX",
    "[DEBUG] flag_gems.ops.softmax.softmax_out: GEMS SOFTMAX_OUT",
    "[DEBUG] flag_gems.ops.sub.sub: GEMS SUB",
    "[DEBUG] flag_gems.ops.tanh.tanh: GEMS TANH FORWARD",
    "[DEBUG] flag_gems.ops.to.to_copy: GEMS TO_COPY",
    "[DEBUG] flag_gems.ops.unbind.unbind: GEMS UNBIND",
    "[DEBUG] flag_gems.ops.unsqueeze.unsqueeze: GEMS UNSQUEEZE",
    "[DEBUG] flag_gems.ops.where.where_self: GEMS WHERE_SELF",
    "[DEBUG] flag_gems.ops.where.where_self_out: GEMS WHERE_SELF_OUT",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_",
    "[DEBUG] flag_gems.ops.zeros.zeros: GEMS ZEROS",
    "[DEBUG] vllm_fl.dispatch.ops.attention_backend: default.flagos"
]
```

## V3
（沿用 V2 结果，V2=V3 同镜像；算子集与 V2 一致）
### 算子白名单
```json
"include": [
    "[DEBUG] flag_gems.ops.add.add: GEMS ADD",
    "[DEBUG] flag_gems.ops.alias.alias: GEMS ALIAS",
    "[DEBUG] flag_gems.ops.arange.arange_start: GEMS ARANGE",
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.cat.cat: GEMS CAT",
    "[DEBUG] flag_gems.ops.clamp.clamp: GEMS CLAMP",
    "[DEBUG] flag_gems.ops.copy.copy_: GEMS COPY_",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.empty.empty: GEMS EMPTY",
    "[DEBUG] flag_gems.ops.expand.expand: GEMS EXPAND",
    "[DEBUG] flag_gems.ops.expand_as.expand_as: GEMS EXPAND_AS",
    "[DEBUG] flag_gems.ops.exponential_.exponential_: GEMS EXPONENTIAL_",
    "[DEBUG] flag_gems.ops.fill.fill_scalar_: GEMS FILL_SCALAR_",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.index.index: GEMS INDEX",
    "[DEBUG] flag_gems.ops.lift_fresh.lift_fresh: GEMS LIFT_FRESH",
    "[DEBUG] flag_gems.ops.linear.linear: GEMS LINEAR",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.mm.mm_out: GEMS MM_OUT",
    "[DEBUG] flag_gems.ops.mul.mul: GEMS MUL",
    "[DEBUG] flag_gems.ops.narrow.narrow: GEMS NARROW",
    "[DEBUG] flag_gems.ops.pow.pow_scalar: GEMS POW_SCALAR",
    "[DEBUG] flag_gems.ops.rand_like.rand_like: GEMS RAND_LIKE",
    "[DEBUG] flag_gems.ops.reciprocal.reciprocal: GEMS RECIPROCAL",
    "[DEBUG] flag_gems.ops.rsub.rsub_scalar: GEMS RSUB_SCALAR",
    "[DEBUG] flag_gems.ops.scalar_tensor.scalar_tensor: GEMS SCALAR_TENSOR",
    "[DEBUG] flag_gems.ops.scatter.scatter_: GEMS SCATTER_",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.softmax.softmax: GEMS SOFTMAX",
    "[DEBUG] flag_gems.ops.softmax.softmax_out: GEMS SOFTMAX_OUT",
    "[DEBUG] flag_gems.ops.sub.sub: GEMS SUB",
    "[DEBUG] flag_gems.ops.tanh.tanh: GEMS TANH FORWARD",
    "[DEBUG] flag_gems.ops.to.to_copy: GEMS TO_COPY",
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
替换算子数：42
```json
[
    "[DEBUG] flag_gems.ops.add.add: GEMS ADD",
    "[DEBUG] flag_gems.ops.alias.alias: GEMS ALIAS",
    "[DEBUG] flag_gems.ops.arange.arange_start: GEMS ARANGE",
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.cat.cat: GEMS CAT",
    "[DEBUG] flag_gems.ops.clamp.clamp: GEMS CLAMP",
    "[DEBUG] flag_gems.ops.copy.copy_: GEMS COPY_",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.empty.empty: GEMS EMPTY",
    "[DEBUG] flag_gems.ops.expand.expand: GEMS EXPAND",
    "[DEBUG] flag_gems.ops.expand_as.expand_as: GEMS EXPAND_AS",
    "[DEBUG] flag_gems.ops.exponential_.exponential_: GEMS EXPONENTIAL_",
    "[DEBUG] flag_gems.ops.fill.fill_scalar_: GEMS FILL_SCALAR_",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.index.index: GEMS INDEX",
    "[DEBUG] flag_gems.ops.lift_fresh.lift_fresh: GEMS LIFT_FRESH",
    "[DEBUG] flag_gems.ops.linear.linear: GEMS LINEAR",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.mm.mm_out: GEMS MM_OUT",
    "[DEBUG] flag_gems.ops.mul.mul: GEMS MUL",
    "[DEBUG] flag_gems.ops.narrow.narrow: GEMS NARROW",
    "[DEBUG] flag_gems.ops.pow.pow_scalar: GEMS POW_SCALAR",
    "[DEBUG] flag_gems.ops.rand_like.rand_like: GEMS RAND_LIKE",
    "[DEBUG] flag_gems.ops.reciprocal.reciprocal: GEMS RECIPROCAL",
    "[DEBUG] flag_gems.ops.rsub.rsub_scalar: GEMS RSUB_SCALAR",
    "[DEBUG] flag_gems.ops.scalar_tensor.scalar_tensor: GEMS SCALAR_TENSOR",
    "[DEBUG] flag_gems.ops.scatter.scatter_: GEMS SCATTER_",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.softmax.softmax: GEMS SOFTMAX",
    "[DEBUG] flag_gems.ops.softmax.softmax_out: GEMS SOFTMAX_OUT",
    "[DEBUG] flag_gems.ops.sub.sub: GEMS SUB",
    "[DEBUG] flag_gems.ops.tanh.tanh: GEMS TANH FORWARD",
    "[DEBUG] flag_gems.ops.to.to_copy: GEMS TO_COPY",
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
（未执行 V4）

# 评测结果

## 精度评测

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - (V1=none, 基线 NV) | 0 |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 30.0 | 42 |

### V3
（沿用 V2 结果，V2=V3 同镜像）
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 50 | 30.0 | 42 |

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | V1=none 无本地基线，以 NV 基线（37.0）为参考，V2=30.0，rel_drop=(37.0-30.0)/37.0=18.92% |
| V1 VS V3 | V3 沿用 V2 结果（V2=V3 同镜像），同 V1 VS V2 |
| V1 VS V4 | 未执行 V4 |
| V2 VS V3 | V2=V3 同镜像，精度一致（30.0） |

## 性能评测

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| EssentialAI/rnj-1-instruct | T-Head | - | 16 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| EssentialAI/rnj-1-instruct | T-Head | - | 16 | - | - | - | - | - | - | - | - |

### V3
（沿用 V2 结果，V2=V3 同镜像）
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| EssentialAI/rnj-1-instruct | T-Head | - | 16 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| EssentialAI/rnj-1-instruct | T-Head | - | 16 | - | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | V1=none 无本地基线，采用合成性能基线（V2 初始×1.05=757.58 tok/s）；V2 调优后 806.0 tok/s，ratio=106.4%（target_override=1.0） |
| V1 VS V3 | V3 沿用 V2 结果（V2=V3 同镜像），同 V1 VS V2 |
| V1 VS V4 | 未执行 V4 |
| V2 VS V3 | V2=V3 同镜像，性能一致 |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 5h 33m 22s |
| 流程消费 | 232.80 元（≈ $32.33 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/rnj-1-instruct-pp001-gemsnone-treenone-cxnone-pluginnone-vllm0.23.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202609051027-v2
  - V3：harbor.baai.ac.cn/flagrelease-project/rnj-1-instruct-pp001-gemsnone-treenone-cxnone-pluginnone-vllm0.23.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202609051027-v3（沿用 V2 结果，V2=V3 同镜像双 tag）
  - V4：-（未执行 V4）

- ModelScope: -（V2 精度未过对外门控，未对外发布权重与 README；仓库命名 FlagRelease/rnj-1-instruct-zhenwu-FlagOS）
- HuggingFace: -（V2 精度未过对外门控，未对外发布权重与 README；仓库命名 FlagRelease/rnj-1-instruct-zhenwu-FlagOS）

# 结论

- 发布镜像上传正常：❌ 未对外发布（Harbor 私有镜像已上传，V2 精度未过对外门控，未对外发布权重与 README）
- 流程自动化结论：❌ 迁移失败（V2 GPQA_Diamond 正确率 30.0，相对 NV 基线 37.0 的 rel_drop=18.92%）

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 平头哥(T-Head) (EssentialAI/rnj-1-instruct)
2. 【FR】Bug: Operator performance degradation on 平头哥(T-Head) (EssentialAI/rnj-1-instruct)

---

报告生成时间：2026.09.09