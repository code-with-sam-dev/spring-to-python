package dev.codewithsam.payments;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;
import org.junit.jupiter.api.Test;

class PaymentServiceTest {

    private final PaymentStore store = mock(PaymentStore.class);
    private final ProviderClient provider = mock(ProviderClient.class);
    private final PaymentService service =
            new PaymentService(store, provider, new Pricing());

    private final NewPayment order =
            new NewPayment("order-42", 500, 3, "GBP");

    @Test
    void chargesTheTotalAndSavesIt() {
        when(store.find("order-42")).thenReturn(Optional.empty());
        when(store.insert(order, 1500)).thenReturn(1L);

        Payment payment = service.create(order);

        verify(provider).charge("order-42", 1500);
        assertThat(payment.total()).isEqualTo(1500);
        assertThat(payment.status()).isEqualTo("CAPTURED");
    }

    @Test
    void aRepeatedOrderRefIsNotChargedAgain() {
        when(store.find("order-42")).thenReturn(Optional.of(7L));

        Payment payment = service.create(order);

        verify(provider, never()).charge(any(), anyLong());
        assertThat(payment.id()).isEqualTo(7);
    }
}
