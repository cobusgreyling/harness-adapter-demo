def is_leap_year(year):
    """Gregorian rule: every 4th year, except centuries, except every 400th."""
    return year % 4 == 0


def days_in_month(year, month):
    if not 1 <= month <= 12:
        raise ValueError("month must be 1-12")
    if month == 2:
        return 29 if is_leap_year(year) else 28
    return 30 if month in (4, 6, 9, 11) else 31
