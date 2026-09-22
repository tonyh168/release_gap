# Magistral-Small-2506 修改文件说明

> 本文件只说明程序文件修改。推理容器必须绑定 `/dev:/dev`、`/usr/local/PPU_SDK:/usr/local/PPU_SDK`、`/mnt/workspace/models:/models`；完整、已核验的 `docker run`、`docker exec` 和健康检查命令见 [适配记录](../Magistral-Small-2506.md) 与 [发布报告](../../reports/Magistral-Small-2506_report.md)。评测容器只调用 API，因此仅绑定 `/mnt/workspace/models:/models`。

## 来源与用途

本次没有修改模型权重、vLLM、`vllm-plugin-FL` 或 FlagGems 源码。唯一持久化修改的程序文件是 GPQA 评测脚本：

```text
远端：/models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods/fast_gpqa.py
本地：workspace/t-head/fixes/fast_gpqa.py
```

用途是让 Magistral-Small-2506 按 reasoning 模型的推荐口径评测，避免回退到普通/贪心配置。

## 原文件与备份

```text
备份：/models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods/fast_gpqa.py.bak_20260920_magistral_fix
修改前 SHA-256：122b4dcce66f21f4f3ab8d6e70b2828d5eae4e9f91ea5d24aef11ea7582ac3bb
远端修改后 SHA-256：e26579051c1593091862a01527faee1c10933bbf18f039292ee45bc03b858d70
```

修改后已通过 Python AST 语法检查。

## 修改一：识别 Magistral 为 thinking 模型

```python
THINKING_PATTERNS = [
    'qwen3', 'qwq', 'deepseek-r1', 'deepseek-r2',
    'light-r1', 'minicpm4.1', 'mimo', 'hunyuan',
    'magistral',
]
```

原理：原脚本没有匹配 Magistral，会遗漏 thinking filter、输出窗口和生成策略。加入模型族识别后不再依赖临时 monkey patch。

## 修改二：固定 README 推荐采样参数

```python
if model_path and 'magistral' in str(model_path).lower():
    cfg['temperature'] = 0.7
    cfg['top_p'] = 0.95
```

原理：模型的 `generation_config.json` 没有这两个字段，但 README 明确推荐 0.7/0.95。适度采样避免 reasoning 模型被贪心解码锁在早期错误或重复路径中。

## 修改三：注入 reasoning system prompt

```python
MAGISTRAL_SYSTEM_PROMPT = (
    "A user will ask you to solve a task. First reason inside <think> and </think>. "
    "Then provide a concise self-contained final answer. The last line must be "
    "ANSWER: [LETTER]."
)

if 'magistral' in model_name.lower():
    dataset_args[dataset]['system_prompt'] = MAGISTRAL_SYSTEM_PROMPT
```

原理：显式对齐 reasoning—总结结构，要求先推理再收敛到标准答案格式，既改善实际答题，也减少无最终答案的样本。

## 运行配置变更（非源码）

```text
temperature=0.7
top_p=0.95
max_tokens=16384
eval_batch_size=2
--no-enable-prefix-caching
--no-enable-chunked-prefill
VLLM_FL_OOT_BLACKLIST=silu_and_mul,rms_norm,rotary_embedding
```

这些参数与脚本修复共同构成最终配置，不能只复制脚本而忽略服务参数。

## 验证结果

```text
GPQA Diamond: 68.00%（34/50）
EvalScope 原始分: 68.00%
NV 基线: 62.00%
parser_mismatch_count: 0
runaway_count: 3/50
```

原始分与校正分一致，说明提升来自实际答对更多，不是答案后处理。

## 复现与回退

复现前确认服务端口 18088、TP2、关闭 prefix/chunked，并核对三个核心算子 blacklist。评测固定 0.7/0.95、16384 tokens、batch=2。

回退命令：

```bash
cp /models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods/fast_gpqa.py.bak_20260920_magistral_fix \
   /models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods/fast_gpqa.py
```

回退后必须重新做语法检查；不要删除备份，也不要用旧预测重新判分冒充真实重跑。

## 完整代码

完整修改后脚本位于：

```text
workspace/t-head/fixes/fast_gpqa.py
```

本文件只记录 Magistral 相关差异，避免多个 Markdown 重复整份脚本产生版本漂移。
