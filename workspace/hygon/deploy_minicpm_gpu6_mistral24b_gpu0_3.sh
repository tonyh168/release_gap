#!/usr/bin/env bash

set -euo pipefail

IMAGE="harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4"
MODEL_ROOT="/public-flash/models"
LOG_ROOT="${MODEL_ROOT}/day0_logs"
HOST_DTK_ENV="/opt/dtk-26.04/env.sh"
CONTAINER_DTK_ENV="/opt/dtk/env.sh"
RUN_ID="${1:-$(date +%Y%m%d-%H%M%S)}"

MINICPM_MODEL="MiniCPM4-8B"
MINICPM_CONTAINER="day0-minicpm4-8b"
MINICPM_GPU="6"
MINICPM_PORT="8010"
MINICPM_MAX_LEN="32768"
MINICPM_WHITELIST="add,arange_start,argmax,broadcast_to,copy_,cos,cumsum,cumsum_out,expand,full,index,le,linear,lt_scalar,masked_fill_,mm_out,ones,rand_like,reciprocal,rsub_scalar,scatter_,sin,softmax,softmax_out,sub,sum_dim,to_copy,true_divide,true_divide_,where_self,where_self_out,zero_,zeros"

MISTRAL_MODEL="Mistral-Small-24B-Instruct-2501"
MISTRAL_CONTAINER="day0-mistral-small-24b-instruct-2501"
MISTRAL_GPUS="0,1,2,3"
MISTRAL_PORT="8005"
MISTRAL_MAX_LEN="32768"
MISTRAL_WHITELIST="add,arange_start,argmax,copy_,cos,expand,full,index,linear,lt_scalar,mm_out,ones,rand_like,randn,reciprocal,sin,softmax,softmax_out,sub,to_copy,true_divide,true_divide_,where_self,where_self_out,zero_,zeros"

mkdir -p "${LOG_ROOT}"

require_file() {
  local path="$1"
  if [[ ! -f "${path}" ]]; then
    echo "Required file is missing: ${path}" >&2
    exit 1
  fi
}

require_absent_container() {
  local container="$1"
  if docker container inspect "${container}" >/dev/null 2>&1; then
    echo "Container already exists; refusing to replace it: ${container}" >&2
    exit 1
  fi
}

require_free_port() {
  local port="$1"
  if ss -lnt | awk '{print $4}' | grep -Eq "(^|:)${port}$"; then
    echo "Port is already in use: ${port}" >&2
    exit 1
  fi
}

requested_gpu_conflicts() {
  local requested_csv="$1"
  local pid visible command requested_gpu

  while read -r pid; do
    [[ -n "${pid}" ]] || continue
    visible="$(
      tr '\0' '\n' < "/proc/${pid}/environ" \
        | sed -n -E 's/^(HIP_VISIBLE_DEVICES|ROCR_VISIBLE_DEVICES|CUDA_VISIBLE_DEVICES)=//p' \
        | head -n 1
    )"
    command="$(ps -p "${pid}" -o args=)"

    if [[ -z "${visible}" ]]; then
      echo "Cannot prove GPU isolation for existing vLLM PID ${pid}: ${command}" >&2
      return 0
    fi

    IFS=',' read -r -a requested_gpus <<< "${requested_csv}"
    for requested_gpu in "${requested_gpus[@]}"; do
      if [[ ",${visible}," == *",${requested_gpu},"* ]]; then
        echo "GPU ${requested_gpu} is already claimed by PID ${pid}: ${command}" >&2
        return 0
      fi
    done
  done < <(pgrep -f '/usr/local/bin/vllm serve' || true)

  return 1
}

create_container() {
  local container="$1"
  local deploy_log="$2"

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
    bash -lc 'sleep infinity' \
    2>&1 | tee -a "${deploy_log}"
}

