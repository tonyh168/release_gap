# iluvatar/OpenReasoning-Nemotron-1.5B 修复日志

- **失败报告**：新增模型（STATUS.md 补录，无历史失败报告）
- **原始失败类型**：未开始（后补评测对象）
- **日期**：2026-09-16 ~ 2026-09-19（iter1 ~ iter4）
- **最终结论**：❌ **不达标**（math_500 **76.0%** vs NV 84.0%，rel_drop **9.52%**；`verdict_math500_iter4.json` 实测 exit=1）
  —— ⚠️ **四项假设已全部被证伪**：权重 ✅、上下文 ✅、并发 ✅、采样 ✅、**输出截断 ✅（iter4 新增）**。
  **剩余差距 9.52% 尚无法归因，嫌疑指向算子精度。**

## 背景分析

OpenReasoning-Nemotron-1.5B 为 NVIDIA 开源推理小模型，1.5B 参数，decoder-only（Llama 架构）。
bf16 约 3 GB，单卡 32 GB 绰绰有余，TP=1。
评测指标为 mmlu + math_500（nv_baseline 无 gpqa_diamond 条目）。
NV 基线：mmlu=52.21，math_500=84.0。

## 环境

| 项目 | 值 |
|------|----|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-openreasoning-nemotron-1.5b` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/OpenReasoning-Nemotron-1.5B` |
| 卡号 | **GPU 0**（`CUDA_VISIBLE_DEVICES=0`，TP=1） |
| 端口 | 8011 |
| 实际 vLLM 版本 | 0.24.0（FlagGems 5.3.4.post1） |
| 算子黑名单 | `sort,sort_stable`（三轮未变） |

## Step 0：登录 + 查卡

```bash
ssh iluvatar-139
/usr/local/corex-4.5.0/bin/ixsmi
docker ps --format '{{.Names}}\t{{.Status}}'
```

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
model_name=openreasoning-nemotron-1.5b
docker run -itd --name flagrelease-fix-${model_name} \
  --device=/dev/iluvatar0  --device=/dev/iluvatar1  --device=/dev/iluvatar2  --device=/dev/iluvatar3 \
  --device=/dev/iluvatar4  --device=/dev/iluvatar5  --device=/dev/iluvatar6  --device=/dev/iluvatar7 \
  --device=/dev/iluvatar8  --device=/dev/iluvatar9  --device=/dev/iluvatar10 --device=/dev/iluvatar11 \
  --device=/dev/iluvatar12 --device=/dev/iluvatar13 --device=/dev/iluvatar14 --device=/dev/iluvatar15 \
  --device=/dev/itrctl --device=/dev/itrlink --device=/dev/itr_peerm_dev0 \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  ${IMAGE} bash
```

## Step 2：确认模型权重

```bash
ls /models/flagrelease/fixes_models/OpenReasoning-Nemotron-1.5B/
```

**权重来源（2026-09-18 改）**：改用 **HuggingFace 官方仓库** `nvidia/OpenReasoning-Nemotron-1.5B`
（<https://huggingface.co/nvidia/OpenReasoning-Nemotron-1.5B>）。此前用的是 ModelScope 镜像
`nv-community/OpenReasoning-Nemotron-1.5B`，因怀疑权重有问题已于 2026-09-18 删除，改从 HF 重新下载。

> 注：原失败报告写的 `nvidia/OpenReasoning-Nemotron-1.5B` 在 **ModelScope** 上是 404（ModelScope 实际为
> `nv-community/...`）；该 repo id 在 **HuggingFace** 上是正确的官方路径。两边别混。
> HF 上该仓库非 gated，许可 CC-BY-4.0（参考模型 Qwen2.5-1.5B，Apache 2.0）。

**下载路径（一律用 HF 官方 repo id，与 URL 一致）**：

| 项 | 值 |
|----|----|
| HF 页面 | <https://huggingface.co/nvidia/OpenReasoning-Nemotron-1.5B> |
| repo id | `nvidia/OpenReasoning-Nemotron-1.5B` |
| 本地目录 | `/models/flagrelease/fixes_models/OpenReasoning-Nemotron-1.5B` |

下载（在 **eval-scope 容器内**执行）：

```bash
docker exec -it eval-scope bash

