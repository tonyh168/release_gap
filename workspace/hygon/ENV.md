# 海光 Hygon 环境信息

> 真实值取自失败报告 `release_迁移失败报告/hygon/` 的「基本信息」表；`<...>` 为需现场填写的未知项。

## 硬件 / 宿主机

| 项目 | 值 | 说明 |
|------|----|----|
| GPU | DCU BW1000，单机 8 卡（显存报告未记，按 `<容量>GB`） | ROCm 生态 |
| 宿主机 IP / 登录 | `<host-ip / ssh 账号>` | 现场填写 |
| 设备节点 | `/dev/kfd`、`/dev/dri` | 启容器需 `--security-opt seccomp=unconfined`（见模板 01） |
| 驱动自检 | `rocm-smi` | 容器内应能看到 8 卡 |

## 软件栈（FlagOS，报告实测版本）

| 组件 | 版本 | 备注 |
|------|------|------|
| 推理后端 vllm | 0.20.2 | ROCm 版，依赖 `vllm._rocm_C` 等编译扩展 |
| plugin-FL | 0.2.0 | |
| FlagGems | 5.4.0dev | |
| Flagtree | 0.6.1 | |
| FlagCX | - | 未启用 |
| 权重/计算数制 | bf16 | |

## 镜像

| 项目 | 值 |
|------|----|
| 镜像仓库 / tag | `<hygon flagos 镜像地址:tag>` |
| 容器命名习惯 | `<模型名>_flagos` |

> ⚠ 海光特有坑：镜像若缺 `vllm._rocm_C / vllm._C / libhydmi.so` 编译产物，`import vllm` 直接失败。选镜像时先在容器内 `python -c "import vllm"` 验证，再下模型。详见 [[KNOWLEDGE]] 一、服务启动失败。

## 版本口径（V1–V4）

- **V1** 基础版：只带 Flagtree，不开任何 FlagOS 组件（裸 vLLM 基线）。
- **V2** Pro：开 FlagGems，性能≥V1 的 80%、精度误差≤5%。
- **V3** Max：V2 基础上加 plugin。
- **V4** Flag-express：性能超过 V1。

## 本厂商已知失败模型（详见 fixes/ 与 KNOWLEDGE.md）

- Light-R1-7B-DS — 镜像缺编译扩展，服务无法启动
- Magistral-Small、Mistral-Small-24B、sarvam-m — plugin-FL 报错 / 精度框架级退化
- Phi-3-medium-128k、SOLAR-10.7B、DeepSeek-R1-Distill-Qwen-32B-Japanese、Nanbeige4.1-3B — 精度不达标
- Qwen2.5-7B-Instruct — V2 GPQA 仅 40.0%
- Phi-3-mini-128k — 报告显示 ✅ 合格（异常，需复核是否误列）
