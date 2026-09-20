# 摩尔线程 Mthreads 环境信息

> 真实值取自两处：**① 现场实测**（2026-09-20 登录 `mthreads-25` / `mthreads-27` 扫描，见下「存储」节）；
> **② 失败报告** `flagrelease_fail_reports/Mthreads/`（50 份）的「基本信息」表 + FlagRelease 流水线的摩尔容器模板。
> `<...>` 为需现场填写 / 核对的未知项。

## 硬件 / 宿主机

| 项目 | 值 | 说明 |
|------|----|------|
| GPU | MTT S5000（MUSA 生态），单机 8 卡，**单卡实测 81920 MiB（80 GB）** | `mthreads-gmi -q -d MEMORY` 实测（2026-09-20，mthreads-25）；报告侧卡数分布：8 卡 ×34、1 卡 ×11、4 卡 ×2、2 卡 ×2、16 卡 ×1 |
| GPU 编码 | `mthreads001` | FlagOS 流水线对 MTT S5000 的编码（镜像 tag / 容器名里能看到） |
| 驱动 | **3.3.5-server**（实测）；BIOS 4.3.46；GPU Name `PH100` | `mthreads-gmi -q` 实测 |
| 宿主机（ssh 免密） | ✅ `mthreads-25`<br>✅ `mthreads-27`<br>❌ `mthreads-26` | 三台均已在 `~/.ssh/config` 配好（bastion 跳板 `bastion.aiops.baai.ac.cn:2224`）。<br>**`mthreads-26` 当前不可用**：登录返回 `match asset failed: No found asset`（跳板侧资产缺失），2026-09-20 复测两次均如此，**开工前先找发起人确认是否已下线/改名**。 |
| 机器名 | `bm-mthreads-bjsjq-zone1-moer-s5000-80g-38-25`（25）/ `…-27`（27） | 从 hostname 可读出：摩尔 S5000 80G 机型 |
| 设备节点 | 无需显式 `--device`；容器用 `--privileged` 透传（实测 8 卡全可见） | 见 `_shared/templates/01_start_container.sh` 的 mthreads 分支 |
| 驱动自检 | `mthreads-gmi`（`/usr/bin/mthreads-gmi`） | 实测容器内可见 8 张 MTT S5000 |
| 共享存储 | **`/datapool`（LeoFS 网络盘，50T，剩 38T，权限 777）** | ⚠ **本机型没有 `/public-flash`**——详见下「存储」节 |
| 占用现状（2026-09-20 12:42） | 8 卡基本空闲：GPU0 仅 35 MiB（无进程），其余 7 卡 0 MiB | 但宿主机上跑着多个**别人的容器**（`sglang_fl_*`、`flagtree-*`、`legilla` 等）——**用前必须 `mthreads-gmi -q` 复查，别抢卡** |

```bash
ssh mthreads-25                 # 或 mthreads-27；26 当前不可用
mthreads-gmi -q                 # 摩尔查卡：每卡显存/进程；有占用先问清楚再用，别抢卡
```

## 存储（2026-09-20 实测扫描，`mthreads-25` / `mthreads-27` 两台一致；26 不可达未测）

> ⚠ **本机型的共享盘不是 `/public-flash`**。`/public-flash` 在 25/27 上**都不存在**；
> 两台机器的存储布局如下，**共享盘只有 `/datapool` 一个**（已实测：在 25 上建目录，27 立即可见）。

| 路径 | 类型 | 容量 | 是否跨机共享 | 用途 |
|------|------|------|:------------:|------|
| **`/datapool`** | **LeoFS 网络文件系统**（`mds=172.220.0.1`） | 50T，剩 38T | ✅ **是**（25/27 内容一致，已实测） | **共享模型池**，权限 777 |
| `/datapool/models` | LeoFS 子目录 | — | ✅ 是 | 通用模型池（`aya-23-8B`、`Phi-3-mini-128k-instruct`、`Qwen2.5-7B-Instruct`、`DeepSeek-V4-*` 等，含 `.downloads`）；另有各团队自建目录（`flagos-qwen36-*`、`codex-musa-0518` …） |
| `/data` | 本机 ext4（`data--vg-data--lv`） | 13T，剩 11T | ❌ **否**（25 与 27 内容不同） | 本机工作区（`/data/flagos-workflow`、各模型的 `*-mthreads-FlagOS` 目录、`/data/vllm-plugin-fl`） |
| `/mnt/his_test` | NFS（`10.121.38.4:/data/nfs/his_test`） | 13T | 由 NFS 侧决定 | 测试共享盘，与本项目无关 |
| `/var/lib/containerd` | 本机 ext4 | 1.5T | ❌ 否 | 容器镜像层（`docker` 数据根在 `/data/docker`） |

