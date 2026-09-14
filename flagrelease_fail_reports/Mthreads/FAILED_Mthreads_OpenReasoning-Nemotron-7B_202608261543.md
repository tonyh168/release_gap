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
| 开始时间 | 2026-08-14 |
| gems+tree版本上传时间 | - |
| 发布时间 | - |
| 模型 | OpenReasoning-Nemotron-7B |
| 模型领域 | 语言 |
| 权重来源 | nvidia/OpenReasoning-Nemotron-7B |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | vllm-plugin-FL 0.2.0 |
| FlagGems版本 | 5.3.0rc2 |
| Flagtree版本 | 0.6.1a2+mthreads3.6 |
| FlagCX版本 | - |
| 厂商 | 摩尔(Mthreads) |
| GPU | MTT S5000 : 1 x 80GB |
| 容器 | OpenReasoning-Nemotron-7B_flagos |
| release自动化工具版本 | v0.1.0 |

# 失败原因

该模型为 long-CoT 思维链模型，单条输出 token 量约为普通模型的 10 倍。V2 使能全量 flaggems 算子后，算子路径整体减速叠加超长输出，使评测单轮耗时超出预算上限，V2 评测未能跑完。仅完成 native（不开算子）基线精度评测，未产出可发布的 V2/V3/V4 版本。native 基线数据完整，模型与框架适配正常，瓶颈在于 flaggems 使能后 long-CoT 场景评测无法在预算内闭环。

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
    "add", "addmm_sqmma", "apply_rotary_pos_emb", "arange_start", "argmax",
    "attention_backend", "cat", "copy_", "cos", "cumsum",
    "cumsum_out", "embedding", "exponential_", "fill_scalar_", "forward",
    "full", "fused_add_rms_norm", "gather", "gems_rms_forward", "gems_rope_forward",
    "gems_silu_and_mul", "index", "le", "lt", "lt_scalar",
    "masked_fill_", "mm_sqmma", "mul", "ones", "pow_scalar",
    "rand_like", "reciprocal", "rms_norm", "rms_norm_forward", "rotary_embedding",
    "rsub_scalar", "scatter_", "silu_and_mul", "sin", "softmax",
    "softmax_out", "sort", "sort_stable", "sub", "to_copy",
    "true_divide", "true_divide_", "where_self", "where_self_out", "zero_",
    "zeros"
]
```
### 算子替换列表（txt）
替换算子数：51
```json
[
    "add", "addmm_sqmma", "apply_rotary_pos_emb", "arange_start", "argmax",
    "attention_backend", "cat", "copy_", "cos", "cumsum",
    "cumsum_out", "embedding", "exponential_", "fill_scalar_", "forward",
    "full", "fused_add_rms_norm", "gather", "gems_rms_forward", "gems_rope_forward",
    "gems_silu_and_mul", "index", "le", "lt", "lt_scalar",
    "masked_fill_", "mm_sqmma", "mul", "ones", "pow_scalar",
    "rand_like", "reciprocal", "rms_norm", "rms_norm_forward", "rotary_embedding",
    "rsub_scalar", "scatter_", "silu_and_mul", "sin", "softmax",
    "softmax_out", "sort", "sort_stable", "sub", "to_copy",
    "true_divide", "true_divide_", "where_self", "where_self_out", "zero_",
    "zeros"
]
```
> 说明：为 V2 使能的全量 flaggems 算子集（初始状态），未经算子调优确认最终达标集。

## V3
### 算子白名单
（未产出 V3）
### 算子替换列表（txt）
替换算子数：0
（未产出 V3）

## V4
### 算子白名单
（未产出 V4）

# 评测结果

## 精度评测

评测数据集：mmlu、math_500。仅完成 native（不开算子）基线评测；V2 使能算子后的评测因 long-CoT 超长输出超预算未跑完。

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | 80.79 | 0 |
| math_500 | - | 94.50 | 0 |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | 未跑完 | 51 |
| math_500 | - | 未跑完 | 51 |

### V3
（未产出 V3）

### V4
（未产出 V4）

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | V2 评测未跑完，无法对比 |
| V1 VS V3 | 无 V3 |
| V1 VS V4 | 无 V4 |
| V2 VS V3 | 无数据 |

## 性能评测

评测项：4k_input_1k_output 64 并发。未采集到有效性能数据点，以 `-` 表示。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|------|------|------|------|------|------|------|------|------|------|------|------|
| nvidia/OpenReasoning-Nemotron-7B | Mthreads | - | 1 | - | - | - | - | - | - | 0 | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|------|------|------|------|------|------|------|------|------|------|------|------|
| nvidia/OpenReasoning-Nemotron-7B | Mthreads | - | 1 | - | - | - | - | - | - | 51 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|------|------|------|------|------|------|------|------|------|------|------|------|
| - | Mthreads | - | 1 | - | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 无有效性能数据点 |
| V1 VS V3 | 无 V3 |
| V1 VS V4 | 无 V4 |
| V2 VS V3 | 无数据 |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | - |
| 流程消费 | - |

# 发布信息

- Harbor 镜像
  - V1：-
  - V2：-
  - V3：-
  - V4：-
- ModelScope: -（未产出对外发布）
- HuggingFace: -（未产出对外发布）
- 仓库可见性：-

# 结论

- 发布镜像上传正常：❌ 未产出对外发布
- 流程自动化结论：❌ 迁移失败（long-CoT 模型 V2 开启全量算子后 mmlu 评测运行至 427/1140 达评测预算上限,V2 精度评测未闭环,故未产出对外发布）

## 提交到 flagos 仓库的 Issue
issue 数量：1
issue 标题：
1. long-CoT 模型 V2 全量算子评测超评测预算上限

---

报告生成时间：2026.08.26
