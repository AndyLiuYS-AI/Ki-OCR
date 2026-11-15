# Ki-OCR

[中文](README_CN.md) | [🤗 Model weights](https://huggingface.co/AndyLiuys/Ki-OCR)

**[Powered by SoMark OXR](https://github.com/SoMarkAI/OXR)**

Ki-OCR is a formula-enhanced document parsing model distilled from [OXR-1.0](https://huggingface.co/SoMarkAI/OXR-1.0). It aims to improve mathematical formula recognition while preserving overall document parsing quality.

**Training data (IBEM500).** We construct IBEM500 from the publicly available [IBEM-v1-cropped dataset](https://huggingface.co/datasets/deepcopy/IBEM-v1-cropped), a cropped version of the [IBEM dataset](https://doi.org/10.5281/zenodo.7963703). IBEM contains mathematical expressions from scientific documents with their LaTeX annotations. IBEM-v1-cropped extracts individual formula images using their annotated bounding boxes, distinguishing displayed (`isolated`) from inline (`embedded`) formulas. We select 500 real displayed-formula images for training. The name IBEM500 refers to the 500 training samples.

**Distillation (OPD).** We use OXR-1.0 as the student and MiniCPM-OCR-1.0 as the teacher. The student generates its own token sequences from formula images, and the teacher provides token-level probability supervision on the student-generated prefixes. To accommodate the different vocabularies, we align candidate tokens and minimize reverse KL divergence over the aligned top-64 candidates. We fine-tune the student using LoRA and merge the adapted weights for inference. The original architecture and document parsing pipeline are retained.

## Results on OmniDocBench

| Model Type | Methods | Size | Overall ↑ | Text<sup>Edit</sup> ↓ | Formula<sup>CDM</sup> ↑ | Table<sup>TEDS</sup> ↑ | Table<sup>TEDS-S</sup> ↑ | Read Order<sup>Edit</sup> ↓ |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Ki-OCR | Specialized VLMs | 1.3B | **97.2683** | 0.02421 | **97.6544** | 96.5713 | 98.4169 | 0.1221 |

## Reproduce on OmniDocBench

### 1. Clone the repository, download the model and start inference

Requirements: Linux, Docker, NVIDIA Container Toolkit and a BF16-capable NVIDIA GPU with a CUDA 13-compatible driver. Tested on an NVIDIA A100 80GB.

Clone the repository:

```bash
git clone https://github.com/AndyLiuYS-AI/Ki-OCR.git
cd Ki-OCR
```

Download the model:

```bash
python -m pip install -U huggingface_hub
hf download AndyLiuys/Ki-OCR --local-dir ./models/Ki-OCR
```

Build the Docker image:

```bash
docker build -f docker/Dockerfile.allinone -t ki_ocr:1.0 .
```

Start the inference service:

```bash
docker run -d --name ki-ocr --gpus '"device=0"' --ipc=host \
  -p 127.0.0.1:18000:8000 \
  -v "$PWD/models/Ki-OCR:/models/ki_ocr-model:ro" \
  ki_ocr:1.0
```

Select an available GPU by replacing `device=0`.

Check the service logs:

```bash
docker logs -f ki-ocr
```

Wait for `all services are ready` in the container logs, then press Ctrl+C to leave the log viewer; the container stays running.

### 2. Run full inference and evaluation

Use the [OmniDocBench v1.6 full dataset](https://huggingface.co/datasets/opendatalab/OmniDocBench) (1,651 pages). From the repository root, run:

```bash
DATA="/path/to/OmniDocBench" bash eval_omnidocbench.sh
```

Replace `/path/to/OmniDocBench` with the actual dataset path. The directory should contain `OmniDocBench.json` and `images/`.

The script completes full inference and automatically runs the [official OmniDocBench evaluator](https://github.com/opendatalab/OmniDocBench). The Markdown predictions, detailed evaluation results and `summary.json` are saved in the evaluation directory (`omnidocbench_eval_*`) printed at the end of the run.

## License and attribution

Ki-OCR is derived from [OXR](https://github.com/SoMarkAI/OXR) and retains its original inference pipeline. See [LICENSE](LICENSE), [Apache License 2.0](LICENSE-APACHE-2.0.txt) and [NOTICE](NOTICE). The model weights follow the license in the [model repository](https://huggingface.co/AndyLiuys/Ki-OCR).

**[Powered by SoMark OXR](https://github.com/SoMarkAI/OXR)**