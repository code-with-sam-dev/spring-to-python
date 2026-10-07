package dev.codewithsam.payments;

import java.util.Optional;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

// The same SQL as the FastAPI store.
@Repository
public class PaymentStore {

    private final JdbcClient jdbc;

    public PaymentStore(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public Optional<Long> find(String orderRef) {
        return jdbc.sql("SELECT id FROM payments"
                        + " WHERE order_ref = ?")
                .param(orderRef)
                .query(Long.class).optional();
    }

    public long insert(NewPayment p, long total) {
        return jdbc.sql("INSERT INTO payments"
                        + " (order_ref, total,"
                        + " currency, status)"
                        + " VALUES (?, ?, ?, 'CAPTURED')"
                        + " RETURNING id")
                .params(p.orderRef(), total, p.currency())
                .query(Long.class).single();
    }
}
