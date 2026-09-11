# 沐曦 Metax 环境信息

> 真实值取自失败报告 `release_迁移失败报告/metax/` 的「基本信息」表；`<...>` 为需现场填写的未知项。

## 硬件 / 宿主机

| 项目 | 值 | 说明 |
|------|----|----|
| GPU | MetaX C550，单机 8 卡，每卡 ~63.6GB | 32B 模型建议 TP=8 |
| 宿主机 IP / 登录 | `<host-ip / ssh 账号>` | 现场填写 |
| 设备节点 | `/dev/dri`、`/dev/mxcd` | 启容器时透传（见模板 01） |
| 驱动自检 | `mx-smi` | 容器内应能看到 8 卡 |

## 软件栈（FlagOS，报告实测版本）

| 组件 | 版本 | 备注 |
|------|------|------|
| 推理后端 vllm | 0.20.2 | |
| plugin-FL | 0.2.0 | 推理框架插件 |
| FlagGems | 5.0.2 | 算子库 |
| Flagtree | 0.6.1 | |
| FlagCX | - | 未启用 |
| 权重/计算数制 | bf16 | |

## 镜像

| 项目 | 值 |
|------|----|
| 镜像仓库 / tag | `<metax flagos 镜像地址:tag>` |
| 容器命名习惯 | `<模型名>_flagos` |

## 版本口径（V1–V4）

- **V1** 基础版：只带 Flagtree，不开任何 FlagOS 组件（裸 vLLM 基线）。
- **V2** Pro：开 FlagGems，性能≥V1 的 80%、精度误差≤5%。
- **V3** Max：V2 基础上加 plugin，指标要求同 V2。
- **V4** Flag-express：V3 基础上性能超过 V1。
- 手动修复通常从 V1 起验证服务可用，再逐级开组件定位问题。

## 本厂商已知失败模型（详见 fixes/ 与 KNOWLEDGE.md）

- EXAONE-4.0-32B、GLM-4-32B-0414、Qwen3-Coder-30B-A3B — 服务启动失败
- SOLAR-10.7B — plugin-FL 报错
- Phi-3-mini-128k-instruct — 精度偏差 ~4%、性能 ~79% 踩线
