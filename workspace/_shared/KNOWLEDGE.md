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

- **现象**：开启算子替换后精度退化 > 5%，关掉后恢复。
  **根因**：某个或某几个替换算子的数值精度不足。
  **处置**：二分法缩小白名单——每次去掉一半算子，重新评测，定位退化算子；找到后关掉该算子并提 issue。
  **来源**：hygon 多个模型（Magistral-Small、Mistral-Small-24B、Phi-3-medium、SOLAR 等）

- **现象**：精度偏差在 4–5% 附近，勉强超阈值（如 metax/Phi-3-mini 偏差 4.0%）。
  **根因**：边界情况，可能与评测题数（50 题）的随机抖动有关。
  **处置**：用 `accuracy_compare.py` 的小样本容忍规则（≤100 题时绝对差 ≤2 题判达标）；若不符合，换 `--limit 0` 跑全量 198 题确认是否真超阈值。
  **来源**：metax/Phi-3-mini-128k-instruct

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

---

## 六、评测注意事项（避免踩坑）

- thinking 模型（QwQ / DeepSeek-R1 / Qwen3 系列）单题输出数千 token，50 题 GPQA 可能跑 6 小时以上，**不要中断**，这是正常现象。
- 两次对比评测**必须用完全相同的参数**，否则结果不可比。
- 评测期间**不要同时跑性能测试**，两者抢 GPU 会污染精度。
- `truncation_detected: true` 说明输出被 max_tokens 截断，分数偏低不可信；需加大 `--max-model-len` 后重跑。
