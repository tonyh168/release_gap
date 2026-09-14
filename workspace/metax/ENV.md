# 沐曦 Metax 环境信息

> 真实值取自失败报告 `release_迁移失败报告/metax/` 的「基本信息」表；`<...>` 为需现场填写的未知项。

## 硬件 / 宿主机

| 项目 | 值 | 说明 |
|------|----|----|
| GPU | MetaX C550，单机 8 卡，每卡 ~63.6GB | 32B 模型建议 TP=8 |
| 宿主机 | `metax-57` / `metax-58` / `metax-59` / `metax-60` / `metax-108` / `metax-109` | ssh 免密直连，如 `ssh metax-57` |
| 共享存储 | 宿主机 `/public-flash/models` → 容器 `/models` | 权重共享盘，各机可见 |
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
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907` |
| vLLM 版本 | 0.24.0（注意：报告基线是 0.20.2，此镜像更高） |
| 容器命名习惯 | `<模型名>_flagos`（示例镜像默认 `xingchen4`） |

> ⚠ 此镜像 vLLM 为 **0.24.0**，与失败报告实测的 0.20.2 不同。0.24 重构了 MLA impl 接口（新增 `forward_mha`/`forward_mqa`），plugin-FL 需对齐；详见 [[KNOWLEDGE]] 与 xingchen4 PR 记录。

## 评测标准

| 项目 | 值 |
|------|----|
| 脚本目录（宿主机） | `/Users/baai/Desktop/baai_proj/release_gap/release_评测标准` |
| 内含 | `fast_gpqa.py`、`accuracy_compare.py`、`nv_baseline.yaml`、`fast_gpqa_config.yaml` |
| 评测执行位置 | 起 vLLM 的**同一台 metax 宿主机**，机上常驻 `llm-eval` 容器；脚本在其中跑 |
| 访问服务 | serve 容器 `--network host`，`llm-eval` 内直接 `http://127.0.0.1:8000/v1` |
| 日志/结果落盘 | `/models/release_run_logs/${model_name}/`（serve.log + gpqa.json + verdict.json 同目录） |
| 模型名约定 | `model_name` 取 NV 表（`nv_baseline.yaml`）的 key；served-model-name / 评测 model-name / 日志目录统一用它，`--nv-baseline` 自动命中基线 |

## NV 基线可查模型（本厂商失败清单）

| 模型 | nv_baseline.yaml key | 权重来源 |
|------|----------------------|----------|
| EXAONE-4.0-32B | `EXAONE-4.0-32B` | LGAI-EXAONE/EXAONE-4.0-32B |
| GLM-4-32B-0414 | `GLM-4-32B-0414` | zai-org/GLM-4-32B-0414 |
| Qwen3-Coder-30B-A3B-Instruct | `Qwen3-Coder-30B-A3B-Instruct` | Qwen/Qwen3-Coder-30B-A3B-Instruct |
| Phi-3-mini-128k-instruct | `Phi-3-mini-128k-instruct` | microsoft/Phi-3-mini-128k-instruct |
| SOLAR-10.7B-Instruct-v1.0 | `SOLAR-10.7B-Instruct-v1.0` | upstage/SOLAR-10.7B-Instruct-v1.0 |

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
