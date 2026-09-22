# 海光 Hygon 环境信息

> 真实值取自失败报告 `release_迁移失败报告/hygon/` 的「基本信息」表；`<...>` 为需现场填写的未知项。

## 硬件 / 宿主机

| 项目 | 值 | 说明 |
|------|----|----|
| GPU | 海光 HCU / DCU（DTK/ROCm 生态），单机多卡 | 参考模型 XingChen4 用 TP=4 |
| 宿主机（ssh 免密） | `hygon-30` `hygon-31` `hygon-32` `hygon-33` | |
| 设备节点 | `/dev/kfd`、`/dev/dri` | 启容器需 `--security-opt seccomp=unconfined --group-add video`（见模板 01） |
| DTK | 容器内优先使用 `/opt/dtk` 稳定入口 | **起服务前必须** `source /opt/dtk/env.sh`；若镜像没有该入口，先按实际镜像确认路径 |
| 驱动自检 | `hy-smi` | |
| 共享存储 | 宿主机模型盘 → 容器 `/models`（如 `/models/XingChen4-29B-A4B-0907`） | |

## 软件栈（FlagOS，报告实测版本）

| 组件 | 版本 | 备注 |
|------|------|------|
| 推理后端 vllm | 失败报告实测 0.20.2；**当前 xingchen4-0907 镜像为 0.24.0** | ROCm 版，依赖 `vllm._rocm_C` 等编译扩展 |
| plugin-FL | 0.2.0（报告期） | |
| FlagGems | 5.4.0dev（报告期） | |
| Flagtree | 0.6.1（报告期）；镜像 tag 标 3.6 | |
| FlagCX | - | 未启用 |
| 权重/计算数制 | bf16 | |

> 说明：上表「报告期」列取自旧失败报告（0.20.2 栈）；实际用[[镜像]]里 xingchen4-0907（vLLM 0.24.0）复现修复，以容器内 `pip show` 实测为准。

## 镜像

| 项目 | 值 |
|------|----|
| 镜像仓库 / tag | `harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4` |
| 内含 | vLLM 0.24.0 / py310 / torch2.10 / dtk26.04 / flagtree3.6 |
| 容器命名习惯 | `<模型名>_flagos` |

> ⚠ 海光特有坑：镜像若缺 `vllm._rocm_C / vllm._C / libhydmi.so` 编译产物，`import vllm` 直接失败。选镜像时先在容器内 `python -c "import vllm"` 验证，再下模型。详见 [[KNOWLEDGE]] 一、服务启动失败。

## 起服务运行时（XingChen4-0907 实测参考）

| 项目 | 值 |
|------|----|
| 环境变量 | `GEMS_VENDOR=hygon` / `VLLM_PLUGINS=fl` / `HIP_VISIBLE_DEVICES=0,1,2,3` / `VLLM_WORKER_MULTIPROC_METHOD=spawn` / `VLLM_FL_FLAGOS_BLACKLIST=cat,slice` / 超时 `VLLM_ENGINE_ITERATION_TIMEOUT_S`+`VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS`=7200 |
| serve flags | `--dtype bfloat16 --tensor-parallel-size 4 --max-model-len 80000 --gpu-memory-utilization 0.9 --attention-backend TRITON_MLA --no-enable-chunked-prefill --no-enable-prefix-caching --enforce-eager --trust-remote-code` |
| 首请求慢 | Triton JIT 编译，单请求可达 ~456s，属正常，非稳态性能 |
| 模型名约定 | `model_name` 取 NV 表 key；served-model-name / 评测 model-name / 日志目录统一用它，`--nv-baseline` 自动命中基线 |
| 日志/结果落盘 | `/models/release_run_logs/${model_name}/`（serve.log + gpqa.json + verdict.json） |
| 评测执行位置 | 同一台 hygon 宿主机常驻的 `llm-eval` 容器 |

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
