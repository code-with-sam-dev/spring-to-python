CREATE TABLE IF NOT EXISTS payments (
    id        BIGSERIAL PRIMARY KEY,
    order_ref TEXT   NOT NULL UNIQUE,
    total     BIGINT NOT NULL,
    currency  TEXT   NOT NULL,
    status    TEXT   NOT NULL);
CREATE TABLE IF NOT EXISTS receipts (
    id         BIGSERIAL PRIMARY KEY,
    payment_id BIGINT NOT NULL);
