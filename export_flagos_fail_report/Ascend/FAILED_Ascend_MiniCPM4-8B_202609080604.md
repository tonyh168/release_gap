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
| 开始时间 | 2026-09-02 19:54:46 |
| gems+tree版本上传时间 | 2026-09-02 21:55:31 |
| 发布时间 | 2026-09-02 21:55:31 |
| 模型 | MiniCPM4-8B |
| 模型领域 | 语言 |
| 权重来源 | openbmb/MiniCPM4-8B |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0 |
| FlagGems版本 | 5.3.4 |
| Flagtree版本 | 0.6.0 |
| FlagCX版本 | - |
| 厂商 | 华为(Ascend) |
| GPU | 910C : 16 x 61GB |
| 容器 | MiniCPM4-8B_flagos |
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
    "_reshape_alias",
    "alias",
    "chunk",
    "cos",
    "cumsum_out",
    "expand",
    "flatten",
    "ge_scalar",
    "le",
    "log_",
    "narrow",
    "repeat",
    "rsqrt",
    "rsub_scalar",
    "scalar_tensor",
    "silu",
    "sin",
    "transpose",
    "unbind",
    "uniform_",
    "unsqueeze",
    "zero_"
]
```
### 算子替换列表（txt）
替换算子数：22
```json
[
    "_reshape_alias",
    "alias",
    "chunk",
    "cos",
    "cumsum_out",
    "expand",
    "flatten",
    "ge_scalar",
    "le",
    "log_",
    "narrow",
    "repeat",
    "rsqrt",
    "rsub_scalar",
    "scalar_tensor",
    "silu",
    "sin",
    "transpose",
    "unbind",
    "uniform_",
    "unsqueeze",
    "zero_"
]
```

## V3
### 算子白名单
```json
"include": [
    "_reshape_alias",
    "alias",
    "chunk",
    "cos",
    "cumsum_out",
    "expand",
    "flatten",
    "ge_scalar",
    "le",
    "log_",
    "narrow",
    "repeat",
    "rsqrt",
    "rsub_scalar",
    "scalar_tensor",
    "silu",
    "sin",
    "transpose",
    "unbind",
    "uniform_",
    "unsqueeze",
    "zero_"
]
```
### 算子替换列表（txt）
替换算子数：22
```json
[
    "_reshape_alias",
    "alias",
    "chunk",
    "cos",
    "cumsum_out",
    "expand",
    "flatten",
    "ge_scalar",
    "le",
    "log_",
    "narrow",
    "repeat",
    "rsqrt",
    "rsub_scalar",
    "scalar_tensor",
    "silu",
    "sin",
    "transpose",
    "unbind",
    "uniform_",
    "unsqueeze",
    "zero_"
]
```

## V4
### 算子白名单
（未执行 V4）
### 算子替换列表（txt）
替换算子数：0
（未执行 V4）

# 评测结果

## 精度评测

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| GPQA_Diamond | - | - | - |

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
| V1 VS V2 | - |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | - |

## 性能评测

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| openbmb/MiniCPM4-8B | Ascend | - | 16 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| openbmb/MiniCPM4-8B | Ascend | - | 16 | - | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| openbmb/MiniCPM4-8B | Ascend | - | 16 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| openbmb/MiniCPM4-8B | Ascend | - | 16 | - | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | - |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | - |

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 2h 0m 45s |
| 流程消费 | 117.84 元（≈ $16.37 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/minicpm4-8b-ascend001-gems5.3.4-tree0.6.0-cxnone-plugin0.2.0-vllm0.20.2-cp311-ptnpu210-cann90-a64-25.5.0:202609030550-v2
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/MiniCPM4-8B-ascend-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/MiniCPM4-8B-ascend-FlagOS

# 结论

- 发布镜像上传正常：❌ 未产出对外镜像（V2 服务因 vllm-FL 内存探测 bug 触发 persistent OOM 崩溃、无法稳定启动，精度/性能未采集，不具备发布资格）
- 流程自动化结论：❌ 迁移失败（V2 default 模式注册 22 算子后启动，vllm-FL 内存探测 bug 导致 persistent OOM，服务恢复失败，GPQA 精度评测被迫跳过，性能未采集）

## 提交到 flagos 仓库的 Issue
issue 数量：3
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 华为(Ascend) (openbmb/MiniCPM4-8B)
2. 【FR】Bug: Operator crash on 华为(Ascend) (openbmb/MiniCPM4-8B)
3. 【FR】Bug: Operator performance degradation on 华为(Ascend) (openbmb/MiniCPM4-8B)

---

报告生成时间：2026.09.02