# ⚠️ 本集群直连 huggingface.co 不通（curl 15s 超时），必须设镜像，否则下载必失败
export HF_ENDPOINT=https://hf-mirror.com

# 方式一：hf（huggingface_hub 1.x 的当前命令；容器内已装 1.31.0）
hf download nvidia/OpenReasoning-Nemotron-1.5B \
  --local-dir /models/flagrelease/fixes_models/OpenReasoning-Nemotron-1.5B

# 方式二：huggingface-cli（旧命令，仍可用，会提示 deprecated）
# huggingface-cli download nvidia/OpenReasoning-Nemotron-1.5B \
#   --local-dir /models/flagrelease/fixes_models/OpenReasoning-Nemotron-1.5B
```

**下载后校验**（避免再次拿到可疑权重）——文件大小应与 HF 上游一致：

| 文件 | 大小（bytes） | sha256 |
|------|--------------|--------|
| `model.safetensors` | 3087467144 | `ca014625d77d04c281d45ee8ba2ed5018dd3f2165509aa6af8882016bbb4a189` |

```bash
cd /models/flagrelease/fixes_models/OpenReasoning-Nemotron-1.5B
ls -l model.safetensors                                   # 应为 3087467144
sha256sum model.safetensors                               # 应与上表一致
```

> **2026-09-18 实测校验结果：✅ 完全一致。**
> 从 HF 重新下载后 `sha256sum` 输出 `ca014625d77d04c281d45ee8ba2ed5018dd3f2165509aa6af8882016bbb4a189`，
> 与上游一致；文件大小 3087467144 也与被删除的那份旧权重逐字节相同。
> **结论：权重不是低分的原因**，此前"权重损坏"的怀疑已排除，勿再重复换权重。

> `HF_ENDPOINT` 说明：`https://hf-mirror.com` 是国内常用的 HuggingFace 镜像站，
> 设了它之后 `hf` / `huggingface-cli` 的请求走镜像域名，**repo id 不用改**。
> 已验证：本集群 `hf-mirror.com` 可达（HTTP 307），`huggingface.co` 直连超时。

## Step 3：起 vLLM 服务

```bash
docker exec -d flagrelease-fix-openreasoning-nemotron-1.5b bash -c "
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=0
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
model_name=OpenReasoning-Nemotron-1.5B
mkdir -p /models/release_run_logs/\${model_name}
vllm serve /models/flagrelease/fixes_models/\${model_name} \
  --served-model-name \${model_name} --dtype bfloat16 \
  --tensor-parallel-size 1 --gpu-memory-utilization 0.9 \
  --max-model-len 131072 \
  --port 8011 --attention-backend TRITON_ATTN \
  --enforce-eager --trust-remote-code \
  2>&1 | tee /models/release_run_logs/\${model_name}/serve.log
"
```

> `--max-model-len 131072` 是 2026-09-18 起**显式加上**的（iter3 服务日志可见）。该模型本就支持
> 131072，并非 phi3 那种推导缺陷，加上只为消除歧义。

若 crash → 抓算子名追加黑名单：
```bash
grep -E "Error|crash|Traceback|RuntimeError|NotImplemented" \
  /models/release_run_logs/OpenReasoning-Nemotron-1.5B/serve.log | tail -20
```

| 迭代 | 黑名单 | TP | 端口 | 结果 | 备注 |
|------|--------|----|------|------|------|
| 第1次 | sort,sort_stable | 1 | 8011 | ❌ mmlu **35.0%**（NV 52.21，↓32.9%） | TRITON_ATTN；服务健康（~190 tok/s，1.5B 正常）；graph 模式 capture 在 batch 56 OOM（9/51 graphs 成功） |
| 第2次 | sort,sort_stable | 1 | 8011 | ❌ math_500 **76.5%**（NV 84.0，↓8.93%） | 换 HF 权重（sha256 已验证）后重测；并发 32 |
| 第3次 | sort,sort_stable | 1 | 8011 | ❌ math_500 **73.5%**（NV 84.0，↓12.50%） | thinking + 0.6/0.95 复评（wrapper）；**比 iter2 更低** |

