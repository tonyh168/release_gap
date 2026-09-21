# Light-R1-7B-DS 文件修改与运行配置留档

## 来源与用途

本轮通过配置涉及两类变更：

1. 服务启动时通过环境变量选择 native `TRITON_ATTN`、关闭 FlagGems attention 和 FL OOT；没有修改 vLLM、vllm-plugin-FL、FlagGems 或模型源码。
2. 评测使用 `/models/day0_eval/fast_gpqa_genconfig_fixed.py`。该文件是 `/models/day0_eval/fast_gpqa.py` 的副本，只在生成配置构建后新增13行模型映射；Light-R1-7B-DS对应项固定`temperature=0.6`、`top_p=0.95`、`max_tokens=20000`。

该专用评测文件位于宿主机挂载目录：

```text
宿主机：/public-flash/models/day0_eval/fast_gpqa_genconfig_fixed.py
容器内：/models/day0_eval/fast_gpqa_genconfig_fixed.py
```

## 文件校验

```text
fast_gpqa.py
  lines: 1455
  sha256: 93d70e36b74296392799dc15aa7c7a6edf27c00f5417aebe20e578585cc0face

fast_gpqa_genconfig_fixed.py
  lines: 1468
  sha256: ccbcf9e438902663b2f0688418f02b42e995ed281c92fb928a7b04aab7283165
```

## 代码差异（等价格式）

修改位置：`run_eval`完成`resolve_gen_params(...)`之后、构建`dataset_args`之前。

```diff
@@
     gen_config = resolve_gen_params(is_thinking, max_tokens, model_path=model_name)
+    _model_key = str(model_name).split('/')[-1]
+    _GEN_OVERRIDES = {
+        'MiniCPM4-8B': {'temperature': 0.8, 'top_p': 0.8},
+        'MiniCPM4.1-8B': {'temperature': 0.8, 'top_p': 0.8},
+        'DeepSeek-R1-Distill-Qwen-32B-Japanese': {
+            'temperature': 0.6,
+            'top_p': 0.95,
+            'max_tokens': 16384,
+        },
+        'Light-R1-7B-DS': {
+            'temperature': 0.6,
+            'top_p': 0.95,
+            'max_tokens': 20000,
+        },
+    }
+    if _model_key in _GEN_OVERRIDES:
+        for _k, _v in _GEN_OVERRIDES[_model_key].items():
+            if _k == 'max_tokens':
+                max_tokens = int(_v)
+            gen_config[_k] = _v
+        print(
+            f"  [gen] applied embedded model config for {_model_key}: "
+            f"temperature={gen_config.get('temperature')}, "
+            f"top_p={gen_config.get('top_p')}, "
+            f"max_tokens={gen_config.get('max_tokens')}"
+        )
```

上面为便于阅读的等价格式；远端实际文件把映射中的每个模型写在单行，逻辑和数值一致。共享专用脚本还包含其他模型的映射，因此自动化时必须按`_model_key`精确匹配，不能把Light参数应用到其他模型。

对Light-R1-7B-DS来说，`0.6/0.95`也与模型`generation_config.json`一致；显式映射的价值是让服务别名无法解析到本地模型目录时仍能固定正确参数，并将实际值写入日志。`max_tokens=20000`同时更新局部变量和`gen_config`，确保最终请求与结果JSON一致。

## 服务侧配置变更

本轮没有服务源码文件修改。服务行为由以下运行时变量确定：

```bash
export VLLM_FL_FLAGOS_WHITELIST=attention_backend
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_FL_OOT_ENABLED=0
export VLLM_FL_TRITON_CACHE_ROOT=/models/day0_logs/triton_cache/Light-R1-7B-DS-fix-whitelist-attn-oot-off
```

对应语义：

```text
attention_backend 标识保留在 plugin-FL 路由
attention 实现使用 vLLM native TRITON_ATTN
FlagGems attention 不启用
FL OOT 不启用
普通 FlagGems 算子不加入白名单
```

`FLAGGEMS_DB_URL=sqlite:///:memory:`只使用内存数据库，不产生持久数据库文件。Triton编译缓存和服务日志会在挂载的`/models/day0_logs`下产生运行时文件。

