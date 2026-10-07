"""The thread-limit experiment, with no database in the way.

Each payment calls the 2 second provider stub with a blocking
client. RAISE_LIMIT=1 raises AnyIO's limiter from 40 to 100.
"""
import os
from contextlib import asynccontextmanager

import httpx
from anyio import to_thread
from fastapi import FastAPI

PROVIDER = os.environ.get("PROVIDER_URL", "http://127.0.0.1:8097")


@asynccontextmanager
async def lifespan(app: FastAPI):
    limiter = to_thread.current_default_thread_limiter()
    if os.environ.get("RAISE_LIMIT"):
        limiter.total_tokens = 100
    app.state.limit = limiter.total_tokens
    yield


app = FastAPI(lifespan=lifespan)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "UP"}


@app.post("/payments/blocking-in-async")
async def blocking_in_async() -> dict[str, str]:
    with httpx.Client(timeout=30) as client:
        return client.post(f"{PROVIDER}/charges").json()


@app.post("/payments/blocking")
def blocking() -> dict[str, str]:
    with httpx.Client(timeout=30) as client:
        return client.post(f"{PROVIDER}/charges").json()


@app.post("/payments/awaited")
async def awaited() -> dict[str, str]:
    async with httpx.AsyncClient(timeout=30) as client:
        return (await client.post(f"{PROVIDER}/charges")).json()
