"""Pytest fixtures for MirrorMind backend tests.

Starts the FastAPI app in TEST_MODE on a random available port.
"""

from __future__ import annotations

import asyncio
import os
import socket

import pytest
import pytest_asyncio
import uvicorn

# Force test mode before importing the app
os.environ["TEST_MODE"] = "true"
os.environ["FIREBASE_PROJECT_ID"] = ""  # Force in-memory gallery


def _find_free_port() -> int:
    """Find an available TCP port on localhost."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


class _UvicornServer:
    """Run uvicorn in a background asyncio task."""

    def __init__(self, app: str, host: str, port: int):
        self.config = uvicorn.Config(app, host=host, port=port, log_level="warning")
        self.server = uvicorn.Server(self.config)
        self._task: asyncio.Task | None = None

    async def start(self) -> None:
        self._task = asyncio.create_task(self.server.serve())
        # Wait until server is accepting connections
        for _ in range(50):
            await asyncio.sleep(0.1)
            if self.server.started:
                break

    async def stop(self) -> None:
        self.server.should_exit = True
        if self._task:
            await self._task


@pytest_asyncio.fixture(scope="session")
def event_loop():
    """Create a single event loop for the whole test session."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture(scope="session")
async def backend_server(event_loop):
    """Start the FastAPI server in test mode and return its base URL."""
    port = _find_free_port()
    server = _UvicornServer("main:app", "127.0.0.1", port)
    await server.start()
    yield f"http://127.0.0.1:{port}"
    await server.stop()


@pytest.fixture(scope="session")
def backend_url(backend_server):
    """HTTP base URL for the test server."""
    return backend_server


@pytest.fixture(scope="session")
def ws_url(backend_server):
    """WebSocket base URL for the test server."""
    return backend_server.replace("http://", "ws://")
