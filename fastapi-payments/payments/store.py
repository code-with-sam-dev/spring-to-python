from sqlalchemy import text
from sqlalchemy.orm import Session

from payments.schemas import NewPayment


class PaymentStore:
    """The same SQL as the Spring store."""

    def __init__(self, session: Session):
        self.session = session

    def find(self, order_ref: str) -> int | None:
        return self.session.execute(
            text("SELECT id FROM payments"
                 " WHERE order_ref = :ref"),
            {"ref": order_ref},
        ).scalar_one_or_none()

    def insert(self, p: NewPayment, total: int) -> int:
        return self.session.execute(
            text(
                "INSERT INTO payments"
                " (order_ref, total, currency, status)"
                " VALUES (:ref, :total, :currency,"
                " 'CAPTURED')"
                " RETURNING id"
            ),
            {"ref": p.order_ref, "total": total,
             "currency": p.currency},
        ).scalar_one()
