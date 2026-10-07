package dev.codewithsam.payments;

import java.util.Optional;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PaymentService {

    private final PaymentStore store;
    private final ProviderClient provider;
    private final Pricing pricing;

    public PaymentService(PaymentStore store,
            ProviderClient provider, Pricing pricing) {
        this.store = store;
        this.provider = provider;
        this.pricing = pricing;
    }

    @Transactional
    public Payment create(NewPayment in) {
        long amount = pricing.total(
                in.unitPrice(), in.quantity());
        Optional<Long> found = store.find(in.orderRef());
        long id;
        if (found.isEmpty()) {
            provider.charge(in.orderRef(), amount);
            id = store.insert(in, amount);
        } else {
            id = found.get();
        }
        return new Payment(id, in.orderRef(), amount,
                in.currency(), "CAPTURED");
    }
}
