# Modified for Ki-OCR (2026-11-15); derived from the SoMark upstream project.
import re
from ki_ocr.pipeline.models import Block, ContentFormat
from ki_ocr.pipeline.postprocess.formula_postprocess import move_formula_numbering_outside_math

def postprocess_text(block: Block, raw_text: str) -> Block:
    """Clean up text block output."""
    text = raw_text.strip()
    # Remove some excessive whitespaces
    text = re.sub(r'\n+', '\n', text)
    text = move_formula_numbering_outside_math(text)
    block.content = text
    block.format = ContentFormat.TEXT
    return block
