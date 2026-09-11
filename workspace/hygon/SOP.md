# 海光 Hygon 迁移修复 SOP

完整流程：**宿主机 → 镜像 → 起容器 → 下模型 → 起 vLLM → 评测**。
真实环境值见 [[ENV]]（本目录），命令模板在 `_shared/templates/`，达标口径见 `_shared/EVAL.md`，踩坑经验见 `_shared/KNOWLEDGE.md`。

---

## 0. 前置

- 硬件：DCU BW1000 × 8（ROCm 生态）。32B 模型用 TP=8。
- 登录宿主机：`ssh <host-ip>`（账号见 ENV）。
- 确认驱动：`rocm-smi` 能看到 8 张卡。

## 1. 起容器

用 `_shared/templates/01_start_container.sh`，`VENDOR=hygon`，透传 `/dev/kfd /dev/dri` 且需放开 seccomp：

```bash
docker run -itd --name <模型名>_flagos \
  --device=/dev/kfd --device=/dev/dri \
  --security-opt seccomp=unconfined --group-add video \
  --ipc=host --network=host \
  -v <模型目录>:/models -v <workspace>:/flagos-workspace \
  <hygon flagos 镜像:tag> bash
docker exec -it <模型名>_flagos bash
# ⚠ 海光第一件事：验证 vLLM 编译扩展是否齐全（Light-R1-7B-DS 就栽在这里）
rocm-smi
python -c "import vllm; print(vllm.__version__)"
# 若报 vllm._rocm_C / vllm._C / libhydmi.so 找不到 → 该镜像不可用，换镜像。见 KNOWLEDGE 一。
```

## 2. 下模型

```bash
modelscope download --model <权重来源，如 Qwen/Qwen2.5-7B-Instruct> \
  --local_dir /models/<模型名>
ls /models/<模型名>   # 确认 config.json / *.safetensors / tokenizer
```

## 3. 起 vLLM 服务

`_shared/templates/03_serve_vllm.sh`。**先确认 `import vllm` 通过（第 1 步），再起服务；先 V1 裸服务，再逐级开组件。**

```bash
VLLM_USE_FLAGGEMS=0 vllm serve /models/<模型名> \
  --served-model-name <模型名> \
  --tensor-parallel-size 8 \
  --port 8000 --dtype bfloat16 \
  --max-model-len <32768，128k 模型按显存下调> \
  --gpu-memory-utilization 0.90 --trust-remote-code \
  2>&1 | tee /flagos-workspace/serve_<模型名>.log
```

- 日志 `Application startup complete` 即就绪。
- **`import vllm` 失败 / 缺 .so** → 换镜像，见 [[KNOWLEDGE]] 一（海光高频坑）。
- **plugin-FL 报错**（Magistral/Mistral/sarvam 都遇到）→ 设 `VLLM_PLUGIN_FL_LOGLEVEL=DEBUG` 看完整栈，对应算子加黑名单，见 KNOWLEDGE 四。
- V1 能起后逐级开 FlagGems(V2)→plugin(V3)。

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

- **精度不达标**：先看是否全关算子仍退化——若是，属 plugin 框架级退化（sarvam-m 结论），上报框架 bug；否则二分法缩白名单定位退化算子。见 KNOWLEDGE 二。
- 小样本（50 题）绝对差 ≤2 题仍判达标。

## 5. 记录

每修一个模型在 `hygon/fixes/<模型名>.md` 留档，规律提炼进 `_shared/KNOWLEDGE.md`。

---

## 单模型修复日志模板（复制到 fixes/<模型名>.md）

```markdown
# hygon/<模型名> 修复日志

- **失败报告**：release_迁移失败报告/hygon/FAILED_Hygon_<...>.md
- **原始失败类型**：服务启动失败 / 精度不达标 / 性能不达标 / plugin报错
- **日期**：

## 现象
（贴关键日志 / 评测分数）

## 定位
（是否缺 .so 编译扩展 / V1V2V3 哪层 / 涉及算子名）

## 处置
（换镜像 / 关算子 / 调参 / 上报框架）

## 结果
- V1 基线分：
- 修复后分 / NV 基线：
- 达标判定（accuracy_compare 退出码）：

## 提炼到 KNOWLEDGE 的条目
（一句话规律，若无则写"无新规律"）
```
