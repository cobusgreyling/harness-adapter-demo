DISCOUNTS = {"SAVE10": 10, "HALF": 50}  # code -> percent off


def line_total(item):
    """Price of one order line, in cents."""
    return item.unit_price_cents


def subtotal(items):
    return sum(line_total(item) for item in items)


def apply_discount(cents, code):
    """Take the code's percentage off. Unknown or missing codes change nothing."""
    percent = DISCOUNTS.get(code, 0)
    return cents - (cents * percent) // 100
