# Modified for Ki-OCR (2026-11-15); derived from the SoMark upstream project.
import os
import cv2
import numpy as np
from ki_ocr.pipeline.models import Block, ContentFormat
from ki_ocr.config.settings import settings
from ki_ocr.pipeline.image_assets import image_assets

def postprocess_picture(block: Block, image: np.ndarray, file_name: str, page_num: int) -> Block:
    """Save picture crop and return markdown reference."""
    assets = image_assets.get()
    if assets is not None:
        block.content = f"![]({assets.save(image)})"
        block.format = ContentFormat.MARKDOWN
        return block
    # filename without extension
    base_name = os.path.splitext(os.path.basename(file_name))[0]
    out_dir = os.path.join(settings.pipeline.image_output_dir, base_name, "imgs")
    os.makedirs(out_dir, exist_ok=True)
    
    img_name = f"{page_num}_{block.idx}.png"
    img_path = os.path.join(out_dir, img_name)
    cv2.imwrite(img_path, image)
    
    # create markdown reference
    block.content = f"![]({img_path})"
    block.format = ContentFormat.MARKDOWN
    return block
