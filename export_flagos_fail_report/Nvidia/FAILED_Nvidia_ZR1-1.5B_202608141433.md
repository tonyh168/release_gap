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
| 开始时间 | 2026-08-14 10:12:26 |
| gems+tree版本上传时间 | 2026-08-14 14:24:00 |
| 发布时间 | 2026-08-14 14:33:00 |
| 模型 | ZR1-1.5B |
| 模型领域 | 语言 |
| 权重来源 | Zyphra/ZR1-1.5B |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0rc2.post1 |
| FlagGems版本 | 5.0.2 |
| Flagtree版本 | 0.6.0 |
| FlagCX版本 | - |
| 厂商 | 英伟达(Nvidia) |
| GPU | H20-3e : 8 x 140GB |
| 容器 | ZR1-1.5B_flagos_0814_1011 |
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
{
    "include": [
        "add",
        "addmm_out",
        "arange_start",
        "argmax",
        "attention_backend",
        "cos",
        "cumsum",
        "cumsum_out",
        "exponential_",
        "full",
        "general_mm",
        "le",
        "lt_scalar",
        "masked_fill_",
        "ones",
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
        "splitk_mm",
        "sub",
        "true_divide",
        "true_divide_",
        "where_self",
        "where_self_out",
        "zero_",
        "zeros"
    ]
}
```

### 算子替换列表（txt）
替换算子数：33
```json
[
    "add",
    "addmm_out",
    "arange_start",
    "argmax",
    "attention_backend",
    "cos",
    "cumsum",
    "cumsum_out",
    "exponential_",
    "full",
    "general_mm",
    "le",
    "lt_scalar",
    "masked_fill_",
    "ones",
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
    "splitk_mm",
    "sub",
    "true_divide",
    "true_divide_",
    "where_self",
    "where_self_out",
    "zero_",
    "zeros"
]
```
> （V2 保留全量 33 算子，ops_list.json / 日志确认）

## V3

### 算子白名单
（V3 未执行：V2 精度/性能均不达标，plugin 流程未触发）

### 算子替换列表（txt）
替换算子数：0
（V3 未执行：V2 精度/性能均不达标，plugin 流程未触发）

## V4

### 算子白名单
（未执行 V4）

### 算子替换列表（txt）
替换算子数：0
（未执行 V4）

# 评测结果

## 精度评测

> 精度基线与判定逻辑：NV 参考基线（mmlu 50.54% / math_500 89.4%）。V1 精度行留空。

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |
| mmlu | - | - | - |
| math_500 | - | - | - |

> （V1 精度行留空）

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |
| mmlu | 5700 | 38.56 | 33 |
| math_500 | 500 | 75.2 | 33 |

> mmlu 38.56% vs NV 50.54%（rel 23.7%）不达标；math_500 75.2% vs NV 89.4%（rel 15.88%）不达标

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |
| mmlu | - | - | - |
| math_500 | - | - | - |

> （V3 未执行）

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |
| mmlu | - | - | - |
| math_500 | - | - | - |

> （V4 未执行）

### 结果对比

| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | mmlu 不达标（vs NV 基线 50.54，rel_drop 23.7%）；math_500 不达标（vs NV 基线 89.4，rel_drop 15.88%） |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | - |

## 性能评测

> ⚠️ **性能基线为合成值，非实测 V1**：V2 初始性能 ×1.05（baseline_source: v2_initial_x1.05）。本报告所有以 V1 为基准的性能比均基于该合成基线。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Zyphra/ZR1-1.5B | 英伟达(Nvidia) | 296 | 8 | 2368 | 570.7 | 723.7 | 6679.99 | 33400.19 | 8.95 | 0 | 14.104810 |

> （合成基线）

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Zyphra/ZR1-1.5B | 英伟达(Nvidia) | 296 | 8 | 2368 | 569.5 | 732.9 | 6632.3 | 33161.6 | 9 | 33 | 14.004054 |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Zyphra/ZR1-1.5B | 英伟达(Nvidia) | - | 8 | - | - | - | - | - | - | - | - |

> （V3 未执行）

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| Zyphra/ZR1-1.5B | 英伟达(Nvidia) | - | 8 | - | - | - | - | - | - | - | - |

> （V4 未执行）

### 结果对比

| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 99.3%（vs 合成基线） |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | - |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 4h 15m 3s |
| 流程消费 | 1227.69 元（≈ $170.51 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/zr1-1.5b-nvidia003-gems5.0.2-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp312-pt211-cu130-x64-570.158.01:202608141424-v2
  - V3：-
  - V4：-
- ModelScope: https://modelscope.cn/models/FlagRelease/ZR1-1.5B-nvidia-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/ZR1-1.5B-nvidia-FlagOS

# 结论

- 发布镜像上传正常：❌ 未达标发布（精度不达标（rel_drop 超阈值）、性能不达标）
- 流程自动化结论：❌ 迁移失败（精度不达标（rel_drop 超阈值）、性能不达标）

## 提交到 flagos 仓库的 Issue

issue 数量：2
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 英伟达(Nvidia) (Zyphra/ZR1-1.5B)
2. 【FR】Bug: Operator performance degradation on 英伟达(Nvidia) (Zyphra/ZR1-1.5B)

---

报告生成时间：2026.08.14