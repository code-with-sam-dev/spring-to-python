from collections.abc import Iterator

from fastapi import Depends, Request
from sqlalchemy.orm import Session

from payments.receipts import Receipts
from payments.service import PaymentService
from payments.store import PaymentStore


def get_session(request: Request) -> Iterator[Session]:
    with request.app.state.sessions() as session:
        with session.begin():
            yield session


def payment_service(
    request: Request,
    session: Session = Depends(
        get_session, scope="function"
    ),
) -> PaymentService:
    provider = request.app.state.provider
    return PaymentService(PaymentStore(session), provider)


def receipts(request: Request) -> Receipts:
    return Receipts(request.app.state.sessions)
