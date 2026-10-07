package dev.codewithsam.payments;

import jakarta.validation.Valid;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class PaymentController {

    private final PaymentService payments;
    private final ReceiptService receipts;

    public PaymentController(PaymentService payments,
            ReceiptService receipts) {
        this.payments = payments;
        this.receipts = receipts;
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "UP");
    }

    @PostMapping("/payments")
    @ResponseStatus(HttpStatus.CREATED)
    public Payment create(
            @Valid @RequestBody NewPayment in)
            throws InterruptedException {
        Payment payment = payments.create(in);
        receipts.send(payment.id());
        return payment;
    }
}
