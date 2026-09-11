# 迁移结果：❌ 失败

> **自动化流程产出镜像版本：**
> - V1：tree版本=基础版：只带flagtree不开启任何flagos组件
> - V2：tree+gems=Pro版：开启flaggems且性能达到V1的80%，与V1的精度误差在5%以内
> - V3：tree+gems+plugin=Max版：在V2的基础上安装使用plugin，且性能达到V1的80%，与V1的精度误差在5%以内
> - V4：tree+gems+plugin=Flag-express版：在V3的基础上，性能表现超过V1版本

# 基本信息

| 项目 | 内容 |
|------|------|
| 项目名称 | - |
| 开始时间 | 2026-07-20T04:57:15Z |
| gems+tree版本上传时间 | 2026-07-20T07:53:50 |
| 发布时间 |  |
| 模型 | Jan-v1-4B |
| 模型领域 | 语言 |
| 权重来源 | janhq/Jan-v1-4B |
| 权重数制 |  |
| 计算数制（默认权重数制） |  |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | installed |
| FlagGems版本 | 5.0.2 |
| Flagtree版本 | 0.6.1 |
| FlagCX版本 | - |
| 厂商 | nvidia |
| GPU | H20-3e : 8 x -GB |
| 容器 | Jan-v1-4B_flagos_0720_1254 |
| release自动化工具版本 | v0.1.0 |

# 算子替换列表

## V1
### 算子白名单
（V1 不开启 FlagGems，无算子白名单）
### 算子替换列表（txt）
（V1 不开启 FlagGems，无算子替换）

## V2
### 算子白名单
```json
"include": [
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.cumsum.cumsum: GEMS CUMSUM",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.exponential_.exponential_: GEMS EXPONENTIAL_",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.gather.gather: GEMS GATHER",
    "[DEBUG] flag_gems.ops.le.le: GEMS LE",
    "[DEBUG] flag_gems.ops.lt.lt: GEMS LT",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.masked_fill.masked_fill_: GEMS MASKED FILL",
    "[DEBUG] flag_gems.ops.ones.ones: GEMS ONES",
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
    "[DEBUG] flag_gems.ops.where.where_self: GEMS WHERE_SELF",
    "[DEBUG] flag_gems.ops.where.where_self_out: GEMS WHERE_SELF_OUT",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_",
    "[DEBUG] flag_gems.ops.zeros.zeros: GEMS ZEROS",
    "[DEBUG] flag_gems.runtime.backend._nvidia.hopper.ops.mm.general_mm: GEMS MM-hopper, [op]: mm, [mm scenario]: general, [shape info]: [-, 8192, 6144, 2560](batch, M, N, K), [A column-major]: False, [B column-major]: True",
    "[DEBUG] vllm_fl.dispatch.ops.attention_backend: default.flagos"
]
```
### 算子替换列表（txt）
```json
[
    "arange_start",
    "argmax",
    "cos",
    "exponential_",
    "full",
    "general_mm",
    "lt_scalar",
    "ones",
    "rand_like",
    "randn",
    "reciprocal",
    "sin",
    "softmax",
    "softmax_out",
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
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.cumsum.cumsum: GEMS CUMSUM",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.exponential_.exponential_: GEMS EXPONENTIAL_",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.gather.gather: GEMS GATHER",
    "[DEBUG] flag_gems.ops.le.le: GEMS LE",
    "[DEBUG] flag_gems.ops.lt.lt: GEMS LT",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.masked_fill.masked_fill_: GEMS MASKED FILL",
    "[DEBUG] flag_gems.ops.ones.ones: GEMS ONES",
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
    "[DEBUG] flag_gems.ops.where.where_self: GEMS WHERE_SELF",
    "[DEBUG] flag_gems.ops.where.where_self_out: GEMS WHERE_SELF_OUT",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_",
    "[DEBUG] flag_gems.ops.zeros.zeros: GEMS ZEROS",
    "[DEBUG] flag_gems.runtime.backend._nvidia.hopper.ops.mm.general_mm: GEMS MM-hopper, [op]: mm, [mm scenario]: general, [shape info]: [-, 8192, 6144, 2560](batch, M, N, K), [A column-major]: False, [B column-major]: True",
    "[DEBUG] vllm_fl.dispatch.ops.attention_backend: default.flagos"
]
```
### 算子替换列表（txt）
```json
[
    "[DEBUG] flag_gems.ops.argmax.argmax: GEMS ARGMAX",
    "[DEBUG] flag_gems.ops.cos.cos: GEMS COS",
    "[DEBUG] flag_gems.ops.cumsum.cumsum: GEMS CUMSUM",
    "[DEBUG] flag_gems.ops.div.true_divide: GEMS TRUE_DIVIDE",
    "[DEBUG] flag_gems.ops.div.true_divide_: GEMS TRUE_DIVIDE_",
    "[DEBUG] flag_gems.ops.exponential_.exponential_: GEMS EXPONENTIAL_",
    "[DEBUG] flag_gems.ops.full.full: GEMS FULL",
    "[DEBUG] flag_gems.ops.gather.gather: GEMS GATHER",
    "[DEBUG] flag_gems.ops.le.le: GEMS LE",
    "[DEBUG] flag_gems.ops.lt.lt: GEMS LT",
    "[DEBUG] flag_gems.ops.lt.lt_scalar: GEMS LT SCALAR",
    "[DEBUG] flag_gems.ops.masked_fill.masked_fill_: GEMS MASKED FILL",
    "[DEBUG] flag_gems.ops.ones.ones: GEMS ONES",
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
    "[DEBUG] flag_gems.ops.where.where_self: GEMS WHERE_SELF",
    "[DEBUG] flag_gems.ops.where.where_self_out: GEMS WHERE_SELF_OUT",
    "[DEBUG] flag_gems.ops.zeros.zero_: GEMS ZERO_",
    "[DEBUG] flag_gems.ops.zeros.zeros: GEMS ZEROS",
    "[DEBUG] flag_gems.runtime.backend._nvidia.hopper.ops.mm.general_mm: GEMS MM-hopper, [op]: mm, [mm scenario]: general, [shape info]: [-, 8192, 6144, 2560](batch, M, N, K), [A column-major]: False, [B column-major]: True",
    "[DEBUG] vllm_fl.dispatch.ops.attention_backend: default.flagos"
]
```

