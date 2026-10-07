package dev.codewithsam.payments;

import org.springframework.stereotype.Component;

@Component
public class Pricing {

    public long total(long unitPrice, int quantity) {
        return unitPrice * quantity;
    }
}
