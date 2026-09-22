# Hygon/gemma-1.1-7b-it 适配与评测记录

- **日期**：2026-09-16
- **远端机器**：10.232.2.33
- **主机名**：bm-srwl-nj-zone3-d-bw1000-64g-2-33
- **模型来源**：google/gemma-1.1-7b-it
- **本次处理结论**：使用明确固定的 Hygon 环境变量重新部署后，模型服务正常；GPQA Diamond 50 题 EvalScope 原始分为 40.00%，答案提取校正后为 42.00%（21/50），高于 NV 基线 37.00%，无 runaway，评测通过

---

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | bm-srwl-nj-zone3-d-bw1000-64g-2-33 / 10.232.2.33 |
| 芯片 | Hygon DCU BW1000，8 × 64GB |
| 推理容器 | day0-gemma-1-1-7b-it |
| 评测容器 | day0-eval-standard |
| 镜像 | harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4 |
| 镜像 ID | sha256:b4dd95d30aa8213e0721856672ee544e773c51216b3737c12069b32ad71d07a0 |
| vLLM / PyTorch | vLLM 0.24.0 / PyTorch 2.10.0 |
| EvalScope | 1.5.1 |
| 模型宿主机路径 | /public-flash/models/gemma-1.1-7b-it |
| 模型容器路径 | /models/gemma-1.1-7b-it |
| GPU | HIP_VISIBLE_DEVICES=6 |
| Tensor Parallel | 1 |
| 服务端口 | 8004 |
| dtype | bfloat16 |

## Step 0：容器运行配置

推理容器由常驻进程保持运行，vLLM 通过 docker exec 在容器内启动：

~~~text
cmd:      ["bash", "-lc", "sleep infinity"]
network:  host
ipc:      host
shm-size: 64 GiB
~~~

设备与权限：

~~~text
/dev/kfd
/dev/dri
seccomp=unconfined
group-add=video
~~~

挂载：

~~~text
/public-flash/models -> /models      读写
/opt/hyhal           -> /opt/hyhal  只读
~~~

评测容器使用 host 网络，并挂载：

~~~text
/public-flash/models/day0_eval -> /models/day0_eval
/public-flash/models/day0_logs -> /models/day0_logs
~~~

## Step 1：启动 vLLM 服务

实际启动命令：

~~~bash
/usr/bin/python3 /usr/local/bin/vllm serve /models/gemma-1.1-7b-it \
  --served-model-name gemma-1.1-7b-it \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 8192 \
  --gpu-memory-utilization 0.90 \
  --port 8004 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code
~~~

关键环境变量：

~~~bash
export DTK_HOME=/opt/dtk
export ROCM_PATH=/opt/dtk
export HIP_PATH=/opt/dtk/hip
export HSA_PATH=/opt/dtk/hsa
export DEVICE_LIB_PATH=/opt/dtk/amdgcn/bitcode
export TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18

export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export HIP_VISIBLE_DEVICES=6
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200


export VLLM_FL_FLAGOS_WHITELIST=add,addmm_out,arange_start,argmax,broadcast_to,copy_,cos,expand,full,index,linear,lt_scalar,mm_out,rand_like,randn,reciprocal,sin,softmax,softmax_out,sub,to_copy,true_divide,true_divide_,where_self,where_self_out,zero_,zeros

export VLLM_FL_OOT_BLACKLIST=silu_and_mul
export VLLM_FL_OOT_ENABLED=0
~~~

环境变量作用：

- TRITON_HIP_CLANG_PATH 显式使用 DTK clang-18，保证 Hygon Triton/HSACO 编译路径正确；
- VLLM_FL_FLAGOS_WHITELIST 固定本轮使用的普通 FlagGems 算子集合；
- VLLM_FL_OOT_ENABLED=0 关闭 vllm-plugin-FL 高层 OOT 注册路径；
- VLLM_FL_OOT_BLACKLIST=silu_and_mul 保留配置追溯；
- 未设置 `VLLM_FL_TRITON_CACHE_ROOT`，沿用 Triton 默认缓存。

vLLM 实际初始化配置中：

~~~text
enable_prefix_caching=True
enable_chunked_prefill=True
enforce_eager=True
attention_backend=TRITON_ATTN
max_seq_len=8192
dtype=bfloat16
~~~

部署及服务日志：

~~~text
/public-flash/models/day0_logs/gemma-1.1-7b-it-deploy-20260916-103723.log
/public-flash/models/day0_logs/gemma-1.1-7b-it-serve-20260916-103723.log
~~~

服务检查：

~~~bash
curl http://127.0.0.1:8004/health
curl http://127.0.0.1:8004/v1/models
~~~

服务正常启动，模型服务名为 gemma-1.1-7b-it。

## Step 2：模型文件和容器变更

模型文件：

~~~text
/public-flash/models/gemma-1.1-7b-it
~~~

本次未重新构建、打 tag 或推送镜像，也未修改：

