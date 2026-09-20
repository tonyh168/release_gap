# 滚动经验库

跨模型、跨厂商的可复用规律。每修完一个模型，把新教训提炼到对应分类写进来。
格式：`- **现象**：...  **根因**：...  **处置**：...  **来源**：<厂商/模型>`

---

## 一、服务启动失败（Operator crash / 容器崩溃）

- **现象**：vLLM 服务起不来，core dump 或直接 OOM，评测全空。
  **根因**：plugin-FL / FlagGems 某算子对该模型架构无实现或实现有 bug，加载模型时触发。
  **处置**：①抓崩溃日志定位算子名；②在 `vllm serve` 前设 `VLLM_USE_FLAGGEMS=0` 关闭替换，确认裸 vLLM 能跑；③再逐步开启算子白名单缩小范围；④向 plugin-FL 提 issue，附算子名+堆栈。
  **来源**：metax/EXAONE-4.0-32B、metax/GLM-4-32B-0414、metax/Qwen3-Coder-30B、iluvatar/QwQ-32B、iluvatar/TinyR1-32B-Preview、iluvatar/Phi-3-medium-128k-instruct、iluvatar/MiroThinker-v1.5-30B

- **现象**：容器内 `import vllm` 直接失败，报 `vllm._rocm_C / vllm._C / libhydmi.so` 找不到。
  **根因**：镜像缺编译扩展，ROCm 下 vLLM 编译产物未打包进镜像。
  **处置**：换有完整编译产物的镜像版本，或在容器内重新编译 `pip install vllm --no-build-isolation`（耗时，备选）。
  **来源**：hygon/Light-R1-7B-DS

- **现象**：天数平台服务起来但一直 hang，无任何输出，不报错。
  **根因**：`sort` / `sort_stable` 被 FlagGems 接管后在天数算子上死锁。
  **处置**：起服务前必设 `VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable`，不加必 hang。
  **来源**：iluvatar/XingChen4-0907

- **现象**：大参数量模型（30B/32B）比小模型更容易崩溃。
  **根因**：算子对大 batch / 大隐层维度的覆盖不完整。
  **处置**：优先用 TP=8 最大并行，降低单卡压力；若仍崩溃，参考"服务启动失败"条目关算子。
  **来源**：metax 三个 32B 模型 vs 5B 模型通过率差异

- **现象**：换高版本 vLLM（0.24）后 plugin-FL 无法实例化，报 `Can't instantiate abstract class FlashMLAImpl ... 'forward_mha', 'forward_mqa'`，或 `ModelRegistry` 导入失败。
  **根因**：vLLM 0.24 重构了 MLA impl 接口并把 `vllm` 变成 namespace package，plugin-FL 未对齐。
  **处置**：plugin-FL 侧补 `forward_mha/forward_mqa`（代理到已有 prefill/decode）、`ModelRegistry` 改从 `vllm.model_executor.models` 导入、`dcp_world_size` 初值 `-1`。选镜像时确认 plugin-FL 与该 vLLM 版本已适配。
  **来源**：metax/XingChen4-0907（镜像 vllm 0.24.0，见 metax PR 记录）

- **现象**：eager/短 prompt 冒烟全 PASS，一上真实评测（长 prompt）所有请求 500 / `EngineDeadError`，报 `flash_attn_varlen_func() got an unexpected keyword argument 'fa_version'`。
  **根因**：短 prompt 只走 decode，长 prompt 才走 MLA prefill 变长注意力；MetaX 的 FA 无 `fa_version` 形参，被上游 partial 注入即崩。
  **处置**：①冒烟必须用长 prompt（直接跑几题 GPQA）验证，别只测 `1+1`；②plugin-FL 去掉 MLA prefill 路径的 fa_version partial 注入。
  **来源**：metax/XingChen4-0907

- **现象**：MetaX 上 FlagGems 的 GEMM 类 kernel 编译崩（`PassManager::run failed` / `shape_judge` 断言），黑名单里写了却没拦住。
  **根因**：`VLLM_FL_FLAGOS_BLACKLIST` 按函数 `__name__`（下划线 `mm_out`/`bmm_out`）匹配，写成 aten 键（点号 `mm.out`）一个都匹配不上。
  **处置**：`.out` 变体一律写下划线；graph 模式黑名单需补全 `mm,mm_out,bmm,bmm_out,linear,...`，把 GEMM 挡回原生 aten。
  **来源**：metax/XingChen4-0907

