from decimal import Decimal
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parent.parent
TESTS = ROOT / "TESTS"
AMOUNT_PATTERN = re.compile(r"^[0-9]{1,10}(\.[0-9]{1,2})?$")
BCD_MODULUS = 10**12


def cents(text):
    return int(Decimal(text) * 100)


def bcd_digits(value):
    return "".join(f"{(value // (10 ** (2 * byte))) % 100:02d}" for byte in range(6))


def format_amount(value):
    return f"{Decimal(value) / Decimal(100):.2f}"


def add_vector(left, right):
    expected = (left + right) % BCD_MODULUS
    carry = int(left + right >= BCD_MODULUS)
    return f"A{bcd_digits(left)}{bcd_digits(right)}", \
        f"ADD={format_amount(expected)} CARRY={carry}"


def sub_vector(left, right):
    expected = (left - right) % BCD_MODULUS
    borrow = int(left < right)
    return f"S{bcd_digits(left)}{bcd_digits(right)}", \
        f"SUB={format_amount(expected)} BORROW={borrow}"


def compare_vector(left, right):
    relation = "LESS" if left < right else "GREATER" if left > right else "EQUAL"
    return f"C{bcd_digits(left)}{bcd_digits(right)}", f"CMP={relation}"


def format_vector(value):
    return f"F{bcd_digits(value)}", f"FORMAT={format_amount(value)}"


def parse_vector(text):
    line = f"P{text}"
    if not AMOUNT_PATTERN.fullmatch(text):
        return line, "PARSE REJECT"
    return line, f"PARSE={format_amount(cents(text))}"


def write_crlf(path, lines):
    path.write_bytes(("\r\n".join(lines) + "\r\n").encode("ascii"))


def main():
    vectors = []
    vectors.extend(
        (
            add_vector(cents("9999999999.99"), cents("0.01")),
            add_vector(cents("9999999999.99"), 0),
            add_vector(cents("99.99"), cents("0.01")),
            add_vector(0, 0),
            sub_vector(0, cents("0.01")),
            sub_vector(cents("123.45"), cents("123.45")),
            compare_vector(cents("125.50"), cents("125.50")),
            compare_vector(cents("0.01"), cents("0.00")),
            compare_vector(cents("0.00"), cents("0.01")),
            compare_vector(cents("9999999999.99"), cents("1.00")),
            format_vector(0),
            format_vector(cents("100.00")),
            format_vector(cents("9999999999.99")),
        )
    )

    accepted = (
        "125",
        "0125",
        "0",
        "0.00",
        "0.01",
        "125.5",
        "125.50",
        "9999999999.99",
    )
    rejected = (
        "125.",
        ".5",
        ".",
        "1.234",
        "1.2.3",
        "1..5",
        "",
        "12a",
        "-5",
        "+5",
        " 5",
        "5 ",
        "1,000",
        "99999999999",
    )
    if any(not AMOUNT_PATTERN.fullmatch(text) for text in accepted):
        raise AssertionError("Accepted parser vector disagrees with FR-11 grammar.")
    if any(AMOUNT_PATTERN.fullmatch(text) for text in rejected):
        raise AssertionError("Rejected parser vector disagrees with FR-11 grammar.")
    vectors.extend(parse_vector(text) for text in accepted + rejected)

    input_lines = [line for line, _ in vectors]
    expected_lines = []
    for line, result in vectors:
        expected_lines.extend((line, result))

    write_crlf(TESTS / "T20.IN", input_lines)
    write_crlf(TESTS / "T20.EXP", expected_lines)
    write_crlf(TESTS / "T20.ARG", ["/T BCD"])
    write_crlf(TESTS / "T20.PGM", ["TDRV"])
    write_crlf(TESTS / "T20.RC", ["0"])
    print(f"Generated {len(vectors)} independent BCD vectors in TESTS\\T20.*")


if __name__ == "__main__":
    main()