- vLLM 源码；
- vllm-plugin-FL 源码；
- FlagGems/Flagtree 算子实现；
- 模型权重、配置和 tokenizer。

本轮产生的运行时文件包括：

- 部署和服务日志；
- 模型独立 Triton 编译缓存；
- EvalScope predictions、reviews、报告及结果 JSON。

## Step 3：评测

评测服务地址：

~~~text
http://127.0.0.1:8004/v1
~~~

评测配置：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | 1.5.1 |
| 题数 | 50 |
| 模式 | standard |
| eval_batch_size | 4 |
| temperature | 0.0 |
| top_p | 1.0 |
| max_model_len | 8192 |
| max_tokens | 4096 |
| stream | true |
| 请求超时 | 120000 ms |
| retries | 5 |
| 截断探测 | 通过命令行显式跳过 |
| 评测耗时 | 631.1 秒，约 10 分 31.1 秒 |

等价评测命令：

~~~bash
python3 fast_gpqa.py \
  --model-name gemma-1.1-7b-it \
  --api-base http://127.0.0.1:8004/v1 \
  --api-key EMPTY \
  --dataset gpqa_diamond \
  --limit 50 \
  --eval-batch-size 4 \
  --max-tokens 4096 \
  --skip-truncation-check \
  --output /models/day0_logs/accuracy/gemma-1.1-7b-it-gpqa50-explicit-env-redeploy-20260916-1046.json
~~~

评测开始时日志记录：

~~~text
Unified pool: 50 items to process, 0 already fully cached
~~~

因此本轮 50 题均重新生成，没有复用历史答案。

结果文件：

~~~text
/public-flash/models/day0_logs/accuracy/gemma-1.1-7b-it-gpqa50-explicit-env-redeploy-20260916-1046.json
~~~

评测日志：

~~~text
/public-flash/models/day0_logs/accuracy/gemma-1.1-7b-it-gpqa50-explicit-env-redeploy-20260916-1046.log
~~~

EvalScope 工作目录：

~~~text
outputs/gpqa_diamond/20260916_024618
~~~

结果摘要：

~~~json
{
  "model": "gemma-1.1-7b-it",
  "benchmark": "gpqa_diamond",
  "mode": "standard",
  "score": 42.0,
  "evalscope_score": 40.0,
  "total_questions": 50,
  "eval_batch_size": 4,
  "max_tokens": 4096,
  "max_model_len": 8192,
  "temperature": 0.0,
  "eval_duration_seconds": 631.1,
  "total_duration_seconds": 631.1,
  "runaway_detection": {
    "checked": 50,
    "runaway_count": 0,
    "runaway_indices": []
  },
  "answer_extraction_audit": {
    "checked": 50,
    "explicit_answer_found": 46,
    "fallback_to_evalscope": 4,
    "format_corrected_score": 42.0,
    "parser_mismatch_count": 6,
    "parser_false_negative_count": 2,
    "parser_false_positive_count": 1,
    "invalid_evalscope_extract_count": 4
  }
}
~~~

答案提取审计将 EvalScope 原始分 40.00% 校正为 42.00%。最终正确题数为：

~~~text
21/50 = 42.00%
~~~

本轮检测结果：

~~~text
runaway_count=0
~~~

## Step 4：与 NV 基线对比

nv_baseline.yaml 中记录：

~~~yaml
gemma-1.1-7b-it:
  metrics:
    gpqa_diamond: 37.0
~~~

对比结果：

| 项目 | 值 |
|------|---:|
| Hygon EvalScope 原始分 | 40.00% |
| Hygon 答案提取校正分 | 42.00% |
| NV 基线 | 37.00% |
| 校正分绝对差 | Hygon 高 5 个百分点 |
| 精度损失 | 0 |
| runaway | 0 |
| 评测判定 | 通过 |

原始分 40.00% 和校正分 42.00% 均高于 NV 基线 37.00%，满足精度要求。

## 当前结果

- 部署：成功；
- 服务：正常；
- GPU：6；
- 端口：8004；
- Tensor Parallel：1；
- dtype：bfloat16；
- attention：TRITON_ATTN；
- FL OOT：关闭；
- prefix cache：开启；
- chunked prefill：开启；
- GPQA Diamond：42.00%（21/50，答案提取校正后）；
- EvalScope 原始分：40.00%；
- NV 基线：37.00%；
- runaway：0；
- 精度判定：通过。

## 可复用规则

1. 国产芯片模型适配记录应保存部署时的完整有效环境变量，而不是只记录启动命令。
2. vLLM 服务启动后应从 EngineCore 初始化日志反查 prefix cache、chunked prefill、dtype 和 max model length 的实际值。
3. GPQA 结果应同时保留 EvalScope 原始分和显式 ANSWER 标记校正分。
4. 评测日志必须记录缓存命中数量；0 already fully cached 才能证明该轮不是复用历史答案。
5. 评测结论应同时核验题数、生成参数、runaway 数量和 NV 基线。