- **现象**：摩尔线程上 `import vllm` 直接崩，native（不开任何 flagos 组件）基线也起不来：
  `AttributeError: module 'torch' has no attribute 'float4_e2m1fn_x2'`，栈在 `vllm/ir/tolerances.py:32`。
  **根因**：vllm 0.20.2 的 `vllm/ir/tolerances.py` 在**模块导入期**就把 `torch.float4_e2m1fn_x2` 写进
  `DEFAULT_TOLERANCES` 字典的 key，而 torch 2.7.1 / torch_musa 未提供该 dtype；导入即 AttributeError，
  与模型无关，整台机器上所有 vllm 0.20.2 服务都受影响。
  **处置**：①换 vLLM 0.24.0 口径的镜像（0.24 不再于导入期引用该 dtype）；②或临时 patch `tolerances.py`
  去掉该 key / 改成惰性引用；③已提 issue 到 `flagos-ai/vllm-plugin-FL`（类型 startup-crash），
  要求对 torch_musa 缺失的 float4 dtype 做兼容或延迟引用。
  **来源**：mthreads/AceMath-RL-Nemotron-7B、mthreads/Darwin-28B-Opus、mthreads/Qwen3-4B-SafeRL（2026-08）

- **现象**：摩尔线程上「服务启动失败 + 精度不达标 + 性能不达标」三类同时出现在同一份报告里（50 份报告里 8 份这样写）。
  **根因**：报告判定粒度粗——流程中途失败时，未执行的阶段被填了默认占位判定，不代表三项独立都失败。
  **处置**：**别按报告结论的条数分配工时**；先看该报告有没有真实评测数据（`accuracy_compare_*.json` / benchmark 结果），
  没有数据的按「从未评测过」处理，用本工作区 SOP 重跑一遍即可定性。
  **来源**：mthreads 50 份报告聚类（其中 7 份明确是流程会话/容器准备中断，非芯片问题）

- **现象**：把其他厂商的 `GEMS_VENDOR=<厂商>` + `VLLM_PLUGINS=fl` 口径照搬到摩尔，起服务时没有生效（或困惑于该设哪个）。
  **根因**：**摩尔这套镜像是 plugin-FL 的 dispatch 机制，不走 `GEMS_VENDOR`**。实测（`vllm_fl/utils.py` + 镜像
  `docker inspect`）：`VLLM_PLUGINS=fl` 已**内置**在镜像 ENV 里（启动即打印 `Platform plugin fl is activated`），
  真正的开关是 `VLLM_FL_PREFER_ENABLED`（全局，默认 true）和 `USE_FLAGGEMS`（FlagGems，**默认 true = 已开**），
  算子粒度用 `VLLM_FL_FLAGOS_WHITELIST` / `VLLM_FL_FLAGOS_BLACKLIST`。
  **处置**：摩尔不要写 `GEMS_VENDOR`、不要重复 export `VLLM_PLUGINS`；要关 FlagGems 用 `USE_FLAGGEMS=0`。
  **通用教训**：**换厂商镜像时先读容器内 plugin 的 README/源码确认开关变量名**，别按上一家的惯例抄——
  厂商镜像的 vllm 安装路径也可能不同（摩尔在 `/usr/local/bin/vllm`，其余厂商是 `/opt/conda/bin/vllm`）。
  **来源**：mthreads `flagrelease_mthreads-gmi_vllm024plugin_base:08281629` 实测（2026-09-20）

- **现象**：摩尔起服务时 vLLM 打告警 `Unknown vLLM environment variable detected: VLLM_FL_FLAGOS_WHITELIST`，
  容易误判为「白名单没生效」。
  **根因**：vLLM 只校验自己的 `VLLM_*` 命名空间，`VLLM_FL_FLAGOS_WHITELIST` 是 plugin-FL 读的，vLLM 不认识就报一句。
  **处置**：**忽略该告警**。验证白名单是否真生效，看 EngineCore 里这几行即可（有几个算子就该有几行，不多不少）：
  ```
  [INFO] [vllm_fl.dispatch.manager] Op 'rms_norm'         using 'default.flagos'
  [INFO] [vllm_fl.dispatch.manager] Op 'rotary_embedding' using 'default.flagos'
  [INFO] [vllm_fl.dispatch.manager] Op 'silu_and_mul'     using 'default.flagos'
  ```
  **来源**：mthreads/Phi-4-reasoning-plus（2026-09-20）

