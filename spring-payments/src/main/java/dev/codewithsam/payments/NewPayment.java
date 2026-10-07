package dev.codewithsam.payments;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record NewPayment(
        @NotBlank String orderRef,
        @Positive long unitPrice,
        @Positive int quantity,
        @Size(min = 3, max = 3) String currency) {
}
