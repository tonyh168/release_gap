# Hygon/Mistral-7B-OpenOrca 适配与评测记录

- **日期**：`2026-09-16`
- **远端机器**：`10.232.2.33`
- **主机名**：`bm-srwl-nj-zone3-d-bw1000-64g-2-33`
- **历史失败报告**：`flagrelease_fail_reports/Hygon/FAILED_Hygon_Mistral-7B-OpenOrca_202607241434.md`
- **历史问题类型**：旧栈下 V2/V3 GPQA 精度分别为 `22%`/`24%`，均低于 NV 记录值 `27%`；同时存在 plugin-FL 问题记录
- **本次处理结论**：新镜像单卡服务正常；GPQA Diamond 全量 198 题为 `25.76%`，相对 NV 记录值下降 `4.59%`，按当前 5% 相对退化门限通过；性能未重测

---

## 背景分析

历史报告使用 vLLM `0.20.2`、plugin-FL `0.2.0`、FlagGems `5.4.0dev` 和 Flagtree `0.6.0+hcu`。V2/V3 均沿用 26 个 FlagGems 算子，50 题 GPQA 分别为 `22%` 和 `24%`，低于 NV 记录值 `27%`，因此迁移失败。

本次改用统一 Hygon 新镜像，在保留历史 26 项算子白名单的前提下，将模型以单卡方式部署；注意力后端显式固定为 `TRITON_ATTN`，并使用 EvalScope `1.5.1` 执行 GPQA Diamond 全量 198 题评测。

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `bm-srwl-nj-zone3-d-bw1000-64g-2-33` / `10.232.2.33` |
| 芯片 | Hygon DCU BW1000，8 × 64GB |
| 推理容器 | `day0-mistral-7b-openorca` |
| 评测容器 | `day0-eval-standard` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4` |
| 镜像 ID | `sha256:b4dd95d30aa8213e0721856672ee544e773c51216b3737c12069b32ad71d07a0` |
| vLLM / PyTorch | `vLLM 0.24.0` / `PyTorch 2.10.0`（镜像版本口径） |
| 模型来源 | `Open-Orca/Mistral-7B-OpenOrca` |
| 模型路径 | `/models/Mistral-7B-OpenOrca` |
| 宿主机共享路径 | `/public-flash/models/Mistral-7B-OpenOrca` |
| GPU | `HIP_VISIBLE_DEVICES=3` |
| 服务端口 | `8001` |

## Step 0：容器运行配置

推理容器由常驻进程保持运行，vLLM 通过 `docker exec` 在容器内启动：

```text
cmd:      ["bash", "-lc", "sleep infinity"]
network:  host
ipc:      host
shm-size: 64 GiB
```

设备与权限：

```text
/dev/kfd
/dev/dri
seccomp=unconfined
group-add=video
```

挂载：

```text
/public-flash/models -> /models      读写
/opt/hyhal           -> /opt/hyhal  只读
```

评测容器使用 host 网络，并挂载：

```text
/public-flash/models/day0_eval -> /models/day0_eval
/public-flash/models/day0_logs -> /models/day0_logs
```

## Step 1：启动 vLLM 服务

实际启动命令：

```bash
/usr/bin/python3 /usr/local/bin/vllm serve /models/Mistral-7B-OpenOrca \
  --served-model-name Mistral-7B-OpenOrca \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.90 \
  --port 8001 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code
```

当前服务检查：

```bash
curl http://127.0.0.1:8001/health
curl http://127.0.0.1:8001/v1/models
```

只读核验结果：`/v1/models` 返回 HTTP `200`，服务模型名为 `Mistral-7B-OpenOrca`，`max_model_len=32768`。

### 环境变量

```bash
export DTK_HOME=/opt/dtk
export ROCM_PATH=/opt/dtk-26.04-DCC2602-0317
export HIP_PATH=/opt/dtk-26.04-DCC2602-0317/hip
export HSA_PATH=/opt/dtk/hsa
export DEVICE_LIB_PATH=/opt/dtk/amdgcn/bitcode
export TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18

export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export HIP_VISIBLE_DEVICES=3
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200

export VLLM_FL_TRITON_CACHE_ROOT=/models/day0_logs/triton_cache/Mistral-7B-OpenOrca
export FLAGGEMS_ENABLE_OPLIST_PATH=/models/day0_logs/Mistral-7B-OpenOrca-enabled-ops-20260914-173759-exact-md-final.txt

