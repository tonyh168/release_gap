# 迁移结果：❌ 失败（未纳入发布清单）

> **说明：** 本报告依据魔搭已发布版本（external-cooperation 历史合作版）重建。当前批次（20260811/20260813）中 Seed-OSS 的 workspace 为空、日志停在步骤1，未走标准自动化流程；此处按已发布 README 数据补充完整。

# 基本信息

| 项目 | 内容 |
|------|------|
| 项目名称 | KT2期 |
| 模型 | Seed-OSS-36B-Instruct |
| 模型领域 | 语言 |
| 权重来源 | ByteDance-Seed/Seed-OSS-36B-Instruct |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.13.0 |
| 推理框架插件plugin-FL | 0.1.1 |
| FlagGems版本 | 5.0.2 |
| Flagtree版本 | 0.5.1 |
| FlagCX版本 | - |
| 厂商 | 摩尔(Mthreads) |
| GPU | MTT S5000 : 2 x MTT S5000 |
| 容器 | Seed-OSS-36B-Instruct_flagos |
| release自动化工具版本 | 外部合作版 |

# 评测结果

## 精度评测（多 benchmark）

| 数据集 | Nvidia-Origin | Mthreads-FlagOS |
|--------|---------------|-----------------|
| gpqa_generative_cot | 0.6149 | 0.6074 |
| aime | 0.666 | 0.6667 |
| livebench_new | 0.51 | 0.5213 |
| musr_generative | 0.4167 | 0.3995 |
| mmlu_pro | 0.488 | 0.4819 |

### 结果对比
| 对比项 | 结果 |
|--------|------|
| 主指标 gpqa_generative_cot | 精度偏差 1.22%（0.6149 → 0.6074，达标） |

# 发布信息

- Harbor 镜像
  - harbor.baai.ac.cn/external-cooperation/seed-oss-36b-instruct-mthreads-tree_0.5.1-gems_5.0.2_vllm_0.13.0_plugin_0.1.1_cx_none_python_3.10.12_torch_2.7.1_pcp_musa_4.3.5_mtt_s5000_x86_64_driver_2.3.2:2608071625

- ModelScope: https://www.modelscope.cn/models/FlagRelease/Seed-OSS-36B-Instruct-mthreads-FlagOS
- HuggingFace: -

# 结论

- 发布镜像上传正常：❌ 未发布（未纳入发布清单）
- 流程自动化结论：❌ 迁移失败（未纳入发布清单；主指标 gpqa 精度偏差 1.22%）

---

报告生成时间：2026.08.19（依据已发布版重建）
