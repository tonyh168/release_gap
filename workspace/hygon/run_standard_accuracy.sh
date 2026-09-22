#!/usr/bin/env bash
set -u

# The evaluator is CPU-side, but importing Hygon torch requires the same DTK
# runtime paths as the model service processes.
export LD_LIBRARY_PATH=/opt/dtk/dcc/gcvm/lib:/opt/dtk/hip/lib:/opt/dtk/llvm/lib:/opt/dtk/lib:/opt/dtk/lib64:/opt/hyhal/lib:/opt/hyhal/lib64:/opt/dtk/dushmem/lib:/opt/dtk/opencl/lib:/opt/dtk/.hyhal/rocm_smi/lib:/usr/local/lib:/usr/local/lib64:/opt/mpi/lib:/opt/hwloc/lib
export PYTHONPATH=/usr/local/
cd /models/day0_eval

run_gpqa() {
    local model="$1" api="$2" stamp="$3"
    rm -f "/models/day0_logs/accuracy/${stamp}.json" \
        "/models/day0_logs/accuracy/${stamp}.exit"
    printf '%s\n' "$(date -Iseconds)" > "/models/day0_logs/accuracy/${stamp}.running"
    python3 fast_gpqa.py \
        --model-name "$model" \
        --api-base "$api" \
        --dataset gpqa_diamond \
        --limit 50 \
        --eval-batch-size 4 \
        --skip-truncation-check \
        --output "/models/day0_logs/accuracy/${stamp}.json" \
        > "/models/day0_logs/accuracy/${stamp}.log" 2>&1
    printf '%s\n' "$?" > "/models/day0_logs/accuracy/${stamp}.exit"
    rm -f "/models/day0_logs/accuracy/${stamp}.running"
}

run_math() {
    local model="$1" api="$2" stamp="$3"
    rm -f "/models/day0_logs/accuracy/${stamp}.json" \
        "/models/day0_logs/accuracy/${stamp}.exit"
    printf '%s\n' "$(date -Iseconds)" > "/models/day0_logs/accuracy/${stamp}.running"
    python3 fast_gpqa.py \
        --model-name "$model" \
        --api-base "$api" \
        --dataset math_500 \
        --limit 40 \
        --eval-batch-size 4 \
        --skip-truncation-check \
        --output "/models/day0_logs/accuracy/${stamp}.json" \
        > "/models/day0_logs/accuracy/${stamp}.log" 2>&1
    printf '%s\n' "$?" > "/models/day0_logs/accuracy/${stamp}.exit"
    rm -f "/models/day0_logs/accuracy/${stamp}.running"
}

run_gpqa MiniCPM4-8B http://127.0.0.1:8010/v1 MiniCPM4-8B-gpqa50-standard-20260915-rerun &
run_gpqa Mistral-7B-OpenOrca http://127.0.0.1:8001/v1 Mistral-7B-OpenOrca-gpqa50-standard-20260915-rerun &
run_gpqa MiniCPM4.1-8B http://127.0.0.1:8002/v1 MiniCPM4.1-8B-gpqa50-standard-20260915-rerun &
run_gpqa gemma-1.1-7b-it http://127.0.0.1:8004/v1 gemma-1.1-7b-it-gpqa50-standard-20260915-rerun &
run_math Light-R1-7B-DS http://127.0.0.1:8003/v1 Light-R1-7B-DS-math500-200-standard-20260915-rerun &
wait