export VLLM_FL_FLAGOS_WHITELIST=add,arange_start,argmax,copy_,cos,expand,full,index,linear,lt_scalar,mm_out,ones,rand_like,randn,reciprocal,sin,softmax,softmax_out,sub,to_copy,true_divide,true_divide_,where_self,where_self_out,zero_,zeros
```

当前进程没有显式设置 `VLLM_FL_OOT_ENABLED`、`VLLM_FL_OOT_BLACKLIST` 或 `VLLM_FL_FLAGOS_BLACKLIST`，即沿用镜像默认 OOT 行为。白名单与历史报告的 26 项算子一致。

## Step 2：模型文件和容器变更

模型文件位于：

```text
/public-flash/models/Mistral-7B-OpenOrca
```

本次没有重新构建、重新打 tag 或推送镜像，也没有修改 vLLM、vllm-plugin-FL 或 FlagGems 源码。运行时新增内容主要包括：

- 独立 Triton 缓存目录；
- FlagGems 实际启用算子记录；
- 部署、服务和评测日志；
- EvalScope 预测、报告及汇总 JSON。

关键日志：

```text
/public-flash/models/day0_logs/Mistral-7B-OpenOrca-deploy-20260914-173759-exact-md.log
/public-flash/models/day0_logs/Mistral-7B-OpenOrca-serve-20260914-173759-exact-md.log
```

## Step 3：评测

评测服务地址：

```text
http://127.0.0.1:8001/v1
```

评测配置：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.5.1` |
| 题数 | 198（全量） |
| `eval_batch_size` | 4 |
| `temperature` | 0 |
| `max_model_len` | 32768 |
| `max_tokens` | 24576（标准模型自动计算值） |
| 截断检测 | 通过 `--skip-truncation-check` 显式跳过，不能据此声明已排除截断 |

结果文件：

```text
/public-flash/models/day0_logs/accuracy/Mistral-7B-OpenOrca-gpqa198-full-standard-20260915-rerun2.json
```

结果摘要：

```json
{
  "score": 25.76,
  "total_questions": 198,
  "runaway_detection": {
    "runaway_count": 4
  },
  "nv_score": 27.0,
  "rel_drop_pct": 4.59,
  "aligned": true
}
```

`25.76%` 对应约 `51/198`。NV 记录值为 `27%`，绝对低 `1.24` 个百分点，相对退化 `4.59%`，未超过 5% 门限。

## 现象

- 新镜像下单卡服务正常启动，接口持续返回 HTTP `200`；
- 历史 50 题 V2/V3 分别为 `22%`/`24%`，本次全量 198 题为 `25.76%`；
- 本轮检测到 4 题 runaway/复读异常，但汇总分仍处于 NV 记录值的 5% 相对容差内；
- 当前未进行性能复测，不能据此宣称完整 V1-V3 性能门控通过。

## 定位

历史失败不能继续简单归因于某一个普通 FlagGems 算子：新镜像在保持同一 26 项白名单的情况下，服务可用且全量精度进入当前门限。变化同时包含 vLLM、plugin-FL、Flagtree、DTK 和注意力实现，因此现有证据只支持“新软件栈及当前 `TRITON_ATTN` 路径解决了本轮部署/精度门控问题”，不能把改善归因到单一组件。

此外，`nv_baseline.yaml` 只记录 NV 分数 `27%`，没有 NV 原始题目 ID、样本量、prompt、EvalScope 版本和逐题预测。因此当前只能确认相对仓库 NV 记录值达标，不能证明 NV 与本次 Hygon 198 题逐题同源。

## 处置

1. 使用统一 Hygon 新镜像和单卡 GPU3；
2. 保留历史 26 项 FlagGems 白名单；
3. 固定 `TRITON_ATTN`、BF16、TP=1 和 eager 模式；
4. 使用独立 Triton 缓存与算子记录文件；
5. 使用 EvalScope `1.5.1`、固定并发 4，执行 GPQA 全量 198 题；
6. 记录 runaway 数量，并与 NV 记录值按同一比较脚本判定。

## 当前结果

- 服务：正常，GPU3，端口 `8001`
- GPQA Diamond 全量：`25.76%`（约 51/198）
- NV 参考值：`27.0%`
- 相对退化：`4.59%`
- 精度判定：✅ 按当前 5% 相对退化规则通过
- Runaway：4 题，需保留为结果质量风险
- 性能验收：本次未重测

## 可复用规则

历史精度失败模型应优先复用原算子白名单，在新镜像上固定注意力后端、并发、评测器版本和完整数据量后重测。结果达标时仍要记录 runaway、截断检测状态和 NV 元数据完整性；只有分数而没有 NV 原始评测产物时，不得宣称已经完成逐题严格对齐。
