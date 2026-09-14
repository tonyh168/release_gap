# 迁移结果：❌ 失败

> **自动化流程产出镜像版本：**
> - V1：tree版本=基础版：只带flagtree不开启任何flagos组件
> - V2：tree+gems=Pro版：开启flaggems且性能达到V1的80%，与V1的精度误差在5%以内
> - V3：tree+gems+plugin=Max版：在V2的基础上安装使用plugin，且性能达到V1的80%，与V1的精度误差在5%以内
> - V4：tree+gems+plugin=Flag-express版：在V3的基础上，性能表现超过V1版本

# 基本信息

| 项目 | 内容 |
|------|------|
| 项目名称 | FlagOS 自动化迁移 |
| 开始时间 | 2026-09-08 13:32:00 |
| gems+tree版本上传时间 | - |
| plugin上传时间 | - |
| 发布时间 | - |
| 模型 | Darwin-28B-Opus |
| 模型领域 | 语言 |
| 权重来源 | FINAL-Bench/Darwin-28B-Opus |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0 |
| FlagGems版本 | 5.3.0 |
| Flagtree版本 | 0.6.1 |
| FlagCX版本 | - |
| PyTorch版本 | 2.7.1 |
| Python版本 | 3.10.12 |
| 厂商 | 摩尔线程 (Mthreads) |
| GPU | MTT S5000 : 1 x 80GB |
| 容器 | Darwin-28B-Opus_flagos |
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
（未进入有效评测阶段，无数据）
### 算子替换列表（txt）
替换算子数：0
（无数据）

## V3
### 算子白名单
（无数据）
### 算子替换列表（txt）
替换算子数：0
（无数据）

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
| - | - | - | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| - | - | - | - |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| - | - | - | - |

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| - | - | - | - |

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
| FINAL-Bench/Darwin-28B-Opus | Mthreads | - | 1 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| FINAL-Bench/Darwin-28B-Opus | Mthreads | - | 1 | - | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| FINAL-Bench/Darwin-28B-Opus | Mthreads | - | 1 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| FINAL-Bench/Darwin-28B-Opus | Mthreads | - | 1 | - | - | - | - | - | - | - | - |

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
| 流程耗时 | - |
| 流程消费 | - |

# 发布信息

- Harbor 镜像
  - V1：-
  - V2：-
  - V3：-
  - V4：-

- ModelScope: -
- HuggingFace: -

> 中断阶段：步骤4 精度评测
> 失败原因：服务启动成功（flagos 模式 62 算子，TP=1，service_ok=true），但精度评测未完成、无 accuracy_compare 结果（accuracy_ok=false）。
> 补充说明：仅完成 V2==V3 双 tag 私有镜像发布（qualified=false，不对外）。

# 结论

- 发布镜像上传正常：❌ 未达标（流程在「步骤4 精度评测」中断，无有效精度/性能评测数据）
- 流程自动化结论：❌ 迁移失败

## 提交到 flagos 仓库的 Issue
issue 数量：1

### Issue 1：【FR】vllm 0.20.2 与 torch 2.7.1(torch_musa) 不兼容：torch.float4_e2m1fn_x2 缺失
- **仓库**：`flagos-ai/vllm-plugin-FL`
- **类型**：startup-crash
- **触发场景**：V1 native 基线（纯 vllm，不开 flagos 组件）启动时，vllm 0.20.2 的 `vllm/ir/tolerances.py` 在模块导入期引用了 `torch.float4_e2m1fn_x2` 数据类型，而 torch 2.7.1 / torch_musa 未提供该 dtype，导入即 AttributeError，V1 基线无法启动。
- **影响**：V1 native 基线不可用 → 精度基线回退 NV 参考，性能基线走合成路径。V2（flagos 模式，62 算子）可正常起服务（chat completion 验证通过），但精度评测阶段未产出有效结果（accuracy_ok=false），迁移判失败。
- **处置**：需 vllm-plugin-FL 侧对 torch_musa 缺失的 float4 dtype 做兼容 patch 或延迟引用。
- **关键报错信息（核对自运行容器日志）**：
```text
Traceback (most recent call last):
  File ".../vllm/ir/op.py", line 12, in <module>
    from vllm.ir.tolerances import DEFAULT_TOLERANCES, ToleranceSpec
  File ".../vllm/ir/tolerances.py", line 32, in <module>
    torch.float4_e2m1fn_x2: {"atol": 3e-1, "rtol": 3e-1},
  File ".../torch/__init__.py", line 2688, in __getattr__
    raise AttributeError(f"module '{__name__}' has no attribute '{name}'")
AttributeError: module 'torch' has no attribute 'float4_e2m1fn_x2'
```

---

报告生成时间：2026.09.08
