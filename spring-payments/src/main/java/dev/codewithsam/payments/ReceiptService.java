package dev.codewithsam.payments;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

// Stands in for a slow email provider.
@Service
public class ReceiptService {

    private final JdbcClient jdbc;

    public ReceiptService(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Async
    public void send(long paymentId)
            throws InterruptedException {
        Thread.sleep(2000);
        jdbc.sql("INSERT INTO receipts (payment_id)"
                        + " VALUES (?)")
                .param(paymentId).update();
    }
}
