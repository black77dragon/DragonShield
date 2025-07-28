from DragonShield.python_scripts.credit_suisse_parser import parse_date_from_excel_cell, parse_statement_date_from_filename


def test_parse_flexible_date_from_cell():
    assert parse_date_from_excel_cell("20 Aug 2025") == "2025-08-20"
    assert parse_date_from_excel_cell("August 5, 2024") == "2024-08-05"


def test_parse_flexible_date_from_filename():
    assert parse_statement_date_from_filename("statement_Aug-15-2023.pdf") == "2023-08-15"
