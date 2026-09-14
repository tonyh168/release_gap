FROM harbor.baai.ac.cn/docker.io/library/ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 python3-pip ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

# evalscope 1.5.1 for OpenAI-API mode (no GPU, no torch needed)
# modelscope needed to download gpqa_diamond dataset at eval time
# Upgrade pip first — Ubuntu 22.04 ships pip 22.0.2 which has a known
# AssertionError in the dependency resolver for large dependency graphs
RUN pip3 install --no-cache-dir \
    -i https://pypi.tuna.tsinghua.edu.cn/simple \
    --upgrade pip

RUN pip3 install --no-cache-dir \
    -i https://pypi.tuna.tsinghua.edu.cn/simple \
    evalscope \
    modelscope \
    requests \
    pyyaml

WORKDIR /workspace
