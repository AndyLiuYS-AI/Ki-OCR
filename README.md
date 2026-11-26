# Ki-OCR

[中文](README_CN.md) | [🤗 Model weights](https://huggingface.co/AndyLiuys/Ki-OCR)

**[Powered by SoMark OXR](https://github.com/SoMarkAI/OXR)**

Ki-OCR is a formula-enhanced document parsing model distilled from [OXR-1.0](https://huggingface.co/SoMarkAI/OXR-1.0). It aims to improve formula recognition ability while preserving overall document parsing quality.

**Training data (IBEM500).** We construct IBEM500 from the public dataset [IBEM-v1-cropped](https://huggingface.co/datasets/deepcopy/IBEM-v1-cropped), a cropped version of [IBEM](https://doi.org/10.5281/zenodo.7963703). IBEM contains mathematical expressions from scientific documents with their LaTeX annotations. IBEM-v1-cropped extracts individual formula images using their annotated bounding boxes, distinguishing displayed (`isolated`) from inline (`embedded`) formulas. We select 500 real displayed-formula images for training. The name IBEM500 refers to the 500 training samples.

**On-Policy Distillation (OPD).** We use [OXR-1.0](https://huggingface.co/SoMarkAI/OXR-1.0) as the student model and [MiniCPM-OCR 1.0](https://huggingface.co/openbmb/MiniCPM-OCR-1.0) as the teacher model. The student model generates its own token sequences from formula images, and the teacher model provides token-level probability supervision on the student-generated prefixes. To accommodate the different vocabularies, we align candidate tokens and minimize reverse KL divergence over the aligned top-64 candidates. We fine-tune the student model using LoRA and merge the adapted weights for inference. The original architecture and document parsing pipeline are retained.

## Results on OmniDocBench

| Model Type | Methods | Size | Overall ↑ | Text<sup>Edit</sup> ↓ | Formula<sup>CDM</sup> ↑ | Table<sup>TEDS</sup> ↑ | Table<sup>TEDS-S</sup> ↑ | Read Order<sup>Edit</sup> ↓ |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Ki-OCR | Specialized VLMs | 1.3B | 97.2812 | 0.0242 | 97.6332 | 96.6306 | 98.4685 | 0.1224 |
| OXR-1.0 | Specialized VLMs | 1.3B | 97.1832 | 0.0251 | 97.4449 | 96.6167 | 98.4395 | 0.1214 |

*Source: OXR-1.0 results are taken from the [issue submitted by the OXR team to the official OmniDocBench repository](https://github.com/opendatalab/OmniDocBench/issues/264); Ki-OCR results are from our local evaluation.*

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

Replace `device=0` with the index of an available GPU.

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

## Additional Benchmark Results

### DocParsingBench

| Model | Overall ↑ | Text ↑ | Formula ↑ | Table ↑ |
| --- | ---: | ---: | ---: | ---: |
| Ki-OCR | 88.41 | 90.98 | 87.12 | 80.21 |
| OXR-1.0 | 87.76 | 90.60 | 85.76 | 80.04 |

*Source: OXR-1.0 results are taken from the [official OXR benchmark report](https://github.com/SoMarkAI/OXR/blob/main/docs/benchmark.md); Ki-OCR results are from our local evaluation.*

### olmOCR-bench

| Model | Overall ↑ | ArXiv Math ↑ | Baseline ↑ | Headers / Footers ↑ | Long Tiny Text ↑ | Multi Column ↑ | Old Scans ↑ | Old Scans Math ↑ | Tables ↑ |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Ki-OCR | 87.18 | 91.49 | 97.49 | 93.55 | 90.95 | 84.95 | 58.75 | 88.86 | 91.39 |
| OXR-1.0 | 87.11 | 91.49 | 97.27 | 93.68 | 90.95 | 85.29 | 58.37 | 88.43 | 91.39 |

*Source: Both OXR-1.0 and Ki-OCR results are from our local evaluation using native PDF inputs. Since we could not reproduce the 87.84 Overall score in the [official OXR benchmark report](https://github.com/SoMarkAI/OXR/blob/main/docs/benchmark.md) in our local evaluation environment, we report the locally evaluated results for both models under the same evaluation settings.*

## License and Attribution

Ki-OCR is derived from [OXR-1.0](https://github.com/SoMarkAI/OXR) and retains its original model architecture and core document parsing pipeline.

This project is distributed under the [OXR Open Source License](LICENSE), which is based on the [Apache License 2.0](LICENSE-APACHE-2.0.txt) with additional terms. Third-party attributions are provided in [NOTICE](NOTICE).

The model weights are subject to the original [OXR-1.0 model license](https://huggingface.co/SoMarkAI/OXR-1.0/blob/main/LICENSE). See the [Ki-OCR model repository](https://huggingface.co/AndyLiuys/Ki-OCR) for details.

**[Powered by SoMark OXR](https://github.com/SoMarkAI/OXR)**