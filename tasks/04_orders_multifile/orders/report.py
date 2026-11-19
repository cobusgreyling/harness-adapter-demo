from .pricing import apply_discount, subtotal
from .tax import add_tax


def invoice_total(items, code=None, tax_rate=15):
    """Total to pay in cents: subtotal, then discount, then tax on the discounted amount."""
    total = subtotal(items)
    total = add_tax(total, tax_rate)
    total = apply_discount(total, code)
    return total
