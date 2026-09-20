# 模型迁移修复工作区

FlagOS 模型迁移失败后的**手动修复**工作区：给国产芯片厂商提供标准迁移 SOP、可复用命令模板，并沉淀每个模型的修复日志与跨模型经验。

> 服务对象：海光(Hygon) / 沐曦(Metax) / 天数(Iluvatar) / 摩尔线程(Mthreads) 四平台上迁移失败的模型。
> 失败报告见上级目录 `flagrelease_fail_reports/`，评测脚本见 `flagrelease_eval_methods/`。

---

## 目录结构

```
workspace/
├── README.md                  ← 本文件，工作区总入口
├── _shared/                   ← 跨厂商共用
│   ├── KNOWLEDGE.md           ← 滚动经验库（按失败类型分类，跨模型复用）
│   ├── EVAL.md                ← 评测统一说明（各厂商共用同一套 fast_gpqa 流程）
│   └── templates/             ← 可复用命令模板（占位符填空即用）
│       ├── 01_start_container.sh
│       ├── 02_download_model.sh
│       ├── 03_serve_vllm.sh
│       └── 04_run_eval.sh
├── metax/                     ← 沐曦
│   ├── SOP.md                 ← 迁移+修复标准流程
│   ├── ENV.md                 ← 环境信息表（已知值+待填占位符）
│   ├── STATUS.md              ← 进度总览
│   └── fixes/                 ← 每模型一份修复日志
├── mthreads/                  ← 摩尔线程（结构同 metax）
├── hygon/                     ← 海光（结构同上）
└── iluvatar/                  ← 天数（结构同上）
```

## 平台名映射

| 报告/中文名 | 目录名 | 芯片 | 查卡命令 | 卡可见性变量 |
|-------------|--------|------|----------|--------------|
| 海光(Hygon) | `hygon` | DCU BW1000 | `hy-smi` | `HIP_VISIBLE_DEVICES` |
| 沐曦(Metax) | `metax` | MetaX C550 | `mx-smi` | `CUDA_VISIBLE_DEVICES` |
| 天数(Iluvatar) | `iluvatar` | BI-V150 | `ixsmi` | `CUDA_VISIBLE_DEVICES` |
| 摩尔线程(Mthreads) | `mthreads` | MTT S5000（MUSA） | `mthreads-gmi` | `MUSA_VISIBLE_DEVICES` |

---

## 修复一个模型的标准动作

1. **读失败报告**：`flagrelease_fail_reports/<厂商>/FAILED_*.md`，看 `结论` 与 `提交到 flagos 仓库的 Issue`，确定失败类型（服务崩溃 / 精度 / 性能 / 插件报错 / 流程中断）。
2. **查经验库**：`_shared/KNOWLEDGE.md` 里是否已有同类失败的处置经验。
3. **按 SOP 执行**：进 `<厂商>/SOP.md`，用 `<厂商>/ENV.md` 的真实值替换 `_shared/templates/` 里的占位符，起容器 → 下模型 → 起 vLLM → 评测。
4. **记修复日志**：在 `<厂商>/fixes/<模型名>.md` 记录现象、根因、尝试、结论（模板见 SOP 末尾，或直接复制 `fixes/_TEMPLATE.md`）。
5. **沉淀经验**：修完若发现可复用规律，回写 `_shared/KNOWLEDGE.md`。

## 记录约定

- **每模型一份日志**（`fixes/<模型>.md`）：过程性、可回溯，一个模型一个文件。
- **一份滚动经验库**（`_shared/KNOWLEDGE.md`）：结论性、跨模型，按失败类型累积可复用规律。
- **一份厂商进度表**（`<厂商>/STATUS.md`）：该厂商失败模型的清单、当前得分与下一步（metax / iluvatar / mthreads 已有）。
- 三者配合：修日志时随手把通用教训提炼进经验库，并把状态同步回进度表。

## 占位符约定

模板与 ENV 表中，`<...>` 为**待你填写**的真实值（宿主机 IP、镜像 tag、模型下载地址等失败报告未提供的信息）。
已从失败报告中提取的真实值（GPU、框架版本等）已直接写入各 `ENV.md`，无需再填。