## Step 4：smoke test

```bash
model_name=OpenReasoning-Nemotron-1.5B
curl -s http://localhost:8011/v1/models
curl -s http://localhost:8011/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"What is 2+2?"}],"max_tokens":64,"temperature":0}'
```

## Step 5：评测

评测指标为 mmlu + math_500（无 gpqa_diamond 基线）。

```bash
docker exec -d eval-scope bash -c "
cd /workspace/eval_scripts
model_name=OpenReasoning-Nemotron-1.5B
mkdir -p /models/release_run_logs/\${model_name}
python3 fast_gpqa.py --model-name \${model_name} \
  --api-base http://127.0.0.1:8011/v1 --dataset mmlu \
  --output /models/release_run_logs/\${model_name}/mmlu.json \
  2>&1 | tee /models/release_run_logs/\${model_name}/eval_mmlu.log
python3 fast_gpqa.py --model-name \${model_name} \
  --api-base http://127.0.0.1:8011/v1 --dataset math_500 \
  --output /models/release_run_logs/\${model_name}/math_500.json \
  2>&1 | tee /models/release_run_logs/\${model_name}/eval_math.log
"
```

compare：
```bash
docker exec eval-scope bash -c "
cd /workspace/eval_scripts
model_name=OpenReasoning-Nemotron-1.5B
python3 accuracy_compare.py \
  --v2 /models/release_run_logs/\${model_name}/mmlu.json \
  --nv-baseline \${model_name} --nv-baseline-file nv_baseline.yaml \
  --metric mmlu --json \
  --output /models/release_run_logs/\${model_name}/verdict_mmlu.json
python3 accuracy_compare.py \
  --v2 /models/release_run_logs/\${model_name}/math_500.json \
  --nv-baseline \${model_name} --nv-baseline-file nv_baseline.yaml \
  --metric math_500 --json \
  --output /models/release_run_logs/\${model_name}/verdict_math.json
"
```

| 迭代 | 模式 / 采样 | max_tokens | 并发 | mmlu | math_500 | verdict |
|------|------------|:----------:|:---:|------|----------|---------|
| 第1次 | standard (T=0.0) | 32768 | 16 | **35.0%**（1140题，NV 52.21） | 中止（容器已停） | ❌ |
| 第2次 | standard (T=0.0) | 32768 | 32 | —（未重测） | **76.5%**（200题，NV 84.0） | ❌ exit=1，rel_drop 8.93% |
| 第3次 | **thinking (T=0.6, top_p=0.95)** | **20000** | 32 | —（未重测） | **73.5%**（200题，NV 84.0） | ❌ exit=1，rel_drop 12.50% |
| **第4次** | standard (T=0.0)（**不变**） | **65536** | **16** | —（未重测） | **76.0%**（200题，NV 84.0） | ❌ exit=1，rel_drop 9.52% |

> **iter3 用的 wrapper**：`/tmp/openreason_thinking.py`（未抄进本文件，NFS 备份见 `_wrappers_backup/`）。
> **iter4 用的 wrapper**：`/tmp/openreason_maxtok.py`（NFS 备份同上），**只覆写 `cfg["max_tokens"]=65536`
> 并锁定并发 16，采样与 `detect_thinking` 均不动**。

> ⚠️ **四轮分数都未由 `fast_gpqa.py` 写出**（`detect_runaway` 对 list content 崩溃，
> `AttributeError: 'list' object has no attribute 'strip'`），分数均从 evalscope 报告
> `outputs/math_500/<ts>/reports/<model>/math_500.json` 的 `metrics[0].score` 恢复：
> iter2 `20260918_081747`、iter3 `20260918_104048`、**iter4 `20260919_063334`**。

## 现象

