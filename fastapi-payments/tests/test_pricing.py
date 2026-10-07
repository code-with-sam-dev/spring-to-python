from payments.pricing import total


def test_total_multiplies_unit_price_by_quantity():
    assert total(500, 3) == 1500
