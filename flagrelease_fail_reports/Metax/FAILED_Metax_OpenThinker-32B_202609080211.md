# 迁移结果：❌ 失败（服务启动崩溃，V2/V3 未产出）

> **自动化流程产出镜像版本：**
> - V1：tree版本=基础版：只带flagtree不开启任何flagos组件
> - V2：tree+gems=Pro版：开启flaggems且性能达到V1的80%，与V1的精度误差在5%以内
> - V3：tree+gems+plugin=Max版：在V2的基础上安装使用plugin，且性能达到V1的80%，与V1的精度误差在5%以内
> - V4：tree+gems+plugin=Flag-express版：在V3的基础上，性能表现超过V1版本

# 基本信息

| 项目 | 内容 |
|------|------|
| 项目名称 | KT2期 |
| 开始时间 | - |
| gems+tree版本上传时间 | 2026-09-04 18:06:11 |
| 发布时间 | 2026-09-04 18:06:11 |
| 模型 | OpenThinker-32B |
| 模型领域 | 语言 |
| 权重来源 | open-thoughts/OpenThinker-32B |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.24.0 |
| 推理框架插件plugin-FL | 0.2.0 |
| FlagGems版本 | 5.4.0 |
| Flagtree版本 | 0.6.0 |
| FlagCX版本 | - |
| 厂商 | 沐曦(Metax) |
| GPU | Metax C550 : 8 x 64GB |
| 容器 | OpenThinker-32B_flagos |
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
（无数据）
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

> V2 FlagGems 开启后服务启动崩溃，算子调优未能定位可归因算子，V2/V3 精度评测未能完成（无有效数据）。

### V1
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - | - |
| math_500 | - | - | - |

### V2
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - | - |
| math_500 | - | - | - |

### V3
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - | - |
| math_500 | - | - | - |

### V4
| 数据集 | 评测条数 | 正确率(%) | 开启算子数 |
|--------|---------|-----------|-----------|
| mmlu | - | - | - |
| math_500 | - | - | - |

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
| open-thoughts/OpenThinker-32B | Metax | - | 8 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| open-thoughts/OpenThinker-32B | Metax | - | 8 | - | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| open-thoughts/OpenThinker-32B | Metax | - | 8 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| open-thoughts/OpenThinker-32B | Metax | - | 8 | - | - | - | - | - | - | - | - |

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
| 流程耗时 | 29m 36s |
| 流程消费 | 239.17 元（≈ $33.22 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/openthinker-32b-metax001-gems5.4.0-tree0.6.0-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt28-maca37-x64-3.3.12:202609050156-v2
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/OpenThinker-32B-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/OpenThinker-32B-FlagOS

# 结论

- 发布镜像上传正常：❌ 未达标发布（服务启动崩溃，V2/V3 未产出可交付版本，仅 Harbor 私有留存）
- 流程自动化结论：❌ 迁移失败（V2 FlagGems 开启后服务启动崩溃，算子调优未能定位可归因算子；精度/性能评测未完成）

## 提交到 flagos 仓库的 Issue
issue 数量：3
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on 沐曦(Metax) (open-thoughts/OpenThinker-32B)
2. 【FR】Bug: Operator crash: libentry, mm on 沐曦(Metax) (open-thoughts/OpenThinker-32B)
3. 【FR】Bug: Operator performance degradation on 沐曦(Metax) (open-thoughts/OpenThinker-32B)

---

报告生成时间：2026.09.05