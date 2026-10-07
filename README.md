# Spring Boot to Python (FastAPI): where your code runs

The code behind the Code with Sam video. The same small payments service built
twice, once with Spring Boot and once with FastAPI, layer for layer, and one
script that measures every number in the video.

| | Spring Boot | FastAPI |
|---|---|---|
| Version | Spring Boot 4.1.1, Java 25 | FastAPI 0.142.2, Python 3.14.8 |
| Web layer | `PaymentController` | `payments/api.py` |
| Service | `PaymentService`, `@Transactional` | `payments/service.py` |
| Pricing | `Pricing` | `payments/pricing.py` |
| Provider client | `ProviderClient`, `RestClient` | `payments/provider.py`, `httpx` |
| Store | `PaymentStore`, `JdbcClient` | `payments/store.py`, SQLAlchemy 2.1.4 |
| Receipts | `ReceiptService`, `@Async` | `payments/receipts.py`, `BackgroundTasks` |
| Validation | Bean Validation, 400 | Pydantic 2.13.5, 422 |

Versions as of October 2026.

## Run it

You need Docker, JDK 25 and Python 3.14.

```bash
python3.14 -m venv .venv
.venv/bin/pip install \
  fastapi==0.142.2 uvicorn==0.54.0 pydantic==2.13.5 httpx==0.28.1 \
  sqlalchemy==2.1.4 "psycopg[binary]==3.3.6" pytest==9.1.1 mypy
scripts/verify.sh
```

`scripts/verify.sh` starts Postgres from `compose.yaml` and the slow payment
provider from `provider-stub/`, runs both test suites, then measures every
claim. Each claim asserts what it expects and stops the script if it does not
hold. The transcripts land in `evidence/`.

## What is in here

- `spring-payments/` and `fastapi-payments/`: the two services, correct versions.
- `overlays/`: one deliberate change each, laid over a scratch copy of an app,
  never the app itself.
  - `async-blocking`: the route made `async def` while it still calls a blocking client.
  - `no-transaction`: the session without `session.begin()`.
  - `provider-per-request`: the provider client built on every request.
  - `in-memory-idempotency`: duplicate payments tracked in process memory.
  - `limiter-100`: AnyIO's thread limiter raised from 40 to 100.
- `experiments/`: small apps that isolate one effect, with no database in the
  way: the thread limit, object lifetime, and type hints.
- `provider-stub/`: a payment provider that answers in 2 seconds and counts the
  connections it was called on.

## The claims, and where each is measured

| Claim | Evidence |
|---|---|
| A blocking client inside `async def` holds up every request, `/health` included | `hook-*.log`, `threads-fastapi.log` |
| `total("5", 3)` returns `'555'`; mypy rejects it | `types.log` |
| An invalid body is 422 in FastAPI and 400 in Spring | `validation.log` |
| A session without a transaction answers 201 and saves nothing | `transaction-*.log` |
| A dependency lives per request; a lifespan object per process | `lifetime*.log` |
| `BackgroundTasks` and in-memory `@Async` both lose work when the process dies | `background*.log` |
| `--workers 4` is four processes with four copies of in-memory state | `workers-*.log` |
| Sync routes share AnyIO's 40-token thread limiter | `threads-*.log` |

## Honest notes

- The thread-limit numbers come from `experiments/`, because in the full apps the
  database connection pool is the first limit you hit: each request holds a
  connection while it waits for the provider. Raising the thread limit without
  looking at the pool and at the provider moves the queue, it does not remove it.
- Idempotency in both services is a lookup followed by a unique column. Two
  concurrent requests with the same reference can both pass the lookup; the
  unique column then refuses the second row, after the provider has charged it.
  Production code reserves the reference first. The video uses sequential
  requests and says so.
- Several Spring replicas have the same in-memory state problem as several
  Uvicorn workers. What differs is that one flag creates it on one machine.
