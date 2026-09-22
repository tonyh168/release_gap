#!/usr/bin/env bash

set -euo pipefail

IMAGE="harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4"
MODEL_ROOT="/public-flash/models"
LOG_ROOT="${MODEL_ROOT}/day0_logs"
DTK_ENV="/opt/dtk/env.sh"
RUN_ID="${1:-$(date +%Y%m%d-%H%M%S)}"

MODELS=(
  "MiniCPM4-8B"
  "Mistral-7B-OpenOrca"
  "MiniCPM4.1-8B"
  "Light-R1-7B-DS"
  "gemma-1.1-7b-it"
)

CONTAINERS=(
  "day0-minicpm4-8b"
  "day0-mistral-7b-openorca"
  "day0-minicpm4-1-8b"
  "day0-light-r1-7b-ds"
  "day0-gemma-1-1-7b-it"
)

GPUS=(2 3 4 5 6)
PORTS=(8010 8001 8002 8003 8004)
MAX_MODEL_LENS=(32768 32768 65536 131072 8192)
HISTORICAL_REPLACEMENT_COUNTS=(33 26 34 0 27)

# Historical V2/V3 FlagGems allowlists from the corresponding Hygon reports.
FLAGOS_WHITELISTS=(
  "add,arange_start,argmax,broadcast_to,copy_,cos,cumsum,cumsum_out,expand,full,index,le,linear,lt_scalar,masked_fill_,mm_out,ones,rand_like,reciprocal,rsub_scalar,scatter_,sin,softmax,softmax_out,sub,sum_dim,to_copy,true_divide,true_divide_,where_self,where_self_out,zero_,zeros"
  "add,arange_start,argmax,copy_,cos,expand,full,index,linear,lt_scalar,mm_out,ones,rand_like,randn,reciprocal,sin,softmax,softmax_out,sub,to_copy,true_divide,true_divide_,where_self,where_self_out,zero_,zeros"
  "add,arange,argmax,broadcast_to,copy,cos,cumsum,div,expand,index,le,lt,masked_fill,rand_like,randn,reciprocal,rsub,scatter,sin,softmax,sub,sum,to,where"
  ""
  "add,addmm_out,arange_start,argmax,broadcast_to,copy_,cos,expand,full,index,linear,lt_scalar,mm_out,rand_like,randn,reciprocal,sin,softmax,softmax_out,sub,to_copy,true_divide,true_divide_,where_self,where_self_out,zero_,zeros"
)

# An environment blacklist overrides the platform default, so retain the
# Hygon default cat entry when excluding the bool-unsupported slice operator.
FLAGOS_BLACKLISTS=("" "" "" "cat,slice" "")

# Gemma historically disabled this OOT fused operator for acceptable performance.
OOT_BLACKLISTS=("" "" "" "" "silu_and_mul")

# Gemma accuracy diagnosis showed that the OOT path changes GPQA answers.
# Disabling OOT is retained as a candidate mitigation, but repeated GPQA runs
# still vary, so this must not be treated as a completed precision fix.
OOT_ENABLED=(1 1 1 1 0)

mkdir -p "${LOG_ROOT}"

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "Required image is not present: ${IMAGE}" >&2
  exit 1
fi

