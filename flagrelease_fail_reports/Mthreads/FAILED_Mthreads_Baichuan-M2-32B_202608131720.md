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
| 开始时间 | - |
| gems+tree版本上传时间 | - |
| 发布时间 | 2026-08-13 17:20:00 |
| 模型 | Baichuan-M2-32B |
| 模型领域 | 语言 |
| 权重来源 | baichuan-inc/Baichuan-M2-32B |
| 权重数制 | bf16 |
| 计算数制（默认权重数制） | bf16 |
| 推理框架后端 | vllm |
| 推理框架后端版本 | 0.20.2 |
| 推理框架插件plugin-FL | 0.2.0+g8a1c299e5 |
| FlagGems版本 | 5.3.0rc2 |
| Flagtree版本 | 0.6.1 |
| FlagCX版本 | - |
| 厂商 | 摩尔(Mthreads) |
| GPU | MTT S5000 : 8 x -GB |
| 容器 | Baichuan-M2-32B_flagos |

# 评测结果

（以下数据来自流水线迁移摘要，原始格式）

```
模型: baichuan-inc/Baichuan-M2-32B | GPU: 8xmthreads GPU | 环境: vllm_plugin_flaggems

精度评测:
  V1=0% V2=0% 偏差=0% → 不达标
  调优: 未触发

性能评测:
  V1=0 V2=0 tok/s, ratio=0% → 不达标
  调优: 未触发

算子配置 vs 运行时 txt 对比:

Issue:
  [1] 【FR】Bug: Operator accuracy degradation on mthreads (baichuan-inc/Baichuan-M2-32B) (精度下降)
      复现: 1. Set up environment on mthreads
  [2] 【FR】Bug: Operator performance degradation on mthreads (baichuan-inc/Baichuan-M2-32B) (性能下降)
      复现: 1. Set up environment on mthreads

发布: qualified=False (未达标, 私有)
═══════════════════════
```

# 发布信息

（无发布链接）

# 结论

- 发布镜像上传正常：❌ 未发布
- 流程自动化结论：❌ 迁移失败（未达标）

