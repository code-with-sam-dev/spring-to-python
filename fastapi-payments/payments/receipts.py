import time

from sqlalchemy import text
from sqlalchemy.orm import sessionmaker


class Receipts:
    """Stands in for a slow email provider."""

    def __init__(self, sessions: sessionmaker):
        self.sessions = sessions

    def send(self, payment_id: int) -> None:
        time.sleep(2)
        with self.sessions.begin() as session:
            session.execute(
                text("INSERT INTO receipts (payment_id)"
                     " VALUES (:id)"),
                {"id": payment_id},
            )
