# Ascend/Phi-3-mini-128k-instruct 适配与评测记录

- **日期**：`2026-09-20`
- **远端机器**：`10.55.0.173`
- **主机名**：`bm-jn-zs-zone1-910C-64G-10-117`
- **芯片**：Ascend 910C，单个逻辑设备 64GB
- **模型来源**：`microsoft/Phi-3-mini-128k-instruct`
- **本次处理结论**：指定 Ascend vLLM 0.20.2/plugin-FL 0.2.0 基础镜像下，模型以 BF16、TP=2、131072 上下文成功部署；GPQA Diamond 50 题得分 `40.00%`，高于 NV 基线 `33.00%`，精度判定通过

---

## 背景分析

本轮目标是在 Ascend 910C 节点上，使用指定的统一基础镜像部署 `Phi-3-mini-128k-instruct`，并按照现有发布评测口径执行 GPQA Diamond 50 题精度评测。精度只与 NV 实测基线对比，Hygon 历史结果不参与本次判定。

部署时确认了两个 Ascend 特有资源约束：

1. `npu-smi` 输出中的 NPU 板卡编号与 `ASCEND_RT_VISIBLE_DEVICES` 使用的全局逻辑设备编号不等价。板卡 5 对应逻辑设备 `10` 和 `11`。
2. TP=1 时，模型权重可以装入单个 64GB 逻辑设备，但 131072 上下文需要约 `48.05 GiB` KV cache，当前后端单卡只能提供约 `23.63 GiB`，估算只能支持约 64384 token。为保留模型标称 128K 上下文，最终使用同一空闲板卡的逻辑设备 `10,11`，TP=2。

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `bm-jn-zs-zone1-910C-64G-10-117` / `10.55.0.173` |
| 芯片 | Ascend 910C |
| 推理容器 | `Phi-3-mini-128k-instruct_flagos` |
| 评测容器 | `phi3-mini-128k-eval` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/flagrelease_ascend_vllm020plugin_base:no_vllm_ascend` |
| vLLM | `0.20.2` |
| vLLM plugin-FL | `0.2.0+g1326a3374` |
| EvalScope | `1.5.1` |
| 模型宿主机路径 | `/public-flash/models/Phi-3-mini-128k-instruct` |
| 模型容器路径 | `/models/Phi-3-mini-128k-instruct` |
| 逻辑设备 | `ASCEND_RT_VISIBLE_DEVICES=10,11` |
| Tensor Parallel | `2` |
| 服务端口 | `8004` |
| dtype | `bfloat16` |
| 最大上下文 | `131072` |

## Step 0：容器运行配置

推理容器使用长驻容器加 `docker exec` 启动 vLLM 服务的方式：

```text
cmd:        ["sleep", "infinity"]
network:    host
ipc:        host
shm-size:   64 GiB
privileged: true
restart:    unless-stopped
```

关键设备环境变量：

```bash
export ASCEND_RT_VISIBLE_DEVICES=10,11
export ASCEND_VISIBLE_DEVICES=10,11
export PYTORCH_NPU_ALLOC_CONF=max_split_size_mb:256
```

关键挂载：

```text
/public-flash/models -> /models
/data/flagos-workspace/microsoft/Phi-3-mini-128k-instruct -> /flagos-workspace
/usr/local/Ascend/driver -> /usr/local/Ascend/driver
/usr/local/dcmi -> /usr/local/dcmi
/usr/local/bin/npu-smi -> /usr/local/bin/npu-smi
/usr/local/sbin -> /usr/local/sbin
/etc/ascend_install.info -> /etc/ascend_install.info
```

按实际运行配置规范化后的可复现命令（原节点默认 runtime 即为 `ascend`，这里显式写出）：

```bash
docker run -d --restart unless-stopped \
  --runtime=ascend --network=host --ipc=host \
  --privileged --security-opt=label=disable --shm-size=64g \
  -e ASCEND_VISIBLE_DEVICES=10,11 \
  -e ASCEND_RT_VISIBLE_DEVICES=10,11 \
  -e PYTORCH_NPU_ALLOC_CONF=max_split_size_mb:256 \
  -v /public-flash/models:/models \
  -v /data/flagos-workspace/microsoft/Phi-3-mini-128k-instruct:/flagos-workspace \
  -v /usr/local/Ascend/driver:/usr/local/Ascend/driver \
  -v /usr/local/dcmi:/usr/local/dcmi \
  -v /usr/local/bin/npu-smi:/usr/local/bin/npu-smi \
  -v /usr/local/sbin:/usr/local/sbin \
  -v /etc/ascend_install.info:/etc/ascend_install.info \
  --name Phi-3-mini-128k-instruct_flagos \
  harbor.baai.ac.cn/flagrelease-public/flagrelease_ascend_vllm020plugin_base:no_vllm_ascend \
  sleep infinity
