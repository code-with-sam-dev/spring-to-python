from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

from payments.config import DATABASE_URL
SCHEMA = """
CREATE TABLE IF NOT EXISTS payments (
    id        BIGSERIAL PRIMARY KEY,
    order_ref TEXT   NOT NULL UNIQUE,
    total     BIGINT NOT NULL,
    currency  TEXT   NOT NULL,
    status    TEXT   NOT NULL);
CREATE TABLE IF NOT EXISTS receipts (
    id         BIGSERIAL PRIMARY KEY,
    payment_id BIGINT NOT NULL);
"""


def connect() -> sessionmaker:
    engine = create_engine(DATABASE_URL)
    with engine.begin() as conn:
        conn.execute(text(SCHEMA))
    return sessionmaker(engine)
