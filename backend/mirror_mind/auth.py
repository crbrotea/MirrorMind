"""Clerk JWT verification for MirrorMind backend."""

from __future__ import annotations

import logging
from typing import Optional

import jwt
from jwt import PyJWKClient

from mirror_mind.config import CLERK_JWKS_URL

logger = logging.getLogger("mirrormind.auth")

_jwks_client: Optional[PyJWKClient] = None


def _get_jwks_client() -> PyJWKClient:
    global _jwks_client
    if _jwks_client is None:
        if not CLERK_JWKS_URL:
            raise ValueError("CLERK_JWKS_URL is not configured")
        _jwks_client = PyJWKClient(CLERK_JWKS_URL, cache_keys=True, lifespan=3600)
    return _jwks_client


async def verify_clerk_token(token: str) -> Optional[str]:
    """Verify a Clerk JWT and return the user_id (sub claim).

    Returns None if verification fails.
    """
    try:
        client = _get_jwks_client()
        signing_key = client.get_signing_key_from_jwt(token)
        payload = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            options={
                "verify_exp": True,
                "verify_aud": False,
            },
        )
        user_id = payload.get("sub")
        if not user_id:
            logger.warning("JWT missing sub claim")
            return None
        return user_id
    except jwt.ExpiredSignatureError:
        logger.warning("Clerk JWT expired")
        return None
    except jwt.InvalidTokenError as e:
        logger.warning("Invalid Clerk JWT: %s", e)
        return None
    except Exception as e:
        logger.error("Unexpected error verifying Clerk JWT: %s", e)
        return None