```

## Step 1：启动 vLLM 服务

实际服务命令：

```bash
export VLLM_WORKER_MULTIPROC_METHOD=spawn

vllm serve /models/Phi-3-mini-128k-instruct \
  --host 0.0.0.0 \
  --port 8004 \
  --served-model-name Phi-3-mini-128k-instruct \
  --dtype bfloat16 \
  --tensor-parallel-size 2 \
  --max-model-len 131072 \
  --gpu-memory-utilization 0.90 \
  --enforce-eager \
  --trust-remote-code
```

健康检查：

```bash
curl --noproxy '*' http://127.0.0.1:8004/health
curl --noproxy '*' http://127.0.0.1:8004/v1/models
```

核验结果：

- `/health` 返回 HTTP `200`；
- `/v1/models` 返回模型名 `Phi-3-mini-128k-instruct`；
- `max_model_len=131072`；
- 短请求生成正常；
- GPQA 评测期间服务端完成 50 题请求，评测结束后健康检查仍为 HTTP `200`。

## Step 2：模型文件和容器变更

模型文件位于：

```text
/public-flash/models/Phi-3-mini-128k-instruct
```

模型完整性核验：

- 架构：`Phi3ForCausalLM`；
- 权重分片：2 个；
- 权重总字节数：`7,642,181,880`；
- `config.json`、tokenizer 和权重索引存在；
- 未发现 `.incomplete` 权重文件。

下载阶段使用过的 `phi3-mini-128k-download` 容器、下载日志、退出码文件和 Hugging Face 临时缓存已删除，模型权重保留。

本轮没有修改 vLLM、`vllm-plugin-FL`、FlagGems 或模型源码，也没有重新构建或推送镜像。

## Step 3：评测

评测服务地址：

```text
http://127.0.0.1:8004/v1
```

评测配置：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.5.1` |
| 题数 | 50 |
| `eval_batch_size` | 4 |
| `temperature` | 0 |
| `seed` | 42 |
| `max_model_len` | 131072 |
| `max_tokens` | 32768 |
| 截断检测 | 通过 `--skip-truncation-check` 显式跳过 |
| 评测耗时 | `3241.42s`，约 54m 1.4s |

命令：

```bash
python3 /flagos-workspace/eval_ascend/fast_gpqa.py \
  --model-name Phi-3-mini-128k-instruct \
  --api-base http://127.0.0.1:8004/v1 \
  --dataset gpqa_diamond \
  --limit 50 \
  --eval-batch-size 4 \
  --skip-truncation-check \
  --dataset-dir /flagos-workspace/eval_ascend/datasets \
  --output /models/release_run_logs/Phi-3-mini-128k-instruct/ascend/gpqa50/gpqa50.json
```

结果文件：

```text
/public-flash/models/release_run_logs/Phi-3-mini-128k-instruct/ascend/gpqa50/gpqa50.json
```

判定文件：

```text
/public-flash/models/release_run_logs/Phi-3-mini-128k-instruct/ascend/gpqa50/verdict.json
```

服务与评测日志：

```text
/public-flash/models/release_run_logs/Phi-3-mini-128k-instruct/ascend/serve.log
/public-flash/models/release_run_logs/Phi-3-mini-128k-instruct/ascend/gpqa50/eval.log
```

### 结果摘要

```json
{
  "score": 40.0,
  "evalscope_score": 40.0,
  "total_questions": 50,
  "eval_batch_size": 4,
  "temperature": 0.0,
  "max_tokens": 32768,
  "max_model_len": 131072,
  "truncation_check_skipped": true,
  "eval_duration_seconds": 3241.42,
  "runaway_detection": {
    "checked": 50,
    "runaway_count": 2,
    "runaway_indices": [17, 41]
  },
  "answer_extraction_audit": {
    "checked": 50,
    "explicit_answer_found": 44,
    "format_corrected_score": 40.0,
    "parser_mismatch_count": 1,
    "invalid_evalscope_extract_count": 7
  }
}
```

### NV 基线对比

NV 基线：

```yaml
Phi-3-mini-128k-instruct:
  metrics:
    gpqa_diamond: 33
```

| 项目 | 值 |
|------|---:|
| Ascend 当前结果 | `40.00%` |
| NV 基线 | `33.00%` |
| 绝对差 | `+7.00` 个百分点 |
| 折算正确题数 | Ascend `20/50` |
| 相对退化 | `-21.21%`，即 Ascend 高于 NV `21.21%` |
| 5% 相对退化口径 | 通过 |
| 小样本噪声容忍 | 未使用 |

`accuracy_compare.py` 判定：

```json
{
  "baseline_mode": "nv_reference",
  "nv_score": 33.0,
  "current_score": 40.0,
  "rel_drop_pct": -21.21,
  "abs_diff": 7.0,
  "aligned": true,
  "noise_zone": false,
  "message": "精度达标: 当前=40.00%, NV=33.00%, 相对退化=-21.21% (容差 5.0%)"
}
```

