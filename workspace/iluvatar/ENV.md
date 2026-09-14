# 天数 Iluvatar 环境信息

> 真实值取自失败报告 `release_迁移失败报告/iluvatar/` 的「基本信息」表；`<...>` 为需现场填写的未知项。

## 硬件 / 宿主机

| 项目 | 值 | 说明 |
|------|----|----|
| GPU | 天数 BI 系列（corex 生态），单机多卡 | 参考模型 XingChen4 用 TP=8（卡 8~15） |
| 宿主机（ssh 免密） | `iluvatar-117` `iluvatar-211` | |
| 设备节点 | `/dev/iluvatar` | 启容器时透传（见模板 01） |
| 驱动自检 | `ixsmi` | |
| 共享存储 | 宿主机模型盘 → 容器 `/models`（如 `/models/XingChen4-29B-A4B-0907`） | |

## 软件栈（FlagOS，报告实测版本）

| 组件 | 版本 | 备注 |
|------|------|------|
| 推理后端 vllm | 失败报告实测 0.20.2；**当前 xingchen4-0907 镜像为 vllm_fl 0.24.0** | |
| plugin-FL | 0.2.0（报告期） | |
| FlagGems | 报告期 5.0.0；镜像预装 5.3.4.post1.dev11 | |
| Flagtree | 0.6.0 | |
| FlagCX | 未启用（cxnone） | |
| 权重/计算数制 | bf16 | |

> 说明：上表「报告期」列取自旧失败报告（0.20.2 栈）；实际用[[镜像]]里 xingchen4-0907（vllm_fl 0.24.0）复现修复，以容器内 `pip show` 实测为准。

## 镜像

| 项目 | 值 |
|------|----|
| 镜像仓库 / tag | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 内含 | corex4.5.0 / flagtree0.6.0 / triton3.6.0 / cxnone / vllm_fl 0.24.0 |
| 容器命名习惯 | `<模型名>_flagos` |

## 起服务运行时（XingChen4-0907 实测参考）

| 项目 | 值 |
|------|----|
| 环境变量 | `GEMS_VENDOR=iluvatar` / `VLLM_PLUGINS=fl` / `CUDA_VISIBLE_DEVICES=8..15` / `VLLM_WORKER_MULTIPROC_METHOD=spawn` / **`VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable`（必设否则 hang）** / `VLLM_ENGINE_ITERATION_TIMEOUT_S=72000` / `VLLM_RPC_TIMEOUT=72000000` / `VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200` |
| serve flags | `--dtype bfloat16 --tensor-parallel-size 8 --max-model-len 32768 --gpu-memory-utilization 0.9 --attention-backend TRITON_MLA --chat-template <目录>/chat_template.jinja --enforce-eager --trust-remote-code` |
| 镜像内组件 | `vllm-plugin-FL`(含 corex patch) / `FlagGems-vllm`(GEMS_VENDOR=iluvatar) / FlagGems 预装 5.3.4.post1.dev11 |
| 模型名约定 | `model_name` 取 NV 表 key；served-model-name / 评测 model-name / 日志目录统一用它 |
| 日志/结果落盘 | `/models/release_run_logs/${model_name}/` |
| 评测执行位置 | 同一台 iluvatar 宿主机常驻的 `llm-eval` 容器 |

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