**既有容器的挂载惯例（实测）**：`sglang_fl_*` 等容器用的是 **`-v /datapool:/datapool`（内外同路径，不重映射到 `/models`）**，
另有 `-v /data:/data` 的用法。本项目沿用「内外同路径」，避免与既有容器冲突。

**本项目约定的路径（建议，若与既有规范冲突请告知）**：

| 用途 | 宿主机 / 容器内路径（同路径） |
|------|------------------------------|
| 项目根 | `/datapool/flagrelease/` |
| 权重落盘 | `/datapool/flagrelease/fixes_models/<模型名>` |
| serve 日志 + 评测结果 | `/datapool/flagrelease/release_run_logs/<模型名>/` |

> 选择理由：`/datapool` 是唯一跨机共享盘（两台机器都能读到同一份权重，已实测验证）；直接建在 777 的 `/datapool` 下而不放进
> `/datapool/models`，是为了不污染那个已被多个团队共用的通用模型池。
> **与其余厂商的差异**：其他厂商统一为「共享盘 → 容器 `/models`」，本机型因为既有容器用内外同路径，改为 `/datapool/...` 原样挂载；下文命令均按此写。
>
> **✅ 已建好**：`/datapool/flagrelease/{fixes_models,release_run_logs}`（2026-09-20 在 25 上创建，27 端已验证可见）。


## 软件栈

### A. 本轮修复镜像实测版本（2026-09-20 在 mthreads-25 起容器实测，✅ 权威）

镜像：`harbor.baai.ac.cn/flagrelease-public/flagrelease_mthreads-gmi_vllm024plugin_base:08281629`

| 组件 | 版本 | 备注 |
|------|------|------|
| Python | 3.10.12 | `/usr/bin/python` |
| 推理后端 vllm | **0.24.0** | `/usr/local/bin/vllm`（**没有 `/opt/conda`**，见 SOP 第 3 节） |
| plugin-FL | **0.3.0** | `/usr/local/lib/python3.10/dist-packages` |
| FlagGems | **5.3.2.post1.dev22+gb1f939eb5.d20260804** | 包名 `flag_gems` |
| Flagtree | **0.6.0+mthreads.gitb97f8214** | |
| torch / torch_musa | **2.9.0 / 2.9.0** | |
| MUSA / 驱动 | MUSA 4.3.5（`/usr/local/musa`）；驱动 **3.3.5-server** | `mthreads-gmi` 实测 |
| tilelang_musa | 0.1.8+musa.3.gitc3ed1bd5 | |
| FlagCX | - | 未启用 |
| 权重/计算数制 | bf16 | |

**镜像内置环境变量**（`docker inspect` 实测，**无需再手动传**）：

| 变量 | 值 | 说明 |
|------|----|------|
| `VLLM_PLUGINS` | `fl` | ✅ plugin-FL 已内置启用，**不用再 export** |
| `MTHREADS_VISIBLE_DEVICES` | `all` | 卡可见性（容器内 8 卡全可见） |
| `MTHREADS_DRIVER_CAPABILITIES` | `all` | |
| `VLLM_USE_MODELSCOPE` | `true` | vLLM 走 ModelScope 源 |
| `PYTORCH_MUSA_ALLOC_CONF` | `expandable_segments:True` | |
| `MUSA_HOME` | `/usr/local/musa` | |
| `TZ` / `LANG` | `Asia/Shanghai` / `C.UTF-8` | |

**镜像预装工具**：`modelscope`、`hf`（HuggingFace CLI）、`git` 均在 PATH 中 → **权重可直接在本容器下载，不必另起下载容器**。
**镜像默认**：`Cmd=sleep infinity`（`docker run <image>` 即可常驻）、`WorkDir=/sgl-workspace`。

**⚠ FlagGems 的开关机制（实测源码，`vllm_fl/utils.py`）**：本镜像**不使用 `GEMS_VENDOR`**，
而是 plugin-FL 的 dispatch 层用 `USE_FLAGGEMS` 控制：

