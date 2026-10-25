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


def pin_hash(account_id, pin):
    value = 0x6D31
    for id_digit, pin_digit in zip(account_id.encode("ascii"), pin.encode("ascii")):
        value = ((value << 1) | (value >> 15)) & 0xFFFF
        value = (value & 0xFF00) | ((value & 0xFF) ^ id_digit)
        value = (value + 0x0137) & 0xFFFF
        value ^= pin_digit << 8
    return (value * 251) & 0xFFFF


def packed_bcd(amount):
    remaining = cents(amount)
    packed = bytearray()
    for _ in range(6):
        pair = remaining % 100
        packed.append(((pair // 10) << 4) | (pair % 10))
        remaining //= 100
    if remaining:
        raise ValueError(f"Seed balance exceeds six-byte BCD: {amount}")
    return bytes(packed)


def seed_record(account_id, pin, amount, active):
    return (
        account_id.encode("ascii")
        + pin_hash(account_id, pin).to_bytes(2, "little")
        + packed_bcd(amount)
        + bytes((int(active),))
        + bytes(3)
    )


def seed_image():
    image = bytearray(b"CALD\x01\x03")
    image.extend(
        b"9001"
        + pin_hash("9001", "1357").to_bytes(2, "little")
        + bytes(10)
    )
    image.extend(seed_record("1001", "1234", "1000.00", True))
    image.extend(seed_record("1002", "4321", "250.75", True))
    image.extend(seed_record("1003", "1111", "0.00", False))
    image.extend((sum(image) & 0xFFFF).to_bytes(2, "little"))
    if len(image) != 72:
        raise AssertionError(f"Seed image has unexpected length: {len(image)}")
    return bytes(image)


MENU_TEXT = (
    "1 List accounts\r\n"
    "2 View account\r\n"
    "3 Create account\r\n"
    "4 Lock/Unlock\r\n"
    "5 Reset customer PIN\r\n"
    "6 Adjust balance\r\n"
    "7 Summary report\r\n"
    "8 Audit log\r\n"
    "9 Exit\r\n"
    "Choice: "
)


def echoed_line(value):
    return value + "\r\n"


def account_row(account):
    account_id, status, balance = account
    return f"{account_id}  {status}  {balance}\r\n"


def admin_session(logins, actions, accounts):
    output = []
    failed = 0
    for account_id, pin in logins:
        output.extend(("Admin ID: ", echoed_line(account_id)))
        output.extend(("Admin PIN: ", "*" * len(pin) + "\r\n"))
        if account_id == "9001" and pin == "1357":
            output.append("Login successful\r\n")
            break
        failed += 1
        if failed == 3:
            output.append("Login failed. Console locked.\r\n")
            return "".join(output)
        output.append("Login failed\r\n")

    for action in actions:
        output.extend((MENU_TEXT, echoed_line(action[0])))
        if action[0] == "1":
            output.append("ACCT  STATUS  BALANCE\r\n")
            output.extend(account_row(account) for account in accounts)
        elif action[0] == "2":
            account_id = action[1]
            output.extend(("Account number: ", echoed_line(account_id)))
            account = next(
                (entry for entry in accounts if entry[0] == account_id), None
            )
            output.append(
                account_row(account) if account else "Account not found\r\n"
            )
        elif action[0] == "3":
            account_id, pin, amount = action[1:]
            output.extend(("Account number: ", echoed_line(account_id)))
            if not re.fullmatch(r"[0-9]{4}", account_id):
                output.append("Invalid account number\r\n")
            elif any(entry[0] == account_id for entry in accounts):
                output.append("Account already exists\r\n")
            elif len(accounts) == 8:
                output.append("Account table full\r\n")
            elif not AMOUNT_PATTERN.fullmatch(amount) or Decimal(amount) > 50000:
                output.extend(
                    (
                        "Customer PIN: ",
                        "*" * len(pin) + "\r\n",
                        "Opening balance: ",
                        echoed_line(amount),
                        "Invalid amount\r\n",
                    )
                )
            else:
                output.extend(
                    ("Customer PIN: ", "*" * len(pin) + "\r\n")
                )
                output.extend(("Opening balance: ", echoed_line(amount)))
                output.append("Account created\r\n")
                accounts.append((account_id, "ACTIVE", f"{Decimal(amount):.2f}"))
    return "".join(output)


def write_admin_case(name, input_lines, output_text, arguments="/T", return_code="0"):
    write_crlf(TESTS / f"{name}.IN", input_lines)
    write_crlf(TESTS / f"{name}.EXP", output_text.rstrip("\r\n").split("\r\n"))
    write_crlf(TESTS / f"{name}.ARG", [arguments])
    write_crlf(TESTS / f"{name}.PGM", ["BANK"])
    write_crlf(TESTS / f"{name}.RC", [return_code])


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
    write_crlf(TESTS / "I05.IN", [])
    write_crlf(TESTS / "I05.EXP", ["Data initialized"])
    write_crlf(TESTS / "I05.ARG", ["/I"])
    write_crlf(TESTS / "I05.PGM", ["BANK"])
    write_crlf(TESTS / "I05.RC", ["0"])
    (TESTS / "I05.DAT").write_bytes(seed_image())
    write_crlf(TESTS / "T00.IN", [])
    write_crlf(TESTS / "T00.EXP", ["Data initialized"])
    write_crlf(TESTS / "T00.ARG", ["/I"])
    write_crlf(TESTS / "T00.PGM", ["BANK"])
    write_crlf(TESTS / "T00.RC", ["0"])
    (TESTS / "T00.DAT").write_bytes(seed_image())

    seed_accounts = [
        ("1001", "ACTIVE", "1000.00"),
        ("1002", "ACTIVE", "250.75"),
        ("1003", "LOCKED", "0.00"),
    ]
    write_admin_case(
        "T01",
        ["9001", "1357", "9"],
        admin_session([("9001", "1357")], [("9",)], seed_accounts.copy()),
    )
    write_admin_case(
        "T02",
        ["9001", "0000", "9001", "0000", "9001", "0000"],
        admin_session(
            [("9001", "0000")] * 3, [], seed_accounts.copy()
        ),
        return_code="2",
    )
    write_admin_case(
        "T03",
        ["9999", "1357", "9001", "1357", "9"],
        admin_session(
            [("9999", "1357"), ("9001", "1357")],
            [("9",)],
            seed_accounts.copy(),
        ),
    )
    write_admin_case(
        "T04",
        ["9001", "1357", "1", "9"],
        admin_session(
            [("9001", "1357")], [("1",), ("9",)], seed_accounts.copy()
        ),
    )
    write_admin_case(
        "T05",
        ["9001", "1357", "2", "1002", "2", "9999", "2", "12x4", "9"],
        admin_session(
            [("9001", "1357")],
            [("2", "1002"), ("2", "9999"), ("2", "12x4"), ("9",)],
            seed_accounts.copy(),
        ),
    )
    created_accounts = seed_accounts.copy()
    create_action = ("3", "1004", "2580", "12.34")
    write_admin_case(
        "T06",
        ["9001", "1357", "3", "1004", "2580", "12.34", "2", "1004", "9"],
        admin_session(
            [("9001", "1357")],
            [create_action, ("2", "1004"), ("9",)],
            created_accounts,
        ),
    )
    full_table = created_accounts.copy()
    full_actions = [
        ("3", "12x4", "", ""),
        ("3", "1001", "0000", "0"),
        ("3", "1005", "0000", "50000.01"),
    ]
    full_inputs = [
        "9001", "1357", "3", "12x4", "3", "1001",
        "3", "1005", "0000", "50000.01",
    ]
    for account_id in ("1005", "1006", "1007", "1008"):
        full_actions.append(("3", account_id, "0000", "0"))
        full_inputs.extend(("3", account_id, "0000", "0"))
    full_actions.append(("3", "1009", "0000", "0"))
    full_inputs.extend(("3", "1009"))
    full_inputs.append("9")
    write_admin_case(
        "T07",
        full_inputs,
        admin_session(
            [("9001", "1357")], full_actions + [("9",)], full_table
        ),
    )
    print(f"Generated {len(vectors)} independent BCD vectors and the seed image in TESTS.")


if __name__ == "__main__":
    main()
