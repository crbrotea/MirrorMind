"""Test the health check and gallery REST endpoints."""

from __future__ import annotations

import httpx
import pytest


@pytest.mark.asyncio
async def test_health_endpoint(backend_url: str) -> None:
    """Health check should return 200 with status=healthy."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(f"{backend_url}/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "healthy"
    assert data["service"] == "mirrormind"
    assert "timestamp" in data


@pytest.mark.asyncio
async def test_gallery_empty_user(backend_url: str) -> None:
    """Gallery for a non-existent user should return empty list."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(f"{backend_url}/api/gallery/nonexistent-user")
    assert resp.status_code == 200
    data = resp.json()
    assert data["gallery"] == []


@pytest.mark.asyncio
async def test_gallery_detail_not_found(backend_url: str) -> None:
    """Gallery detail for non-existent ID should return 404."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(f"{backend_url}/api/gallery/user/fake-gallery-id")
    assert resp.status_code == 404
