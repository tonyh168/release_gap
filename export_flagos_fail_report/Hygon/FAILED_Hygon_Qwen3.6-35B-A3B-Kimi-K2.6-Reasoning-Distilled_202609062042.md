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
| gems+tree版本上传时间 | 2026-09-06 12:29:53 |
| 发布时间 | 2026-09-06 12:31:53 |
| 模型 | Qwen3.6-35B-A3B-Kimi-K2.6-Reasoning-Distilled |
| 模型领域 | 语言 |
| 权重来源 | lordx64/Qwen3.6-35B-A3B-Kimi-K2.6-Reasoning-Distilled |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.24.0 |
| 推理框架插件plugin-FL | 0.3.0 |
| FlagGems版本 | 5.3.0 |
| Flagtree版本 | 0.6.0 |
| FlagCX版本 | - |
| 厂商 | 海光(Hygon) |
| GPU | DCU BW1000 : 8 x 64GB |
| 容器 | Qwen3.6-35B-A3B-Kimi-K2.6-Reasoning-Distilled_flagos_0906_1235 |
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
    "[DEBUG] flag_gems.fused.moe_align_block_size.moe_align_block_size_triton: GEMS MOE ALIGN BLOCK SIZE",
    "[DEBUG] flag_gems.fused.moe_sum.moe_sum: GEMS MOE SUM",
    "[DEBUG] flag_gems.fused.silu_and_mul.forward: GEMS SILU AND MUL FORWARD",
    "[DEBUG] flag_gems.fused.topk_softmax.topk_softmax: GEMS TOPK SOFTMAX",
    "[DEBUG] flag_gems.modules.activation.gems_silu_and_mul: GEMS CUSTOM SILU_AND_MUL FORWARD",
    "[DEBUG] flag_gems.ops._unsafe_view._unsafe_view: GEMS UNSAFE_VIEW",
    "[DEBUG] flag_gems.ops.add.add: GEMS ADD",
    "[DEBUG] flag_gems.ops.arange.arange_start: GEMS ARANGE",
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.bitwise_not.bitwise_not: GEMS BITWISE NOT",
    "[DEBUG] flag_gems.ops.broadcast_to.broadcast_to: GEMS BROADCAST_TO",
    "[DEBUG] flag_gems.ops.copy.copy_: GEMS COPY_",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.cumsum.cumsum: GEMS CUMSUM",
    "[DEBUG] flag_gems.ops.diff.diff: GEMS DIFF",
    "[DEBUG] flag_gems.ops.div.floor_divide: GEMS FLOOR_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.embedding.embedding: GEMS EMBEDDING FORWARD",
    "[DEBUG] flag_gems.ops.expand.expand: GEMS EXPAND",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.gt.gt_scalar: GEMS GT SCALAR",
    "[DEBUG] flag_gems.ops.index.index: GEMS INDEX",
    "[DEBUG] flag_gems.ops.index_put.index_put_: GEMS INDEX PUT_",
    "[DEBUG] flag_gems.ops.layernorm.layer_norm: GEMS LAYERNORM FORWARD",
    "[DEBUG] flag_gems.ops.linear.linear: GEMS LINEAR",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.masked_fill.masked_fill_: GEMS MASKED FILL",
    "[DEBUG] flag_gems.ops.mm.mm_out: GEMS MM_OUT",
    "[DEBUG] flag_gems.ops.narrow.narrow: GEMS NARROW",
    "[DEBUG] flag_gems.ops.nonzero.nonzero: GEMS NONZERO",
    "[DEBUG] flag_gems.ops.nonzero_numpy.nonzero_numpy: GEMS NONZERO_NUMPY",
    "[DEBUG] flag_gems.ops.normal.normal_: GEMS NORMAL_",
    "[DEBUG] flag_gems.ops.ones.ones: GEMS ONES",
    "[DEBUG] flag_gems.ops.pad.pad: GEMS CONSTANT PAD ND",
    "[DEBUG] flag_gems.ops.rand_like.rand_like: GEMS RAND_LIKE",
    "[DEBUG] flag_gems.ops.randn.randn: GEMS RANDN",
    "[DEBUG] flag_gems.ops.reciprocal.reciprocal: GEMS RECIPROCAL",
    "[DEBUG] flag_gems.ops.resolve_conj.resolve_conj: GEMS RESOLVE_CONJ",
    "[DEBUG] flag_gems.ops.resolve_neg.resolve_neg: GEMS RESOLVE_NEG",
    "[DEBUG] flag_gems.ops.scalar_tensor.scalar_tensor: GEMS SCALAR_TENSOR",
    "[DEBUG] flag_gems.ops.sigmoid.sigmoid: GEMS SIGMOID FORWARD",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.softmax.softmax: GEMS SOFTMAX",
    "[DEBUG] flag_gems.ops.softmax.softmax_out: GEMS SOFTMAX_OUT",
    "[DEBUG] flag_gems.ops.sub.sub: GEMS SUB",
    "[DEBUG] flag_gems.ops.to.to_copy: GEMS TO_COPY",
    "[DEBUG] flag_gems.ops.where.where_self: GEMS WHERE_SELF",
    "[DEBUG] flag_gems.ops.where.where_self_out: GEMS WHERE_SELF_OUT",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_",
    "[DEBUG] flag_gems.ops.zeros.zeros: GEMS ZEROS",
    "[DEBUG] flag_gems.ops.zeros_like.zeros_like: GEMS ZEROS_LIKE",
    "[DEBUG] vllm_fl.dispatch.ops.attention_backend: default.flagos",
    "[DEBUG] vllm_fl.dispatch.ops.invoke_fused_moe_triton_kernel: default.flagos",
    "[DEBUG] vllm_fl.dispatch.ops.moe_align_block_size: default.flagos",
    "[DEBUG] vllm_fl.dispatch.ops.moe_sum: default.flagos",
    "[DEBUG] vllm_fl.dispatch.ops.silu_and_mul: default.flagos",
    "[DEBUG] vllm_fl.dispatch.ops.topk_softmax: default.flagos"
]
```
### 算子替换列表（txt）
替换算子数：58
```json
[
    "[DEBUG] flag_gems.fused.moe_align_block_size.moe_align_block_size_triton: GEMS MOE ALIGN BLOCK SIZE",
    "[DEBUG] flag_gems.fused.moe_sum.moe_sum: GEMS MOE SUM",
    "[DEBUG] flag_gems.fused.silu_and_mul.forward: GEMS SILU AND MUL FORWARD",
    "[DEBUG] flag_gems.fused.topk_softmax.topk_softmax: GEMS TOPK SOFTMAX",
    "[DEBUG] flag_gems.modules.activation.gems_silu_and_mul: GEMS CUSTOM SILU_AND_MUL FORWARD",
    "[DEBUG] flag_gems.ops._unsafe_view._unsafe_view: GEMS UNSAFE_VIEW",
    "[DEBUG] flag_gems.ops.add.add: GEMS ADD",
    "[DEBUG] flag_gems.ops.arange.arange_start: GEMS ARANGE",
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.bitwise_not.bitwise_not: GEMS BITWISE NOT",
    "[DEBUG] flag_gems.ops.broadcast_to.broadcast_to: GEMS BROADCAST_TO",
    "[DEBUG] flag_gems.ops.copy.copy_: GEMS COPY_",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.cumsum.cumsum: GEMS CUMSUM",
    "[DEBUG] flag_gems.ops.diff.diff: GEMS DIFF",
    "[DEBUG] flag_gems.ops.div.floor_divide: GEMS FLOOR_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.embedding.embedding: GEMS EMBEDDING FORWARD",
    "[DEBUG] flag_gems.ops.expand.expand: GEMS EXPAND",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.gt.gt_scalar: GEMS GT SCALAR",
    "[DEBUG] flag_gems.ops.index.index: GEMS INDEX",
    "[DEBUG] flag_gems.ops.index_put.index_put_: GEMS INDEX PUT_",
    "[DEBUG] flag_gems.ops.layernorm.layer_norm: GEMS LAYERNORM FORWARD",
    "[DEBUG] flag_gems.ops.linear.linear: GEMS LINEAR",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.masked_fill.masked_fill_: GEMS MASKED FILL",
    "[DEBUG] flag_gems.ops.mm.mm_out: GEMS MM_OUT",
    "[DEBUG] flag_gems.ops.narrow.narrow: GEMS NARROW",
    "[DEBUG] flag_gems.ops.nonzero.nonzero: GEMS NONZERO",
    "[DEBUG] flag_gems.ops.nonzero_numpy.nonzero_numpy: GEMS NONZERO_NUMPY",
    "[DEBUG] flag_gems.ops.normal.normal_: GEMS NORMAL_",
    "[DEBUG] flag_gems.ops.ones.ones: GEMS ONES",
    "[DEBUG] flag_gems.ops.pad.pad: GEMS CONSTANT PAD ND",
    "[DEBUG] flag_gems.ops.rand_like.rand_like: GEMS RAND_LIKE",
    "[DEBUG] flag_gems.ops.randn.randn: GEMS RANDN",
    "[DEBUG] flag_gems.ops.reciprocal.reciprocal: GEMS RECIPROCAL",
    "[DEBUG] flag_gems.ops.resolve_conj.resolve_conj: GEMS RESOLVE_CONJ",
    "[DEBUG] flag_gems.ops.resolve_neg.resolve_neg: GEMS RESOLVE_NEG",
    "[DEBUG] flag_gems.ops.scalar_tensor.scalar_tensor: GEMS SCALAR_TENSOR",
    "[DEBUG] flag_gems.ops.sigmoid.sigmoid: GEMS SIGMOID FORWARD",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.softmax.softmax: GEMS SOFTMAX",
    "[DEBUG] flag_gems.ops.softmax.softmax_out: GEMS SOFTMAX_OUT",
    "[DEBUG] flag_gems.ops.sub.sub: GEMS SUB",
    "[DEBUG] flag_gems.ops.to.to_copy: GEMS TO_COPY",
    "[DEBUG] flag_gems.ops.where.where_self: GEMS WHERE_SELF",
    "[DEBUG] flag_gems.ops.where.where_self_out: GEMS WHERE_SELF_OUT",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_",
    "[DEBUG] flag_gems.ops.zeros.zeros: GEMS ZEROS",
    "[DEBUG] flag_gems.ops.zeros_like.zeros_like: GEMS ZEROS_LIKE",
    "[DEBUG] vllm_fl.dispatch.ops.attention_backend: default.flagos",
    "[DEBUG] vllm_fl.dispatch.ops.invoke_fused_moe_triton_kernel: default.flagos",
    "[DEBUG] vllm_fl.dispatch.ops.moe_align_block_size: default.flagos",
    "[DEBUG] vllm_fl.dispatch.ops.moe_sum: default.flagos",
    "[DEBUG] vllm_fl.dispatch.ops.silu_and_mul: default.flagos",
    "[DEBUG] vllm_fl.dispatch.ops.topk_softmax: default.flagos"
]
```

## V3
（沿用 V2 算子集，V2=V3 同镜像，无独立 V3 运行）
### 算子白名单
```json
"include": [
    "[DEBUG] flag_gems.fused.moe_align_block_size.moe_align_block_size_triton: GEMS MOE ALIGN BLOCK SIZE",
    "[DEBUG] flag_gems.fused.moe_sum.moe_sum: GEMS MOE SUM",
    "[DEBUG] flag_gems.fused.silu_and_mul.forward: GEMS SILU AND MUL FORWARD",
    "[DEBUG] flag_gems.fused.topk_softmax.topk_softmax: GEMS TOPK SOFTMAX",
    "[DEBUG] flag_gems.modules.activation.gems_silu_and_mul: GEMS CUSTOM SILU_AND_MUL FORWARD",
    "[DEBUG] flag_gems.ops._unsafe_view._unsafe_view: GEMS UNSAFE_VIEW",
    "[DEBUG] flag_gems.ops.add.add: GEMS ADD",
    "[DEBUG] flag_gems.ops.arange.arange_start: GEMS ARANGE",
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.bitwise_not.bitwise_not: GEMS BITWISE NOT",
    "[DEBUG] flag_gems.ops.broadcast_to.broadcast_to: GEMS BROADCAST_TO",
    "[DEBUG] flag_gems.ops.copy.copy_: GEMS COPY_",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.cumsum.cumsum: GEMS CUMSUM",
    "[DEBUG] flag_gems.ops.diff.diff: GEMS DIFF",
    "[DEBUG] flag_gems.ops.div.floor_divide: GEMS FLOOR_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.embedding.embedding: GEMS EMBEDDING FORWARD",
    "[DEBUG] flag_gems.ops.expand.expand: GEMS EXPAND",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.gt.gt_scalar: GEMS GT SCALAR",
    "[DEBUG] flag_gems.ops.index.index: GEMS INDEX",
    "[DEBUG] flag_gems.ops.index_put.index_put_: GEMS INDEX PUT_",
    "[DEBUG] flag_gems.ops.layernorm.layer_norm: GEMS LAYERNORM FORWARD",
    "[DEBUG] flag_gems.ops.linear.linear: GEMS LINEAR",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.masked_fill.masked_fill_: GEMS MASKED FILL",
    "[DEBUG] flag_gems.ops.mm.mm_out: GEMS MM_OUT",
    "[DEBUG] flag_gems.ops.narrow.narrow: GEMS NARROW",
    "[DEBUG] flag_gems.ops.nonzero.nonzero: GEMS NONZERO",
    "[DEBUG] flag_gems.ops.nonzero_numpy.nonzero_numpy: GEMS NONZERO_NUMPY",
    "[DEBUG] flag_gems.ops.normal.normal_: GEMS NORMAL_",
    "[DEBUG] flag_gems.ops.ones.ones: GEMS ONES",
    "[DEBUG] flag_gems.ops.pad.pad: GEMS CONSTANT PAD ND",
    "[DEBUG] flag_gems.ops.rand_like.rand_like: GEMS RAND_LIKE",
    "[DEBUG] flag_gems.ops.randn.randn: GEMS RANDN",
    "[DEBUG] flag_gems.ops.reciprocal.reciprocal: GEMS RECIPROCAL",
    "[DEBUG] flag_gems.ops.resolve_conj.resolve_conj: GEMS RESOLVE_CONJ",
    "[DEBUG] flag_gems.ops.resolve_neg.resolve_neg: GEMS RESOLVE_NEG",
    "[DEBUG] flag_gems.ops.scalar_tensor.scalar_tensor: GEMS SCALAR_TENSOR",
    "[DEBUG] flag_gems.ops.sigmoid.sigmoid: GEMS SIGMOID FORWARD",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.softmax.softmax: GEMS SOFTMAX",
    "[DEBUG] flag_gems.ops.softmax.softmax_out: GEMS SOFTMAX_OUT",
    "[DEBUG] flag_gems.ops.sub.sub: GEMS SUB",
    "[DEBUG] flag_gems.ops.to.to_copy: GEMS TO_COPY",
    "[DEBUG] flag_gems.ops.where.where_self: GEMS WHERE_SELF",
    "[DEBUG] flag_gems.ops.where.where_self_out: GEMS WHERE_SELF_OUT",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_",
    "[DEBUG] flag_gems.ops.zeros.zeros: GEMS ZEROS",
    "[DEBUG] flag_gems.ops.zeros_like.zeros_like: GEMS ZEROS_LIKE",
    "[DEBUG] vllm_fl.dispatch.ops.attention_backend: default.flagos",
    "[DEBUG] vllm_fl.dispatch.ops.invoke_fused_moe_triton_kernel: default.flagos",
    "[DEBUG] vllm_fl.dispatch.ops.moe_align_block_size: default.flagos",
    "[DEBUG] vllm_fl.dispatch.ops.moe_sum: default.flagos",
    "[DEBUG] vllm_fl.dispatch.ops.silu_and_mul: default.flagos",
    "[DEBUG] vllm_fl.dispatch.ops.topk_softmax: default.flagos"
]
```
### 算子替换列表（txt）
替换算子数：58
```json
[
    "[DEBUG] flag_gems.fused.moe_align_block_size.moe_align_block_size_triton: GEMS MOE ALIGN BLOCK SIZE",
    "[DEBUG] flag_gems.fused.moe_sum.moe_sum: GEMS MOE SUM",
    "[DEBUG] flag_gems.fused.silu_and_mul.forward: GEMS SILU AND MUL FORWARD",
    "[DEBUG] flag_gems.fused.topk_softmax.topk_softmax: GEMS TOPK SOFTMAX",
    "[DEBUG] flag_gems.modules.activation.gems_silu_and_mul: GEMS CUSTOM SILU_AND_MUL FORWARD",
    "[DEBUG] flag_gems.ops._unsafe_view._unsafe_view: GEMS UNSAFE_VIEW",
    "[DEBUG] flag_gems.ops.add.add: GEMS ADD",
    "[DEBUG] flag_gems.ops.arange.arange_start: GEMS ARANGE",
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.bitwise_not.bitwise_not: GEMS BITWISE NOT",
    "[DEBUG] flag_gems.ops.broadcast_to.broadcast_to: GEMS BROADCAST_TO",
    "[DEBUG] flag_gems.ops.copy.copy_: GEMS COPY_",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.cumsum.cumsum: GEMS CUMSUM",
    "[DEBUG] flag_gems.ops.diff.diff: GEMS DIFF",
    "[DEBUG] flag_gems.ops.div.floor_divide: GEMS FLOOR_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.embedding.embedding: GEMS EMBEDDING FORWARD",
    "[DEBUG] flag_gems.ops.expand.expand: GEMS EXPAND",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.gt.gt_scalar: GEMS GT SCALAR",
    "[DEBUG] flag_gems.ops.index.index: GEMS INDEX",
    "[DEBUG] flag_gems.ops.index_put.index_put_: GEMS INDEX PUT_",
    "[DEBUG] flag_gems.ops.layernorm.layer_norm: GEMS LAYERNORM FORWARD",
    "[DEBUG] flag_gems.ops.linear.linear: GEMS LINEAR",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.masked_fill.masked_fill_: GEMS MASKED FILL",
    "[DEBUG] flag_gems.ops.mm.mm_out: GEMS MM_OUT",
    "[DEBUG] flag_gems.ops.narrow.narrow: GEMS NARROW",
    "[DEBUG] flag_gems.ops.nonzero.nonzero: GEMS NONZERO",
    "[DEBUG] flag_gems.ops.nonzero_numpy.nonzero_numpy: GEMS NONZERO_NUMPY",
    "[DEBUG] flag_gems.ops.normal.normal_: GEMS NORMAL_",
    "[DEBUG] flag_gems.ops.ones.ones: GEMS ONES",
    "[DEBUG] flag_gems.ops.pad.pad: GEMS CONSTANT PAD ND",
    "[DEBUG] flag_gems.ops.rand_like.rand_like: GEMS RAND_LIKE",
    "[DEBUG] flag_gems.ops.randn.randn: GEMS RANDN",
    "[DEBUG] flag_gems.ops.reciprocal.reciprocal: GEMS RECIPROCAL",
    "[DEBUG] flag_gems.ops.resolve_conj.resolve_conj: GEMS RESOLVE_CONJ",
    "[DEBUG] flag_gems.ops.resolve_neg.resolve_neg: GEMS RESOLVE_NEG",
    "[DEBUG] flag_gems.ops.scalar_tensor.scalar_tensor: GEMS SCALAR_TENSOR",
    "[DEBUG] flag_gems.ops.sigmoid.sigmoid: GEMS SIGMOID FORWARD",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.softmax.softmax: GEMS SOFTMAX",
    "[DEBUG] flag_gems.ops.softmax.softmax_out: GEMS SOFTMAX_OUT",
    "[DEBUG] flag_gems.ops.sub.sub: GEMS SUB",
    "[DEBUG] flag_gems.ops.to.to_copy: GEMS TO_COPY",
    "[DEBUG] flag_gems.ops.where.where_self: GEMS WHERE_SELF",
    "[DEBUG] flag_gems.ops.where.where_self_out: GEMS WHERE_SELF_OUT",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_",
    "[DEBUG] flag_gems.ops.zeros.zeros: GEMS ZEROS",
    "[DEBUG] flag_gems.ops.zeros_like.zeros_like: GEMS ZEROS_LIKE",
    "[DEBUG] vllm_fl.dispatch.ops.attention_backend: default.flagos",
    "[DEBUG] vllm_fl.dispatch.ops.invoke_fused_moe_triton_kernel: default.flagos",
    "[DEBUG] vllm_fl.dispatch.ops.moe_align_block_size: default.flagos",
    "[DEBUG] vllm_fl.dispatch.ops.moe_sum: default.flagos",
    "[DEBUG] vllm_fl.dispatch.ops.silu_and_mul: default.flagos",
    "[DEBUG] vllm_fl.dispatch.ops.topk_softmax: default.flagos"
]
```

## V4
### 算子白名单
（未执行 V4）


# 评测结果

## 精度评测

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - (V1=none, 基线 NV=91.0) | - |
| math_500 | - | - (V1=none, 基线 NV=84.6) | - |
> V1 未单独启动（V1=none），精度基线回退 NV 参考（`nv_baseline.yaml`）。

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | 1140 | 91.41 | 58 |
| math_500 | 200 | 78.50 | 58 |
> V2 判定：mmlu: 当前=91.41%, 基线(NV 参考)=91.0, 相对退化=-0.45% → 达标；math_500: 当前=78.50%, 基线(NV 参考)=84.6, 相对退化=+7.21% → 超阈（相对退化 ≤5% 为达标）。

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | 1140 | 91.41 | 58 |
| math_500 | 200 | 78.50 | 58 |
> V3 沿用 V2 结果（V2=V3 同镜像，无独立 V3 运行）。

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - | - |
| math_500 | - | - | - |
> 未执行 V4。

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | mmlu 91.41%（rel -0.45%）；math_500 78.50%（rel +7.21%） |
| V1 VS V3 | V3 沿用 V2（同镜像） |
| V1 VS V4 | - |
| V2 VS V3 | V2=V3 同镜像，精度一致 |

## 性能评测

> ⚠️ **性能基线为合成值，非实测 V1**：V2 初始性能 ×1.05（`v2_initial_x1.05`，吞吐×1.05、延迟÷1.05，达标线=基线×1.0=V2初始×1.05）。本报告所有以 V1 为基准的性能比均基于该合成基线。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| lordx64/Qwen3.6-35B-A3B-Kimi-K2.6-Reasoning-Distilled | Hygon | - | 8 | - | - | - | 766.08 | 3830.3 | - | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| lordx64/Qwen3.6-35B-A3B-Kimi-K2.6-Reasoning-Distilled | Hygon | - | 8 | - | - | - | 696.7 | 3483.6 | - | 58 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| lordx64/Qwen3.6-35B-A3B-Kimi-K2.6-Reasoning-Distilled | Hygon | - | 8 | - | - | - | 696.7 | 3483.6 | - | 58 | - |
> V3 沿用 V2 结果（V2=V3 同镜像，无独立 V3 运行）。

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| lordx64/Qwen3.6-35B-A3B-Kimi-K2.6-Reasoning-Distilled | Hygon | - | 8 | - | - | - | - | - | - | - | - |
> 未执行 V4。

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 90.9%（vs 合成基线×1.05） |
| V1 VS V3 | 性能比 90.9%（V3 沿用 V2） |
| V1 VS V4 | - |
| V2 VS V3 | V2=V3 同镜像，性能一致 |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 7h 53m 17s |
| 流程消费 | 153.82 元（≈ $21.36 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/qwen3.6-35b-a3b-kimi-k2.6-reasoning-distilled-hygon001-gems5.3.0-tree0.6.0-cxnone-plugin0.3.0-vllm0.24.0-cp310-pt210-dtk2604-x64-6.3.30-v1.4.1a:202609062015-v2
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/Qwen3.6-35B-A3B-Kimi-K2.6-Reasoning-Distilled-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Qwen3.6-35B-A3B-Kimi-K2.6-Reasoning-Distilled-FlagOS

# 结论

- 发布镜像上传正常：❌ 未对外发布（迁移结果失败，仅保留 Harbor 私有镜像）
- 流程自动化结论：❌ 迁移失败（V2 精度：mmlu 91.41%（rel -0.45%）；math_500 78.50%（rel +7.21%）；性能比 90.9%（合成基线×1.05）；V3 沿用 V2）

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 海光(Hygon) (lordx64/Qwen3.6-35B-A3B-Kimi-K2.6-Reasoning-Distilled)
2. 【FR】Bug: Operator performance degradation on 海光(Hygon) (lordx64/Qwen3.6-35B-A3B-Kimi-K2.6-Reasoning-Distilled)

---

报告生成时间：2026.09.09
