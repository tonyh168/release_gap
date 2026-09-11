# 天数 Iluvatar 环境信息

> 真实值取自失败报告 `release_迁移失败报告/iluvatar/` 的「基本信息」表；`<...>` 为需现场填写的未知项。

## 硬件 / 宿主机

| 项目 | 值 | 说明 |
|------|----|----|
| GPU | BI-V150，单机 16 卡（显存报告未记，按 `<容量>GB`） | 卡数多但单卡算力弱，TP 可开大 |
| 宿主机 IP / 登录 | `<host-ip / ssh 账号>` | 现场填写 |
| 设备节点 | `/dev/iluvatar` | 启容器时透传（见模板 01） |
| 驱动自检 | `ixsmi` | 容器内应能看到 16 卡 |

## 软件栈（FlagOS，报告实测版本）

| 组件 | 版本 | 备注 |
|------|------|------|
| 推理后端 vllm | 0.20.2 | |
| plugin-FL | 0.2.0 | |
| FlagGems | 5.0.0 | |
| Flagtree | 0.6.0 | |
| FlagCX | 未启用（cxnone） | |
| 权重/计算数制 | bf16 | |

## 镜像

| 项目 | 值 |
|------|----|
| 镜像仓库 / tag | `<iluvatar flagos 镜像地址:tag>` |
| 容器命名习惯 | `<模型名>_flagos` |

## 版本口径（V1–V4）

- **V1** 基础版：只带 Flagtree，不开任何 FlagOS 组件（裸 vLLM 基线）。
- **V2** Pro：开 FlagGems，性能≥V1 的 80%、精度误差≤5%。
- **V3** Max：V2 基础上加 plugin。
- **V4** Flag-express：性能超过 V1。

## 本厂商已知失败模型（详见 fixes/ 与 KNOWLEDGE.md）

- QwQ-32B、TinyR1-32B-Preview、Phi-3-medium-128k、MiroThinker-v1.5-30B — 服务启动失败，未产出可评测服务
- OpenThinker-7B — 服务可启（65 算子 TP=1），评测跑到 mmlu 145/1140 中断
- Fathom-R1-14B、LFM2.5-1.2B-Thinking、SOLAR-10.7B — 待逐个复核
- 备注：0910 CSV 列 48 个失败模型，但 zip 仅含 8 份报告，其余无报告需另取
