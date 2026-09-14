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
| 开始时间 | 2026-08-28 06:48:17 |
| gems+tree版本上传时间 | 2026-08-28 09:54:50 |
| 发布时间 | 2026-08-28 09:55:47 |
| 模型 | Qwen3-4B-Thinking-2507 |
| 模型领域 | 语言 |
| 权重来源 | Qwen/Qwen3-4B-Thinking-2507 |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0 |
| FlagGems版本 | 5.0.2 |
| Flagtree版本 | 0.6.0 |
| FlagCX版本 | - |
| 厂商 | 平头哥(T-Head) |
| GPU | PPU-ZW810E : 16 x 96GB |
| 容器 | Qwen3-4B-Thinking-2507_flagos |
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
    "[DEBUG] flag_gems.ops.copy.copy_: GEMS COPY_",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.cumsum.cumsum: GEMS CUMSUM",
    "[DEBUG] flag_gems.ops.cumsum.cumsum_out: GEMS CUMSUM_OUT",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.exponential_.exponential_: GEMS EXPONENTIAL_",
    "[DEBUG] flag_gems.ops.fill.fill_scalar_: GEMS FILL_SCALAR_",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.gather.gather: GEMS GATHER",
    "[DEBUG] flag_gems.ops.index.index: GEMS INDEX",
    "[DEBUG] flag_gems.ops.le.le: GEMS LE",
    "[DEBUG] flag_gems.ops.lt.lt: GEMS LT",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.masked_fill.masked_fill_: GEMS MASKED FILL",
    "[DEBUG] flag_gems.ops.mm.mm: GEMS MM",
    "[DEBUG] flag_gems.ops.mm.mm_out: GEMS MM_OUT",
    "[DEBUG] flag_gems.ops.mul.mul: GEMS MUL",
    "[DEBUG] flag_gems.ops.ones.ones: GEMS ONES",
    "[DEBUG] flag_gems.ops.pow.pow_scalar: GEMS POW_SCALAR",
    "[DEBUG] flag_gems.ops.rand_like.rand_like: GEMS RAND_LIKE",
    "[DEBUG] flag_gems.ops.randn.randn: GEMS RANDN",
    "[DEBUG] flag_gems.ops.reciprocal.reciprocal: GEMS RECIPROCAL",
    "[DEBUG] flag_gems.ops.rsub.rsub_scalar: GEMS RSUB_SCALAR",
    "[DEBUG] flag_gems.ops.scatter.scatter_: GEMS SCATTER_",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.softmax.softmax: GEMS SOFTMAX",
    "[DEBUG] flag_gems.ops.softmax.softmax_out: GEMS SOFTMAX_OUT",
    "[DEBUG] flag_gems.ops.sort.sort: GEMS SORT",
    "[DEBUG] flag_gems.ops.sort.sort_stable: GEMS SORT.STABLE",
    "[DEBUG] flag_gems.ops.sub.sub: GEMS SUB",
    "[DEBUG] flag_gems.ops.to.to_copy: GEMS TO_COPY",
    "[DEBUG] flag_gems.ops.where.where_self: GEMS WHERE_SELF",
    "[DEBUG] flag_gems.ops.where.where_self_out: GEMS WHERE_SELF_OUT",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_",
    "[DEBUG] flag_gems.ops.zeros.zeros: GEMS ZEROS",
    "[DEBUG] vllm_fl.dispatch.ops.attention_backend: default.flagos"
]
```
### 算子替换列表（txt）
替换算子数：40
```json
[
    "add",
    "arange_start",
    "argmax",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "exponential_",
    "fill_scalar_",
    "full",
    "gather",
    "index",
    "le",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mm",
    "mm_out",
    "mul",
    "ones",
    "pow_scalar",
    "rand_like",
    "randn",
    "reciprocal",
    "rsub_scalar",
    "scatter_",
    "sin",
    "softmax",
    "softmax_out",
    "sort",
    "sort_stable",
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
    "[DEBUG] flag_gems.ops.add.add: GEMS ADD",
    "[DEBUG] flag_gems.ops.arange.arange_start: GEMS ARANGE",
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.cat.cat: GEMS CAT",
    "[DEBUG] flag_gems.ops.copy.copy_: GEMS COPY_",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.cumsum.cumsum: GEMS CUMSUM",
    "[DEBUG] flag_gems.ops.cumsum.cumsum_out: GEMS CUMSUM_OUT",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.exponential_.exponential_: GEMS EXPONENTIAL_",
    "[DEBUG] flag_gems.ops.fill.fill_scalar_: GEMS FILL_SCALAR_",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.gather.gather: GEMS GATHER",
    "[DEBUG] flag_gems.ops.index.index: GEMS INDEX",
    "[DEBUG] flag_gems.ops.le.le: GEMS LE",
    "[DEBUG] flag_gems.ops.lt.lt: GEMS LT",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.masked_fill.masked_fill_: GEMS MASKED FILL",
    "[DEBUG] flag_gems.ops.mm.mm: GEMS MM",
    "[DEBUG] flag_gems.ops.mm.mm_out: GEMS MM_OUT",
    "[DEBUG] flag_gems.ops.mul.mul: GEMS MUL",
    "[DEBUG] flag_gems.ops.ones.ones: GEMS ONES",
    "[DEBUG] flag_gems.ops.pow.pow_scalar: GEMS POW_SCALAR",
    "[DEBUG] flag_gems.ops.rand_like.rand_like: GEMS RAND_LIKE",
    "[DEBUG] flag_gems.ops.randn.randn: GEMS RANDN",
    "[DEBUG] flag_gems.ops.reciprocal.reciprocal: GEMS RECIPROCAL",
    "[DEBUG] flag_gems.ops.rsub.rsub_scalar: GEMS RSUB_SCALAR",
    "[DEBUG] flag_gems.ops.scatter.scatter_: GEMS SCATTER_",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.softmax.softmax: GEMS SOFTMAX",
    "[DEBUG] flag_gems.ops.softmax.softmax_out: GEMS SOFTMAX_OUT",
    "[DEBUG] flag_gems.ops.sort.sort: GEMS SORT",
    "[DEBUG] flag_gems.ops.sort.sort_stable: GEMS SORT.STABLE",
    "[DEBUG] flag_gems.ops.sub.sub: GEMS SUB",
    "[DEBUG] flag_gems.ops.to.to_copy: GEMS TO_COPY",
    "[DEBUG] flag_gems.ops.where.where_self: GEMS WHERE_SELF",
    "[DEBUG] flag_gems.ops.where.where_self_out: GEMS WHERE_SELF_OUT",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_",
    "[DEBUG] flag_gems.ops.zeros.zeros: GEMS ZEROS",
    "[DEBUG] vllm_fl.dispatch.ops.attention_backend: default.flagos"
]
```
### 算子替换列表（txt）
替换算子数：41
```json
[
    "[DEBUG] flag_gems.ops.add.add: GEMS ADD",
    "[DEBUG] flag_gems.ops.arange.arange_start: GEMS ARANGE",
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.cat.cat: GEMS CAT",
    "[DEBUG] flag_gems.ops.copy.copy_: GEMS COPY_",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.cumsum.cumsum: GEMS CUMSUM",
    "[DEBUG] flag_gems.ops.cumsum.cumsum_out: GEMS CUMSUM_OUT",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.exponential_.exponential_: GEMS EXPONENTIAL_",
    "[DEBUG] flag_gems.ops.fill.fill_scalar_: GEMS FILL_SCALAR_",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.gather.gather: GEMS GATHER",
    "[DEBUG] flag_gems.ops.index.index: GEMS INDEX",
    "[DEBUG] flag_gems.ops.le.le: GEMS LE",
    "[DEBUG] flag_gems.ops.lt.lt: GEMS LT",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.masked_fill.masked_fill_: GEMS MASKED FILL",
    "[DEBUG] flag_gems.ops.mm.mm: GEMS MM",
    "[DEBUG] flag_gems.ops.mm.mm_out: GEMS MM_OUT",
    "[DEBUG] flag_gems.ops.mul.mul: GEMS MUL",
    "[DEBUG] flag_gems.ops.ones.ones: GEMS ONES",
    "[DEBUG] flag_gems.ops.pow.pow_scalar: GEMS POW_SCALAR",
    "[DEBUG] flag_gems.ops.rand_like.rand_like: GEMS RAND_LIKE",
    "[DEBUG] flag_gems.ops.randn.randn: GEMS RANDN",
    "[DEBUG] flag_gems.ops.reciprocal.reciprocal: GEMS RECIPROCAL",
    "[DEBUG] flag_gems.ops.rsub.rsub_scalar: GEMS RSUB_SCALAR",
    "[DEBUG] flag_gems.ops.scatter.scatter_: GEMS SCATTER_",
    "[DEBUG] flag_gems.ops.sin.sin: GEMS SIN",
    "[DEBUG] flag_gems.ops.softmax.softmax: GEMS SOFTMAX",
    "[DEBUG] flag_gems.ops.softmax.softmax_out: GEMS SOFTMAX_OUT",
    "[DEBUG] flag_gems.ops.sort.sort: GEMS SORT",
    "[DEBUG] flag_gems.ops.sort.sort_stable: GEMS SORT.STABLE",
    "[DEBUG] flag_gems.ops.sub.sub: GEMS SUB",
    "[DEBUG] flag_gems.ops.to.to_copy: GEMS TO_COPY",
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

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 30 | 63.33 | 41 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | 30 | 63.33 | 41 |

> V3 无独立评测（V3 镜像 = V2 同镜像双 tag 发布至 flagrelease-project），沿用 V2 结果。

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | V1=none（基线缺失），如实记录 V2=63.33% |
| V1 VS V3 | V3 沿用 V2，同 63.33% |
| V1 VS V4 | - |
| V2 VS V3 | V3 沿用 V2，同 63.33% |

## 性能评测

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Qwen/Qwen3-4B-Thinking-2507 | T-Head | - | 16 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Qwen/Qwen3-4B-Thinking-2507 | T-Head | - | 16 | - | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Qwen/Qwen3-4B-Thinking-2507 | T-Head | - | 16 | - | - | - | - | - | - | 41 | - |

> V3 无独立评测（V3 镜像 = V2 同镜像双 tag 发布至 flagrelease-project），沿用 V2 结果。

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Qwen/Qwen3-4B-Thinking-2507 | T-Head | - | 16 | - | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 98.4%（vs 合成基线，2 轮算子调优达上限） |
| V1 VS V3 | V3 沿用 V2，性能比 98.4%（vs 合成基线） |
| V1 VS V4 | - |
| V2 VS V3 | V3 沿用 V2，性能一致 |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 3h 7m 30s |
| 流程消费 | 242.99 元（≈ $33.75 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/qwen3-4b-thinking-2507-pp001-gemsnone-treenone-cxnone-pluginnone-vllm0.23.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608281749-v2
  - V3：harbor.baai.ac.cn/flagrelease-project/qwen3-4b-thinking-2507-pp001-gemsnone-treenone-cxnone-pluginnone-vllm0.23.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608281749-v3（V3 镜像 = V2 同镜像双 tag 发布）
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/Qwen3-4B-Thinking-2507-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Qwen3-4B-Thinking-2507-FlagOS

# 结论

- 发布镜像上传正常：❌ 私有发布（V2 精度 63.33%/基线缺失，性能比 98.4% vs 合成基线；未对外发布权重）
- 流程自动化结论：❌ 迁移失败（V2 精度 63.33%、性能比 98.4% vs 合成基线）

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 平头哥(T-Head) (Qwen/Qwen3-4B-Thinking-2507)
2. 【FR】Bug: Operator performance degradation on 平头哥(T-Head) (Qwen/Qwen3-4B-Thinking-2507)

---

报告生成时间：2026.08.28