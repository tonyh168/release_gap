# mthreads/<模型名> 修复日志

- **失败报告**：flagrelease_fail_reports/Mthreads/FAILED_Mthreads_<...>.md（无则注明）
- **原始失败类型**：服务启动失败 / 精度不达标 / 性能不达标 / 评测中断 / 生成失控
- **日期**：

---

## 最终结论

| 项目 | 值 |
|------|---|
| Mthreads 最终得分（题数 / 数据集） | |
| 达标基准（NV 基线，来自 `nv_baseline.yaml`） | |
| 差值 / rel_drop | |
| 判定（`accuracy_compare` 退出码 0/1/2/3） | |

**核心修复**：（一句话：根因 + 有效动作）

---

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `mthreads-25` / `mthreads-27` |
| 容器名 | `flagrelease-fix-<模型名>` |
| 镜像 | |
| 模型路径 | `/models/flagrelease/fixes_models/<模型名>` |
| TP / GPU / 端口 | |
| 实际 vLLM 版本 | |

## 现象

（贴关键日志 / 评测分数 / 中断位置；runaway、truncation 等红旗字段一并记下）

## 定位

（缺 dtype 导入崩溃 / crash 算子名 / 精度退化算子 / OOM / runaway / 采样参数被忽略 / 非模型问题）

## 处置

（换镜像 / 开关算子 / 调 TP / 固定 max-tokens 与并发 / 补 context.yaml / 上报 issue）

## 结果

- 修复后分 / NV 基线：
- 达标判定（accuracy_compare 退出码）：

## 提炼到 KNOWLEDGE 的条目

（一句话规律，若无则写"无新规律"）
