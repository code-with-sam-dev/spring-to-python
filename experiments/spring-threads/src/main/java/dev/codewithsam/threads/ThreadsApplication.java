package dev.codewithsam.threads;

import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestClient;

// The thread-limit experiment's Spring side, with no database
// in the way: each payment calls the 2 second provider stub.
@SpringBootApplication
@RestController
public class ThreadsApplication {

    private final RestClient provider;

    public ThreadsApplication(
            @Value("${provider.url}") String url) {
        this.provider = RestClient.create(url);
    }

    public static void main(String[] args) {
        SpringApplication.run(ThreadsApplication.class, args);
    }

    @GetMapping("/health")
    Map<String, String> health() {
        return Map.of("status", "UP");
    }

    @PostMapping("/payments/blocking")
    Map<?, ?> blocking() {
        return provider.post().uri("/charges")
                .retrieve().body(Map.class);
    }
}
