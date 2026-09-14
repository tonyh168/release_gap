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
| 开始时间 | 2026-09-08 18:26:00 |
| gems+tree版本上传时间 | - |
| plugin上传时间 | - |
| 发布时间 | - |
| 模型 | kanana-1.5-15.7b-a3b-instruct |
| 模型领域 | 语言 |
| 权重来源 | kakaocorp/kanana-1.5-15.7b-a3b-instruct |
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
| 容器 | kanana-1.5-15.7b-a3b-instruct_flagos |
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
| kakaocorp/kanana-1.5-15.7b-a3b-instruct | Mthreads | - | 1 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| kakaocorp/kanana-1.5-15.7b-a3b-instruct | Mthreads | - | 1 | - | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| kakaocorp/kanana-1.5-15.7b-a3b-instruct | Mthreads | - | 1 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| kakaocorp/kanana-1.5-15.7b-a3b-instruct | Mthreads | - | 1 | - | - | - | - | - | - | - | - |

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

> 中断阶段：步骤3 服务启动
> 失败原因：GPU 显存不足，多个 GPU 均被占用，服务无法启动；MUSA 显存检测失败导致 calc_tp_size.py ZeroDivisionError（手动回退 TP=1 仍无法调度）。
> 补充说明：未进入精度/性能评测阶段，无有效评测数据。

# 结论

- 发布镜像上传正常：❌ 未达标（流程在「步骤3 服务启动」中断，无有效精度/性能评测数据）
- 流程自动化结论：❌ 迁移失败

## 提交到 flagos 仓库的 Issue
issue 数量：1

### Issue 1：【FR】无空闲 GPU 导致 TP 计算除零：calc_tp_size ZeroDivisionError
- **仓库**：`flagos-ai/vllm-plugin-FL`
- **类型**：startup-crash
- **触发场景**：服务启动前计算 TP 时，MUSA 显存检测在所有 GPU 均被占用的情况下返回 memory_gb=0，`calc_tp` 以 0 作分母触发除零；手动回退 TP=1 仍因无空闲显存无法调度服务。
- **影响**：步骤3 服务启动失败（service_ok=false，crashed=true, recovery=failed），未进入精度/性能评测阶段，迁移判失败。
- **处置**：等待 GPU 资源释放后重跑；calc_tp_size 需对 memory_gb=0 做空闲卡校验兜底，避免除零。
- **关键报错信息（核对自运行容器日志）**：
```text
Traceback (most recent call last):
  File "/flagos-workspace/scripts/calc_tp_size.py", line 162, in main
    tp, reason = calc_tp(model_size_gb, gpu_info["memory_gb"], gpu_info["count"])
  File "/flagos-workspace/scripts/calc_tp_size.py", line 117, in calc_tp
    raw_tp = math.ceil(estimated_required_gb / gpu_memory_gb)
ZeroDivisionError: float division by zero
```

---

报告生成时间：2026.09.08
