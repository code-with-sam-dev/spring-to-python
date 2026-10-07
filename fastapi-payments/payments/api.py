from fastapi import APIRouter, BackgroundTasks, Depends

from payments.deps import payment_service, receipts
from payments.receipts import Receipts
from payments.schemas import NewPayment, Payment
from payments.service import PaymentService

router = APIRouter()


@router.get("/health")
async def health() -> dict[str, str]:
    return {"status": "UP"}


@router.post("/payments", status_code=201)
def create(
    new: NewPayment,
    tasks: BackgroundTasks,
    service: PaymentService = Depends(payment_service),
    receipt_sender: Receipts = Depends(receipts),
) -> Payment:
    payment = service.create(new)
    tasks.add_task(receipt_sender.send, payment.id)
    return payment
