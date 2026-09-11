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
| 开始时间 | 2026-08-27 23:01:24 |
| gems+tree版本上传时间 | 2026-08-28 10:31:32 |
| 发布时间 | 2026-08-28 10:32:12 |
| 模型 | Mistral-Small-24B-Instruct-2501-reasoning |
| 模型领域 | 语言 |
| 权重来源 | yentinglin/Mistral-Small-24B-Instruct-2501-reasoning |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0 |
| FlagGems版本 | 5.4.0dev |
| Flagtree版本 | 0.6.0 |
| FlagCX版本 | - |
| 厂商 | 海光(Hygon) |
| GPU | DCU BW1000 : 8 x -GB |
| 容器 | Mistral-Small-24B-Instruct-2501-reasoning_flagos |
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
    "add",
    "addmm",
    "bmm",
    "clamp",
    "cross_entropy_loss",
    "cumsum",
    "div",
    "embedding",
    "exp",
    "gelu",
    "groupnorm",
    "layernorm",
    "log_softmax",
    "masked_fill",
    "mm",
    "mul",
    "mv",
    "nll_loss",
    "outer",
    "pow",
    "prod",
    "relu",
    "rmsnorm",
    "rsqrt",
    "scaled_dot_product_attention",
    "silu",
    "softmax",
    "sqrt",
    "sub",
    "var_mean",
    "where"
]
```
### 算子替换列表（txt）
替换算子数：26
```json
[
    "add",
    "arange_start",
    "argmax",
    "copy_",
    "cos",
    "expand",
    "full",
    "index",
    "linear",
    "lt_scalar",
    "mm_out",
    "ones",
    "rand_like",
    "randn",
    "reciprocal",
    "sin",
    "softmax",
    "softmax_out",
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
    "add",
    "addmm",
    "bmm",
    "clamp",
    "cross_entropy_loss",
    "cumsum",
    "div",
    "embedding",
    "exp",
    "gelu",
    "groupnorm",
    "layernorm",
    "log_softmax",
    "masked_fill",
    "mm",
    "mul",
    "mv",
    "nll_loss",
    "outer",
    "pow",
    "prod",
    "relu",
    "rmsnorm",
    "rsqrt",
    "scaled_dot_product_attention",
    "silu",
    "softmax",
    "sqrt",
    "sub",
    "var_mean",
    "where"
]
```
### 算子替换列表（txt）
替换算子数：31
```json
[
    "add",
    "addmm",
    "bmm",
    "clamp",
    "cross_entropy_loss",
    "cumsum",
    "div",
    "embedding",
    "exp",
    "gelu",
    "groupnorm",
    "layernorm",
    "log_softmax",
    "masked_fill",
    "mm",
    "mul",
    "mv",
    "nll_loss",
    "outer",
    "pow",
    "prod",
    "relu",
    "rmsnorm",
    "rsqrt",
    "scaled_dot_product_attention",
    "silu",
    "softmax",
    "sqrt",
    "sub",
    "var_mean",
    "where"
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

> V1=none（服务强依赖 FlagGems），精度基线回退 NV 参考值（mmlu=81.75%，math_500=86.0%）。

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - (V1=none, 基线 NV=81.75) | - |
| math_500 | - | - (V1=none, 基线 NV=86.0) | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | 81.14 | 27 |
| math_500 | - | 86.0 | 27 |

> V2 精度判定：mmlu rel_drop 0.75%（NV81.75）达标；math_500 rel_drop 0%（NV86.0）达标。accuracy_ok=true。

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | 81.14 | 27 |
| math_500 | - | 86.0 | 27 |

> 沿用 V2 结果（V2=V3 同镜像，分支 B 3.2 场景，V3 步骤已双 tag 发布，无独立 V3 评测）。

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - | - |
| math_500 | - | - | - |

> 未执行 V4。

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 精度达标（mmlu vs NV81.75 rel_drop 0.75%；math_500 vs NV86.0 rel_drop 0%） |
| V1 VS V3 | 同 V2（V3=V2 同镜像，沿用 V2 结果） |
| V1 VS V4 | - （未执行 V4） |
| V2 VS V3 | 等价（V2=V3 同镜像） |

## 性能评测

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| yentinglin/Mistral-Small-24B-Instruct-2501-reasoning | Hygon | - | 8 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| yentinglin/Mistral-Small-24B-Instruct-2501-reasoning | Hygon | - | 8 | - | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| yentinglin/Mistral-Small-24B-Instruct-2501-reasoning | Hygon | - | 8 | - | - | - | - | - | - | 27 | - |

> 沿用 V2 结果（V2=V3 同镜像，分支 B 3.2 场景，无独立 V3 性能测试）。

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| yentinglin/Mistral-Small-24B-Instruct-2501-reasoning | Hygon | - | 8 | - | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 96.3%（V2 合成基线，合成基线 target=100% 未达） |
| V1 VS V3 | 同 V2（V3=V2 同镜像，沿用 V2 数据） |
| V1 VS V4 | - （未执行 V4） |
| V2 VS V3 | 等价（V2=V3 同镜像） |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 11h 30m 48s |
| 流程消费 | 532.03 元（≈ $73.89 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/mistral-small-24b-instruct-2501-reasoning-hygon001-gems5.4.0-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp310-pt210-dtknone-x64-6.3.30-v1.4.1a:202608281830-v2
  - V3：harbor.baai.ac.cn/flagrelease-project/mistral-small-24b-instruct-2501-reasoning-hygon001-gems5.4.0-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp310-pt210-dtknone-x64-6.3.30-v1.4.1a:202608281830-v3
  - V4：-（未执行 V4）

- ModelScope: https://modelscope.cn/models/FlagRelease/Mistral-Small-24B-Instruct-2501-reasoning-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Mistral-Small-24B-Instruct-2501-reasoning-FlagOS

# 结论

- 发布镜像上传正常：❌ 未达标发布（V2/V3 Harbor 已推送，qualified=false；ModelScope 私有上传成功）
- 流程自动化结论：❌ 迁移失败（V2 性能比 96.3%，低于合成基线目标 100%；精度 mmlu 81.14%/math_500 86.0% 双达标）

## 提交到 flagos 仓库的 Issue
issue 数量：2
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 海光(Hygon) (yentinglin/Mistral-Small-24B-Instruct-2501-reasoning)
2. 【FR】Bug: Operator performance degradation on 海光(Hygon) (yentinglin/Mistral-Small-24B-Instruct-2501-reasoning)

---

报告生成时间：2026.08.28