- **现象**：摩尔起服务日志里有整段 traceback：`RuntimeError: Cannot re-initialize MUSA in forked subprocess.
  To use MUSA with multiprocessing, you must use the 'spawn' start method`，但服务**照样正常起来**。
  **根因**：报错发生在 `vllm/usage/usage_lib.py` 的**用量上报**路径——它 fork 子进程去读设备属性，
  撞上 torch_musa 的 "MUSA 不能在被 fork 的子进程里重新初始化" 检查。
  **处置**：①**别当成启动失败**——只要最终有 `Application startup complete` 就是好的；
  ②日志分析脚本**不要按 `Traceback` 关键字判死**，摩尔日志里这条是常态；
  ③想消掉噪声用 `VLLM_NO_USAGE_STATS=1`（或 `DO_NOT_TRACK=1`）。
  **注意**：`VLLM_WORKER_MULTIPROC_METHOD=spawn` **挡不住**这条——触发点不是 worker 而是上报路径。
  **来源**：mthreads/Phi-4-reasoning-plus（2026-09-20）

- **现象**：摩尔起服务时告警 `patch_moe_topk_softmax_for_musa: cannot import topk_softmax_flaggems —
  MoE models will fail on MUSA`，以及 `Failed to register Reference operators: 'ReferenceBackend' object
  has no attribute 'moe_align_block_size'`。
  **根因**：plugin-FL 给 MUSA 打的 MoE 补丁拿不到 FlagGems 的 `topk_softmax` 实现（模块循环导入）。
  **处置**：**dense 模型无影响**（Phi-4-reasoning-plus 实测正常）。**MoE 模型要重点验证**——
  摩尔失败清单里的 MoE：`gpt-oss-20b`、`Moonlight-16B-A3B-Instruct`、`Qwen3-30B-A3B-Instruct-2507`、
  `kanana-1.5-15.7b-a3b-instruct`、`LFM2-2.6B-Exp`（MoE 版）。
  **来源**：mthreads/Phi-4-reasoning-plus（2026-09-20）

- **现象**：`Phi-4-reasoning-plus`、`Magistral` 这类 reasoning 模型评测时被当成普通模型（贪心 + 小 max_tokens）。
  **根因**：`fast_gpqa.py` 的 `THINKING_PATTERNS` 是**关键词白名单**（`qwen3`/`qwq`/`deepseek-r1`/`deepseek-r2`/
  `light-r1`/`minicpm4.1`/`mimo`/`hunyuan`），**名字里没有这些词的 reasoning 模型一律识别不出来**。
  Phi-4-reasoning-plus 实测输出带 `<think>`，但不在名单里。
  **处置**：靠 `context.yaml` 显式标记（优先级高于关键词）：
  ```yaml
  model:
    local_path: <容器内模型目录>
    thinking_model: true
  ```
  注意该文件路径被脚本**硬编码**为 `/flagos-workspace/shared/context.yaml`——容器没挂 `/flagos-workspace` 时
  要在容器内建同路径目录。
  **来源**：mthreads/Phi-4-reasoning-plus 服务冒烟（2026-09-20）；同类问题曾见于 hygon/Magistral-Small-2506
  （摩尔侧同批实测确认：`LFM2.5-1.2B-Thinking` 输出 `<think>`、`reka-flash-3` 输出 `<reasoning>`，**三个都不在名单里**）

- **现象**：vLLM 服务端启动时打 WARNING：`Default vLLM sampling parameters have been overridden by the
  model's generation_config.json: {...}`，于是以为「采样参数问题已经被 vLLM 自动解决了」。
  **根因**：**服务端确实采纳了模型采样参数作为默认值**，但评测脚本会在请求里**显式传 `temperature=0.0`**，
  显式值覆盖服务端默认 → 照样退化成贪心。
  **处置**：①**别以为看到这条 WARNING 就不需要修评测侧**——`context.yaml` 该补还得补；
  ②**绝不要加 `--generation-config vllm`**——那会主动丢弃模型采样参数，让问题更严重。
  **来源**：mthreads/reka-flash-3 服务实测（2026-09-20）

