import pytest

from stats import moving_average


def test_basic():
    assert moving_average([1, 2, 3, 4, 5], 3) == [2.0, 3.0, 4.0]


def test_window_equals_length():
    assert moving_average([2, 4, 6], 3) == [4.0]


def test_window_of_one():
    assert moving_average([5, 7], 1) == [5.0, 7.0]


def test_window_too_big():
    assert moving_average([1, 2], 5) == []


def test_bad_window():
    with pytest.raises(ValueError):
        moving_average([1, 2, 3], 0)