- iter1（sort,sort_stable，TRITON_ATTN，TP=1，GPU 0，port 8011）：
  - 服务正常启动，smoke test 通过，生成速度约 190 tok/s（1.5B，正常）。
  - MMLU 完成（1140 题），从报告恢复 **35.0%**，NV 52.21，↓32.9%。
  - math_500 未跑完即随容器停止中止。
  - graph 模式 capture 在 batch 56 时 OOM（9/51 graphs 成功）。
- iter2（换 HF 权重后，仅重测 math_500，standard 贪心，mt=32768，并发 32）：
  - **76.5%**（153/200），NV 84.0，↓8.93%。verdict exit=1。
  - 200 题中 **30 题撞 32768 输出上限，且这 30 题全部答错**。
  - **排除撞顶题后为 153/170 = 90.0%** —— 已**高于** NV 基线 84.0。
- iter3（thinking + 0.6/0.95，mt 被 thinking 公式压到 20000，并发 32）：
  - **73.5%**（147/200），比 iter2 **更低** 3pt。verdict exit=1，rel_drop 12.50%。
  - 撞顶 **26 题，同样全部答错**；**排除撞顶后 147/174 = 84.5%**。
  - runaway 由 iter2 的 23 题降到 **6 题**（采样修正确实压住了复读）。
- **iter4（只抬 max_tokens 32768 → 65536，采样不变 standard 贪心，并发 16）**：
  - **76.0%**（152/200），NV 84.0，**↓9.52%**。verdict exit=1。
  - **与 iter2 的 76.5% 实质相同**（差 1 题 = 0.5%，属噪声）。**抬上限没有带来任何提升。**
  - 撞顶题数 **30 → 29**（几乎没变），尽管上限翻倍；**新增 9 题**在 65536 处撞顶。
  - 平均输出 token **10094 → 15030（+49%）**，单次评测总 token 大幅上升 —— **多烧了约一半算力，零收益**。

## 定位

### 1. 输出截断假设：**已被 iter4 证伪**（这是本轮最重要的结论）

iter2 的分析曾指向"撞顶的题是差一点没做完"，因此预测"抬上限就能救回来"。**iter4 实测否定了这个预测**：

| 指标 | iter2（mt=**32768**） | **iter4（mt=65536）** | 变化 |
|------|:---:|:---:|:---:|
| math_500 得分 | 76.5% (153/200) | **76.0% (152/200)** | **−0.5pt（噪声）** |
| 撞 max_tokens 题数 | 30 | **29** | 几乎没变 |
| 排除撞顶后 | 90.0% (153/170) | 88.3% (151/171) | 基本持平 |
| 平均输出 tokens | 10094 | **15030** | **+49%** |
| runaway 复读题 | 23 | 27 | 略增 |

逐题追踪撞顶题的去向（决定性证据）：

```
iter2 撞顶的 30 题中：20 题在 iter4 给了 2 倍预算后【仍然撞顶】
                      10 题在 iter4 正常结束
iter4 新增撞顶（iter2 没撞顶的）：9 题
```

**即：那些撞顶题不是"差一点就写完"，而是真的停不下来的死循环 ——
给多少预算就烧多少，不会因此变对。**

> ⚠️ **由此需要修正一条早先的判读方法**：先前写的「排除撞顶题后的分数更能反映真实能力」
> **在本题上被推翻了**。90.0% 那个数字是**幸存者偏差**——排除掉的题不是"运气不好被截断"，
> 而是"本身就无法收敛"。**"排除撞顶"只适用于诊断，不能当作能力估计。**
> （该指标在 TinyR1 上成立，是因为那里的复读题在正确采样下确实收敛了；此处不成立。）

### 2. 五项假设的最终状态

| 假设 | 验证方式 | 结论 |
|------|---------|------|
| 权重损坏 | HF 重下 + sha256 与上游逐字节一致 | ❌ 排除 |
| 上下文长度 | `--max-model-len 131072` 本就正确 | ❌ 排除 |
| 并发过高 | 16→32，服务健康、KV 未打满 | ❌ 排除 |
| 采样配置 | iter3 thinking 0.6/0.95 → **反而更低** | ❌ 排除 |
| **输出截断** | **iter4 抬到 65536 → 无提升** | ❌ **本轮排除** |

