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
| 开始时间 | 2026-09-08 05:01:00 |
| gems+tree版本上传时间 | - |
| plugin上传时间 | - |
| 发布时间 | - |
| 模型 | Qwen3.5-27B-Derestricted |
| 模型领域 | 语言 |
| 权重来源 | ArliAI/Qwen3.5-27B-Derestricted |
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
| 容器 | Qwen3.5-27B-Derestricted_flagos |
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
| ArliAI/Qwen3.5-27B-Derestricted | Mthreads | - | 1 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| ArliAI/Qwen3.5-27B-Derestricted | Mthreads | - | 1 | - | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| ArliAI/Qwen3.5-27B-Derestricted | Mthreads | - | 1 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| ArliAI/Qwen3.5-27B-Derestricted | Mthreads | - | 1 | - | - | - | - | - | - | - | - |

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
> 失败原因：服务启动成功（default 模式 62 算子，health 200 OK，推理验证通过），但精度评测阶段中断、未产出有效评测结果（accuracy_ok=false）。
> 补充说明：仅完成 V2==V3 双 tag 私有镜像发布（qualified=false，不对外）。

# 结论

- 发布镜像上传正常：❌ 未达标（流程在「步骤4 精度评测」中断，无有效精度/性能评测数据）
- 流程自动化结论：❌ 迁移失败

## 提交到 flagos 仓库的 Issue
issue 数量：2

### Issue 1：【FR】vllm_fl 引擎核心初始化崩溃：Qwen3.5 GDN/mamba 线性注意力 profile_run 失败
- **仓库**：`flagos-ai/vllm-plugin-FL`
- **类型**：startup-crash
- **触发场景**：V2 baseline 启动 Qwen3.5-27B（qwen3_next 混合 GDN/mamba 线性注意力结构）时，vllm_fl worker 在 `profile_run` 显存探测阶段进入 GDN linear attention 的 gemm 路径，torch_dynamo 在 torch_musa 后端编译该算子失败，引擎核心初始化崩溃。
- **影响**：默认模式引擎核心初始化失败；改 enforce-eager 绕过编译后服务可起（62 算子，health 200），但精度评测阶段服务停滞（service_stall，305s 无日志活动），未产出有效评测结果。
- **处置**：需 vllm-plugin-FL 侧适配 qwen3_next GDN 线性注意力在 torch_musa 下的编译路径。
- **关键报错信息（核对自运行容器日志）**：
```text
RuntimeError: Engine core initialization failed. See root cause above. Failed core proc(s): {}
root cause traceback:
  File "/workspace/vllm-plugin-FL/vllm_fl/worker/worker.py", line 488, in determine_available_memory
    self.model_runner.profile_run()
  File "/workspace/vllm-plugin-FL/vllm_fl/worker/model_runner.py", line 5908, in profile_run
    hidden_states, last_hidden_states = self._dummy_run(...)
  File ".../vllm/model_executor/models/qwen3_next.py", line 408, in forward
  File ".../vllm/model_executor/layers/mamba/gdn_linear_attn.py", line 544, in forward_cuda
  File ".../vllm/model_executor/layers/utils.py", line 98, in default_unquantized_gemm
  → torch_dynamo 编译异常（torch_musa 后端），profile_run 阶段中止
```

### Issue 2：【FR】vllm_fl 与厂商 platform plugin 激活冲突：['musa', 'fl']
- **仓库**：`flagos-ai/vllm-plugin-FL`
- **类型**：startup-crash
- **触发场景**：容器同时注册了 musa 厂商 platform plugin 与 fl plugin，vllm 平台插件互斥检查报错。
- **影响**：需显式选择单一 platform plugin 方能启动，增加基线选择复杂度。
- **处置**：按 baseline_selector 优先级固定 VLLM_PLUGINS，避免双 platform plugin 同时激活。
- **关键报错信息（核对自运行容器日志）**：
```text
Error: Only one platform plugin can be activated, but got: ['musa', 'fl']
```

---

报告生成时间：2026.09.08