| 变量 | 默认 | 作用 |
|------|:----:|------|
| `VLLM_FL_PREFER_ENABLED` | `true` | 全局总开关；`false` = 关掉全部 dispatch |
| `USE_FLAGGEMS` | `true` | **FlagGems 开关，默认已开** |
| `VLLM_FL_FLAGOS_WHITELIST` | （无） | FlagGems 白名单，与黑名单互斥；优先级最高 |
| `VLLM_FL_FLAGOS_BLACKLIST` | （无） | FlagGems 黑名单 |
| `VLLM_FL_PREFER` | `flagos` | 后端偏好：`flagos` / `vendor` / `reference` |
| `VLLM_FL_OOT_ENABLED` / `VLLM_FL_OOT_WHITELIST` / `VLLM_FL_OOT_BLACKLIST` | `1` / 无 / 无 | OOT 算子控制 |

> 完整表见容器内 `/usr/local/lib/python3.10/dist-packages/vllm_fl/dispatch/README.md`。
> **注意**：其余厂商工作区用的是 `GEMS_VENDOR=<厂商>` + `VLLM_PLUGINS=fl`，**摩尔这套镜像不是这个机制**，别照搬。

### B. 失败报告期的历史版本（仅作背景，本轮不用）

| 组件 | 版本 | 备注 |
|------|------|------|
| 推理后端 vllm | 0.20.2（多数报告）；0.24.0（2026-09 起） | ⚠ 0.20.2 + torch_musa 2.7.1 有 import 期崩溃坑，见下 |
| plugin-FL | 0.2.0 / 0.2.0+g8a1c299e5 / 0.3.0 | |
| FlagGems | 5.0.0 / 5.3.0rc2 / 5.3.2 | |
| Flagtree | 0.6.1 / 0.6.1a2+mthreads3.6 / 0.6.0 | |

> ⚠ **摩尔高频坑（3 份报告命中，已提 issue 到 vllm-plugin-FL）**：vllm 0.20.2 的 `vllm/ir/tolerances.py`
> 在模块导入期引用 `torch.float4_e2m1fn_x2`，而 `torch 2.7.1 / torch_musa` 未提供该 dtype →
> `AttributeError: module 'torch' has no attribute 'float4_e2m1fn_x2'`，**native 基线直接起不来**。
> 来源：mthreads/AceMath-RL-Nemotron-7B、Darwin-28B-Opus、Qwen3-4B-SafeRL。
> **本镜像（vllm 0.24.0 + torch 2.9.0）已避开该坑**，实测 `import vllm` 正常。

## 镜像

### 推理镜像（vLLM + MUSA）

| 项目 | 值 |
|------|----|
| **镜像（修复用，已确认）** | **`harbor.baai.ac.cn/flagrelease-public/flagrelease_mthreads-gmi_vllm024plugin_base:08281629`** |
| 容器命名习惯 | `flagrelease-fix-<模型名小写>`（流水线侧为 `<模型名>_flagos`） |
| 验证状态 | ✅ 2026-09-20 已完成全链路验证：`docker manifest inspect` 通过（41 层 / 压缩 13.88 GiB）→ `docker pull` 成功 → 起容器实测版本、8 卡可见、`/datapool` 挂载正常。**镜像现已在 `mthreads-25` 本地**（27 需自行 pull 或从 25 分发）。 |

> 该镜像是**通用基础镜像**（名字里带 `base`），不是按模型发布的私有镜像，故无 `<模型名>` 前缀、也没有 `-v2` 这类流水线后缀。

