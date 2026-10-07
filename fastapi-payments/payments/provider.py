import httpx


class ProviderClient:
    """The payment provider, over a blocking client."""

    def __init__(self, base_url: str):
        self.http = httpx.Client(base_url=base_url,
                                 timeout=10)

    def charge(self, order_ref: str, amount: int) -> None:
        body = {"order_ref": order_ref, "amount": amount}
        response = self.http.post("/charges", json=body)
        response.raise_for_status()

    def close(self) -> None:
        self.http.close()
