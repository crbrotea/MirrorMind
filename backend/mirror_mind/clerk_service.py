"""Clerk Backend API service for managing user metadata (points, roles)."""

from __future__ import annotations

import logging
from datetime import datetime, timezone

import httpx

from mirror_mind.config import CLERK_SECRET_KEY

logger = logging.getLogger(__name__)

_CLERK_API_BASE = "https://api.clerk.com/v1"

_client: httpx.AsyncClient | None = None


def _get_client() -> httpx.AsyncClient:
    global _client
    if _client is None:
        _client = httpx.AsyncClient(
            base_url=_CLERK_API_BASE,
            headers={
                "Authorization": f"Bearer {CLERK_SECRET_KEY}",
                "Content-Type": "application/json",
            },
            timeout=10.0,
        )
    return _client


async def _get_user(user_id: str) -> dict:
    """Fetch a user from Clerk by ID."""
    resp = await _get_client().get(f"/users/{user_id}")
    resp.raise_for_status()
    return resp.json()


async def get_user_points(user_id: str) -> int:
    """Get the points balance for a user (default 0)."""
    user = await _get_user(user_id)
    return int(user.get("public_metadata", {}).get("points", 0))


async def get_user_role(user_id: str) -> str:
    """Get the role for a user (default 'user')."""
    user = await _get_user(user_id)
    return str(user.get("public_metadata", {}).get("role", "user"))


async def update_user_points(user_id: str, points: int) -> dict:
    """Set the points balance for a user via Clerk Backend API."""
    user = await _get_user(user_id)
    metadata = user.get("public_metadata", {})
    metadata["points"] = points
    metadata["pointsUpdatedAt"] = datetime.now(timezone.utc).isoformat()

    resp = await _get_client().patch(
        f"/users/{user_id}/metadata",
        json={"public_metadata": metadata},
    )
    resp.raise_for_status()
    logger.info("Updated points for user %s to %d", user_id, points)
    return resp.json()


async def list_all_users(limit: int = 100, offset: int = 0) -> list[dict]:
    """List users from Clerk with their metadata."""
    resp = await _get_client().get(
        "/users",
        params={"limit": limit, "offset": offset, "order_by": "-created_at"},
    )
    resp.raise_for_status()
    data = resp.json()

    users = data if isinstance(data, list) else data.get("data", [])
    return [
        {
            "id": u["id"],
            "email": (u.get("email_addresses") or [{}])[0].get("email_address", ""),
            "first_name": u.get("first_name"),
            "last_name": u.get("last_name"),
            "image_url": u.get("image_url"),
            "points": int(u.get("public_metadata", {}).get("points", 0)),
            "role": str(u.get("public_metadata", {}).get("role", "user")),
            "created_at": u.get("created_at"),
            "last_sign_in_at": u.get("last_sign_in_at"),
        }
        for u in users
    ]
