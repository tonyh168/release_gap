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
| 开始时间 | 2026-07-30 01:01:49 |
| gems+tree版本上传时间 | 2026-07-30 01:45:55 |
| 发布时间 | 2026-07-30 01:45:55 |
| 模型 | Ministral-3-14B-Instruct-2512 |
| 模型领域 | 语言 |
| 权重来源 | mistralai/Ministral-3-14B-Instruct-2512 |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0 |
| FlagGems版本 | 5.0.2 |
| Flagtree版本 | 0.5.1 |
| FlagCX版本 | - |
| 厂商 | 沐曦(Metax) |
| GPU | MetaX C550 : 8 x 64GB |
| 容器 | Ministral-3-14B-Instruct-2512_flagos |
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
| mistralai/Ministral-3-14B-Instruct-2512 | Metax | - | 8 | - | - | - | - | - | - | - | - |

### V2
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| mistralai/Ministral-3-14B-Instruct-2512 | Metax | - | 8 | - | - | - | - | - | - | - | - |

### V3
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| mistralai/Ministral-3-14B-Instruct-2512 | Metax | - | 8 | - | - | - | - | - | - | - | - |

### V4
| 模型名 | 厂商 | TFLOPS（单卡） | 卡数 | TFLOPS（单卡） × 卡数 | 4k-1k 64并发 - mean TTFT（ms） | 4k-1k 64并发 - P99 TTFT（ms） | 4k-1k 64并发 - output toks/s | 4k-1k 64并发 - total tok/s | 4k-1k 64并发 - Mean TPOT (ms) | 开算子数 | 单算力吞吐 |
|--------|------|---------------|------|---------------------|------|------|------|------|------|------|------|
| mistralai/Ministral-3-14B-Instruct-2512 | Metax | - | 8 | - | - | - | - | - | - | - | - |

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
| 流程耗时 | 44m 6s |
| 流程消费 | 58.52 元（≈ $8.13 × 7.2） |

# 发布信息

- Harbor 镜像
  - V1：（阶段一手动发布）
  - V2：harbor.baai.ac.cn/flagrelease-public/ministral-3-14b-instruct-2512-flagos-metax-fp8-incompatible:latest
  - V3：-
  - V4：-

- ModelScope: https://modelscope.cn/models/FlagRelease/Ministral-3-14B-Instruct-2512-FlagOS
- HuggingFace: https://huggingface.co/FlagRelease/Ministral-3-14B-Instruct-2512-FlagOS

# 结论

- 发布镜像上传正常：⚠️ 部分产出（V2 已产出，但未达标：服务启动失败、精度不达标（rel_drop 超阈值）、性能不达标）
- 流程自动化结论：❌ 迁移失败（服务启动失败、精度不达标（rel_drop 超阈值）、性能不达标）

## 提交到 flagos 仓库的 Issue
issue 数量：3
issue 标题：
1. 【FR】Bug: Operator accuracy degradation on metax (mistralai/Ministral-3-14B-Instruct-2512)
2. 【FR】Bug: Operator crash on metax (mistralai/Ministral-3-14B-Instruct-2512)
3. 【FR】Bug: Operator performance degradation on metax (mistralai/Ministral-3-14B-Instruct-2512)

---

报告生成时间：2026.08.05