## 50 题逐题结果

题号以人类可读的 `1–50` 编号记录。EvalScope 原始 `index` 为从 0 开始的 `0–49`，两者关系为：

```text
文档题号 = EvalScope 原始 index + 1
```

### 通过题号

共 20 题：

```text
1, 5, 6, 8, 11, 13, 14, 16, 17, 19,
20, 21, 22, 26, 31, 32, 36, 37, 41, 46
```

对应 EvalScope 原始索引：

```text
0, 4, 5, 7, 10, 12, 13, 15, 16, 18,
19, 20, 21, 25, 30, 31, 35, 36, 40, 45
```

### 失败题号

共 30 题：

```text
2, 3, 4, 7, 9, 10, 12, 15, 18, 23,
24, 25, 27, 28, 29, 30, 33, 34, 35, 38,
39, 40, 42, 43, 44, 45, 47, 48, 49, 50
```

对应 EvalScope 原始索引：

```text
1, 2, 3, 6, 8, 9, 11, 14, 17, 22,
23, 24, 26, 27, 28, 29, 32, 33, 34, 37,
38, 39, 41, 42, 43, 44, 46, 47, 48, 49
```

### 异常题号审计

| 类型 | 文档题号 | EvalScope 原始 index | 结果 |
|------|---|---|---|
| Runaway 复读 | `18` | `17` | 错误，`finish_reason=max_tokens` |
| Runaway 复读 | `42` | `41` | 错误，`finish_reason=max_tokens` |
| Parser mismatch | `34` | `33` | 错误，EvalScope 未提取到选项，显式答案为 A，标准答案为 B，未造成误扣 |

两道 runaway 题的多样性与压缩比：

| 题号 | diversity | compress ratio |
|---:|---:|---:|
| 18 | `0.0060` | `0.0106` |
| 42 | `0.0134` | `0.0194` |

## 现象

- TP=1 能加载权重，但不能为 131072 上下文分配足够 KV cache；
- 改为同一空闲板卡的两个逻辑设备、TP=2 后，128K 服务正常启动；
- GPQA Diamond 50 题得分 `40.00%`，格式校正分仍为 `40.00%`；
- 其中 2 题发生 runaway 复读，均输出到 `32768` token 上限，是本轮耗时达到 54 分钟的主要原因；
- 评测结果中的 `service_crashed=true` 为评测监控器误报：监控器读取了历史 `startup_native.log` 并使用了旧进程识别逻辑。实际 vLLM 进程未退出，50 题均完成，结束后 `/health` 仍返回 HTTP `200`。

## 定位

### 1. Ascend 设备编号映射

不能直接把 `npu-smi` 中的板卡 NPU 编号作为 `ASCEND_RT_VISIBLE_DEVICES`。本机每张板卡包含两个逻辑设备，板卡 5 对应全局逻辑设备 10/11。自动化在分配设备前必须同时核对拓扑映射、进程表和实际空闲显存。

### 2. 长上下文的 KV cache 容量

小模型权重能装入单卡不等于标称长上下文也能在单卡上服务。自动化需要在模型启动阶段解析 vLLM 返回的 KV cache 需求和估算最大长度；若标称长度不能满足，应优先增加 TP，不应静默降低 `max_model_len`。

### 3. MCQ 任务的过大生成窗口

`max_model_len=131072` 使评测脚本自动得到 `max_tokens=32768`。对 GPQA 这类 MCQ 任务，正常答案远小于该窗口，但一旦模型进入复读，会显著拉长评测。本轮为与现有参考口径一致保留 32768，发布自动化应增加 MCQ 专用上限、重复片段在线检测和单题取消机制。

## 处置

1. 核对 Ascend 板卡到全局逻辑设备的映射；
2. 使用实际空闲的逻辑设备 `10,11`；
3. 将 TP 从 1 调整为 2，保留 `max_model_len=131072`；
4. 固定 BF16、eager 模式和 `trust-remote-code`；
5. 使用 EvalScope `1.5.1`、并发 4、temperature 0 执行 GPQA Diamond 50 题；
6. 使用 `accuracy_compare.py` 仅与 NV `33.00%` 对比；
7. 保存逐题预测、正确/错误题号、runaway 和答案解析审计。

## 当前结果

- 服务：正常，Ascend 逻辑设备 `10,11`，TP=2，端口 `8004`
- 上下文：`131072`
- GPQA Diamond 50 题：`40.00%` / `20/50`
- NV 参考值：`33.00%`
- 相对退化：`-21.21%`，即当前高于 NV
- 精度判定：通过
- Runaway：2 题，题号 `18, 42`
- Parser mismatch：1 题，题号 `34`，未影响最终得分
- 性能验收：本次未执行