## 复现命令

评测服务必须先在`http://127.0.0.1:8003/v1`健康运行。使用新的输出文件名，避免覆盖证据：

```bash
docker exec day0-eval-standard env \
  LD_LIBRARY_PATH=/opt/dtk-26.04-DCC2602-0317/dcc/gcvm/lib:/opt/dtk-26.04-DCC2602-0317/hip/lib:/opt/dtk-26.04-DCC2602-0317/llvm/lib:/opt/dtk-26.04-DCC2602-0317/lib:/opt/dtk-26.04-DCC2602-0317/lib64:/opt/dtk-26.04-DCC2602-0317/.hyhal/hsa/lib:/opt/dtk-26.04-DCC2602-0317/.hyhal/rocm_smi/lib:/usr/local/lib:/usr/local/lib64:/opt/mpi/lib:/opt/hwloc/lib \
  /usr/bin/python3 \
  /models/day0_eval/fast_gpqa_genconfig_fixed.py \
  --model-name Light-R1-7B-DS \
  --api-base http://127.0.0.1:8003/v1 \
  --api-key EMPTY \
  --dataset math_500 \
  --limit 10 \
  --eval-batch-size 4 \
  --skip-truncation-check \
  --output /models/day0_logs/accuracy/Light-R1-7B-DS-math500-50-repro.json
```

`--limit 10`是per-subset参数，实际执行Level 1--5各10题，总计50题。脚本没有`--max-tokens` CLI参数，`20000`来自专用脚本中的模型映射。

上面的命令只为本次评测进程补入DTK动态库路径，不修改容器或安装软件包。若镜像中的DTK目录版本变化，应先按实际路径定位`libgalaxyhip.so.5`、`libhsa-runtime64.so`和`librocm_smi64.so.2`，再更新路径。

## 文件影响范围

| 文件或目录 | 本轮作用 |
|------|------|
| `/models/day0_eval/fast_gpqa.py` | 基础评测脚本，只读，未修改 |
| `/models/day0_eval/fast_gpqa_genconfig_fixed.py` | 新增模型参数映射；本轮实际评测入口 |
| `/models/Light-R1-7B-DS` | 模型权重、配置、tokenizer未修改 |
| vLLM / plugin-FL / FlagGems源码 | 未修改 |
| `/models/day0_logs/triton_cache/Light-R1-7B-DS-fix-whitelist-attn-oot-off` | 本轮服务的Triton运行缓存 |
| `/models/day0_logs/Light-R1-7B-DS-serve-fix-whitelist-attn-oot-off-20260918-0048.log` | 服务日志 |
| `/models/day0_logs/accuracy/Light-R1-7B-DS-math500-50-fix-whitelist-attn-oot-off-b4-20260918-0051.*` | 评测日志、结果、退出状态 |
| `/models/day0_eval/outputs/math_500/20260918_045356` | 50题predictions、reviews、TaskConfig和HTML报告 |

## 验证

最终TaskConfig：

```text
dataset=math_500
dataset_hub=modelscope
limit=10 per subset
eval_batch_size=4
mode=thinking
temperature=0.6
top_p=0.95
max_tokens=20000
stream=true
timeout=120000
seed=42
```

日志与逐题产物审计：

```text
0 already fully cached
Level 1--5各10题
predictions=50
reviews=50
stop=49
max_tokens_finish_count=1（Level 5，答案正确）
api_errors=0
runaway_count=0
score=46/50=92%
exit=0
done=0
```

结果相对NV记录值94%的精度损失为2.13%，本轮50题精度通过。

## 自动化提炼

1. 将模型采样参数放入结构化的model-key配置，而不是复制整份评测脚本。
2. 启动前打印并校验attention实现、OOT状态、普通算子白名单和最终generation config。
3. MATH-500自动换算`总题数=limit×subset数`，报告每级样本数与分数。
4. 结果验收同时要求缓存命中审计、逐题结束原因、API错误、runaway和退出状态。
5. 产物目录必须位于持久挂载，防止容器删除后丢失逐题证据。
