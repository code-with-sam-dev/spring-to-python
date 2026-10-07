from pydantic import BaseModel, Field


class NewPayment(BaseModel):
    order_ref: str = Field(min_length=1)
    unit_price: int = Field(gt=0)
    quantity: int = Field(gt=0)
    currency: str = Field(min_length=3, max_length=3)


class Payment(BaseModel):
    id: int
    order_ref: str
    total: int
    currency: str
    status: str