for index in "${!MODELS[@]}"; do
  model="${MODELS[$index]}"
  container="${CONTAINERS[$index]}"
  gpu="${GPUS[$index]}"
  port="${PORTS[$index]}"
  max_len="${MAX_MODEL_LENS[$index]}"
  historical_replacement_count="${HISTORICAL_REPLACEMENT_COUNTS[$index]}"
  whitelist="${FLAGOS_WHITELISTS[$index]}"
  blacklist="${FLAGOS_BLACKLISTS[$index]}"
  oot_blacklist="${OOT_BLACKLISTS[$index]}"
  oot_enabled="${OOT_ENABLED[$index]}"
  model_path="${MODEL_ROOT}/${model}"
  deploy_log="${LOG_ROOT}/${model}-deploy-${RUN_ID}.log"
  serve_log="${LOG_ROOT}/${model}-serve-${RUN_ID}.log"

  if [[ ! -f "${model_path}/config.json" ]]; then
    echo "Missing model config: ${model_path}/config.json" | tee -a "${deploy_log}" >&2
    exit 1
  fi

  if docker container inspect "${container}" >/dev/null 2>&1; then
    echo "Container already exists, refusing to replace it: ${container}" | tee -a "${deploy_log}" >&2
    exit 1
  fi

  if ss -lnt | awk '{print $4}' | grep -Eq "(^|:)${port}$"; then
    echo "Port is already in use: ${port}" | tee -a "${deploy_log}" >&2
    exit 1
  fi

  {
    echo "run_id=${RUN_ID}"
    echo "model=${model}"
    echo "model_path=${model_path}"
    echo "container=${container}"
    echo "image=${IMAGE}"
    echo "image_id=$(docker image inspect -f '{{.Id}}' "${IMAGE}")"
    echo "gpu=${gpu}"
    echo "port=${port}"
    echo "tensor_parallel_size=1"
    echo "max_model_len=${max_len}"
    echo "attention_backend=TRITON_ATTN"
    echo "historical_replacement_count=${historical_replacement_count}"
    echo "flagos_whitelist=${whitelist:-<unset>}"
    echo "flagos_blacklist=${blacklist:-<unset>}"
    echo "oot_blacklist=${oot_blacklist:-<unset>}"
    echo "oot_enabled=${oot_enabled}"
    echo "serve_log=${serve_log}"
    date -Is
  } | tee -a "${deploy_log}"

  docker run -d \
    --name "${container}" \
    --device=/dev/kfd \
    --device=/dev/dri \
    --security-opt seccomp=unconfined \
    --group-add video \
    --ipc=host \
    --network=host \
    --shm-size 64g \
    -v "${MODEL_ROOT}":/models \
    -v /opt/hyhal:/opt/hyhal:ro \
    "${IMAGE}" \
    bash -lc 'sleep infinity' 2>&1 | tee -a "${deploy_log}"

  docker exec \
    -e "GEMS_VENDOR=hygon" \
    -e "VLLM_PLUGINS=fl" \
    -e "HIP_VISIBLE_DEVICES=${gpu}" \
    "${container}" bash -lc \
    "source '${DTK_ENV}' && python -c 'import torch, vllm, vllm_fl; assert torch.cuda.device_count() == 1, torch.cuda.device_count(); print(\"vllm=\" + vllm.__version__); print(\"device=\" + torch.cuda.get_device_name(0)); print(\"plugin_fl=ok\")'" \
    2>&1 | tee -a "${deploy_log}"

  exec_env=(
    -e "DTK_HOME=/opt/dtk"
    -e "ROCM_PATH=/opt/dtk"
    -e "HIP_PATH=/opt/dtk/hip"
    -e "HSA_PATH=/opt/dtk/hsa"
    -e "DEVICE_LIB_PATH=/opt/dtk/amdgcn/bitcode"
    -e "TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18"
    -e "VLLM_FL_TRITON_CACHE_ROOT=/models/triton_cache/${model}"
    -e "GEMS_VENDOR=hygon"
    -e "VLLM_PLUGINS=fl"
    -e "HIP_VISIBLE_DEVICES=${gpu}"
    -e "VLLM_WORKER_MULTIPROC_METHOD=spawn"
    -e "VLLM_ENGINE_ITERATION_TIMEOUT_S=7200"
    -e "VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200"
  )

  if [[ -n "${whitelist}" ]]; then
    exec_env+=(-e "VLLM_FL_FLAGOS_WHITELIST=${whitelist}")
  fi
  if [[ -n "${blacklist}" ]]; then
    exec_env+=(-e "VLLM_FL_FLAGOS_BLACKLIST=${blacklist}")
  fi
  if [[ -n "${oot_blacklist}" ]]; then
    exec_env+=(-e "VLLM_FL_OOT_BLACKLIST=${oot_blacklist}")
  fi
  if [[ "${oot_enabled}" == "0" ]]; then
    exec_env+=(-e "VLLM_FL_OOT_ENABLED=0")
  fi
  docker exec -d "${exec_env[@]}" "${container}" bash -lc \
    "mkdir -p '/models/triton_cache/${model}' && source '${DTK_ENV}' && exec vllm serve '/models/${model}' \
      --served-model-name '${model}' \
      --dtype bfloat16 \
      --tensor-parallel-size 1 \
      --max-model-len '${max_len}' \
      --gpu-memory-utilization 0.90 \
      --port '${port}' \
      --attention-backend TRITON_ATTN \
      --enforce-eager \
      --trust-remote-code \
      >> '/models/day0_logs/${model}-serve-${RUN_ID}.log' 2>&1"

  echo "service_dispatched_at=$(date -Is)" | tee -a "${deploy_log}"
done

echo "run_id=${RUN_ID}"
echo "All five services were dispatched. Check readiness via the per-model serve logs."
