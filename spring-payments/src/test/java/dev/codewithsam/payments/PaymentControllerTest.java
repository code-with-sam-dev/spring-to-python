package dev.codewithsam.payments;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(PaymentController.class)
class PaymentControllerTest {

    @Autowired
    MockMvc mvc;

    @MockitoBean
    PaymentService payments;

    @MockitoBean
    ReceiptService receipts;

    @Test
    void aValidPaymentIsCreated() throws Exception {
        when(payments.create(any())).thenReturn(
                new Payment(1, "order-42", 1500, "GBP", "CAPTURED"));
        mvc.perform(post("/payments").contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"orderRef":"order-42","unitPrice":500,
                     "quantity":3,"currency":"GBP"}"""))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.total").value(1500));
    }

    @Test
    void aNegativeUnitPriceIsRejectedWith400() throws Exception {
        mvc.perform(post("/payments").contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"orderRef":"order-42","unitPrice":-5,
                     "quantity":3,"currency":"GBP"}"""))
            .andExpect(status().isBadRequest());
    }

    @Test
    void healthAnswers() throws Exception {
        mvc.perform(get("/health"))
            .andExpect(jsonPath("$.status").value("UP"));
    }
}
