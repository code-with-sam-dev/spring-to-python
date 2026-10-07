package dev.codewithsam.payments;

import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

// The payment provider, over a blocking HTTP client.
@Component
public class ProviderClient {

    private final RestClient http;

    public ProviderClient(
            @Value("${provider.url}") String url) {
        this.http = RestClient.create(url);
    }

    public void charge(String orderRef, long amount) {
        http.post().uri("/charges")
                .body(Map.of("order_ref", orderRef,
                        "amount", amount))
                .retrieve().toBodilessEntity();
    }
}
