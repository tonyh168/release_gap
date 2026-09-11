# 天数 Iluvatar 迁移修复 SOP

完整流程：**宿主机 → 镜像 → 起容器 → 下模型 → 起 vLLM → 评测**。
真实环境值见 [[ENV]]（本目录），命令模板在 `_shared/templates/`，达标口径见 `_shared/EVAL.md`，踩坑经验见 `_shared/KNOWLEDGE.md`。

---

## 0. 前置

- 硬件：BI-V150 × 16。单卡算力偏弱、卡多，TP 可开大（32B 可 TP=8 或更高）。
- 登录宿主机：`ssh <host-ip>`（账号见 ENV）。
- 确认驱动：`ixsmi` 能看到 16 张卡。

## 1. 起容器

用 `_shared/templates/01_start_container.sh`，`VENDOR=iluvatar`，透传 `/dev/iluvatar`：

```bash
docker run -itd --name <模型名>_flagos \
  --device=/dev/iluvatar \
  --ipc=host --network=host \
  -v <模型目录>:/models -v <workspace>:/flagos-workspace \
  <iluvatar flagos 镜像:tag> bash
docker exec -it <模型名>_flagos bash
ixsmi
python -c "import vllm; print(vllm.__version__)"   # 应为 0.20.2
```

## 2. 下模型

```bash
modelscope download --model <权重来源，如 Qwen/QwQ-32B> \
  --local_dir /models/<模型名>
ls /models/<模型名>   # 确认 config.json / *.safetensors / tokenizer
```

## 3. 起 vLLM 服务

`_shared/templates/03_serve_vllm.sh`。**先 V1 裸服务确认能起，再逐级开组件。**

```bash
VLLM_USE_FLAGGEMS=0 vllm serve /models/<模型名> \
  --served-model-name <模型名> \
  --tensor-parallel-size 8 \
  --port 8000 --dtype bfloat16 \
  --max-model-len <32768，thinking 模型建议放大到 20000+ 输出预算> \
  --gpu-memory-utilization 0.90 --trust-remote-code \
  2>&1 | tee /flagos-workspace/serve_<模型名>.log
```

- **服务启动失败**（QwQ/TinyR1/Phi-3-medium/MiroThinker 都栽在这）→ 抓栈定位缺实现的算子，先关 FlagGems 跑通 V1，再逐步开算子白名单。见 [[KNOWLEDGE]] 一。
- 大模型崩溃优先加大 TP（本平台 16 卡资源足）降单卡压力。

## 4. 评测判定

```bash
cd <release_评测标准 路径>
pip install -q 'evalscope==1.5.1' requests pyyaml
python3 fast_gpqa.py --model-name <模型名> \
  --api-base http://localhost:8000/v1 \
  --output /flagos-workspace/eval_out/<模型名>/gpqa.json
python3 accuracy_compare.py \
  --v2 /flagos-workspace/eval_out/<模型名>/gpqa.json \
  --nv-baseline <NV基线表中的模型名> \
  --nv-baseline-file nv_baseline.yaml --json \
  --output /flagos-workspace/eval_out/<模型名>/verdict.json
```

- **评测中途中断**（OpenThinker-7B 跑到 mmlu 145/1140 停）→ 先 `--limit 20` 小样本验稳定，查 serve 日志有无 OOM/CUDA error，再跑全量。见 KNOWLEDGE 五。
- thinking 模型（QwQ 等）50 题可能 6h+，勿中断。

## 5. 记录

每修一个模型在 `iluvatar/fixes/<模型名>.md` 留档，规律提炼进 `_shared/KNOWLEDGE.md`。

> 注：0910 CSV 列本厂商 48 个失败模型，zip 仅 8 份报告。修无报告的模型时，先补取报告或按同类失败类型套用本 SOP。

---

## 单模型修复日志模板（复制到 fixes/<模型名>.md）

```markdown
# iluvatar/<模型名> 修复日志

- **失败报告**：release_迁移失败报告/iluvatar/FAILED_Iluvatar_<...>.md（无则注明）
- **原始失败类型**：服务启动失败 / 精度不达标 / 性能不达标 / 评测中断
- **日期**：

## 现象
（贴关键日志 / 评测分数 / 中断位置）

## 定位
（缺实现的算子名 / V1V2V3 哪层 / 是否 OOM）

## 处置
（关算子 / 调 TP / 调参 / 上报）

## 结果
- V1 基线分：
- 修复后分 / NV 基线：
- 达标判定（accuracy_compare 退出码）：

## 提炼到 KNOWLEDGE 的条目
（一句话规律，若无则写"无新规律"）
```
