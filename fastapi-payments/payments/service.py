from payments.pricing import total
from payments.provider import ProviderClient
from payments.schemas import NewPayment, Payment
from payments.store import PaymentStore


class PaymentService:

    def __init__(self, store: PaymentStore,
                 provider: ProviderClient):
        self.store = store
        self.provider = provider

    def create(self, new: NewPayment) -> Payment:
        amount = total(new.unit_price, new.quantity)
        found = self.store.find(new.order_ref)
        if found is None:
            self.provider.charge(new.order_ref, amount)
            found = self.store.insert(new, amount)
        return Payment(
            id=found, order_ref=new.order_ref,
            total=amount, currency=new.currency,
            status="CAPTURED",
        )
