"""Send N concurrent POSTs and time them, while asking /health.

  load.py <base url> <path> <n> [--body json] [--same-ref]

Prints one line a person can read and one JSON line a script can
assert on.
"""
import argparse
import asyncio
import json
import time

import httpx


async def run(base: str, path: str, n: int, body: str | None,
              same_ref: bool) -> dict:
    limits = httpx.Limits(max_connections=n + 10)
    async with httpx.AsyncClient(base_url=base, timeout=120,
                                 limits=limits) as client:

        def payload(i: int):
            if body is None:
                return None
            data = json.loads(body)
            key = "order_ref" if "order_ref" in data else "orderRef"
            if not same_ref:
                data[key] = f"{data[key]}-{i}"
            return data

        async def health() -> float:
            await asyncio.sleep(0.2)
            start = time.perf_counter()
            await client.get("/health")
            return time.perf_counter() - start

        start = time.perf_counter()
        results = await asyncio.gather(
            *[client.post(path, json=payload(i)) for i in range(n)],
            health(),
        )
        took = time.perf_counter() - start
    codes: dict[int, int] = {}
    for r in results[:-1]:
        codes[r.status_code] = codes.get(r.status_code, 0) + 1
    return {"n": n, "seconds": round(took, 2),
            "health_seconds": round(results[-1], 2),
            "status_codes": codes}


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("base")
    p.add_argument("path")
    p.add_argument("n", type=int)
    p.add_argument("--body")
    p.add_argument("--same-ref", action="store_true")
    a = p.parse_args()
    r = asyncio.run(run(a.base, a.path, a.n, a.body, a.same_ref))
    print(f"{r['n']} payments in {r['seconds']} s,"
          f" /health answered in {r['health_seconds']} s,"
          f" status codes {r['status_codes']}")
    print("RESULT " + json.dumps(r))


if __name__ == "__main__":
    main()
