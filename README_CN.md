# Ki-OCR

[English](README.md) | [🤗 模型权重](https://huggingface.co/AndyLiuys/Ki-OCR)

**[Powered by SoMark OXR](https://github.com/SoMarkAI/OXR)**

Ki-OCR 是基于 [OXR-1.0](https://huggingface.co/SoMarkAI/OXR-1.0) 蒸馏得到的公式增强型文档解析模型，旨在提升公式识别能力，同时保持整体文档解析性能。

**训练数据（IBEM500）。** IBEM500 构建自公开数据集 [IBEM-v1-cropped](https://huggingface.co/datasets/deepcopy/IBEM-v1-cropped)，该数据集源自 [IBEM](https://doi.org/10.5281/zenodo.7963703)，包含科学文献中的数学公式及对应的 LaTeX 标注。IBEM-v1-cropped 按照标注框从原始文档页面裁剪单个公式，并区分独立公式（`isolated`）与行内公式（`embedded`）。我们选取其中 500 张真实的独立公式图像用于训练。IBEM500 的名称来源于 500 条训练样本。

**在线策略蒸馏（OPD）。** 我们以 OXR-1.0 为学生模型、MiniCPM-OCR 1.0 为教师模型。学生模型根据公式图像自主生成 token 序列，教师模型在学生生成的前缀上提供逐 token 的概率分布监督。针对两个模型词表不同的问题，对候选 token 进行对齐，并在对齐后的 Top-64 候选集合上计算反向 KL 散度。训练采用 LoRA，合并适配后的权重用于推理，保留原始模型架构和文档解析流程。

## OmniDocBench 实验结果

| Model Type | Methods | Size | Overall ↑ | Text<sup>Edit</sup> ↓ | Formula<sup>CDM</sup> ↑ | Table<sup>TEDS</sup> ↑ | Table<sup>TEDS-S</sup> ↑ | Read Order<sup>Edit</sup> ↓ |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Ki-OCR | Specialized VLMs | 1.3B | **97.2812** | 0.02420 | **97.6332** | 96.6306 | 98.4685 | 0.1224 |

## 在 OmniDocBench 上复现

### 1. 克隆仓库、下载模型并启动推理服务

环境要求：Linux、Docker、NVIDIA Container Toolkit、支持 BF16 的 NVIDIA GPU 及兼容 CUDA 13 的驱动。已在 NVIDIA A100 80GB 上验证。

克隆仓库：

```bash
git clone https://github.com/AndyLiuYS-AI/Ki-OCR.git
cd Ki-OCR
```

下载模型：

```bash
python -m pip install -U huggingface_hub
hf download AndyLiuys/Ki-OCR --local-dir ./models/Ki-OCR
```

构建 Docker 镜像：

```bash
docker build -f docker/Dockerfile.allinone -t ki_ocr:1.0 .
```

启动推理服务：

```bash
docker run -d --name ki-ocr --gpus '"device=0"' --ipc=host \
  -p 127.0.0.1:18000:8000 \
  -v "$PWD/models/Ki-OCR:/models/ki_ocr-model:ro" \
  ki_ocr:1.0
```

将 `device=0` 替换为可用 GPU 编号。

查看服务日志：

```bash
docker logs -f ki-ocr
```

等待日志出现 `all services are ready`，再按 Ctrl+C 退出日志查看，容器继续运行。

### 2. 全量推理及自动评分

使用 [OmniDocBench v1.6 全量数据集](https://huggingface.co/datasets/opendatalab/OmniDocBench)（1,651 页），在仓库根目录执行：

```bash
DATA="/path/to/OmniDocBench" bash eval_omnidocbench.sh
```

将 `/path/to/OmniDocBench` 替换为实际数据集路径，该目录应包含 `OmniDocBench.json` 和 `images/`。

脚本自动完成全量推理，并调用 [OmniDocBench 官方评测工具](https://github.com/opendatalab/OmniDocBench) 进行评分。Markdown 预测文件、详细评分文件及 `summary.json` 均保存在运行结束时输出的评测目录（`omnidocbench_eval_*`）中。

## 许可证与致谢

Ki-OCR 基于 [OXR](https://github.com/SoMarkAI/OXR) 蒸馏，保留原始推理流程。请参阅 [原始许可证](LICENSE)、[Apache 2.0 许可证](LICENSE-APACHE-2.0.txt) 及[第三方声明](NOTICE)。模型权重遵循 [模型仓库](https://huggingface.co/AndyLiuys/Ki-OCR) 中的许可证。

**[Powered by SoMark OXR](https://github.com/SoMarkAI/OXR)**