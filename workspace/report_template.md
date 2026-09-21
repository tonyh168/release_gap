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
> 段内代码块：**三个必需**（发布信息 / 容器创建 / 启动服务）**+ 一个可选**（开启算子列表）。

### 一、发布信息

```bash
# MODEL_SOURCE: <org/name>
# IMAGE: <完整镜像地址:tag>
# HARBOR_VER: <V1|V2|V3|V4>
# VLLM_VER: <vLLM 版本 或 ->
# PLUGIN_FL_VER: <vllm-plugin-FL 版本，必填>
# FLAGGEMS_VER: <FlagGems 版本，必填>
# FLAGTREE_VER: <FlagTree 版本，必填>
# FLAGCX_VER: <FlagCX 版本 或 ->
# GPU: <芯片型号, N × XXGB>
# TP: <张量并行数>
# VERDICT: <ok|bad|pending>
# METRIC: <GPQA_Diamond|MMLU|math_500|...>
# SCORE_ORIGIN: <基线分 或 ->
# SCORE_FLAGOS: <本平台分 或 ->
# CONTAINER_DEVS: <--device=/dev/kfd --device=/dev/dri --shm-size=64g>
```

> **`PLUGIN_FL_VER` / `FLAGGEMS_VER` / `FLAGTREE_VER` 三个必须点名**——这套配置的版本就是
> 靠它们三件套说清楚的，写不出就说明配置还没定下来，别留空。`VLLM_VER` / `FLAGCX_VER` 选填，
> 缺就写 `-`。
> **块内只能出现 `# KEY: value` 行**（空行可以）：混进分隔线（`# --- 组件版本 ---`）或写成
> 小写键时，解析端会放宽识别并告警，但请写干净；混进一行散文（如「组件版本见下」）则整块失效、
> **整个模型会被跳过**。

| 键 | 必填 | 含义 |
|----|------|------|
| `MODEL_SOURCE` | 是 | 上游权重 ID，`org/name` 形式 |
| `IMAGE` | 是 | 完整镜像地址（含 tag） |
| `HARBOR_VER` | 否 | `V1`/`V2`/`V3`/`V4` |
| `VLLM_VER` | 否 | vLLM 版本 |
| `PLUGIN_FL_VER` | **是** | vllm-plugin-FL 版本 |
| `FLAGGEMS_VER` | **是** | FlagGems 版本 |
| `FLAGTREE_VER` | **是** | FlagTree 版本 |
| `FLAGCX_VER` | 否 | FlagCX 版本（未使用则 `-`） |
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

### 四、开启算子列表（可选）

本块承载**算子白名单**，即这套配置下实际启用的算子清单。各轮迭代的名单不用都往这里放，
写最终的那一份即可，中间失败尝试的留在上面的「## 处置」里。

内容只能是**一个裸的 JSON 字符串数组**：不要 `"include":` 前缀、不要「替换算子数」、
不要注释与尾逗号、块内不出现中文。没有算子数据时**整块省略**或写 `[]`（两者等价）。

```json
[
  "add",
  "arange_start",
  "argmax",
  "copy_",
  "cos",
  "expand",
  "full",
  "index",
  "linear",
  "lt_scalar",
  "mm_out",
  "ones",
  "rand_like",
  "reciprocal",
  "scatter_",
  "sin",
  "softmax",
  "softmax_out",
  "sub",
  "to_copy",
  "true_divide",
  "true_divide_",
  "where_self",
  "where_self_out",
  "zero_",
  "zeros"
]
```

> 上面是范例，照写法填自己的值，不是固定模板。

### 几条硬要求

- 环境变量一个都不能省（flagos 开关、编译路径、超时、黑白名单），需要 `source` 的写在启动块第一行
- 路径写容器内真实路径、端口写实际端口（发布工具会改写为 `/data/{仓库名}` 和 8000）
- 不要写运维尾巴（`2>&1`、`| tee`、`> 文件`、`nohup`、行尾 `&`）；不要写 `mkdir -p`、`model_name=`、设备号
- 命令块内不要出现中文
- 元信息格式严格是 `# KEY: value`；**「一、发布信息」块里除了 `# KEY: value` 行不能有别的内容**
  （空行除外）——混进分隔线或小写键还能被放宽识别救回，混进散文则整块失效、整个模型会被跳过
- 第四块标题用**三个 `#`**（`### 四、开启算子列表`），写成 `##` 会把段落切断、算子块被丢掉
- 第四块只放裸 JSON 数组；将来若真要区分版本，改成带键对象，不要并列放第二个数组
- `FLAGGEMS_VER`、`FLAGTREE_VER`、`PLUGIN_FL_VER` **三个组件版本必须点名**，一个都不能少
- `VERDICT` 必须显式写，不能只在「## 结果」正文里说「达标」

