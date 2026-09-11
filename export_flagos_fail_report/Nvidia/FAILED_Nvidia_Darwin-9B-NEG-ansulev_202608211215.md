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
| gems+tree版本上传时间 | - |
| 发布时间 | - |
| 模型 | Darwin-9B-NEG-ansulev |
| 模型领域 | 语言 |
| 权重来源 | ansulev/Darwin-9B-NEG |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0rc2.post1 |
| FlagGems版本 | 5.0.2 |
| Flagtree版本 | - |
| FlagCX版本 | - |
| 厂商 | 英伟达(Nvidia) |
| GPU | H20-3e : 8 x 140GB |
| 容器 | Darwin-9B-NEG_flagos_0821_0704 |
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
    "[DEBUG] flag_gems.ops.addmm.addmm_out: GEMS ADDMM_OUT, [shape info]: [-, 8192, 4096, 12288](batch, M, N, K), [A column-major]: False, [B column-major]: True, [bias column-major]: False",
    "[DEBUG] flag_gems.ops.arange.arange_start: GEMS ARANGE",
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.bitwise_not.bitwise_not: GEMS BITWISE NOT",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.diff.diff: GEMS DIFF",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.embedding.embedding: GEMS EMBEDDING FORWARD",
    "[DEBUG] flag_gems.ops.exp.exp: GEMS EXP",
    "[DEBUG] flag_gems.ops.exponential_.exponential_: GEMS EXPONENTIAL_",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.gelu.gelu: GEMS GELU FORWARD",
    "[DEBUG] flag_gems.ops.gt.gt_scalar: GEMS GT SCALAR",
    "[DEBUG] flag_gems.ops.layernorm.layer_norm: GEMS LAYERNORM FORWARD",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.masked_fill.masked_fill_: GEMS MASKED FILL",
    "[DEBUG] flag_gems.ops.normal.normal_: GEMS NORMAL_",
    "[DEBUG] flag_gems.ops.ones.ones: GEMS ONES",
    "[DEBUG] flag_gems.ops.rand_like.rand_like: GEMS RAND_LIKE",
    "[DEBUG] flag_gems.ops.randn.randn: GEMS RANDN",
    "[DEBUG] flag_gems.ops.reciprocal.reciprocal: GEMS RECIPROCAL",
    "[DEBUG] flag_gems.ops.resolve_conj.resolve_conj: GEMS RESOLVE_CONJ",
    "[DEBUG] flag_gems.ops.resolve_neg.resolve_neg: GEMS RESOLVE_NEG",
    "[DEBUG] flag_gems.ops.scatter.scatter_: GEMS SCATTER_",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.softmax.softmax: GEMS SOFTMAX",
    "[DEBUG] flag_gems.ops.softmax.softmax_out: GEMS SOFTMAX_OUT",
    "[DEBUG] flag_gems.ops.sub.sub: GEMS SUB",
    "[DEBUG] flag_gems.ops.where.where_self: GEMS WHERE_SELF",
    "[DEBUG] flag_gems.ops.where.where_self_out: GEMS WHERE_SELF_OUT",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_",
    "[DEBUG] flag_gems.ops.zeros.zeros: GEMS ZEROS",
    "[DEBUG] flag_gems.runtime.backend._nvidia.hopper.ops.mm.general_mm: GEMS MM-hopper, [op]: mm, [mm scenario]: general, [shape info]: [-, 8192, 12288, 4096](batch, M, N, K), [A column-major]: False, [B column-major]: True",
    "[DEBUG] flag_gems.runtime.backend._nvidia.hopper.ops.mm.splitk_mm: GEMS MM-hopper, [op]: mm, [mm scenario]: splitk, [shape info]: [-, 512, 64, 4096](batch, M, N, K)",
    "[DEBUG] vllm_fl.dispatch.ops.attention_backend: default.flagos"
]
```
### 算子替换列表（txt）
替换算子数：36
```json
[
    "[DEBUG] flag_gems.ops.addmm.addmm_out: GEMS ADDMM_OUT, [shape info]: [-, 8192, 4096, 12288](batch, M, N, K), [A column-major]: False, [B column-major]: True, [bias column-major]: False",
    "[DEBUG] flag_gems.ops.arange.arange_start: GEMS ARANGE",
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.bitwise_not.bitwise_not: GEMS BITWISE NOT",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.diff.diff: GEMS DIFF",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.embedding.embedding: GEMS EMBEDDING FORWARD",
    "[DEBUG] flag_gems.ops.exp.exp: GEMS EXP",
    "[DEBUG] flag_gems.ops.exponential_.exponential_: GEMS EXPONENTIAL_",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.gelu.gelu: GEMS GELU FORWARD",
    "[DEBUG] flag_gems.ops.gt.gt_scalar: GEMS GT SCALAR",
    "[DEBUG] flag_gems.ops.layernorm.layer_norm: GEMS LAYERNORM FORWARD",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.masked_fill.masked_fill_: GEMS MASKED FILL",
    "[DEBUG] flag_gems.ops.normal.normal_: GEMS NORMAL_",
    "[DEBUG] flag_gems.ops.ones.ones: GEMS ONES",
    "[DEBUG] flag_gems.ops.rand_like.rand_like: GEMS RAND_LIKE",
    "[DEBUG] flag_gems.ops.randn.randn: GEMS RANDN",
    "[DEBUG] flag_gems.ops.reciprocal.reciprocal: GEMS RECIPROCAL",
    "[DEBUG] flag_gems.ops.resolve_conj.resolve_conj: GEMS RESOLVE_CONJ",
    "[DEBUG] flag_gems.ops.resolve_neg.resolve_neg: GEMS RESOLVE_NEG",
    "[DEBUG] flag_gems.ops.scatter.scatter_: GEMS SCATTER_",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.softmax.softmax: GEMS SOFTMAX",
    "[DEBUG] flag_gems.ops.softmax.softmax_out: GEMS SOFTMAX_OUT",
    "[DEBUG] flag_gems.ops.sub.sub: GEMS SUB",
    "[DEBUG] flag_gems.ops.where.where_self: GEMS WHERE_SELF",
    "[DEBUG] flag_gems.ops.where.where_self_out: GEMS WHERE_SELF_OUT",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_",
    "[DEBUG] flag_gems.ops.zeros.zeros: GEMS ZEROS",
    "[DEBUG] flag_gems.runtime.backend._nvidia.hopper.ops.mm.general_mm: GEMS MM-hopper, [op]: mm, [mm scenario]: general, [shape info]: [-, 8192, 12288, 4096](batch, M, N, K), [A column-major]: False, [B column-major]: True",
    "[DEBUG] flag_gems.runtime.backend._nvidia.hopper.ops.mm.splitk_mm: GEMS MM-hopper, [op]: mm, [mm scenario]: splitk, [shape info]: [-, 512, 64, 4096](batch, M, N, K)",
    "[DEBUG] vllm_fl.dispatch.ops.attention_backend: default.flagos"
]
```

## V3
### 算子白名单
```json
"include": [
    "[DEBUG] flag_gems.ops.addmm.addmm_out: GEMS ADDMM_OUT, [shape info]: [-, 8192, 4096, 12288](batch, M, N, K), [A column-major]: False, [B column-major]: True, [bias column-major]: False",
    "[DEBUG] flag_gems.ops.arange.arange_start: GEMS ARANGE",
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.bitwise_not.bitwise_not: GEMS BITWISE NOT",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.diff.diff: GEMS DIFF",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.embedding.embedding: GEMS EMBEDDING FORWARD",
    "[DEBUG] flag_gems.ops.exp.exp: GEMS EXP",
    "[DEBUG] flag_gems.ops.exponential_.exponential_: GEMS EXPONENTIAL_",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.gelu.gelu: GEMS GELU FORWARD",
    "[DEBUG] flag_gems.ops.gt.gt_scalar: GEMS GT SCALAR",
    "[DEBUG] flag_gems.ops.layernorm.layer_norm: GEMS LAYERNORM FORWARD",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.masked_fill.masked_fill_: GEMS MASKED FILL",
    "[DEBUG] flag_gems.ops.normal.normal_: GEMS NORMAL_",
    "[DEBUG] flag_gems.ops.ones.ones: GEMS ONES",
    "[DEBUG] flag_gems.ops.rand_like.rand_like: GEMS RAND_LIKE",
    "[DEBUG] flag_gems.ops.randn.randn: GEMS RANDN",
    "[DEBUG] flag_gems.ops.reciprocal.reciprocal: GEMS RECIPROCAL",
    "[DEBUG] flag_gems.ops.resolve_conj.resolve_conj: GEMS RESOLVE_CONJ",
    "[DEBUG] flag_gems.ops.resolve_neg.resolve_neg: GEMS RESOLVE_NEG",
    "[DEBUG] flag_gems.ops.scatter.scatter_: GEMS SCATTER_",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.softmax.softmax: GEMS SOFTMAX",
    "[DEBUG] flag_gems.ops.softmax.softmax_out: GEMS SOFTMAX_OUT",
    "[DEBUG] flag_gems.ops.sub.sub: GEMS SUB",
    "[DEBUG] flag_gems.ops.where.where_self: GEMS WHERE_SELF",
    "[DEBUG] flag_gems.ops.where.where_self_out: GEMS WHERE_SELF_OUT",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_",
    "[DEBUG] flag_gems.ops.zeros.zeros: GEMS ZEROS",
    "[DEBUG] flag_gems.runtime.backend._nvidia.hopper.ops.mm.general_mm: GEMS MM-hopper, [op]: mm, [mm scenario]: general, [shape info]: [-, 8192, 12288, 4096](batch, M, N, K), [A column-major]: False, [B column-major]: True",
    "[DEBUG] flag_gems.runtime.backend._nvidia.hopper.ops.mm.splitk_mm: GEMS MM-hopper, [op]: mm, [mm scenario]: splitk, [shape info]: [-, 512, 64, 4096](batch, M, N, K)",
    "[DEBUG] vllm_fl.dispatch.ops.attention_backend: default.flagos"
]
```
### 算子替换列表（txt）
替换算子数：36
```json
[
    "[DEBUG] flag_gems.ops.addmm.addmm_out: GEMS ADDMM_OUT, [shape info]: [-, 8192, 4096, 12288](batch, M, N, K), [A column-major]: False, [B column-major]: True, [bias column-major]: False",
    "[DEBUG] flag_gems.ops.arange.arange_start: GEMS ARANGE",
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.bitwise_not.bitwise_not: GEMS BITWISE NOT",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.diff.diff: GEMS DIFF",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.embedding.embedding: GEMS EMBEDDING FORWARD",
    "[DEBUG] flag_gems.ops.exp.exp: GEMS EXP",
    "[DEBUG] flag_gems.ops.exponential_.exponential_: GEMS EXPONENTIAL_",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.gelu.gelu: GEMS GELU FORWARD",
    "[DEBUG] flag_gems.ops.gt.gt_scalar: GEMS GT SCALAR",
    "[DEBUG] flag_gems.ops.layernorm.layer_norm: GEMS LAYERNORM FORWARD",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.masked_fill.masked_fill_: GEMS MASKED FILL",
    "[DEBUG] flag_gems.ops.normal.normal_: GEMS NORMAL_",
    "[DEBUG] flag_gems.ops.ones.ones: GEMS ONES",
    "[DEBUG] flag_gems.ops.rand_like.rand_like: GEMS RAND_LIKE",
    "[DEBUG] flag_gems.ops.randn.randn: GEMS RANDN",
    "[DEBUG] flag_gems.ops.reciprocal.reciprocal: GEMS RECIPROCAL",
    "[DEBUG] flag_gems.ops.resolve_conj.resolve_conj: GEMS RESOLVE_CONJ",
    "[DEBUG] flag_gems.ops.resolve_neg.resolve_neg: GEMS RESOLVE_NEG",
    "[DEBUG] flag_gems.ops.scatter.scatter_: GEMS SCATTER_",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.softmax.softmax: GEMS SOFTMAX",
    "[DEBUG] flag_gems.ops.softmax.softmax_out: GEMS SOFTMAX_OUT",
    "[DEBUG] flag_gems.ops.sub.sub: GEMS SUB",
    "[DEBUG] flag_gems.ops.where.where_self: GEMS WHERE_SELF",
    "[DEBUG] flag_gems.ops.where.where_self_out: GEMS WHERE_SELF_OUT",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_",
    "[DEBUG] flag_gems.ops.zeros.zeros: GEMS ZEROS",
    "[DEBUG] flag_gems.runtime.backend._nvidia.hopper.ops.mm.general_mm: GEMS MM-hopper, [op]: mm, [mm scenario]: general, [shape info]: [-, 8192, 12288, 4096](batch, M, N, K), [A column-major]: False, [B column-major]: True",
    "[DEBUG] flag_gems.runtime.backend._nvidia.hopper.ops.mm.splitk_mm: GEMS MM-hopper, [op]: mm, [mm scenario]: splitk, [shape info]: [-, 512, 64, 4096](batch, M, N, K)",
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

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - (NV baseline) | - |
| math_500 | - | - (NV baseline) | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | 86.84 | - |
| math_500 | - | 86.00 | - |

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
| V1 VS V2 | 性能比 92.0% |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | - |

## 性能评测

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| ansulev/Darwin-9B-NEG | Nvidia | 296 | 8 | 2368 | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| ansulev/Darwin-9B-NEG | Nvidia | 296 | 8 | 2368 | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| ansulev/Darwin-9B-NEG | Nvidia | 296 | 8 | 2368 | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| ansulev/Darwin-9B-NEG | Nvidia | 296 | 8 | 2368 | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 92.0% |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | - |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 21m 12s |
| 流程消费 | 359.17 元（≈ $49.89 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/darwin-9b-neg-nvidia003-gems5.0.2-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp312-pt211-cu130-x64-570.158.01:202608211129-v2
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/Darwin-9B-NEG-nvidia-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Darwin-9B-NEG-nvidia-FlagOS

# 结论

- 发布镜像上传正常：❌ 未达标发布（仅 Harbor 私有镜像，未对外发布）
- 流程自动化结论：❌ 迁移失败（V2 精度 mmlu 86.84%/math_500 86.00% + 性能比 92.0%；未产出对外发布版本）

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. 【FR】Bug: Operator performance degradation on 英伟达(Nvidia) (ansulev/Darwin-9B-NEG)
2. 【FR】Bug: vllm-plugin-FL error: dispatch, vllm_fl on 英伟达(Nvidia) (ansulev/Darwin-9B-NEG)

---

报告生成时间：2026.08.21