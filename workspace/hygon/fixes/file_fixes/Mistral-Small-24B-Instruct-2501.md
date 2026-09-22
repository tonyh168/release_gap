# Mistral-Small-24B-Instruct-2501 评测配置完整留档

## 来源与用途

该模型当时没有修改 Python 评测脚本；修改的是评测容器 `/flagos-workspace/shared/context.yaml`，让现有评测器能定位模型目录并读取 `generation_config.json`。因此本文件保存完整配置片段，不伪造 Python 修改。

## 复现方式

将 YAML 合并到评测容器的 `/flagos-workspace/shared/context.yaml`，确认 `/models/Mistral-Small-24B-Instruct-2501/generation_config.json` 存在后再运行评测。

## 完整配置

```yaml
# This model did not require a fast_gpqa.py code change.
# The evaluation container needed this complete context fragment so the
# existing evaluator could resolve the local model directory and read
# generation_config.json (temperature=0.15, do_sample=true).
model:
  container_path: /models/Mistral-Small-24B-Instruct-2501
```