**五项全部排除，剩余差距 9.52%（76.0% vs 84.0）目前无法归因。**
按排除法，嫌疑指向**算子精度**（`sort,sort_stable` 之外的算子影响了数值正确性），
但这**尚未有任何直接证据**，需要单独设计实验（如逐算子打开/关闭做精度对照）。

> **mmlu 的 35.0% 仍是更大的疑点**：MMLU 答案很短、不会被截断，
> 35.0% vs 52.21（↓32.9%）比 math_500 的差距大得多，且权重已验。
> 两项可能同源（算子精度），建议合并排查。

## 处置

- **变量排除已完成（五项穷尽）**：权重 ✅、上下文 ✅、并发 ✅、采样 ✅、**输出截断 ✅（iter4）**。
- ⬜ **下一步（建议，尚未执行）**：
  1. **查算子精度**。这是排除法剩下的唯一方向。做法：以 `sort,sort_stable` 为基础，
     按 `fast_gpqa` 的算子使用清单**逐组打开/关闭**（去掉黑名单项），观察 math_500 分数变化，
     定位到造成数值偏差的具体算子。代价高（每轮 ~5h），但这是唯一还没试过的方向。
  2. **mmlu 单独重测**。iter1 的 35.0% 是在 `--max-model-len 4096` 缺省、且未做任何采样的
     最差配置下得到的，需要一轮干净的重测才能确认它是否真的这么低。
  3. **不要**再在 `max_tokens` / 采样上投入 —— 两者都已被实测证伪。

## 结果

- **math_500**：iter4 **76.0%**（200题）— ❌ 不达标（NV 84.0，↓9.52%，`verdict_math500_iter4.json` exit=1）
- **mmlu**：iter1 **35.0%**（1140题）— ❌ 不达标（NV 52.21，↓32.9%，配置较差，建议重测）
- 达标判定：**❌ 不达标**（四项假设全部证伪，剩余差距 9.52% 待归因）

## 提炼到 KNOWLEDGE 的条目

1. **"排除撞 max_tokens 的题再看分数"这个做法有陷阱 —— 可能是幸存者偏差**。
   OpenReasoning 的 iter2 排除撞顶后达 90.0%（> 基线），看起来"瓶颈在输出预算"；
   但 iter4 把上限翻倍后**分数纹丝不动（76.5%→76.0%）**，且 30 题里有 20 题给了 2 倍预算**仍然撞顶**。
   **那些题是死循环，不是"差一点就写完"。** 该指标只能用于诊断，**不能当作能力估计**。
   （反例对照：TinyR1 上它是成立的 —— 那里复读题在正确采样下确实收敛了。**要分模型判断。**）
2. **抬 `max_tokens` 之前，先确认撞顶题"是否接近收尾"**：看撞顶题的输出尾部
   （是 `\boxed{...}` 附近被截，还是复读循环）以及**给更多预算后是否收敛**。
   本例实测：撞顶题平均烧掉 15030 tokens（上限 65536），**多烧 49% 算力换 0 收益**。
3. **排除法的结论要说"排除"，不要说"根因是最后剩的那个"**。
   OpenReasoning 五项假设全部排除后，只能得出"**剩余差距无法归因**"，
   而不是"根因是算子精度"——后者**尚无任何直接证据**。
4. **`fast_gpqa` 的 max_tokens 封顶**（standard `clamp(max_model_len-8192, 4096, 32768)`、
   thinking `clamp(…, 8192, 20000)`）会掩盖长思维链模型的真实表现，
   但**放开它不一定有用**（本例无用）—— 需先判断模型是"被截断"还是"停不下来"。
5. **切 thinking 模式的连带副作用**（同 TinyR1）：`max_tokens` 被压到 20000、
   加 `remove_until='</think>'` 过滤器 —— 做对照实验时必须计入变量。
