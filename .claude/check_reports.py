#!/usr/bin/env python3
"""校验 workspace/*/reports/*_report.md 是否符合 workspace/report_template.md 的发布字段规范。

要点：
- 只检查「## 发布字段」里的命令块（正文与证据块不属于「命令块」）。
- 「二、容器创建」允许 `--device=`（模板范例本身就有）；「三、启动服务」不得出现设备号。
- 代码块内不得出现中文（`# KEY: value` 注释行除外，但 KEY 行本身也不该有中文）。
- 可选的第四块「### 四、开启算子列表」只放裸 JSON 字符串数组，
  且不计入「块三」的 `vllm serve` 判定。

用法: python3 .claude/check_reports.py
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1] / "workspace"
REQUIRED_KEYS = ["MODEL_SOURCE", "IMAGE", "VERDICT", "METRIC", "SCORE_ORIGIN", "SCORE_FLAGOS"]
OPTIONAL_KEYS = ["HARBOR_VER", "GPU", "TP", "CONTAINER_DEVS"]
SECTIONS = ["## 现象", "## 定位", "## 处置", "## 结果", "## 提炼到 KNOWLEDGE 的条目", "## 发布字段"]
SUBS = ["### 一、发布信息", "### 二、容器创建（宿主机执行）", "### 三、启动服务（容器内执行）"]
OPT_BLOCK = "### 四、开启算子列表"
BANNED = [r"2>&1", r"\|\s*tee\b", r"\bnohup\b", r"mkdir\s+-p", r"\bmodel_name\s*=", r">\s*\S+\.(log|json|txt)"]
DEVICE_VARS = r"\b(CUDA|HIP|XPU|MACA|ASCEND|PPU)_VISIBLE_DEVICES\s*="
CJK = re.compile(r"[一-鿿　-〿＀-￯]")
PUB_HEADING = re.compile(r"^## 发布字段\s*$", re.M)


def fenced(text):
    return [m.group(1) for m in re.finditer(r"```[a-z]*\n(.*?)```", text, re.S)]


def main():
    problems = []
    files = sorted(ROOT.glob("*/reports/*_report.md"))
    if not files:
        print("no reports found")
        return 1
    for p in files:
        rel = str(p.relative_to(ROOT))
        text = p.read_text(encoding="utf-8")

        # 章节
        pos = [(s, text.find(s)) for s in SECTIONS]
        for s, i in pos:
            if i < 0:
                problems.append(f"{rel}: 缺章节 {s}")
        heads = PUB_HEADING.findall(text)
        if len(heads) != 1:
            problems.append(f"{rel}: `## 发布字段` 标题出现 {len(heads)} 次（应为 1）")
        found = [(s, i) for s, i in pos if i >= 0]
        if found != sorted(found, key=lambda x: x[1]):
            problems.append(f"{rel}: 章节顺序不符模板")

        m = PUB_HEADING.search(text)
        if not m:
            continue
        pub = text[m.start():]
        at = [pub.find(s) for s in SUBS]
        for s, i in zip(SUBS, at):
            if i < 0:
                problems.append(f"{rel}: 发布字段缺 {s}")
        if any(i < 0 for i in at):
            continue
        # 第四块可选；块三必须止于第四块之前，否则第四块的 JSON 会被当成"块三缺 vllm serve"
        at4 = pub.find(OPT_BLOCK)
        sec1, sec2 = pub[:at[1]], pub[at[1]:at[2]]
        if at4 > at[2]:
            sec3, sec4 = pub[at[2]:at4], pub[at4:]
        else:
            sec3, sec4 = pub[at[2]:], ""

        # 元信息 KEY
        for k in REQUIRED_KEYS:
            if not re.search(rf"^# {k}: .+$", sec1, re.M):
                problems.append(f"{rel}: 缺必填元信息 `# {k}:`")
        for k in OPTIONAL_KEYS:
            mm = re.search(rf"^# {k}: (.+)$", sec1, re.M)
            if mm and mm.group(1).strip() in {"<待补>", "<TBD>", "-", "N/A", ""}:
                problems.append(f"{rel}: 选填 {k} 填了占位符 `{mm.group(1).strip()}`（无值应整行删除）")
        for line in sec1.splitlines():
            if line.startswith("# ") and ":" not in line:
                problems.append(f"{rel}: 元信息行不是 `# KEY: value` 形式 -> {line[:60]}")

        # 命令块
        for label, sec in (("二", sec2), ("三", sec3)):
            for body in fenced(sec):
                for pat in BANNED:
                    if re.search(pat, body):
                        problems.append(f"{rel}: 块{label}含被禁写法 {pat}")
                if label == "三" and re.search(DEVICE_VARS, body):
                    problems.append(f"{rel}: 块三含设备号变量")
                for line in body.splitlines():
                    if CJK.search(line):
                        problems.append(f"{rel}: 块{label}含中文 -> {line.strip()[:60]}")
        for body in fenced(sec3):
            if "vllm serve" not in body:
                problems.append(f"{rel}: 块三未见 vllm serve")

        # 第四块（可选）：只能是裸 JSON 字符串数组
        if sec4:
            bodies = fenced(sec4)
            if not bodies:
                problems.append(f"{rel}: 第四块未见代码块")
            for body in bodies:
                if re.search(r'"include"\s*:', body):
                    problems.append(f"{rel}: 第四块不应带 `\"include\":` 前缀")
                if "替换算子数" in body:
                    problems.append(f"{rel}: 第四块不应写「替换算子数」")
                if CJK.search(body):
                    problems.append(f"{rel}: 第四块含中文")
                try:
                    ops = json.loads(body)
                except Exception as e:
                    problems.append(f"{rel}: 第四块不是合法 JSON（{e}）")
                    continue
                if not isinstance(ops, list) or not all(isinstance(x, str) for x in ops):
                    problems.append(f"{rel}: 第四块应为 JSON 字符串数组")
                elif len(set(ops)) != len(ops):
                    problems.append(f"{rel}: 第四块有重复算子名")

    print(f"检查 {len(files)} 份报告")
    if problems:
        print(f"\n发现 {len(problems)} 个问题：")
        for x in problems:
            print(" -", x)
        return 1
    print("全部通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
