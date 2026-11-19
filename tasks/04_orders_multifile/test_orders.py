from orders.models import Item
from orders.pricing import apply_discount, line_total, subtotal
from orders.report import invoice_total
from orders.tax import add_tax

ITEMS = [Item("widget", 1000, qty=2), Item("gadget", 550)]


def test_line_total_uses_quantity():
    assert line_total(Item("widget", 1000, qty=2)) == 2000


def test_subtotal():
    assert subtotal(ITEMS) == 2550


def test_discount():
    assert apply_discount(2550, "SAVE10") == 2295
    assert apply_discount(2550, "NOPE") == 2550
    assert apply_discount(2550, None) == 2550


def test_tax_rounds_half_up():
    assert add_tax(2295, 15) == 2639


def test_invoice_without_code():
    assert invoice_total(ITEMS) == 2933


def test_invoice_discount_before_tax():
    # 2550 -> 2295 after SAVE10 -> 2639 after 15% tax
    assert invoice_total(ITEMS, code="SAVE10") == 2639
