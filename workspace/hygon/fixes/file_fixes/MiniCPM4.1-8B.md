# MiniCPM4.1-8B 评测入口与文件变更留档

## 来源与用途

本轮 50 题使用本机临时入口 `/tmp/minicpm41_full50_fixed.py`，经标准输入传给 `10.232.2.33` 的 `day0-eval-standard` 容器执行。完整代码留在本文，供后续自动化复用；临时文件不应被当作仓库内的持久产物。

入口导入容器已有的 `/models/day0_eval/fast_gpqa.py`，只对服务名 `MiniCPM4.1-8B` 覆盖两处运行时函数：

1. `auto_max_tokens` 返回 `32768`，保留从服务端查询到的 `max_model_len=65536`；不修改统一脚本的全局 `THINKING_MAX_TOKENS_CAP=20000`。
2. `resolve_gen_params` 保持 `temperature=0.6`、`top_p=0.95`，设置 `max_tokens=32768`，通过 EvalScope `extra_body` 透传 `add_special_tokens=True` 与 `chat_template_kwargs.enable_thinking=True`。

这次是评测客户端参数修正，不是修改模型权重、chat template、vLLM 服务或 FlagGems 算子实现。MiniCPM4.1 的 `generation_config.json` 含 `temperature=0.8`、`top_p=0.8`，但本轮明确采用此前较好的 thinking 评测口径 `0.6/0.95`；不要把这组数误写成直接读取模型 generation config。

## 完整代码

本机实际执行的入口源码：

```python
#!/usr/bin/env python3
import sys

sys.path.insert(0, "/models/day0_eval")
import fast_gpqa

_original_auto_max_tokens = fast_gpqa.auto_max_tokens
_original_resolve_gen_params = fast_gpqa.resolve_gen_params


def _is_minicpm41(model_name):
    return str(model_name).rstrip("/").split("/")[-1].lower() == "minicpm4.1-8b"


def patched_auto_max_tokens(api_base, api_key, model_name, is_thinking=False, is_multimodal=False):
    if _is_minicpm41(model_name):
        max_model_len = fast_gpqa.query_model_max_len(api_base, api_key, model_name)
        return 32768, max_model_len
    return _original_auto_max_tokens(
        api_base,
        api_key,
        model_name,
        is_thinking=is_thinking,
        is_multimodal=is_multimodal,
    )


def patched_resolve_gen_params(is_thinking, max_tokens, model_path=None):
    config = _original_resolve_gen_params(
        is_thinking,
        max_tokens,
        model_path=model_path,
    )
    if _is_minicpm41(model_path):
        config.update(
            {
                "max_tokens": 32768,
                "temperature": 0.6,
                "top_p": 0.95,
                "extra_body": {
                    "add_special_tokens": True,
                    "chat_template_kwargs": {"enable_thinking": True},
                },
            }
        )
        print(
            "  [gen] MiniCPM4.1 fixed config: "
            "temperature=0.6, top_p=0.95, max_tokens=32768, "
            "add_special_tokens=True, enable_thinking=True"
        )
    return config


fast_gpqa.auto_max_tokens = patched_auto_max_tokens
fast_gpqa.resolve_gen_params = patched_resolve_gen_params

if __name__ == "__main__":
    fast_gpqa.main()
```

保留两处覆盖很重要：只改 `generation_config` 会造成报告顶层 `max_tokens` 与实际请求不一致；只改 `auto_max_tokens` 则不会给 API 传入特殊 token 和显式 thinking 参数。统一脚本 `fast_gpqa.py` 本身未被修改。

## 本轮实际执行

本轮在评测容器中临时设置 DTK 动态库路径，否则导入 EvalScope 时 PyTorch 会因为找不到 `libgalaxyhip.so.5` 或 `librocm_smi64.so.2` 失败；没有安装或替换软件包。

