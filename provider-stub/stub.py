"""A payment provider that answers a charge in 2 seconds.

It records the client connection each charge arrived on,
so the scripts can count the connections an app opened.
"""
import asyncio
import os

from fastapi import FastAPI, Request

DELAY = float(os.environ.get("PROVIDER_DELAY", "2"))
app = FastAPI()
connections: list[str] = []


@app.post("/charges")
async def charge(request: Request) -> dict[str, str]:
    c = request.client
    where = f"{c.host}:{c.port}" if c else "?"
    connections.append(where)
    await asyncio.sleep(DELAY)
    return {"status": "captured"}


@app.get("/connections")
async def seen() -> dict[str, int]:
    return {"charges": len(connections),
            "distinct_connections": len(set(connections))}


@app.delete("/connections")
async def reset() -> None:
    connections.clear()
