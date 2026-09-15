# FlagOS 迁移修复 Handoff — 2026-09-15

## 当前状态

分支：`metax-fix-0914-2`
节点：`metax-60`（8× MetaX C550，单卡 ~63.6GB）

---

## 已完成的模型（metax）

### ✅ SOLAR-10.7B-Instruct-v1.0
- GPQA 34%，NV 基线 38.5%，rel_drop 11.76%，绝对差 2 题
- noise_zone 达标
- fix 日志：`workspace/metax/fixes/SOLAR-10.7B-Instruct-v1.0.md`

### ✅ Qwen3-Coder-30B-A3B-Instruct
- GPQA 50%（thinking 模式），NV 基线 54%，绝对差 2.0 题，noise_zone 达标
- TP=4（GPU 2,3,4,5），port=8002，评测容器：Phi-3-mini-eval
- 逐题对错数据无法恢复（evalscope 输出在 Phi-3-mini-eval 本地 FS，未挂共享盘）
- fix 日志：`workspace/metax/fixes/Qwen3-Coder-30B-A3B-Instruct.md`

### ✅ GLM-4-32B-0414
- GPQA 52%（standard 模式），NV 基线 55%，绝对差 1.5 题，noise_zone 达标
- TP=2（GPU 0,1），port=8003，plugin-FL 默认黑名单，一次启动成功
- 逐题对错：正确 26 题（doc_id: 0 1 2 4 5 7 11 12 13 14 16 17 18 19 23 26 31 32 35 37 38 39 41 46 47 48）
- fix 日志：`workspace/metax/fixes/GLM-4-32B-0414.md`

### ✅ EXAONE-4.0-32B
- GPQA 58%（standard 模式），NV 基线 62%，绝对差 2.0 题，noise_zone 达标
- TP=4（GPU 0,1,2,3），port=8000，plugin-FL 默认黑名单，一次启动成功
- 注意：EXAONE 输出以 `Answer: X`（首字母大写）结尾，自行解析须用 `re.IGNORECASE`
- 逐题对错：正确 29 题（doc_id: 0 1 2 4 5 6 7 9 13 14 15 16 18 19 20 25 26 27 29 35 37 38 40 41 42 44 46 47 49）
- fix 日志：`workspace/metax/fixes/EXAONE-4.0-32B.md`

---

## 待处理的模型（metax）

### 🔄 Phi-3-mini-128k-instruct（精度不达标，定位中）
- 第1次评测（plugin-FL 默认黑名单）：GPQA 28%，NV 33%，rel_drop 15.15% → ❌ 不达标
- 下一步：关闭 plugin（裸 vLLM）跑 V1 基线，确认退化来源是 plugin 还是 vLLM 0.24.0 本身
- 重跑 36 道错题（temperature=0.8）测试偶发性的脚本已写好：`/tmp/rerun_wrong_cases.py`
- 权重：`/public-flash/models/Phi-3-mini-128k-instruct`（已在共享盘）
- fix 日志模板：`workspace/metax/fixes/Phi-3-mini-128k-instruct.md`

### ✅ Phi-3.5-mini-instruct
- GPQA 34%，NV 基线 26%，metax 超 NV 8 题，达标
- TP=1（GPU 0），port=8001，plugin-FL 默认黑名单，一次启动成功
- 注意：MHA 架构，rms_norm/silu_and_mul 在 FlagGems 下无精度问题
- doc_id 23/34 evalscope 挂起（长回答），用 eval_missing2.py 补评
- 逐题对错：正确 17 题（doc_id: 6 8 9 11 13 15 16 18 19 27 29 30 31 36 38 45 49）
- fix 日志：`workspace/metax/fixes/Phi-3.5-mini-instruct.md`

### ✅ Phi-4-mini-instruct
- GPQA 44%，NV 基线 38%，metax 超 NV 6 题，达标
- TP=1（GPU 1），port=8002，扩展黑名单（默认 + rms_norm,silu_and_mul）
- 根本原因：Phi-4 是 GQA（24Q/8KV），plugin-FL 下 rms_norm/silu_and_mul 走 FlagGems，GQA 张量 shape 触发精度问题；扩展黑名单后回退 MACA 原生实现，精度恢复
- 逐题对错：正确 22 题（doc_id: 2 4 5 6 9 10 12 13 17 18 19 20 26 29 30 31 35 40 44 47 48 49）
- 注意：doc_id 2 evalscope 挂起，用 eval_missing_phi4_v3.py 补评
- fix 日志：`workspace/metax/fixes/Phi-4-mini-instruct.md`

---

## 基础设施说明

- eval-scope 容器（metax-60）：用于 GLM 和 EXAONE 的评测，evalscope 输出落共享盘 `/models/release_run_logs/`
- Phi-3-mini-eval 容器（metax-60）：用于 Qwen3-Coder 评测，evalscope 输出在容器本地 FS（未落共享盘）
- fast_gpqa.py parse bug：score 字段写成 null；从 evalscope report `metrics[0].score` 回填，用 `_score_source` 标注
- 常用黑名单：`mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice`
- `VLLM_FL_USE_FLAGGEMS_ATTN=0`：所有 metax 服务必设，使用 MetaX 原生 FA
