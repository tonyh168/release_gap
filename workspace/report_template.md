# {厂商}/{模型名} 修复日志

- **失败报告**：flagrelease_fail_reports/{厂商}/FAILED_{厂商}_{模型名}_{时间戳}.md（无则写"暂无"）
- **原始失败类型**：服务启动失败 / 精度不达标 / 性能不达标 / plugin报错 / 评测中断
- **日期**：YYYY-MM-DD

## 现象
（贴关键日志 / 评测分数 / 中断位置）

## 定位
（plugin-FL 下的报错类型：是否缺 .so 编译扩展 / crash 算子名 / 精度退化算子 / OOM）

## 处置
（换镜像 / 关算子 / 调参 / 上报框架。多轮迭代的完整过程写在这里，含失败尝试）

## 结果
- 修复后分 / NV 基线：
- 达标判定（accuracy_compare 退出码）：

## 提炼到 KNOWLEDGE 的条目
（一句话规律，若无则写"无新规律"）

---

## 发布字段

> ⚠️ **本段是发布数据的唯一来源，请逐字填写。**
> **只写最终达标的那一套配置** —— 中间迭代版本（失败的尝试）全部留在上面的「## 处置」里。
> 本段固定放在报告**最后一节**，标题写 `## 发布字段`，全文件只此一处。

### 一、发布信息

```bash
# MODEL_SOURCE: <org/name>
# IMAGE: <完整镜像地址:tag>
# HARBOR_VER: <V1|V2|V3|V4>
# GPU: <芯片型号, N × XXGB>
# TP: <张量并行数>
# VERDICT: <ok|bad|pending>
# METRIC: <GPQA_Diamond|MMLU|math_500|...>
# SCORE_ORIGIN: <基线分 或 ->
# SCORE_FLAGOS: <本平台分 或 ->
# CONTAINER_DEVS: <--device=/dev/kfd --device=/dev/dri --shm-size=64g>
```

| 键 | 必填 | 含义 |
|----|------|------|
| `MODEL_SOURCE` | 是 | 上游权重 ID，`org/name` 形式 |
| `IMAGE` | 是 | 完整镜像地址（含 tag） |
| `HARBOR_VER` | 否 | `V1`/`V2`/`V3`/`V4` |
| `GPU` | 否 | 芯片型号 × 数量 |
| `TP` | 否 | 张量并行数 |
| `VERDICT` | 是 | `ok`=达标可发布 / `bad`=不达标 / `pending`=未完成 |
| `METRIC` | 是 | 精度指标名 |
| `SCORE_ORIGIN` | 是 | NV / 原厂基线分（无则 `-`） |
| `SCORE_FLAGOS` | 是 | 本平台得分（无则 `-`） |
| `CONTAINER_DEVS` | 否 | 容器设备挂载与运行参数 |

### 二、容器创建（宿主机执行）

写成用户视角、可直接粘贴执行的交互式命令（一步进容器 shell），按本次实测真实值写。

```bash
docker run --init -it --net=host --ipc=host \
  --security-opt seccomp=unconfined --device=/dev/kfd --device=/dev/dri --shm-size=64g \
  -v /data:/data \
  --name flagos \
  harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist \
  /bin/bash
```

### 三、启动服务（容器内执行）

写成用户视角、可直接粘贴执行的交互式命令，**环境变量与 `vllm serve` 写在同一个块内**。

```bash
source /opt/dtk/env.sh
export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export TRITON_HIP_CLANG_PATH=/opt/dtk-26.04-DCC2602-0317/aillvm/bin/clang-18
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
export FLAGGEMS_DB_URL=sqlite:///:memory:
vllm serve /models/flagrelease/fixes_models/Phi-3-medium-128k-instruct \
  --served-model-name Phi-3-medium-128k-instruct \
  --dtype bfloat16 \
  --tensor-parallel-size 2 \
  --max-model-len 131072 \
  --gpu-memory-utilization 0.90 \
  --port 8000 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code
```

> 上面三个块都是**范例**，照写法填自己的值，不是固定模板。

### 几条硬要求

- 环境变量一个都不能省（flagos 开关、编译路径、超时、黑白名单），需要 `source` 的写在启动块第一行
- 路径写容器内真实路径、端口写实际端口（发布工具会改写为 `/data/{仓库名}` 和 8000）
- 不要写运维尾巴（`2>&1`、`| tee`、`> 文件`、`nohup`、行尾 `&`）；不要写 `mkdir -p`、`model_name=`、设备号
- 命令块内不要出现中文
- 元信息格式严格是 `# KEY: value`
- `VERDICT` 必须显式写，不能只在「## 结果」正文里说「达标」

