import pytest

from calendar_utils import days_in_month, is_leap_year


@pytest.mark.parametrize("year", [2024, 2000, 1996])
def test_leap_years(year):
    assert is_leap_year(year)


@pytest.mark.parametrize("year", [2023, 1900, 2100])
def test_not_leap_years(year):
    assert not is_leap_year(year)


def test_february_in_a_century_year():
    assert days_in_month(1900, 2) == 28
    assert days_in_month(2000, 2) == 29


def test_other_months():
    assert days_in_month(2023, 1) == 31
    assert days_in_month(2023, 4) == 30
