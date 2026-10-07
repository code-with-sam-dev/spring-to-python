from fastapi.testclient import TestClient

from payments.deps import payment_service, receipts
from payments.main import app
from payments.schemas import Payment


class StubService:
    def create(self, new):
        return Payment(id=1, order_ref=new.order_ref, total=new.unit_price * new.quantity,
                       currency=new.currency, status="CAPTURED")


class NoReceipts:
    def send(self, payment_id):
        pass


def client():
    app.dependency_overrides[payment_service] = lambda: StubService()
    app.dependency_overrides[receipts] = lambda: NoReceipts()
    return TestClient(app)


def test_a_valid_payment_is_created():
    r = client().post("/payments", json={"order_ref": "order-42", "unit_price": 500, "quantity": 3, "currency": "GBP"})
    assert r.status_code == 201
    assert r.json()["total"] == 1500


def test_a_negative_unit_price_is_rejected_with_422():
    r = client().post("/payments", json={"order_ref": "order-42", "unit_price": -5, "quantity": 3, "currency": "GBP"})
    assert r.status_code == 422
    assert r.json()["detail"][0]["loc"] == ["body", "unit_price"]


def test_health_answers():
    assert client().get("/health").json() == {"status": "UP"}
