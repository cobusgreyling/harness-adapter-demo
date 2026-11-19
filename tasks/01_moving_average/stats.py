def moving_average(values, window):
    """Return the average of every full window of `window` consecutive values.

    moving_average([1, 2, 3, 4, 5], 3) -> [2.0, 3.0, 4.0]
    A window larger than the list gives an empty list.
    """
    if window <= 0:
        raise ValueError("window must be positive")
    averages = []
    for i in range(len(values) - window):
        averages.append(sum(values[i:i + window]) / window)
    return averages
