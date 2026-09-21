# SuperNova-Medius guarded evaluator 完整留档

## 来源与用途

来源于本机 `/Users/baai3333/Desktop/flagos/auto-day0/scripts/evalscope_guarded_gpqa.py`。脚本限制生成窗口、识别 API error/非 stop 结果、备份并按索引删除异常缓存、局部重试，最后强制审计 198 题索引完整性。

## 复现方式

将代码块保存为 `evalscope_guarded_gpqa.py`。传入只包含 `gpqa_diamond` 的 EvalScope YAML、独立工作目录和 `--max-tokens 4096`；已有目录续跑必须显式加 `--resume`。

## 完整代码

```python
#!/usr/bin/env python3
"""Run an isolated GPQA evaluation with a bounded generation window."""

import argparse
import json
import shutil
from pathlib import Path


def configured_task(config_path: Path, work_dir: Path, max_tokens: int, resume: bool = False) -> dict:
    import yaml

    config = yaml.safe_load(config_path.read_text(encoding="utf-8"))
    if not isinstance(config, dict) or config.get("datasets") != ["gpqa_diamond"]:
        raise ValueError("Expected a single GPQA Diamond EvalScope task config")
    if max_tokens < 1:
        raise ValueError("max_tokens must be positive")
    if work_dir.exists() and not resume:
        raise FileExistsError(f"Refusing to overwrite an existing evaluation: {work_dir}")
    if resume and not work_dir.is_dir():
        raise FileNotFoundError(f"Resume directory does not exist: {work_dir}")

    config["work_dir"] = str(work_dir)
    config["no_timestamp"] = True
    config["use_cache"] = str(work_dir) if resume else None
    config["generation_config"]["max_tokens"] = max_tokens
    return config


def _jsonl(path: Path) -> list[dict]:
    if not path.is_file():
        raise FileNotFoundError(path)
    with path.open(encoding="utf-8") as file:
        return [json.loads(line) for line in file if line.strip()]


def invalid_generations(work_dir: Path, model_id: str) -> tuple[list[int], list[tuple[int, str]]]:
    name = "gpqa_diamond_default.jsonl"
    predictions = _jsonl(work_dir / "predictions" / model_id / name)
    errors = []
    truncated = []
    for row in predictions:
        result = row["model_output"]
        index = row["index"]
        if result.get("error") or not result.get("choices"):
            errors.append(index)
            continue
        reason = result["choices"][0].get("stop_reason")
        if reason != "stop":
            truncated.append((index, reason))
    return errors, truncated


def _rewrite_without_indexes(path: Path, indexes: set[int]) -> None:
    rows = [row for row in _jsonl(path) if row["index"] not in indexes]
    attempt = 1
    while True:
        backup = path.with_suffix(path.suffix + f".before-retry-{attempt}")
        if not backup.exists():
            break
        attempt += 1
    shutil.copy2(path, backup)

    replacement = path.with_suffix(path.suffix + ".rewrite-tmp")
    replacement.write_text(
        "".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows),
        encoding="utf-8",
    )
    replacement.replace(path)


def prepare_retry(work_dir: Path, model_id: str, indexes: set[int]) -> None:
    """Remove only invalid cached samples so EvalScope can resume the rest."""
    name = "gpqa_diamond_default.jsonl"
    for kind in ("predictions", "reviews"):
        path = work_dir / kind / model_id / name
        if path.exists():
            _rewrite_without_indexes(path, indexes)


def audit(work_dir: Path, model_id: str, expected: int) -> dict:
    name = "gpqa_diamond_default.jsonl"
    reviews = _jsonl(work_dir / "reviews" / model_id / name)
    predictions = _jsonl(work_dir / "predictions" / model_id / name)
    review_ids = [r["index"] for r in reviews]
    prediction_ids = [p["index"] for p in predictions]
    indexes = set(range(expected))
    if (len(reviews) != expected or len(predictions) != expected
            or len(set(review_ids)) != expected or len(set(prediction_ids)) != expected
            or set(review_ids) != indexes or set(prediction_ids) != indexes):
        raise ValueError(
            f"Incomplete evaluation: reviews={len(reviews)} predictions={len(predictions)} "
            f"missing_reviews={sorted(indexes - set(review_ids))} "
            f"missing_predictions={sorted(indexes - set(prediction_ids))}"
        )

    output_tokens = []
    errors, truncated = invalid_generations(work_dir, model_id)
    for row in predictions:
        result = row["model_output"]
        if result.get("error") or not result.get("choices"):
            continue
        output_tokens.append((result.get("usage") or {}).get("output_tokens") or 0)
    if errors or truncated:
        raise ValueError(f"Invalid generation: api_errors={errors} non_stop={truncated}")

    correct = sum(float(r["sample_score"]["score"]["value"]["acc"]) for r in reviews)
    return {
        "complete": True,
        "questions": expected,
        "correct_raw": correct,
        "accuracy_raw_pct": round(100 * correct / expected, 3),
        "max_output_tokens": max(output_tokens),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--task-config", type=Path, required=True)
    parser.add_argument("--work-dir", type=Path, required=True)
    parser.add_argument("--max-tokens", type=int, required=True)
    parser.add_argument("--expected", type=int, default=198)
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--retry-invalid", type=int, default=2,
                        help="Retry API errors or non-stop generations using EvalScope cache")
    args = parser.parse_args()
    config = configured_task(args.task_config, args.work_dir, args.max_tokens, args.resume)
    print(json.dumps({
        "work_dir": config["work_dir"],
        "use_cache": config["use_cache"],
        "generation_config": config["generation_config"],
    }), flush=True)

    from evalscope.run import run_task

    run_task(config)
    for attempt in range(1, args.retry_invalid + 1):
        errors, truncated = invalid_generations(args.work_dir, config["model_id"])
        indexes = set(errors) | {index for index, _ in truncated}
        if not indexes:
            break
        print(json.dumps({
            "retry_attempt": attempt,
            "indexes": sorted(indexes),
            "api_errors": errors,
            "non_stop": truncated,
        }), flush=True)
        prepare_retry(args.work_dir, config["model_id"], indexes)
        retry_config = dict(config)
        retry_config["use_cache"] = str(args.work_dir)
        run_task(retry_config)
    print(json.dumps(audit(args.work_dir, config["model_id"], args.expected)), flush=True)


if __name__ == "__main__":
    main()
```
