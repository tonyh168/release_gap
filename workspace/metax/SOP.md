# 沐曦 Metax 迁移修复 SOP

完整流程：**宿主机 → 镜像 → 起容器 → 下模型 → 起 vLLM → 评测**。
真实环境值见 [[ENV]]（本目录），命令模板在 `_shared/templates/`，达标口径见 `_shared/EVAL.md`，踩坑经验见 `_shared/KNOWLEDGE.md`。

---

## 0. 前置

- 硬件：MetaX C550 × 8（单卡 ~63.6GB）。32B 模型用 TP=8。
- 登录宿主机：`ssh <host-ip>`（账号见 ENV）。
- 确认驱动：`mx-smi` 能看到 8 张卡。

## 1. 起容器

用 `_shared/templates/01_start_container.sh`，`VENDOR=metax`，透传设备 `/dev/dri /dev/mxcd`：

```bash
docker run -itd --name <模型名>_flagos \
  --device=/dev/dri --device=/dev/mxcd \
  --ipc=host --network=host \
  -v <模型目录>:/models -v <workspace>:/flagos-workspace \
  <metax flagos 镜像:tag> bash
docker exec -it <模型名>_flagos bash
# 容器内自检
mx-smi
python -c "import vllm; print(vllm.__version__)"   # 应为 0.20.2
```

## 2. 下模型

`_shared/templates/02_download_model.sh`，默认 ModelScope：

```bash
modelscope download --model <权重来源，如 LGAI-EXAONE/EXAONE-4.0-32B> \
  --local_dir /models/<模型名>
ls /models/<模型名>   # 确认 config.json / *.safetensors / tokenizer
```

## 3. 起 vLLM 服务

`_shared/templates/03_serve_vllm.sh`。**修复策略：先起 V1 裸服务确认能跑，再逐级开组件。**

```bash
# V1 基线：关掉 FlagGems，验证裸 vLLM 是否能起
VLLM_USE_FLAGGEMS=0 vllm serve /models/<模型名> \
  --served-model-name <模型名> \
  --tensor-parallel-size 8 \
  --port 8000 --dtype bfloat16 \
  --max-model-len <32768，长上下文按显存下调> \
  --gpu-memory-utilization 0.90 --trust-remote-code \
  2>&1 | tee /flagos-workspace/serve_<模型名>.log
```

- 日志出现 `Application startup complete` 即就绪，新终端 `curl http://localhost:8000/v1/models` 自检。
- **起不来（core dump / OOM）** → 见 [[KNOWLEDGE]] 一。抓栈定位算子；OOM 则降 `--max-model-len`、确认 TP=8。
- V1 能起后，去掉 `VLLM_USE_FLAGGEMS=0` 开 V2（FlagGems），再加 plugin 到 V3，逐级定位崩溃/精度退化来自哪一层。

## 4. 评测判定

`_shared/templates/04_run_eval.sh`。对已起的服务跑 GPQA 并判 5% 退化：

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
# 退出码 0=达标 1=不达标 3=NV表无此模型(改两轮对比)
```

- thinking 模型（EXAONE/QwQ 类）单题输出长，50 题可能数小时，勿中断。
- `truncation_detected:true` → 加大 `--max-model-len` 重跑。

## 5. 记录

每修一个模型，在 `metax/fixes/<模型名>.md` 按下方模板留档，并把可复用规律提炼进 `_shared/KNOWLEDGE.md`。

---

## 单模型修复日志模板（复制到 fixes/<模型名>.md）

```markdown
# metax/<模型名> 修复日志

- **失败报告**：release_迁移失败报告/metax/FAILED_Metax_<...>.md
- **原始失败类型**：服务启动失败 / 精度不达标 / 性能不达标 / plugin报错
- **日期**：

## 现象
（贴关键日志 / 评测分数）

## 定位
（V1/V2/V3 哪一层引入问题，涉及算子名）

## 处置
（改了什么：关算子 / 换镜像 / 调参）

## 结果
- V1 基线分：
- 修复后分 / NV 基线：
- 达标判定（accuracy_compare 退出码）：

## 提炼到 KNOWLEDGE 的条目
（一句话规律，若无则写"无新规律"）
```
