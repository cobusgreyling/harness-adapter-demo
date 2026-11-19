import re


def slugify(text):
    """Turn a title into a URL slug.

    "Hello, World!" -> "hello-world"
    Runs of non-alphanumeric characters become a single hyphen, and the
    result never starts or ends with a hyphen.
    """
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-")
