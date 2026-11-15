# Modified for Ki-OCR (2026-11-15); derived from the SoMark upstream project.
import asyncio

import pytest

from ki_ocr.config.settings import settings
from ki_ocr.server.app import app, lifespan


@pytest.mark.parametrize(
    ("layout_url", "ki_ocr_url", "missing_name"),
    [
        (None, "http://ki_ocr:8080/v1", "layout_analyze_model.url"),
        ("http://layout:8081", None, "ki_ocr_model.url"),
    ],
)
def test_direct_asgi_lifespan_requires_both_model_urls(
    monkeypatch,
    layout_url,
    ki_ocr_url,
    missing_name,
):
    monkeypatch.setattr(settings.layout_analyze_model, "url", layout_url)
    monkeypatch.setattr(settings.ki_ocr_model, "url", ki_ocr_url)

    async def scenario():
        with pytest.raises(ValueError, match=missing_name):
            async with lifespan(app):
                pass

    asyncio.run(scenario())


def test_lifespan_closes_both_clients_when_one_close_fails(monkeypatch):
    closed = []
    monkeypatch.setattr(settings.layout_analyze_model, "url", "http://layout:8081")
    monkeypatch.setattr(settings.ki_ocr_model, "url", "http://ki_ocr:8080/v1")

    async def close_layout():
        closed.append("layout")
        raise RuntimeError("layout close failed")

    async def close_ki_ocr():
        closed.append("ki_ocr")

    monkeypatch.setattr("ki_ocr.server.app.layout_client.aclose", close_layout)
    monkeypatch.setattr("ki_ocr.server.app.model_client.aclose", close_ki_ocr)

    async def scenario():
        with pytest.raises(RuntimeError, match="layout close failed"):
            async with lifespan(app):
                pass

    asyncio.run(scenario())

    assert closed == ["layout", "ki_ocr"]
