# 0910 失败报告提取记录

**日期**：2026-09-11  
**操作**：从 `flagrelease_fail_report.zip` 中，按 `0910-fail-model-list.csv` 筛选对应平台的失败报告，提取到本目录。

---

## 平台映射

| CSV 列名 | zip 子目录 | 本目录子目录 |
|---------|-----------|------------|
| 沐曦    | Metax     | metax/     |
| 天数    | Iluvatar  | iluvatar/  |
| 海光    | Hygon     | hygon/     |

---

## 提取结果

共提取 **23 份**报告：

### hygon/（10 份，海光平台，CSV 列出 10 个模型，全部命中）

- FAILED_Hygon_DeepSeek-R1-Distill-Qwen-32B-Japanese_202608071433.md
- FAILED_Hygon_Light-R1-7B-DS_202608182136.md
- FAILED_Hygon_Magistral-Small-2506_202607311737.md
- FAILED_Hygon_Mistral-Small-24B-Instruct-2501_202607290628.md
- FAILED_Hygon_Nanbeige4.1-3B_202607150245.md
- FAILED_Hygon_Phi-3-medium-128k-instruct_202607300330.md
- FAILED_Hygon_Phi-3-mini-128k-instruct_202607150538.md
- FAILED_Hygon_Qwen2.5-7B-Instruct_202607241708.md
- FAILED_Hygon_SOLAR-10.7B-Instruct-v1.0_202607252026.md
- FAILED_Hygon_sarvam-m_202607290952.md

### iluvatar/（8 份，天数平台，CSV 列出 48 个模型，仅 8 个命中）

- FAILED_Iluvatar_Fathom-R1-14B_202608211539.md
- FAILED_Iluvatar_LFM2.5-1.2B-Thinking_202607281813.md
- FAILED_Iluvatar_MiroThinker-v1.5-30B_202608241019.md
- FAILED_Iluvatar_OpenThinker-7B_202609081330.md
- FAILED_Iluvatar_Phi-3-medium-128k-instruct_202608211621.md
- FAILED_Iluvatar_QwQ-32B_202608261444.md
- FAILED_Iluvatar_SOLAR-10.7B-Instruct-v1.0_202608142022.md
- FAILED_Iluvatar_TinyR1-32B-Preview_202608271844.md

### metax/（5 份，沐曦平台，CSV 列出 5 个模型，全部命中）

- FAILED_Metax_EXAONE-4.0-32B_202608070744.md
- FAILED_Metax_GLM-4-32B-0414_202608070851.md
- FAILED_Metax_Phi-3-mini-128k-instruct_202607160324.md
- FAILED_Metax_Qwen3-Coder-30B-A3B-Instruct_202608012329.md
- FAILED_Metax_SOLAR-10.7B-Instruct-v1.0_202607261725.md

---

## 缺口：天数平台 40 个模型无报告

CSV 中天数列出的以下模型，在 zip 的 `Iluvatar/` 目录中没有对应报告文件，可能尚未从平台导出或未生成：

A.X-4.0-Light, AReaL-boba-2-14B, AReaL-boba-2-14B-Open, AReaL-boba-2-32B,
AceReason-Nemotron-14B, Athene-V2-Chat, Darwin-9B-NEG-ansulev,
DeepSeek-R1-Distill-Llama-70B, Dria-Agent-a-7B, IndustrialCoder,
Lamarckvergence-14B, Ling-lite-1.5, Llama-3-3-3-Nemotron-Super-49B-v1,
Llama-3-3-3-Nemotron-Super-49B-v1-5, Llama-3.1-Nemotron-70B-Instruct-HF,
Llama-3.1-Tulu-3.1-8B, Marco-Mini-Instruct, Midm-2.0-Base-Instruct,
Nemotron-Cascade-14B-Thinking, Nemotron-Cascade-8B, OREAL-32B,
Olmo-3.1-32B-Instruct, OpenR1-Qwen-7B, OpenReasoning-Nemotron-1.5B,
OpenReasoning-Nemotron-14B, OpenReasoning-Nemotron-32B, OpenThinker2-32B,
OpenThinker3-7B, Phi-4-mini-reasoning, Qwen2.5-72B-Instruct,
Qwopus3.6-27B-Coder, Ring-lite, Ring-lite-distill-preview, Rubicon-Preview,
Sky-T1-32B-Flash, T-lite-it-2.1, gemma-3-4B-T1-it, granite-3.3-2b-instruct,
kanana-1.5-8b-instruct-2505, meta-llama-Llama-3.3-70B-Instruct

---

## 源文件

- `../0910-fail-model-list.csv`：失败模型列表
- `../flagrelease_fail_report.zip`：完整失败报告 zip（含 Hygon/Metax/Iluvatar/Ascend/Mthreads/Nvidia/T-Head 七个平台，本次只提取前三个）
