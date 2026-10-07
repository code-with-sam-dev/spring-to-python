package dev.codewithsam.payments;

public record Payment(
        long id, String orderRef, long total,
        String currency, String status) {
}
