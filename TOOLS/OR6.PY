from decimal import Decimal
from pathlib import Path
import sys

sys.dont_write_bytecode = True
from ORACLE import MENU_TEXT, account_row, echoed_line, packed_bcd, pin_hash, seed_image


ROOT = Path(__file__).resolve().parent.parent
TESTS = ROOT / "TESTS"
DATE_PREFIX = "2000-01-01 00:00:00 "


def make_image(accounts):
    image = bytearray(seed_image()[:22])
    image[5] = len(accounts)
    for account in accounts:
        record = bytearray(16)
        record[:4] = account["id"].encode("ascii")
        record[4:6] = pin_hash(
            account["id"], account.get("pin", "0000")
        ).to_bytes(2, "little")
        record[6:12] = packed_bcd(account["balance"])
        record[12] = int(account["status"] == "ACTIVE")
        image.extend(record)
    image.extend(b"\0\0")
    image[-2:] = (sum(image[:-2]) & 0xFFFF).to_bytes(2, "little")
    return bytes(image)


def fixture_accounts(balance="1000.00", status="ACTIVE"):
    return [
        {"id": "1001", "status": status, "balance": Decimal(balance), "pin": "1234"},
        {"id": "1002", "status": "ACTIVE", "balance": Decimal("250.75"), "pin": "4321"},
        {"id": "1003", "status": "LOCKED", "balance": Decimal("0.00"), "pin": "1111"},
    ]


def write_case(name, actions, accounts=None, initialize=True, prior_events=None, failures=()):
    accounts = accounts if accounts is not None else fixture_accounts()
    initial_image = make_image(accounts) if initialize else None
    events = list(prior_events or [])
    input_lines = []
    output = []

    for account_id, pin in failures:
        input_lines.extend((account_id, pin))
        output.extend(
            (
                "Admin ID: ",
                echoed_line(account_id),
                "Admin PIN: ",
                "*" * len(pin) + "\r\n",
                "Login failed\r\n",
            )
        )
        events.append(("FAILED", "----", account_id, "-"))

    input_lines.extend(("9001", "1357"))
    output.extend(
        (
            "Admin ID: ",
            echoed_line("9001"),
            "Admin PIN: ",
            "****\r\n",
            "Login successful\r\n",
        )
    )
    events.append(("LOGIN", "----", "9001", "-"))

    for action in actions:
        choice = action[0]
        input_lines.append(choice)
        output.extend((MENU_TEXT, echoed_line(choice)))
        if choice == "3":
            account_id, pin, amount_text = action[1:]
            input_lines.extend((account_id, pin, amount_text))
            output.extend(
                (
                    "Account number: ",
                    echoed_line(account_id),
                    "Customer PIN: ",
                    "****\r\n",
                    "Opening balance: ",
                    echoed_line(amount_text),
                )
            )
            account = {
                "id": account_id,
                "status": "ACTIVE",
                "balance": Decimal(amount_text),
                "pin": pin,
            }
            accounts.append(account)
            output.append("Account created\r\n")
            events.append(
                ("CREATE", account_id, "9001", f"{account['balance']:.2f}")
            )
        elif choice == "4":
            account_id = action[1]
            input_lines.append(account_id)
            output.extend(("Account number: ", echoed_line(account_id)))
            account = next((item for item in accounts if item["id"] == account_id), None)
            if account is None:
                output.append("Account not found\r\n")
                continue
            account["status"] = (
                "LOCKED" if account["status"] == "ACTIVE" else "ACTIVE"
            )
            message = "Account locked" if account["status"] == "LOCKED" else "Account unlocked"
            output.append(message + "\r\n")
            events.append(
                ("LOCK" if account["status"] == "LOCKED" else "UNLOCK",
                 account_id, "9001", "-")
            )
        elif choice == "5":
            account_id, pin = action[1:]
            input_lines.extend((account_id, pin))
            output.extend(
                (
                    "Account number: ",
                    echoed_line(account_id),
                    "Customer PIN: ",
                    "****\r\n",
                )
            )
            account = next((item for item in accounts if item["id"] == account_id), None)
            if account is None:
                output.append("Account not found\r\n")
                continue
            account["pin"] = pin
            output.append("Customer PIN reset\r\n")
            events.append(("RESETPIN", account_id, "9001", "-"))
        elif choice == "6":
            account_id, kind, amount_text = action[1:]
            input_lines.extend((account_id, kind, amount_text))
            output.extend(
                (
                    "Account number: ",
                    echoed_line(account_id),
                    "C (credit) or D (debit): ",
                    echoed_line(kind),
                    "Amount: ",
                    echoed_line(amount_text),
                )
            )
            account = next((item for item in accounts if item["id"] == account_id), None)
            if account is None:
                output.append("Account not found\r\n")
                continue
            amount = Decimal(amount_text)
            if amount <= 0 or amount > Decimal("50000.00"):
                output.append("Invalid amount\r\n")
                continue
            if kind.upper() == "C":
                result = account["balance"] + amount
                if result > Decimal("9999999999.99"):
                    output.append("Balance overflow\r\n")
                    continue
                account["balance"] = result
                events.append(
                    ("CREDIT", account_id, "9001", f"{amount:.2f}")
                )
            else:
                if amount > account["balance"]:
                    output.append("Insufficient funds\r\n")
                    continue
                account["balance"] -= amount
                events.append(
                    ("DEBIT", account_id, "9001", f"{amount:.2f}")
                )
            output.append("Balance adjusted\r\n")
        elif choice == "2":
            account_id = action[1]
            input_lines.append(account_id)
            output.extend(("Account number: ", echoed_line(account_id)))
            account = next((item for item in accounts if item["id"] == account_id), None)
            output.append(
                account_row(
                    (account["id"], account["status"], f'{account["balance"]:.2f}')
                )
                if account
                else "Account not found\r\n"
            )
        elif choice == "7":
            active = sum(item["status"] == "ACTIVE" for item in accounts)
            locked = len(accounts) - active
            total = sum((item["balance"] for item in accounts), Decimal("0.00"))
            output.extend(
                (
                    f"ACCOUNTS: {len(accounts)}\r\n",
                    f"ACTIVE: {active}\r\n",
                    f"LOCKED: {locked}\r\n",
                    f"TOTAL: {total:.2f}\r\n",
                )
            )
            events.append(("REPORT", "----", "9001", "-"))
        elif choice == "8":
            output.append("Audit log: see AUDIT.LOG\r\n")
        elif choice == "9":
            events.append(("EXIT", "----", "9001", "-"))

    if not actions or actions[-1][0] != "9":
        input_lines.append("9")
        output.extend((MENU_TEXT, echoed_line("9")))
        events.append(("EXIT", "----", "9001", "-"))

    path = TESTS / name
    path.with_suffix(".IN").write_bytes("\r\n".join(input_lines).encode("ascii") + b"\r\n")
    path.with_suffix(".EXP").write_bytes("".join(output).encode("ascii"))
    path.with_suffix(".ARG").write_bytes(b"/T\r\n")
    path.with_suffix(".PGM").write_bytes(b"BANK\r\n")
    path.with_suffix(".RC").write_bytes(b"0\r\n")
    if initialize:
        path.with_suffix(".INI").write_bytes(initial_image)
    path.with_suffix(".DAT").write_bytes(make_image(accounts))
    log = "".join(
        f"{DATE_PREFIX}{actor} {event} {account_id} {detail}\r\n"
        for event, account_id, actor, detail in events
    )
    path.with_suffix(".LOG").write_bytes(log.encode("ascii"))
    return accounts, events