launch_service() {
  local model="$1"
  local container="$2"
  local gpus="$3"
  local port="$4"
  local tensor_parallel_size="$5"
  local max_model_len="$6"
  local whitelist="$7"
  local deploy_log="$8"
  local serve_log="$9"
  local enabled_ops_path="/models/day0_logs/${model}-enabled-ops-${RUN_ID}.txt"
  local cache_root="/models/day0_logs/triton_cache/${model}"

  {
    echo "run_id=${RUN_ID}"
    echo "model=${model}"
    echo "container=${container}"
    echo "image=${IMAGE}"
    echo "image_id=$(docker image inspect -f '{{.Id}}' "${IMAGE}")"
    echo "host_model_path=${MODEL_ROOT}/${model}"
    echo "hip_visible_devices=${gpus}"
    echo "port=${port}"
    echo "tensor_parallel_size=${tensor_parallel_size}"
    echo "max_model_len=${max_model_len}"
    echo "attention_backend=TRITON_ATTN"
    echo "flagos_whitelist=${whitelist}"
    echo "serve_log=${serve_log}"
    date -Is
  } | tee -a "${deploy_log}"

  create_container "${container}" "${deploy_log}"

  docker exec \
    -e "DTK_HOME=/opt/dtk" \
    -e "ROCM_PATH=/opt/dtk" \
    -e "HIP_PATH=/opt/dtk/hip" \
    -e "HSA_PATH=/opt/dtk/hsa" \
    -e "DEVICE_LIB_PATH=/opt/dtk/amdgcn/bitcode" \
    -e "TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18" \
    -e "GEMS_VENDOR=hygon" \
    -e "VLLM_PLUGINS=fl" \
    -e "HIP_VISIBLE_DEVICES=${gpus}" \
    -e "VLLM_WORKER_MULTIPROC_METHOD=spawn" \
    -e "VLLM_ENGINE_ITERATION_TIMEOUT_S=7200" \
    -e "VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200" \
    -e "FLAGGEMS_DB_URL=sqlite:///:memory:" \
    -e "VLLM_FL_TRITON_CACHE_ROOT=${cache_root}" \
    -e "FLAGGEMS_ENABLE_OPLIST_PATH=${enabled_ops_path}" \
    -e "VLLM_FL_FLAGOS_WHITELIST=${whitelist}" \
    "${container}" bash -lc \
    "source '${CONTAINER_DTK_ENV}' && python -c 'import torch, vllm, vllm_fl; assert torch.cuda.device_count() == ${tensor_parallel_size}, torch.cuda.device_count(); print(\"vllm=\" + vllm.__version__); print(\"device_count=\" + str(torch.cuda.device_count())); print(\"plugin_fl=ok\")'" \
    2>&1 | tee -a "${deploy_log}"

  docker exec -d \
    -e "DTK_HOME=/opt/dtk" \
    -e "ROCM_PATH=/opt/dtk" \
    -e "HIP_PATH=/opt/dtk/hip" \
    -e "HSA_PATH=/opt/dtk/hsa" \
    -e "DEVICE_LIB_PATH=/opt/dtk/amdgcn/bitcode" \
    -e "TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18" \
    -e "GEMS_VENDOR=hygon" \
    -e "VLLM_PLUGINS=fl" \
    -e "HIP_VISIBLE_DEVICES=${gpus}" \
    -e "VLLM_WORKER_MULTIPROC_METHOD=spawn" \
    -e "VLLM_ENGINE_ITERATION_TIMEOUT_S=7200" \
    -e "VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200" \
    -e "FLAGGEMS_DB_URL=sqlite:///:memory:" \
    -e "VLLM_FL_TRITON_CACHE_ROOT=${cache_root}" \
    -e "FLAGGEMS_ENABLE_OPLIST_PATH=${enabled_ops_path}" \
    -e "VLLM_FL_FLAGOS_WHITELIST=${whitelist}" \
    "${container}" bash -lc \
    "source '${CONTAINER_DTK_ENV}' && exec /usr/bin/python3 /usr/local/bin/vllm serve '/models/${model}' \
      --served-model-name '${model}' \
      --dtype bfloat16 \
      --tensor-parallel-size '${tensor_parallel_size}' \
      --max-model-len '${max_model_len}' \
      --gpu-memory-utilization 0.90 \
      --port '${port}' \
      --attention-backend TRITON_ATTN \
      --enforce-eager \
      --trust-remote-code \
      >> '${serve_log}' 2>&1"

  echo "service_dispatched_at=$(date -Is)" | tee -a "${deploy_log}"
}

require_file "${HOST_DTK_ENV}"
require_file "${MODEL_ROOT}/${MINICPM_MODEL}/config.json"
require_file "${MODEL_ROOT}/${MISTRAL_MODEL}/config.json"

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "Required image is not present: ${IMAGE}" >&2
  exit 1
fi

require_absent_container "${MINICPM_CONTAINER}"
require_absent_container "${MISTRAL_CONTAINER}"
require_free_port "${MINICPM_PORT}"
require_free_port "${MISTRAL_PORT}"

if requested_gpu_conflicts "${MINICPM_GPU}"; then
  exit 1
fi
if requested_gpu_conflicts "${MISTRAL_GPUS}"; then
  exit 1
fi

launch_service \
  "${MINICPM_MODEL}" \
  "${MINICPM_CONTAINER}" \
  "${MINICPM_GPU}" \
  "${MINICPM_PORT}" \
  "1" \
  "${MINICPM_MAX_LEN}" \
  "${MINICPM_WHITELIST}" \
  "${LOG_ROOT}/${MINICPM_MODEL}-deploy-${RUN_ID}-gpu6.log" \
  "/models/day0_logs/${MINICPM_MODEL}-serve-${RUN_ID}-gpu6.log"

launch_service \
  "${MISTRAL_MODEL}" \
  "${MISTRAL_CONTAINER}" \
  "${MISTRAL_GPUS}" \
  "${MISTRAL_PORT}" \
  "4" \
  "${MISTRAL_MAX_LEN}" \
  "${MISTRAL_WHITELIST}" \
  "${LOG_ROOT}/${MISTRAL_MODEL}-deploy-${RUN_ID}-gpu0-3.log" \
  "/models/day0_logs/${MISTRAL_MODEL}-serve-${RUN_ID}-gpu0-3.log"

echo "Both services were dispatched."
echo "MiniCPM health: curl -sS http://127.0.0.1:${MINICPM_PORT}/health"
echo "Mistral health: curl -sS http://127.0.0.1:${MISTRAL_PORT}/health"