- **现象**：混合 SSM 模型（LFM2 系，config 带 `conv_L_cache` / `block_*` 字段）在摩尔起服务时告警
  `Add 2 padding layers, may waste at most 20.00% KV cache memory`。
  **根因**：卷积层与注意力层结构不同，vLLM 需补 padding 层对齐层数。
  **处置**：**不影响正确性**，可正常服务（实测 LFM2.5-1.2B-Thinking 短/长 prompt 均 200）。
  但 KV cache 利用率最多损失 20%，配合大 `max_model_len`（该模型 128000）时要核算显存。
  另：这类模型**不要指定 TRITON_MLA**（iluvatar 经验），摩尔走默认 `--attention-backend` 即可。
  **来源**：mthreads/LFM2.5-1.2B-Thinking（2026-09-20）

- **现象**：小模型（1.2B）独占一张 80GB 卡，实测占用 73882 MiB。
  **根因**：`--gpu-memory-utilization 0.9` 是**按卡容量**预留 KV cache，与模型大小无关
  ——1.2B 的小模型也会把整卡 73GB 全部吃掉。
  **处置**：想在同一张卡上多开服务，必须显式下调 `--gpu-memory-utilization`；
  否则「一模型独占一卡」。8 卡机器上跑 50 个模型时这条很关键。
  **来源**：mthreads/LFM2.5-1.2B-Thinking（2026-09-20，权重仅 2.2GB 却占用 73.8GB）

- **现象**：起服务时按模型 config 的 `max_position_embeddings` 走，结果 KV cache 装不下 / 起不来。
  **根因**：**不能直接信模型声明的上下文长度**，要先按 KV cache 反算。每 token KV 大小 =
  `层数 × 2(K,V) × kv_heads × head_dim × dtype字节`。head_dim 大的模型（如 256）极其吃 KV。
  **实例**：mthreads/`Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled` —— 64 层 × 4 kv_heads × 256 head_dim
  = **256 KB/token**；权重 52GB 后仅剩约 20GB 给 KV，模型默认 262144（256K）需 **64GB**，必然装不下。
  显式 `--max-model-len 32768`（8GB）后才起来。
  **处置**：起任何新模型前先算一遍；模型默认值超过可用 KV 时**显式传 `--max-model-len`**。
  评测若报 `truncation_detected:true`，**逐级上调**（32768→65536→…），别一步跳到模型上限。
  **来源**：mthreads/Qwen3.5-27B-Distilled（2026-09-20）；同类风险见各厂商 128k/256K 长上下文模型

- **现象**：同一个算子白名单下，不同模型日志里注册到 `default.flagos` 的算子数不一样
  （Phi-4-reasoning-plus 3 个：`rms_norm`/`rotary_embedding`/`silu_and_mul`；
  Qwen3.5-27B-Distilled 只有 `silu_and_mul` 1 个）。容易误判成「白名单没生效」。
  **根因**：`Op 'X' using 'default.flagos'` 这行是**算子首次被 dispatch 时**才打印的（惰性），
  不是启动时一次性列出全部白名单。模型架构不同 → 触达的算子不同；Qwen3.5 的 rms_norm/rotary
  可能走了 fused 或专用实现，压根没经过 dispatch 层。
  **处置**：①**别用「注册了几个算子」判断白名单是否生效**——要看有没有 `OpManager initialized: N ops`
  这行（它反映的是总算子集），以及具体哪些 op 被 dispatch；
  ②反过来，这个差异本身是**有价值的探针**：它说明该模型的哪些算子**实际走了 FlagGems**，
  写修复报告时应明确列出，否则「算子替换覆盖率」会说不清。
  **来源**：mthreads/Phi-4-reasoning-plus vs Qwen3.5-27B-Distilled 对照（2026-09-20）

- **现象**：担心摩尔镜像不支持新架构（如 Qwen3.5、带 MTP 的模型），不敢起。
  **根因**：vLLM 0.24.0 覆盖面比预期广。查法：
  ```bash
  grep -n "<架构名>" /usr/local/lib/python3.10/dist-packages/vllm/model_executor/models/registry.py
  ls /usr/local/lib/python3.10/dist-packages/vllm/model_executor/models/ | grep -i <关键词>
  ```
  **实例**：`Qwen3_5ForConditionalGeneration` 在 registry 第 566 行有映射（→ `qwen3_5`），
  且存在 `qwen3_5_mtp.py`；mthreads 镜像**直接起成功**，无需额外适配。
  **处置**：起服务**前**花 10 秒查 registry，比起来之后再排查快得多。
  **来源**：mthreads/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled（2026-09-20）

