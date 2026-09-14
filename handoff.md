# FlagOS 迁移修复 Handoff — 2026-09-14

## 当前状态

分支：`metax-fix-0914`（已推送到 origin）
节点：`metax-60`（8× MetaX C550，单卡 ~63.6GB）
当前所有容器已停止，GPU 全部空闲。

---

## 已完成的模型（metax）

### ✅ SOLAR-10.7B-Instruct-v1.0
- GPQA 34%，NV 基线 38.5%，rel_drop 11.76%，绝对差 2 题
- 结论：noise zone，达标
- verdict.json：`/models/release_run_logs/SOLAR-10.7B-Instruct-v1.0/verdict.json`

### ✅ Qwen3-Coder-30B-A3B-Instruct
- GPQA 50%，NV 基线 54%，rel_drop 7.41%，绝对差 2 题
- 服务正常启动（TP=4，端口 8002），MLA prefill 路径验证通过
- evalscope 1.11.1 score 字段 null bug 已修复（commit 5b70c34）
- verdict.json：`/models/release_run_logs/Qwen3-Coder-30B-A3B-Instruct/verdict.json`

---

## 进行中 / 待上机的模型（metax）

### 🔄 Phi-3-mini-128k-instruct（精度未达标，定位中）
- 第1次评测（plugin-FL 默认黑名单）：GPQA 28%，NV 33%，rel_drop 15.15% → ❌ 不达标
- 下一步：关闭 plugin（裸 vLLM）跑 V1 基线，确认退化来源是 plugin 还是 vLLM 0.24.0 本身
- 重跑 36 道错题（temperature=0.8）测试偶发性的脚本已写好：`/tmp/rerun_wrong_cases.py`
- 权重：`/public-flash/models/Phi-3-mini-128k-instruct`（已在共享盘）

### 📋 Phi-4-mini-instruct（尚未上机）
- 原报告：V3 GPQA 28% vs NV 38%，rel_drop 26.3% + plugin-FL dispatch/vllm_fl 报错
- 修复方案：先裸 vLLM V1 基线，再二分法黑名单
- 权重需下载：`microsoft/Phi-4-mini-instruct`（ModelScope）
- fix 日志模板：`workspace/metax/fixes/Phi-4-mini-instruct.md`
- TP=1（3.8B，~7.6GB）

### 📋 EXAONE-4.0-32B（尚未上机）
- 原报告：Operator crash，V1-V4 全部数据空
- 修复方案：eager + 默认黑名单 → 抓崩溃算子加黑名单
- 权重已下载完成：`/public-flash/models/EXAONE-4.0-32B`（28 个文件，全部就绪）
- fix 日志模板：`workspace/metax/fixes/EXAONE-4.0-32B.md`
- TP=4，注意 `VLLM_FL_USE_FLAGGEMS_ATTN=0`

### 📋 GLM-4-32B-0414（尚未上机）
- 原报告：Operator crash + 精度不达标 + 性能不达标
- 修复方案：先裸 vLLM V1 基线，再开 plugin 二分法
- 权重下载状态：截至停机前下载中（~80%），重启后需确认完整性
- fix 日志模板：`workspace/metax/fixes/GLM-4-32B-0414.md`
- TP=4，ModelScope：`zai-org/GLM-4-32B-0414`

---

## 基础设施变更（本 session 完成）

### eval-scope 专用评测容器
- 镜像：`harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope`
- 已推送，digest：`sha256:8a2847c2b8cee9f4ccd62ae6534b46bc9b59694c6c33571e20ab34f535c2c128`
- 内含 modelscope 1.40.0，基于原 `flagos-evalscope:latest`
- 创建命令：
  ```bash
  docker run -d --name eval-scope \
    --network host \
    -v /public-flash/models:/models \
    harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope \
    sleep infinity
  ```

### SOP 更新（三平台同步）
1. **下模型**：统一在 `eval-scope` 容器执行，路径统一为 `/models/flagrelease/fixes_models/<模型名>`
2. **评测**：统一使用 `eval-scope` 容器，附容器存活检查和创建命令，去掉方式A/B分支
3. **服务容器命名**：统一改为 `flagrelease-fix-${model_name}`（model_name 小写）
4. **vllm serve 路径**：改为 `/models/flagrelease/fixes_models/${model_name}`

---

## 关键参数速查（metax）

| 项目 | 值 |
|------|---|
| 节点 | `metax-60` |
| 服务镜像 | `harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907` |
| 评测镜像 | `harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope` |
| 权重目录 | `/public-flash/models/flagrelease/fixes_models/<模型名>` |
| 日志目录 | `/models/release_run_logs/<model_name>/` |
| 默认黑名单 | `mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice` |
| MLA 设置 | `VLLM_FL_USE_FLAGGEMS_ATTN=0` |
| NV 基线文件 | `/workspace/eval_scripts/nv_baseline.yaml`（容器内） |

---

## 上机第一步清单

```bash
ssh metax-60
mx-smi                              # 确认 GPU 全空闲
docker ps                           # 确认无残留容器

# 确认 GLM 权重下载是否完整
ls /public-flash/models/GLM-4-32B-0414/ | wc -l   # 应有 safetensors + config

# 若 eval-scope 容器不在
docker run -d --name eval-scope \
  --network host \
  -v /public-flash/models:/models \
  harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope \
  sleep infinity
```

---

## 优先级建议

1. **EXAONE-4.0-32B** — 权重已就绪，直接上机，crash 类问题照黑名单二分法处理
2. **Phi-3-mini-128k-instruct** — 接着跑 V1 裸 vLLM 基线定位退化来源
3. **GLM-4-32B-0414** — 确认权重完整后上机
4. **Phi-4-mini-instruct** — 需先下载权重（用 eval-scope 容器）

---

## 相关文件

- SOP：`workspace/metax/SOP.md`、`workspace/hygon/SOP.md`、`workspace/iluvatar/SOP.md`
- 操作红线：`workspace/_shared/KNOWLEDGE.md`
- 各模型 fix 日志：`workspace/metax/fixes/<模型名>.md`
