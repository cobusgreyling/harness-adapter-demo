from dataclasses import dataclass


@dataclass
class Item:
    name: str
    unit_price_cents: int
    qty: int = 1