---

## 二、精度不达标（rel_drop 超 5% 阈值）

- **现象**：关掉所有算子替换（全裸 V1）精度仍不达标。
  **根因**：plugin-FL 框架层本身引入精度退化，不是单个算子的问题；可能是 attention / softmax 数值精度差异。
  **处置**：上报 plugin-FL 框架级 bug，附两份结果 JSON（NV 基线 vs 本平台 V1）；短期内该模型无法通过。
  **来源**：hygon/sarvam-m（报告明确写"Plugin 精度框架级退化，全关算子仍不达标"）

- **现象**：sarvam-m 在新 Hygon 镜像上服务可用，但 GPQA 50 题只有 32%，且 9/50 题出现高重复并达到 `max_tokens`。
  **根因**：本轮只能确认结果受到长输出/复读污染；不能仅凭这一轮把原因归因到某个算子。历史报告还提示该模型存在 plugin-FL 框架级精度退化。
  **处置**：保留 `score` 与 `evalscope_score`，做逐题输出审计；后续按 `FlagGems 开/关 × OOT 开/关` 2×2 重复实验，并固定并发、生成上限和缓存状态。2026-09-15 的 50 题结果为 32%；2026-09-16 全量 198 题结果为 29.80%，NV 基线 48.00%，相对退化 37.92%，且 40/198 题 runaway，不达标。
  **来源**：hygon/sarvam-m，2026-09-15/16 新镜像实测

- **现象**：开启算子替换后精度退化 > 5%，关掉后恢复。
  **根因**：某个或某几个替换算子的数值精度不足。
  **处置**：二分法缩小白名单——每次去掉一半算子，重新评测，定位退化算子；找到后关掉该算子并提 issue。
  **来源**：hygon 多个模型（Magistral-Small、Mistral-Small-24B、Phi-3-medium、SOLAR 等）

- **现象**：Mistral 类非 thinking 模型 50 题从 NV 54% 掉到 40%，无解析误扣，关闭全部 FlagGems 也不能恢复；修复后单轮可到 52%，但同参数复跑掉到 48%。
  **根因**：本例是两个因素叠加：① prefix cache / chunked prefill 对 Hygon 当前 vLLM/plugin-FL 组合有精度污染；②评测脚本只拿到 served model name，没拿到容器内模型目录时读不到 `generation_config.json`，错误退回 `temperature=0.0`，而模型配置要求 `temperature=0.15`。
  **处置**：服务侧加 `--no-enable-prefix-caching --no-enable-chunked-prefill`；评测侧写 `/flagos-workspace/shared/context.yaml` 指向模型目录，确保采样参数来自模型 `generation_config.json`。本例从 40% -> 46% -> 52%，但复跑为 48%；50 题采样口径不能只看单轮达标，需跑全量 198 题或固定 seed/确定性口径确认稳定性。
  **来源**：hygon/Mistral-Small-24B-Instruct-2501，2026-09-17 新镜像实测

- **现象**：Qwen2.5-7B-Instruct 在 Hygon 新镜像 GPQA 50 题从 NV 39% 掉到 26%；改生成上限后仍只有 32% 左右。
  **根因**：服务用 `--dtype float16` 跑了模型配置声明的 `bfloat16` 权重，同时 broad FlagGems 替换会引入额外数值扰动；把核心算子强制走 `reference` 反而崩到 8%，说明不能简单回退所有核心 op。
  **处置**：服务侧改 `--dtype bfloat16`，保留默认 prefix/chunk；将 `VLLM_FL_FLAGOS_WHITELIST` 和 `VLLM_FL_OOT_WHITELIST` 收敛到 `silu_and_mul,rms_norm,rotary_embedding`。本例 50 题从 26% -> 36%，NV=39%，绝对差 1.5 题，按小样本噪声容忍判达标；`--no-enable-prefix-caching --no-enable-chunked-prefill` 会降到 32%，不要套用。
  **来源**：hygon/Qwen2.5-7B-Instruct，2026-09-17/18 新镜像实测

