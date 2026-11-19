def add_tax(cents, rate_percent):
    """Add tax, rounding the tax half up to the nearest cent."""
    return cents + (cents * rate_percent + 50) // 100
