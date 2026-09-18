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