## 可复用规则

1. Ascend 多芯板卡必须区分板卡编号、物理芯片编号和全局逻辑设备编号；空闲检查必须以实际逻辑设备显存为准。
2. 长上下文模型的 TP 计算不能只看权重大小，必须同时计算最大上下文所需 KV cache。
3. 快速精度验收必须保存原始逐题数据，并同时记录正确题号、错误题号、runaway、`finish_reason`、parser mismatch 和格式校正分。
4. 评测监控器的服务进程识别和日志路径必须与当前部署方式绑定，不能复用历史容器的 PID/日志元数据，否则会产生假崩溃报警。
5. 50 题 GPQA 只能作为快速验收。本轮 `40%` 高于 NV `33%`，但仍应保留小样本方差和 2 题 runaway 的风险说明；若用于严格发布门控，应进一步执行 198 题全量或重复多轮评测。

## 2026-09-20 稳定性复测（第二轮）

第二轮保持与首轮相同的模型、服务和评测参数：

| 项目 | 值 |
|------|---|
| 服务 | 同一个 `Phi-3-mini-128k-instruct_flagos` 容器 |
| 逻辑设备 | `10,11` |
| TP | 2 |
| EvalScope | `1.5.1` |
| 数据集 | GPQA Diamond 同一前 50 题 |
| `eval_batch_size` | 4 |
| `temperature` | 0 |
| `seed` | 42 |
| `max_tokens` | 32768 |
| `max_model_len` | 131072 |

第二轮结果文件：

```text
/public-flash/models/release_run_logs/Phi-3-mini-128k-instruct/ascend/gpqa50_r2/gpqa50_r2.json
/public-flash/models/release_run_logs/Phi-3-mini-128k-instruct/ascend/gpqa50_r2/verdict.json
/public-flash/models/release_run_logs/Phi-3-mini-128k-instruct/ascend/gpqa50_r2/eval.log
```

第二轮结果：

| 项目 | 第一轮 | 第二轮 |
|------|---:|---:|
| 得分 | `40.00%` | `46.00%` |
| 正确题数 | `20/50` | `23/50` |
| 相对 NV 33% | `+7` 个百分点 | `+13` 个百分点 |
| Runaway | 2 | 0 |
| Parser mismatch | 1 | 0 |
| 无效 EvalScope 答案提取 | 7 | 2 |
| 耗时 | `3241.42s` | `507.01s` |
| NV 判定 | 通过 | 通过 |

第二轮 NV 判定：

```json
{
  "current_score": 46.0,
  "nv_score": 33.0,
  "abs_diff": 13.0,
  "rel_drop_pct": -39.39,
  "aligned": true,
  "noise_zone": false
}
```

### 第二轮通过题号

共 23 题：

```text
1, 6, 8, 11, 12, 13, 14, 16, 17, 19,
20, 21, 22, 27, 31, 34, 35, 36, 37, 41,
46, 47, 50
```

### 两轮稳定通过题号

两轮均正确，共 17 题：

```text
1, 6, 8, 11, 13, 14, 16, 17, 19,
20, 21, 22, 31, 36, 37, 41, 46
```

### 两轮稳定失败题号

两轮均错误，共 24 题：

```text
2, 3, 4, 7, 9, 10, 15, 18, 23, 24,
25, 28, 29, 30, 33, 38, 39, 40, 42, 43,
44, 45, 48, 49
```

### 正确性翻转题号

两轮共有 9 题发生正确性翻转：

| 变化 | 题号 |
|------|---|
| 第一轮正确、第二轮错误 | `5, 26, 32` |
| 第一轮错误、第二轮正确 | `12, 27, 34, 35, 47, 50` |

稳定性指标：

| 指标 | 值 |
|------|---:|
| 分数差 | `+6.00` 个百分点（第二轮相对第一轮） |
| 折算题数差 | `+3` 题 |
| 逐题正确性一致率 | `41/50 = 82.00%` |
| 正确题集合 Jaccard | `65.38%` |
| 两轮均超过 NV 基线 | 是 |

### 稳定性结论

- 从发布门限看，两轮分别为 `40%` 和 `46%`，均高于 NV `33%`，精度门限判定稳定通过。
- 从输出确定性看，在 `temperature=0`、`seed=42` 和所有显式配置一致的情况下，仍有 9/50 题发生正确性翻转，分数波动 6 个百分点，不能宣称严格确定性稳定。
- 首轮有 2 题 runaway，第二轮为 0，导致耗时从 54m1s 降到 8m27s。这说明当前后端存在会放大评测时延和分数波动的输出级非确定性。
- 如需给出严格稳定性结论，应至少再跑 1 轮，或直接执行 198 题全量多轮复测，并检查 Ascend 算子确定性、并发调度顺序和 TP 间归约差异。