- **现象**：Magistral-Small-2506 按普通模型贪心评测只有 48%（服务侧优化后 54%），低于 NV 62%；输出中有 7/50 题高重复并撞 `max_tokens`。
  **根因**：这是 reasoning 模型，但脚本按 served model name 未识别为 thinking，退回 `temperature=0.0` 贪心；模型 README 推荐 `temperature=0.7/top_p=0.95`。同时 Hygon 当前服务需要关 prefix cache / chunked prefill，并避免核心 Mistral op 走有问题的 FlagGems 路径。
  **处置**：服务侧使用 `--no-enable-prefix-caching --no-enable-chunked-prefill`，FlagGems 白名单保留非核心 26 项，让 `silu_and_mul/rms_norm/rotary_embedding` 走 reference；评测侧按 thinking 跑 GPQA，固定 `max_tokens=4096, temperature=0.7, top_p=0.95, eval_batch_size=4`。本例 50 题 62%，NV=62%，runaway=0，达标；普通贪心口径仍会误判失败。
  **来源**：hygon/Magistral-Small-2506，2026-09-17/18 新镜像实测

- **现象**：精度偏差在 4–5% 附近，勉强超阈值（如 metax/Phi-3-mini 偏差 4.0%）。
  **根因**：边界情况，可能与评测题数（50 题）的随机抖动有关。
  **处置**：用 `accuracy_compare.py` 的小样本容忍规则（≤100 题时绝对差 ≤2 题判达标）；若不符合，换 `--limit 0` 跑全量 198 题确认是否真超阈值。
  **来源**：metax/Phi-3-mini-128k-instruct

- **现象**：精度远低于基线（如 46% vs 59%），且响应极长、有明显复读/自我推翻痕迹
  （典型：末尾出现 `...The answer must be B, but that's wrong`），runaway 检测命中多题。
  **根因**：**模型自带 `generation_config.json` 的采样参数从未生效，评测一直在用默认贪心
  （temperature=0.0）**。`fast_gpqa.py` 的 `resolve_gen_params()` 本应优先采用模型配置，
  但其模型目录定位函数 `_resolve_model_dir()` 只认两个来源：①`--model-name` 本身是本地目录；
  ②容器内存在 `/flagos-workspace/shared/context.yaml`。标准流程里 `--model-name` 传的是
  NV 表 key（非路径），且容器内没有 `context.yaml` → 两者都不满足 → **静默退回贪心**。
  对 `do_sample=true` 的模型，贪心会**确定性**地一路复读无法逃逸。
  **处置**：在评测容器内补出兜底文件（不改脚本代码）：
  ```bash
  docker exec <eval容器> sh -c 'mkdir -p /flagos-workspace/shared && cat > /flagos-workspace/shared/context.yaml <<EOF
  model:
    local_path: /models/flagrelease/fixes_models/<模型名>
    container_path: /models/flagrelease/fixes_models/<模型名>
  EOF'
  ```
  **换模型时必须同步改其中路径**。实测收益（reka-flash-3，同题同量 index 0..114）：
  正确率 **46.96% → 53.04%（+6.08pt）**，最长响应 **93324 → 36210 字符**，
  `≥20k` 长响应档正确率 **12.5% → 36.7%**。
  **来源**：metax/reka-flash-3（2026-09-18；注：此问题影响本项目**全部 10 个模型**的历轮评测，
  只是多数模型本就该贪心评测而未暴露）

- **现象**：摩尔线程上「精度不达标」和「性能不达标」成对出现（17 个精度不达标里 16 个同时报性能不达标），
  且全部集中在开满 FlagGems 全量算子（约 51–62 个）的 V2/V3 阶段。
  **根因**：尚未定位到单一算子——现象上更像「全量算子替换在摩尔后端上整体偏慢 + 数值路径偏差」的叠加。
  **处置**：摩尔侧首轮**不要开全量**。先按 `VLLM_FL_FLAGOS_WHITELIST=silu_and_mul,rms_norm,rotary_embedding`
  这类安全集跑通并出分，再按「精度优先」逐步放开；一旦出现吞吐骤降或分数下掉，就把该算子退回。
  （Hygon/Qwen2.5-7B-Instruct 已验证该安全集可用；摩尔待实测。）
  **来源**：mthreads 50 份报告聚类（DASD-4B-Thinking、GLM-4.7-Flash、LFM2-2.6B-Exp、Light-R1-14B-DS、
  Moonlight-16B-A3B-Instruct、OpenMath-Nemotron-14B-Kaggle、Qwen3-4B-SafeRL、VibeThinker-1.5B、ZR1-1.5B、
  gemma-3-1b-it、gpt-oss-20b、llama-3-Korean-Bllossom-8B、phi-4、reka-flash-3、rnj-1-instruct、Dhanishtha-2.0-preview）

