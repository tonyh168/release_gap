# evalscope 评测镜像

轻量 Ubuntu 22.04 基础镜像，仅包含 evalscope 及其依赖，不含 GPU 驱动/torch/MACA，
用于与 vLLM 容器隔离的独立评测环境。

## 镜像信息

| 项目 | 值 |
|------|---|
| 本地 tag | `flagos-evalscope:1.5.1` |
| 基础镜像 | `ubuntu:22.04` |
| evalscope 版本 | `1.5.1` |
| 预估大小 | ~800MB（对比 MetaX vLLM 镜像 ~20GB+） |
| 首次构建节点 | `metax-60` |

## 构建方法

```bash
# 在目标节点执行（首次或更新时）
docker build -t flagos-evalscope:1.5.1 workspace/shared/evalscope/
```

若需推送到 harbor 供其他节点使用：
```bash
docker tag flagos-evalscope:1.5.1 harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:1.5.1
docker push harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:1.5.1
```

## 使用方式

评测容器与 vLLM 容器均用 `--network host`，eval 容器直接打 `127.0.0.1:8000`。

```bash
MODEL_NAME=Phi-3-mini-128k-instruct

# 起评测容器
docker run -d --rm \
  --name ${MODEL_NAME}-eval \
  --network host \
  -v /public-flash/models:/models \
  -v /tmp/eval_scripts:/workspace/eval_scripts \
  flagos-evalscope:1.5.1 \
  sleep infinity

# 复制评测脚本（本地项目 → 远端节点 → 容器）
# scp -r flagrelease_eval_methods/ <node>:/tmp/eval_scripts/
# docker cp /tmp/eval_scripts/. ${MODEL_NAME}-eval:/workspace/eval_scripts/

# 运行评测
docker exec ${MODEL_NAME}-eval bash -c "
cd /workspace/eval_scripts
python3 fast_gpqa.py \
  --model-name ${MODEL_NAME} \
  --api-base http://127.0.0.1:8000/v1 \
  --dataset gpqa_diamond \
  --output /models/release_run_logs/${MODEL_NAME}/gpqa.json
python3 accuracy_compare.py \
  --v2 /models/release_run_logs/${MODEL_NAME}/gpqa.json \
  --nv-baseline ${MODEL_NAME} \
  --nv-baseline-file nv_baseline.yaml \
  --json \
  --output /models/release_run_logs/${MODEL_NAME}/verdict.json
"
```

## 设计原则

- vLLM 容器保持干净，不安装任何额外包，避免 anyio/starlette 等依赖冲突
- evalscope 容器无需 GPU device，起容器时不挂 `/dev/dri`、`/dev/mxcd`
- 两容器共享 `/public-flash/models` NFS 挂载，eval 结果直接写 `/models/release_run_logs/`
- 镜像版本与 evalscope 版本号对齐，升级时重新 build 并更新 tag
