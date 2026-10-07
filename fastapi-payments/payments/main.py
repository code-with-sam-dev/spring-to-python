from contextlib import asynccontextmanager

from fastapi import FastAPI

from payments import db
from payments.api import router
from payments.config import PROVIDER_URL
from payments.provider import ProviderClient


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.sessions = db.connect()
    app.state.provider = ProviderClient(PROVIDER_URL)
    yield
    app.state.provider.close()


app = FastAPI(lifespan=lifespan)
app.include_router(router)
