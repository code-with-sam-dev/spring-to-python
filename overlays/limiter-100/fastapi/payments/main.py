from contextlib import asynccontextmanager

from anyio import to_thread

from fastapi import FastAPI

from payments import db
from payments.api import router
from payments.config import PROVIDER_URL
from payments.provider import ProviderClient


@asynccontextmanager
async def lifespan(app: FastAPI):
    limiter = to_thread.current_default_thread_limiter()
    limiter.total_tokens = 100
    app.state.sessions = db.connect()
    app.state.provider = ProviderClient(PROVIDER_URL)
    yield
    app.state.provider.close()


app = FastAPI(lifespan=lifespan)
app.include_router(router)