> **流水线按模型发布的私有镜像命名规则**（历史报告里的 tag，供比对确认，本轮不用）：
> `<模型名>-mthreads001-gems<FlagGems版本>-tree<Flagtree版本>-cxnone-plugin<plugin版本>-vllm<vllm版本>-cp<py>-pt<torch>-musa43-x64-<驱动>-server:<时间戳>-v<N>`
>
> **已观测实例（新→旧）**：
>
> | 口径 | 实例 | 备注 |
> |------|------|------|
> | vllm 0.24.0 | `harbor.baai.ac.cn/flagrelease-public/fluentlyqwen2.5-32b-mthreads001-gems5.3.2-tree0.6.0-cxnone-plugin0.3.0-vllm0.24.0-cp310-pt29-musa43-x64-3.3.5-server:202609050940-v2` | 2026-09 最新栈 |
> | vllm 0.20.2 | `…-mthreads001-gems5.3.0-tree0.6.1-cxnone-plugin0.2.0-vllm0.20.2-cp310-pt27-musa43-x64-3.3.6-server:…-v2` | 大多数失败报告用的口径 |
> | vllm 0.20.2 | `…-mthreads001-gems5.0.0-treenone-cxnone-plugin0.2.0-vllm0.20.2-cp310-pt27-musa43-x64-3.3.6-server:…-v2` | 三个 ✅ 达标模型（Phi-3 系列、Nanbeige4.1-3B）用的口径 |
>
> 其他厂商的私有 `*-FlagOS` 镜像在 ModelScope 上可匿名读 README，**摩尔的读不到**（`Code:10990101007 获取模型文件失败，文件内容为空`），
> 所以摩尔镜像的启动参数只能以**实测**为准，别照抄 ModelScope README。

### 评测镜像（evalscope，独立容器）

| 项目 | 值 |
|------|----|
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope` |
| 内含 | evalscope（判分脚本要求 `1.5.1`）+ modelscope |
| 用法 | 与 vLLM 容器**隔离运行**，`--network host`，直接打 `http://127.0.0.1:8000/v1`；起容器**不挂** GPU 设备 |

> ⚠ **2026-09-20 实测：25/27 上都没有这个 evalscope 镜像**，也没有 `release_评测标准/` 脚本
> （`find /data /datapool -name fast_gpqa.py` 无结果）。**首轮开工前必须先补齐这两样**：
> 拉 evalscope 镜像 + 把本仓库 `flagrelease_eval_methods/` 传到共享盘。
> 25 上有一个 `harbor.baai.ac.cn/flageval/flageval-llmeval`（5.2GB，2 个月前）可作备选，但**未经本项目验证，优先用 flagos-evalscope**。

> 💡 **提示**：修复镜像里已预装 `modelscope` / `hf` CLI，**下权重不必另起容器**——
> 直接在 `flagrelease-fix-<模型>` 容器里 `modelscope download` 即可（见 SOP 第 2 节）。
> `eval-scope` 容器只在**跑评测**时必需。

```bash
docker run -d --name eval-scope \
  --network host \
  -v /datapool:/datapool \
  harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope \
  sleep infinity
```

## 起服务运行时（✅ 除算子值外均为实测）

| 项目 | 值 |
|------|----|
| 卡可见性 | `MUSA_VISIBLE_DEVICES=0,1,2,3,…`（用几张卡就列几张）。镜像已设 `MTHREADS_VISIBLE_DEVICES=all`（容器内 8 卡全可见），`MUSA_VISIBLE_DEVICES` 用于**在容器内再限定用哪几张** |
| FlagOS 后端开关 | ✅ **无需设置**——镜像内置 `VLLM_PLUGINS=fl`，实测启动即打印 `Platform plugin fl is activated`。**不用 `GEMS_VENDOR`**（见上文「开关机制」表） |
| FlagGems 开关 | `USE_FLAGGEMS`（默认 `true` = 已开）；全局 `VLLM_FL_PREFER_ENABLED`（默认 `true`） |
| 算子控制 | `VLLM_FL_FLAGOS_WHITELIST`（优先级最高）/ `VLLM_FL_FLAGOS_BLACKLIST`，二选一。<br>**首轮建议收窄**（见 SOP 第 3 节），具体名单待实测产出后回填此处 |
| worker | `VLLM_WORKER_MULTIPROC_METHOD=spawn`（沿用其余厂商口径，摩尔待实测确认是否必需） |
| 超时 | `VLLM_ENGINE_ITERATION_TIMEOUT_S=7200`、`VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200` |
| serve 路径 | ✅ **`/usr/local/bin/vllm`**（镜像内**没有 `/opt/conda`**，`vllm` 也不在 `/opt/conda/bin`） |
| serve flags | `--dtype bfloat16 --tensor-parallel-size <TP> --gpu-memory-utilization 0.9 --enforce-eager --trust-remote-code`（`--attention-backend` 待实测） |
| 模型名约定 | `model_name` 取 NV 表 key；served-model-name / 评测 model-name / 日志目录统一用它 |
| 日志/结果落盘 | `/datapool/flagrelease/release_run_logs/${model_name}/`（serve.log + gpqa.json + verdict.json） |
| 评测执行位置 | 同一台宿主机上的 `eval-scope` 容器（⚠ eval 镜像尚未就位，见上节） |
| 容器内组件版本 | ✅ 见上文「A. 本轮修复镜像实测版本」 |

