from payments.schemas import NewPayment
from payments.service import PaymentService


class FakeStore:
    def __init__(self, existing=None):
        self.saved = []
        self.existing = existing or {}

    def find(self, order_ref):
        return self.existing.get(order_ref)

    def insert(self, payment, total):
        self.saved.append((payment, total))
        return len(self.saved)


class FakeProvider:
    def __init__(self):
        self.charged = []

    def charge(self, order_ref, amount):
        self.charged.append((order_ref, amount))


def new_payment(order_ref="order-42"):
    return NewPayment(order_ref=order_ref, unit_price=500, quantity=3, currency="GBP")


def test_create_charges_the_total_and_saves_it():
    store, provider = FakeStore(), FakeProvider()
    payment = PaymentService(store, provider).create(new_payment())
    assert provider.charged == [("order-42", 1500)]
    assert payment.total == 1500 and payment.status == "CAPTURED"


def test_a_repeated_order_ref_is_not_charged_again():
    existing = {"order-42": 7}
    store, provider = FakeStore(existing), FakeProvider()
    payment = PaymentService(store, provider).create(new_payment())
    assert provider.charged == []
    assert payment.id == 7
