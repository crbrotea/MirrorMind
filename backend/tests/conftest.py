"""Pytest fixtures for MirrorMind backend tests.

Starts the FastAPI app in TEST_MODE as a subprocess on a random port.
"""

from __future__ import annotations

import os
import socket
import subprocess
import sys
import time

import httpx
import pytest

# Force test mode
os.environ["TEST_MODE"] = "true"
os.environ["FIREBASE_PROJECT_ID"] = ""


def _find_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def _wait_for_server(url: str, timeout: float = 15.0) -> bool:
    """Poll until the server is ready or timeout."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            resp = httpx.get(f"{url}/health", timeout=2.0)
            if resp.status_code == 200:
                return True
        except Exception:
            pass
        time.sleep(0.3)
    return False


@pytest.fixture(scope="session")
def backend_server():
    """Start the backend as a subprocess in TEST_MODE and yield the base URL."""
    port = _find_free_port()
    backend_dir = os.path.join(os.path.dirname(__file__), "..")
    venv_python = os.path.join(backend_dir, ".venv", "bin", "python")

    env = {**os.environ, "TEST_MODE": "true", "FIREBASE_PROJECT_ID": "", "LOG_LEVEL": "WARNING"}

    proc = subprocess.Popen(
        [
            venv_python, "-m", "uvicorn", "main:app",
            "--host", "127.0.0.1", "--port", str(port),
        ],
        cwd=backend_dir,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    base_url = f"http://127.0.0.1:{port}"
    if not _wait_for_server(base_url):
        proc.terminate()
        stdout, stderr = proc.communicate(timeout=5)
        raise RuntimeError(
            f"Backend failed to start on port {port}.\n"
            f"stdout: {stdout.decode()}\nstderr: {stderr.decode()}"
        )

    yield base_url

    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()


@pytest.fixture(scope="session")
def backend_url(backend_server):
    return backend_server


@pytest.fixture(scope="session")
def ws_url(backend_server):
    return backend_server.replace("http://", "ws://")