- **现象**：摩尔线程上 FlagGems 使能后 mmlu 评测**生成失控（runaway）**，模型不复读却停不下来，
  精度无法评测（FluentlyQwen2.5-32B，V2 镜像 `…vllm0.24.0…plugin0.3.0…:202609050940-v2`）。
  **根因**：报告未定位到算子（同模型另提了 accuracy degradation + performance degradation 两个 issue）；
  评测侧也无法用 runaway 分数判定达标。
  **处置**：先收窄算子白名单重跑；同时固定 `--max-tokens` 与 `--eval-batch-size`，把 `runaway_count`
  和 `truncation_detected` 当准入条件——两项非零时不采信分数。
  **来源**：mthreads/FluentlyQwen2.5-32B（2026-09-05）

---

## 三、性能不达标（吞吐 < V1 的 80%）

- **现象**：精度达标但性能比卡在 79–80% 附近（如 metax/Phi-3-mini 79.2%）。
  **根因**：替换算子的吞吐比原生实现低，差距小但刚好踩线。
  **处置**：①检查 TP 是否最大化；②关闭部分性能差的替换算子（保留精度好的）；③或接受略低性能，重新确认门槛是否可放宽。
  **来源**：metax/Phi-3-mini-128k-instruct、iluvatar/SOLAR-10.7B

---

## 四、vllm-plugin-FL 报错

- **现象**：日志出现 `vllm-plugin-FL error` / `dispatch` / `vllm_fl` 等报错，服务起来了但结果异常。
  **根因**：plugin-FL 的 dispatch 层找不到该 op 的实现，或版本不匹配。
  **处置**：①检查 plugin-FL 版本（`pip show vllm-plugin-fl`）与镜像要求是否一致；②设 `VLLM_PLUGIN_FL_LOGLEVEL=DEBUG` 看完整报错；③对应算子加入黑名单跳过。
  **来源**：hygon/Magistral-Small（vllm-plugin-FL error）、hygon/Mistral-Small-24B、hygon/sarvam-m、metax/SOLAR、metax/Qwen3-Coder

---

## 五、评测过程中断

- **现象**：服务能启动，评测跑到中途（如 mmlu 145/1140）崩溃停止，流程标记 `workflow_complete=false`。
  **根因**：长时间推理下触发算子内存问题或超时。
  **处置**：①检查 serve 日志是否有 OOM / CUDA error；②用 `--limit 20` 先跑小样本确认稳定性；③稳定后再跑全量；④若依然中断，降 `--gpu-memory-utilization` 或 TP 调整。
  **来源**：iluvatar/OpenThinker-7B

- **现象**：Hygon vLLM 服务评测中途 `EngineCore` 退出，端口拒绝连接，日志有 `sqlite3.OperationalError: database is locked`，栈在 FlagGems autotune cache。
  **根因**：多 TP worker 共用同一个 SQLite autotune DB，反射/写入 benchmark 表时互相锁住。
  **处置**：服务启动环境里设置 `FLAGGEMS_DB_URL=sqlite:///:memory:`，或为各 rank 配独立 DB/cache；重启后再跑全量。保留 `VLLM_FL_TRITON_CACHE_ROOT` 仅作 kernel cache，不等同于 FlagGems DB 隔离。
  **来源**：hygon/sarvam-m，2026-09-16 全量评测首轮 53/198 崩溃

- **现象**：`.running` 标记还在，但评测日志不再更新，评测进程消失；Docker events 显示评测容器 `kill/die 137/destroy`，模型服务仍健康。
  **根因**：评测跑在临时下载/工具容器里，容器被外部清理或 kill，遗留 stale running 标记。
  **处置**：不要只看 `.running`；同时看 `ps`、日志 `mtime`、Docker events 和服务 health。长时间全量评测优先挂在模型长驻容器或稳定评测容器里，结果写共享盘。
  **来源**：hygon/sarvam-m，2026-09-16 r2 在 24/198 后退出码 137