## V4
### 算子白名单
（无数据）
### 算子替换列表（txt）
（无数据）

# 评测结果

## 精度评测

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
| -------- | --------- | ----------- | ----------- |
| GPQA_Diamond | - | - | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
| -------- | --------- | ----------- | ----------- |
| GPQA_Diamond | 50 | 64.0 | 21 |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
| -------- | --------- | ----------- | ----------- |
| GPQA_Diamond | 50 | 56.0 | 0 |

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
| -------- | --------- | ----------- | ----------- |
| GPQA_Diamond | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | - |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | 精度偏差 8.0% |

## 性能评测

> ⚠️ **性能基线为合成值，非实测 V1**：V2 初始性能 ×1.2（baseline_source: v2_initial_x1.2）。本报告所有以 V1 为基准的性能比均基于该合成基线。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
| -------- | ------ | --------------- | ------ | --------------------- | ------ | ------ | ------ | ------ | ------ | ------ | ------ |
| janhq/Jan-v1-4B | Nvidia | 296 | 8 | 2368 | 2081.17 | 2367.83 | 2642.88 | 13214.64 | 22.33 | 0 | 5.580507 |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
| -------- | ------ | --------------- | ------ | --------------------- | ------ | ------ | ------ | ------ | ------ | ------ | ------ |
| janhq/Jan-v1-4B | Nvidia | 296 | 8 | 2368 | 737.2 | 923.7 | 2370.7 | 11853.2 | 26.1 | 21 | 5.005574 |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
| -------- | ------ | --------------- | ------ | --------------------- | ------ | ------ | ------ | ------ | ------ | ------ | ------ |
| janhq/Jan-v1-4B | Nvidia | 296 | 8 | 2368 | 11757.0 | 11971.6 | 1707.2 | 8536.0 | 31.3 | 0 | 3.604730 |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
| -------- | ------ | --------------- | ------ | --------------------- | ------ | ------ | ------ | ------ | ------ | ------ | ------ |
| janhq/Jan-v1-4B | Nvidia | 296 | 8 | 2368 | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 89.7% |
| V1 VS V3 | 性能比 64.6% |
| V1 VS V4 | - |
| V2 VS V3 | 性能比 72.0% |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | - |
| 流程消费 | — |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/jan-v1-4b-nvidia003-gems5.0.2-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp312-pt211-cu130-x64-570.158.01:202607201428-v2
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/Jan-v1-4B-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Jan-v1-4B-FlagOS

# 结论

- 流自动化程结论：✅ 流程已达标
- gems+tree上传正常：✅
- Plugin 上传正常：❌ 不合格
- 该模型目前是否达到正常模型发布标准（是否安装plugin成功）：是

## 提交到 flagos 仓库的 Issue
issue 数量：8
issue 标题：[性能下降] 【FR】Bug: Operator performance degradation on nvidia (janhq/Jan-v1-4B)；[性能下降] 【FR】Bug: Operator performance degradation on nvidia (janhq/Jan-v1-4B)；[性能下降] 【FR】Bug: Operator performance degradation on nvidia (janhq/Jan-v1-4B)；[Plugin 错误] 【FR】Bug: vllm-plugin-FL error on nvidia (janhq/Jan-v1-4B)；[Plugin 错误] 【FR】Bug: vllm-plugin-FL error on nvidia (janhq/Jan-v1-4B)；[Plugin 错误] 【FR】Bug: vllm-plugin-FL error on nvidia (janhq/Jan-v1-4B)；results/issue_performance-degraded_flagos-ai_FlagGems_20260720_060456.md；results/issue_performance-degraded_flagos-ai_FlagGems_20260720_061639.md

---

数据来源：/data/flagos-workspace/janhq/Jan-v1-4B/results/*.json, config/context_*.yaml

报告生成时间：2026.07.20
