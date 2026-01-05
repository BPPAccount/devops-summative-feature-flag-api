from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Any, Dict, Optional

from fastapi import FastAPI, Header, HTTPException, Response
from pydantic import BaseModel, Field

app = FastAPI(title="Feature Flag API", version=os.getenv("APP_VERSION", "dev"))

FLAGS: Dict[str, Any] = {}


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def require_admin(auth_header: Optional[str]) -> None:
    token = os.getenv("ADMIN_TOKEN")
    if not token:
        raise HTTPException(status_code=500, detail="Server misconfigured: ADMIN_TOKEN is not set")

    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header")

    provided = auth_header.removeprefix("Bearer ").strip()
    if provided != token:
        raise HTTPException(status_code=403, detail="Forbidden")


class HealthResponse(BaseModel):
    status: str = "ok"
    timeUtc: str
    version: str = Field(default_factory=lambda: os.getenv("APP_VERSION", "dev"))
    commitSha: str = Field(default_factory=lambda: os.getenv("COMMIT_SHA", "unknown"))


class FlagUpsertRequest(BaseModel):
    value: Any


class FlagResponse(BaseModel):
    key: str
    value: Any
    updatedAtUtc: str


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(timeUtc=now_iso())


@app.get("/flags/{key}", response_model=FlagResponse)
def get_flag(key: str) -> FlagResponse:
    if key not in FLAGS:
        raise HTTPException(status_code=404, detail="Flag not found")
    return FlagResponse(key=key, value=FLAGS[key], updatedAtUtc=now_iso())


@app.put("/flags/{key}", response_model=FlagResponse)
def put_flag(
    key: str,
    body: FlagUpsertRequest,
    authorization: Optional[str] = Header(default=None),
) -> FlagResponse:
    require_admin(authorization)
    FLAGS[key] = body.value
    return FlagResponse(key=key, value=FLAGS[key], updatedAtUtc=now_iso())


@app.delete("/flags/{key}", status_code=204)
def delete_flag(
    key: str,
    authorization: Optional[str] = Header(default=None),
) -> Response:
    require_admin(authorization)
    if key in FLAGS:
        del FLAGS[key]
    return Response(status_code=204)