---

## 六、评测注意事项（避免踩坑）

- **评测前必查采样参数来源**：跑起来后先 grep 日志确认，这是最容易静默出错的一项：
  ```bash
  grep '\[gen\]' <eval日志>
  ```
  - 「采用模型 generation_config.json 采样参数: {...}」→ ✅ 正确生效
  - 「未定位到模型目录（--model-name 非本地路径且 context.yaml 无路径），沿用默认采样参数」
    → ⚠️ **模型配置被忽略，正在用贪心**，见第二节对应条目
  该提示是 INFO 级、措辞像正常默认行为，极易被跳过（本项目历轮评审均漏过）。

- **`limit` 语义与同题对照方法**：`limit=50` 严格等于 `index 0..49`（文件顺序前 N 条，
  **不采样、不打乱**；执行顺序是乱序并发提交，但样本集合是确定的）。全量按 index 递增消费。
  题序由 `seed=42` 固定，**同一 index 跨轮次就是同一道题**（已验证 v3/v4/v6 共同 index
  的 target 逐题一致）。→ **做配置对照实验时，固定用相同的 index 区间对比，比不同题数的
  粗略对比可信得多。**

- **eager 模式的吞吐代价不可接受**：实测 reka-flash-3 eager **16 tok/s** vs graph **160 tok/s**
  （差 10 倍）。**评测一律用 graph 模式**，不要为了「对齐某个参考配置」而切 eager。

- thinking 模型（QwQ / DeepSeek-R1 / Qwen3 系列）单题输出数千 token，50 题 GPQA 可能跑 6 小时以上，**不要中断**，这是正常现象。
- 模型名没有命中 `THINKING_PATTERNS` 不代表它不是 reasoning 模型；Magistral 这类模型必须按 README/模型卡确认采样口径，必要时通过 `context.yaml` 标记 `thinking_model` 或临时 monkeypatch，否则会被 `temperature=0.0` 贪心误评。
- 普通模型也可能输出长推理；自动按 `max_model_len` 推导出的 24576 `max_tokens` 会把 GPQA 单轮耗时放大到小时级。慢速芯片上应按任务协议显式固定 `--max-tokens`，并同时检查 `truncation_detected`、`runaway_detection`，不能只看最终分数。
- 两次对比评测**必须用完全相同的参数**，否则结果不可比。
- 评测期间**不要同时跑性能测试**，两者抢 GPU 会污染精度。
- `truncation_detected: true` 说明输出被 max_tokens 截断，分数偏低不可信；需加大 `--max-model-len` 后重跑。
- **`max_tokens` 无法通过 CLI 指定**（脚本设计禁止，由 `auto_max_tokens()` 按
  `max_model_len - 8192` 自适应，且截断检测还会自动翻倍）。需间接控制时，
  调**服务端 `--max-model-len`** 即可：如要 max_tokens=16384，就把 `--max-model-len` 设为 24576。

- **引用历史报告的"性能比"前先确认基线来源**：摩尔线程的报告里大量出现
  `baseline_source: v2_initial_x1.2`（用 V2 初始性能 ×1.2 合成 V1 基线），
  Phi-3.5-mini 等报告明确标注"性能基线为合成值，非实测 V1"。
  这类比值只能当参考，**不能当达标依据**；本轮判定一律以 `accuracy_compare.py` 退出码为准。
  **来源**：mthreads/Phi-3.5-mini-instruct、Darwin-28B-Coder、iFlow-ROME 等报告

- **long-CoT 模型在慢速芯片上会先撞评测预算，再谈精度**：
  摩尔 `OpenReasoning-Nemotron-7B` 在 V2 全量算子下 mmlu 只跑到 427/1140 就到预算上限；
  `Apodex-1.0-4B-SFT` 同样是 V2 起单题耗时显著变长后未闭环。
  处置：显式固定 `--max-tokens` + `--eval-batch-size`（受控 A/B），必要时先只跑 `--limit 0` 的
  小子集确认稳定性，再决定是否跑全量；不要用"跑不完"直接判芯片不达标。
  **来源**：mthreads/OpenReasoning-Nemotron-7B、mthreads/Apodex-1.0-4B-SFT
