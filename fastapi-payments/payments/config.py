import os

DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql+psycopg://payments:payments"
    "@localhost:5443/payments",
)
PROVIDER_URL = os.environ.get(
    "PROVIDER_URL", "http://127.0.0.1:8097"
)
