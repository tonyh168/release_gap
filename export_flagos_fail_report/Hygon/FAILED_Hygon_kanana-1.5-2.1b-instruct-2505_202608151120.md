# 迁移结果：❌ 失败（性能不达标（vs 合成基线 95.1% < 100%），综合判定 qualified=false）

> **自动化流程产出镜像版本：**
> - V1：tree版本=基础版：只带flagtree不开启任何flagos组件
> - V2：tree+gems=Pro版：开启flaggems且性能达到V1的80%，与V1的精度误差在5%以内
> - V3：tree+gems+plugin=Max版：在V2的基础上安装使用plugin，且性能达到V1的80%，与V1的精度误差在5%以内
> - V4：tree+gems+plugin=Flag-express版：在V3的基础上，性能表现超过V1版本

# 基本信息

| 项目 | 内容 |
|------|------|
| 项目名称 | KT2期 |
| 开始时间 | 2026-08-15 11:20:08 |
| gems+tree版本上传时间 | - |
| 发布时间 | - |
| 模型 | kanana-1.5-2.1b-instruct-2505 |
| 模型领域 | 语言 |
| 权重来源 | kakaocorp/kanana-1.5-2.1b-instruct-2505 |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0+gffa2ee3eb |
| FlagGems版本 | 5.4.0dev |
| Flagtree版本 | 0.6.0 |
| FlagCX版本 | - |
| 厂商 | Hygon |
| GPU | DCU BW1000 : 8 |
| 容器 | kanana-1.5-2.1b-instruct-2505_flagos_0815_1120 |
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
（服务启动时启用 27 个 FlagGems 算子；因流程未生成 report.md/report.json，日志未持久化完整算子白名单名单明细）
### 算子替换列表（txt）
替换算子数：27
（算子数取自服务启动日志 “27 FlagGems ops active”；具体算子名单未在事件流中留存）

## V3
### 算子白名单
（Plugin 流程未触发，未产出 V3）
### 算子替换列表（txt）
替换算子数：0
（未产出 V3）

## V4
### 算子白名单
（未产出 V4）
### 算子替换列表（txt）
替换算子数：0
（未产出 V4）

# 评测结果

## 精度评测

> 注：本模型为 Branch B（gems+tree+plugin），V1 环境不适用（native == flagos），V2 精度以 NV 参考基线（nv_baseline.yaml）为基准，评测集为 mmlu + math_500。

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | 使用NV参考基线 | 0 |
| math_500 | - | 使用NV参考基线 | 0 |

> 注：V1 环境无法启动或不适用，使用 NV 参考基线（nv_baseline.yaml）作为精度基准

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | 1140 | 54.82 | 27 |
| math_500 | 200 | 66.0 | 27 |

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
| V1 VS V2 | 使用NV参考基线，mmlu 54.82%>NV 53.35（rel-drop −2.76%）、math_500 66.0%>NV 60.6（rel-drop −8.91%）均达标 ✅ |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | - |

## 性能评测

> 注：V1 性能基线缺失，使用合成基线（V2 初始性能 940.8 tok/s × 1.05 = 987.8 tok/s，target_ratio 覆盖为 1.0）作为性能基准。

### V1
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| kakaocorp/kanana-1.5-2.1b-instruct-2505 | Hygon | - | 8 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| kakaocorp/kanana-1.5-2.1b-instruct-2505 | Hygon | - | 8 | - | 995.3 | - | 939.7 | 4698.6 | 66.8 | 27 | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| kakaocorp/kanana-1.5-2.1b-instruct-2505 | Hygon | - | 8 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| kakaocorp/kanana-1.5-2.1b-instruct-2505 | Hygon | - | 8 | - | - | - | - | - | - | - | - |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| V1 VS V2 | 性能比 95.1%（V2 939.7 tok/s vs 合成基线 987.8 tok/s），未达 100% 覆盖阈值，performance_ok=false ❌ |
| V1 VS V3 | - |
| V1 VS V4 | - |
| V2 VS V3 | - |

> 说明：合成基线为 V2 初始值 ×1.05（940.8→987.8），相当于“需超越自身 105%”的不可达标尺；939.7 与 940.8 之间为运行间噪声，5% 差距主要来自 ×1.05 放大而非真实回退。按流程判定口径 performance_ok=false，综合 qualified=false，故本次标记为失败。

# 流程耗时与消费

| 项目 | 内容 |
|------|------|
| 流程耗时 | 4h 42m 7s |
| 流程消费 | 194.98 元（≈ $27.08 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：-
  - V3：-
  - V4：-

- ModelScope: -
- HuggingFace: -

# 结论

- 发布镜像上传正常：❌ 未达标发布（性能不达标（vs 合成基线 95.1%），综合 qualified=false）
- 流程自动化结论：❌ 迁移失败

> 备注：本次迁移主流程执行至步骤 6（性能评测），精度达标（accuracy_ok=true），性能按合成基线口径判定不达标（performance_ok=false），综合判定 qualified=false。流程在容器准备阶段发生会话中断（耗时 282m7s 后中断，pipeline 触发自动重试），最终未生成 report.md/report.json，本报告依据流水线事件流日志（claude_pipeline / pipeline.log / terminal.log）人工回填。服务启动阶段曾命中真实阻塞：transformers 5.8.1 的 LlamaConfig.validate_architecture 因该模型解耦 head_dim（hidden_size 1792 不被 24 个 head 整除、显式 head_dim=128）而报错，经修补 configuration_llama.py（在设置 head_dim 时跳过校验，已备份）后干净启动（TP1、GPU0、port 8000、max_model_len 32768、27 个 FlagGems 算子、启动 321s，冒烟测试正确）。

## 提交到 flagos 仓库的 Issue
issue 数量：1
issue 标题：
1. 【FR】Bug: Operator performance below synthetic baseline on 海光(Hygon) (kakaocorp/kanana-1.5-2.1b-instruct-2505)

---

报告生成时间：2026.08.20
