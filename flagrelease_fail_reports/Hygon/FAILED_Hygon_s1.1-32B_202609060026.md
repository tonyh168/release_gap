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
| 开始时间 | 2026-09-05 02:35:22 |
| gems+tree版本上传时间 | - |
| 发布时间 | - |
| 模型 | s1.1-32B |
| 模型领域 | 语言 |
| 权重来源 | simplescaling/s1.1-32B |
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
| 容器 | s1.1-32B_flagos_0905_1033 |
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
    "_unsafe_view",
    "add",
    "addmm_out",
    "arange_start",
    "argmax",
    "bitwise_or_tensor",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "eq_scalar",
    "expand",
    "full",
    "gather",
    "gt_scalar",
    "index",
    "le",
    "linear",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mm_out",
    "narrow",
    "ones",
    "ones_like",
    "rand_like",
    "reciprocal",
    "repeat",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "scatter_add_0",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "sub_",
    "sum_dim",
    "to_copy",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：46
```json
[
    "_unsafe_view",
    "add",
    "addmm_out",
    "arange_start",
    "argmax",
    "bitwise_or_tensor",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "eq_scalar",
    "expand",
    "full",
    "gather",
    "gt_scalar",
    "index",
    "le",
    "linear",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mm_out",
    "narrow",
    "ones",
    "ones_like",
    "rand_like",
    "reciprocal",
    "repeat",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "scatter_add_0",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "sub_",
    "sum_dim",
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
（沿用 V2 算子集，V2=V3 同镜像，无独立 V3 运行）
### 算子白名单
```json
"include": [
    "_unsafe_view",
    "add",
    "addmm_out",
    "arange_start",
    "argmax",
    "bitwise_or_tensor",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "eq_scalar",
    "expand",
    "full",
    "gather",
    "gt_scalar",
    "index",
    "le",
    "linear",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mm_out",
    "narrow",
    "ones",
    "ones_like",
    "rand_like",
    "reciprocal",
    "repeat",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "scatter_add_0",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "sub_",
    "sum_dim",
    "to_copy",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：46
```json
[
    "_unsafe_view",
    "add",
    "addmm_out",
    "arange_start",
    "argmax",
    "bitwise_or_tensor",
    "cat",
    "copy_",
    "cos",
    "cumsum",
    "cumsum_out",
    "eq_scalar",
    "expand",
    "full",
    "gather",
    "gt_scalar",
    "index",
    "le",
    "linear",
    "lt",
    "lt_scalar",
    "masked_fill_",
    "mm_out",
    "narrow",
    "ones",
    "ones_like",
    "rand_like",
    "reciprocal",
    "repeat",
    "rsub_scalar",
    "scalar_tensor",
    "scatter_",
    "scatter_add_0",
    "sin",
    "softmax",
    "softmax_out",
    "sub",
    "sub_",
    "sum_dim",
    "to_copy",
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
（未执行 V4）


# 评测结果

## 精度评测

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | 1140 | 58.24 | 0 |
| math_500 | 200 | 93.00 | 0 |
> V1 为本地实测基线。

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | 1140 | 63.07 | 46 |
| math_500 | 200 | 93.00 | 46 |
> V2 判定：mmlu: 当前=63.07%, 基线(本地 V1)=58.24, 相对退化=-8.29% → 达标；math_500: 当前=93.00%, 基线(本地 V1)=93.0, 相对退化=+0.00% → 达标（相对退化 ≤5% 为达标）。

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | 1140 | 63.07 | 46 |
| math_500 | 200 | 93.00 | 46 |
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
| V1 VS V2 | mmlu 63.07%（rel -8.29%）；math_500 93.00%（rel +0.00%） |
| V1 VS V3 | V3 沿用 V2（同镜像） |
| V1 VS V4 | - |
| V2 VS V3 | V2=V3 同镜像，精度一致 |

## 性能评测

> ⚠️ **性能基线为合成值，非实测 V1**：V2 初始性能 ×1.05（`v2_initial_x1.05`，吞吐×1.05、延迟÷1.05，达标线=基线×1.0=V2初始×1.05）。本报告所有以 V1 为基准的性能比均基于该合成基线。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| simplescaling/s1.1-32B | Hygon | - | 8 | - | 840.29 | 1340.38 | 1220.73 | 6103.34 | 51.43 | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| simplescaling/s1.1-32B | Hygon | - | 8 | - | 875.0 | 1419.3 | 1160.7 | 5803.5 | 54.1 | 46 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| simplescaling/s1.1-32B | Hygon | - | 8 | - | 875.0 | 1419.3 | 1160.7 | 5803.5 | 54.1 | 46 | - |
> V3 沿用 V2 结果（V2=V3 同镜像，无独立 V3 运行）。

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| simplescaling/s1.1-32B | Hygon | - | 8 | - | - | - | - | - | - | - | - |
> 未执行 V4。

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 95.1%（vs 合成基线×1.05） |
| V1 VS V3 | 性能比 95.1%（V3 沿用 V2） |
| V1 VS V4 | - |
| V2 VS V3 | V2=V3 同镜像，性能一致 |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 5h 5m 36s |
| 流程消费 | 203.66 元（≈ $28.29 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：-
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/s1.1-32B-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/s1.1-32B-FlagOS

# 结论

- 发布镜像上传正常：❌ 未对外发布（迁移结果失败，仅保留 Harbor 私有镜像）
- 流程自动化结论：❌ 迁移失败（V2 精度：mmlu 63.07%（rel -8.29%）；math_500 93.00%（rel +0.00%）；性能比 95.1%（合成基线×1.05）；V3 沿用 V2）

## 提交到 flagos 仓库的 Issue
issue 数量：0
issue 标题：无

---

报告生成时间：2026.09.09
