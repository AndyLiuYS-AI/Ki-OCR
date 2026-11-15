# Modified for Ki-OCR (2026-11-15); derived from the SoMark upstream project.
import asyncio
from contextlib import asynccontextmanager
from pathlib import Path
from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from ki_ocr.config.settings import settings
from ki_ocr.model.client import model_client
from ki_ocr.model.layout_client import layout_client
from ki_ocr.server.queue.memory_store import MemoryTaskStore
from ki_ocr.server.demo_api import router as demo_router, start_demo, stop_demo


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings.validate_for_server()
    app.state.task_store = MemoryTaskStore()
    await start_demo(app)
    try:
        yield
    finally:
        demo_close_results = await asyncio.gather(stop_demo(app), return_exceptions=True)
        close_results = await asyncio.gather(
            layout_client.aclose(),
            model_client.aclose(),
            return_exceptions=True,
        )
        for result in demo_close_results + close_results:
            if isinstance(result, BaseException):
                raise result


app = FastAPI(
    title="KiOCR Server", version="0.1.0", lifespan=lifespan,
    description="Ki-OCR document parsing API. [Powered by SoMark OXR](https://github.com/SoMarkAI/OXR).",
)

from ki_ocr.server.routes import router

app.include_router(router, prefix="/v1")

# KiOCR Online Demo — bundled UI and its dedicated API endpoints.
app.include_router(demo_router, prefix="/v1")
DEMO_DIR = Path(__file__).parent / "demo"


@app.get("/demo", include_in_schema=False)
@app.get("/demo/", include_in_schema=False)
async def demo_page():
    return FileResponse(DEMO_DIR / "index.html", headers={"Cache-Control": "no-cache"})


app.mount("/demo/assets", StaticFiles(directory=DEMO_DIR, check_dir=False), name="demo-assets")