def main():
    accounts, events = write_case("Z08A", [("4", "1001")])
    write_case(
        "Z08B",
        [("2", "1001"), ("4", "1001")],
        accounts=accounts,
        initialize=False,
        prior_events=events,
    )

    reset_accounts = fixture_accounts()
    write_case("Z09", [("5", "1001", "2468")], accounts=reset_accounts)

    write_case(
        "Z10",
        [("6", "1001", "C", "25.50"),
         ("6", "1001", "D", "10.25"),
         ("2", "1001")],
    )
    write_case(
        "Z11",
        [("6", "1001", "D", "0"),
         ("6", "1001", "D", "1000.01"),
         ("2", "1001")],
    )
    write_case(
        "Z12",
        [("6", "1001", "C", "0.01"), ("2", "1001")],
        accounts=fixture_accounts("99999.99"),
    )
    write_case(
        "Z13",
        [("6", "1001", "C", "0.01"), ("2", "1001")],
        accounts=fixture_accounts("9999999999.99"),
    )
    write_case(
        "Z14",
        [("7",), ("8",)],
    )
    write_case(
        "Z15",
        [("9",)],
        failures=(("9001", "0000"),),
    )
    write_case(
        "Z16",
        [("6", "1001", "D", "0.01"), ("2", "1001")],
        accounts=fixture_accounts("0.01"),
    )
    write_case(
        "Z17",
        [("3", "1004", "2580", "12.34"), ("2", "1004")],
    )
    wide_total = fixture_accounts("9999999999.99")
    wide_total[1]["balance"] = Decimal("9999999999.99")
    write_case("Z18", [("7",)], accounts=wide_total)
    print("Generated Stage 6 admin and audit fixtures from independent input models.")


if __name__ == "__main__":
    main()