## 版本口径（V1–V4）

- **V1** 基础版：只带 Flagtree，不开任何 FlagOS 组件（裸 vLLM 基线）。
- **V2** Pro：开 FlagGems，性能≥V1 的 80%、精度误差≤5%。
- **V3** Max：V2 基础上加 plugin，指标要求同 V2。
- **V4** Flag-express：V3 基础上性能超过 V1。
- 手动修复只做一件事：**用 plugin-FL + vLLM 起服务、评测过关**，不需要复现 V1/V2/V3 分层。

> ⚠ **摩尔的性能基线多为合成值**：报告中大量出现 `baseline_source: v2_initial_x1.2`（V2 初始性能 ×1.2 当 V1 基线）。
> 引用历史报告的"性能比"时先确认基线来源，别把合成基线当成实测 V1。

## NV 基线可查模型（本厂商失败清单）

50 个失败模型里 **49 个在 `nv_baseline.yaml` 能查到基线**（唯一落空的是 `Darwin-9B-NEG-FINAL`）。
逐模型的「指标 + NV 基线值 + 当前状态」见同目录 [[STATUS]]，不必在此重复。

- 指标以 `gpqa_diamond` 为主（如 Baichuan-M2-32B=64、phi-4=73、Seed-OSS-36B-Instruct=79）；
- 数学/知识类模型多为 `mmlu` + `math_500`（如 OpenReasoning-Nemotron-7B=81.49/95.0、Apodex-1.0-4B-SFT=86.14/92.4）；
- 查不到的模型走两轮对比（裸 vLLM 基线 vs plugin-FL），见 `_shared/EVAL.md`。

## 本厂商已知失败模型（按失败类型聚类，详见 STATUS.md）

| 失败类型 | 数量 | 模型 |
|----------|:----:|------|
| 精度不达标（rel_drop 超阈值） | 17 | DASD-4B-Thinking、Dhanishtha-2.0-preview、GLM-4.7-Flash、LFM2-2.6B-Exp、LFM2.5-1.2B-Thinking、Light-R1-14B-DS、Moonlight-16B-A3B-Instruct、OpenMath-Nemotron-14B-Kaggle、Qwen3-4B-SafeRL、VibeThinker-1.5B、ZR1-1.5B、gemma-3-1b-it、gpt-oss-20b、llama-3-Korean-Bllossom-8B、phi-4、reka-flash-3、rnj-1-instruct |
| 性能不达标 | 16 | 与上表高度重合（DASD、Dhanishtha、GLM-4.7-Flash、LFM2-2.6B-Exp、Light-R1-14B-DS、Moonlight、OpenMath、Qwen3-4B-SafeRL、VibeThinker、ZR1、gemma-3-1b、gpt-oss-20b、llama-3-Korean-Bllossom-8B、phi-4、reka-flash-3、rnj-1-instruct） |
| 服务启动失败 | 9 | LFM2-2.6B-Exp、Magistral-Small-2506、Moonlight-16B-A3B-Instruct、OpenMath-Nemotron-14B-Kaggle、VibeThinker-1.5B、gemma-3-1b-it、gpt-oss-20b、llama-3-Korean-Bllossom-8B、phi-4 |
| 流程中断（会话/容器准备，非芯片问题） | 7 | AceReason-Nemotron-7B、Hermes-2-Pro-Llama-3-8B、Ministral-3-14B-Instruct-2512、Phi-4-reasoning-plus、Qwen2.5-7B-Instruct、Qwen2.5-Coder-7B-Instruct、aya-23-8B |
| 生成失控（runaway）/ 评测超预算 | 2 | FluentlyQwen2.5-32B（mmlu runaway）、OpenReasoning-Nemotron-7B（long-CoT 超预算） |
| 已达标（复核后可跳过） | 3 | Nanbeige4.1-3B、Phi-3-mini-128k-instruct、Phi-3.5-mini-instruct |

> 「流程中断」7 个是流水线侧（Claude API 流式卡顿 / 权重下载超时 / 容器准备中断）导致，**不代表芯片不兼容**，修复价值最高：
> 这些模型从未被真正评测过，直接按本 SOP 跑一遍即可。
