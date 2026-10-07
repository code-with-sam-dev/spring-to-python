package dev.codewithsam.payments;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class PricingTest {

    @Test
    void totalMultipliesUnitPriceByQuantity() {
        assertThat(new Pricing().total(500, 3)).isEqualTo(1500);
    }
}
