from slug import slugify


def test_simple():
    assert slugify("Hello World") == "hello-world"


def test_punctuation():
    assert slugify("Hello, World!") == "hello-world"


def test_extra_spaces():
    assert slugify("  Multiple   spaces  ") == "multiple-spaces"


def test_already_a_slug():
    assert slugify("already-a-slug") == "already-a-slug"


def test_empty_and_symbols_only():
    assert slugify("") == ""
    assert slugify("?!?") == ""