```bash
# 在本机执行；源码从本机 /tmp 通过 SSH 标准输入传给远端容器
ssh -o BatchMode=yes -p 2224 'xionglei@root@10.232.2.33@bastion.aiops.baai.ac.cn' \
  "docker exec -i day0-eval-standard env \
    LD_LIBRARY_PATH=/opt/dtk-26.04-DCC2602-0317/dcc/gcvm/lib:/opt/dtk-26.04-DCC2602-0317/hip/lib:/opt/dtk-26.04-DCC2602-0317/llvm/lib:/opt/dtk-26.04-DCC2602-0317/lib:/opt/dtk-26.04-DCC2602-0317/lib64:/opt/dtk-26.04-DCC2602-0317/.hyhal/hsa/lib:/opt/dtk-26.04-DCC2602-0317/.hyhal/rocm_smi/lib:/usr/local/lib:/usr/local/lib64:/opt/mpi/lib:/opt/hwloc/lib \
    /usr/bin/python3 - \
    --model-name MiniCPM4.1-8B \
    --api-base http://127.0.0.1:8002/v1 \
    --api-key EMPTY \
    --dataset gpqa_diamond \
    --limit 50 \
    --eval-batch-size 4 \
    --skip-truncation-check \
    --output /models/day0_logs/accuracy/MiniCPM4.1-8B-gpqa50-repro.json" \
  < /tmp/minicpm41_full50_fixed.py
```

上面是与本轮等价的复现命令；本轮实际在远端 `docker exec -i ... bash -lc` 中导出同样的 `LD_LIBRARY_PATH`，使用不同的结果文件名。该 `/tmp` 入口属本机临时路径，日后复现应先将本文代码作为独立入口文件保存，并改用尚未存在的输出路径。`fast_gpqa.py` 没有 `--max-tokens` CLI 参数，`32768` 来自本入口代码，不能在复现命令中虚构该参数。

## 文件影响范围

| 位置 | 本轮变化 |
|------|----------|
| 本机 `/tmp/minicpm41_full50_fixed.py` | 新建隔离评测入口；源码完整保存在本文 |
| 容器 `/models/day0_eval/fast_gpqa.py` | 只读导入；未修改 |
| 容器 `/models/MiniCPM4.1-8B` | 权重、配置、tokenizer 均未修改 |
| 推理容器 vLLM / plugin-FL / FlagGems | 未修改源码、未重启服务 |
| 评测进程 `LD_LIBRARY_PATH` | 仅该次进程临时设置；未修改镜像或容器启动配置 |
| 宿主机 `/public-flash/models/day0_logs/accuracy/MiniCPM4.1-8B-gpqa50-fixed-thinking-20260920-env.{log,json,exit,done}` | 新增本轮日志、结果、退出状态 |
| 评测容器 `/root/outputs/gpqa_diamond/20260920_065338` | 新增预测、判分、配置与报告；位于容器可写层，未挂载到宿主机 `/public-flash/models/day0_eval` |

容器删除前应将 `/root/outputs/gpqa_diamond/20260920_065338` 导出到持久目录，以保留逐题证据。上述导出**不是**本次已执行的文件修改。

## 验证与边界

日志中最终生效配置为：

```text
mode=thinking
temperature=0.6
top_p=0.95
max_tokens=32768
extra_body={"add_special_tokens": true, "chat_template_kwargs": {"enable_thinking": true}}
eval_batch_size=4
0 already fully cached
```

实际评测产出 `50/50` 条不同索引的 predictions 与 reviews，`34/50=68%`，退出码 `0`；其中 48 题自然停止，索引 `12`、`22` 两题达到 `32768` 且判错；runaway 检测数为 0。`--skip-truncation-check` 仅跳过开测前探测，不表示所有题都自然结束。

本轮同时变更了 BOS/tokenizer 参数和输出上限，不能把 20 个百分点的提升全部归因于其中一个变量；`temperature=0.6`、`top_p=0.95` 与此前较好的轮次相同。

## 自动化提炼

将评测配置来源显式记录为模型专用覆盖，开测前校验最终 `generation_config` 与 `/v1/models.max_model_len`；保存请求中的 `extra_body` 和 `max_tokens`、缓存命中数、逐题结束原因、答案提取审计及输出工作目录。只有汇总 JSON 而没有逐题产物时，不应把一次抽样成绩当成跨轮次稳定性证明。
