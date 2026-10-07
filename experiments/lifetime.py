"""How long does a FastAPI dependency live?

A per-request dependency, the same one asked for twice in one
request, and an object built once in the lifespan.
"""
import os
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Request

built = {"per_request": 0, "lifespan": 0}


class PaymentGateway:
    def __init__(self, lifetime: str):
        built[lifetime] += 1


def gateway() -> PaymentGateway:
    return PaymentGateway("per_request")


def fraud_check(g: PaymentGateway = Depends(gateway)):
    return g


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.gateway = PaymentGateway("lifespan")
    yield


app = FastAPI(lifespan=lifespan)


@app.post("/charge")
def charge(
    request: Request,
    g: PaymentGateway = Depends(gateway),
    f: PaymentGateway = Depends(fraud_check),
) -> dict:
    return {
        "same_object_twice_in_one_request": g is f,
        "built": built,
        "pid": os.getpid(),
        "lifespan_object": id(request.app.state.gateway),
    }
