#!/usr/bin/env python3
"""
Daily Ichimoku Kinko Hyo market scanner for S&P 500 and Nasdaq 100.

Generates a CSV report with the top five bullish momentum candidates and
sends it via email. Maintains a positions.csv file to track open positions and
emits sell alerts when the close falls below the Kijun Sen.

Environment variables required for email:
  SMTP_SERVER, SMTP_PORT, SMTP_USER, SMTP_PASSWORD, EMAIL_TO
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from datetime import datetime
from email.message import EmailMessage
from pathlib import Path
from typing import Iterable, List

import pandas as pd
import smtplib

POSITIONS_FILE = Path("positions.csv")
LOOKBACK_SLOPE = 3


@dataclass
class Candidate:
    ticker: str
    close: float
    tenkan: float
    kijun: float
    score: float


def get_sp500_tickers() -> List[str]:
    tables = pd.read_html(
        "https://en.wikipedia.org/wiki/List_of_S%26P_500_companies"
    )
    return tables[0]["Symbol"].tolist()


def get_nasdaq100_tickers() -> List[str]:
    tables = pd.read_html("https://en.wikipedia.org/wiki/Nasdaq-100")
    # The ticker symbols are typically in the table labelled "Tickers".
    for table in tables:
        if "Ticker" in table.columns:
            return table["Ticker"].tolist()
    raise ValueError("Nasdaq 100 tickers table not found")


def ticker_universe() -> List[str]:
    tickers = set(get_sp500_tickers()) | set(get_nasdaq100_tickers())
    return sorted(tickers)


def fetch_history(ticker: str) -> pd.DataFrame:
    # 1y provides enough data for 52-period calculations
    import yfinance as yf  # local import to avoid hard dependency for tests

    return yf.download(ticker, period="1y", auto_adjust=False, progress=False)


def ichimoku(df: pd.DataFrame) -> pd.DataFrame:
    high9 = df["High"].rolling(9).max()
    low9 = df["Low"].rolling(9).min()
    tenkan = (high9 + low9) / 2

    high26 = df["High"].rolling(26).max()
    low26 = df["Low"].rolling(26).min()
    kijun = (high26 + low26) / 2

    span_a = ((tenkan + kijun) / 2).shift(26)
    high52 = df["High"].rolling(52).max()
    low52 = df["Low"].rolling(52).min()
    span_b = ((high52 + low52) / 2).shift(26)
    chikou = df["Close"].shift(-26)

    return pd.DataFrame(
        {
            "Close": df["Close"],
            "Tenkan": tenkan,
            "Kijun": kijun,
            "SpanA": span_a,
            "SpanB": span_b,
            "Chikou": chikou,
        }
    )


def is_bullish(ich: pd.DataFrame) -> bool:
    if ich.dropna().empty:
        return False
    last = ich.iloc[-1]
    if last["Close"] <= max(last["SpanA"], last["SpanB"]):
        return False
    if last["Tenkan"] <= last["Kijun"]:
        return False
    # Chikou span check 26 periods ago
    try:
        past = ich.iloc[-26]
    except IndexError:
        return False
    if past["Chikou"] <= max(past["Close"], past["SpanA"], past["SpanB"]):
        return False
    return True


def slope_score(ich: pd.DataFrame, lookback: int = LOOKBACK_SLOPE) -> float:
    if len(ich.dropna()) <= lookback:
        return float("-inf")
    recent = ich.iloc[-1]
    prior = ich.iloc[-lookback - 1]
    return (recent["Tenkan"] - prior["Tenkan"]) + (
        recent["Kijun"] - prior["Kijun"]
    )


def scan() -> List[Candidate]:
    candidates: List[Candidate] = []
    for ticker in ticker_universe():
        try:
            history = fetch_history(ticker)
            ich = ichimoku(history)
            if is_bullish(ich):
                score = slope_score(ich)
                last = ich.iloc[-1]
                candidates.append(
                    Candidate(
                        ticker=ticker,
                        close=float(last["Close"]),
                        tenkan=float(last["Tenkan"]),
                        kijun=float(last["Kijun"]),
                        score=float(score),
                    )
                )
        except Exception:
            # Skip problematic tickers silently
            continue
    candidates.sort(key=lambda c: c.score, reverse=True)
    return candidates[:5]


def load_positions() -> pd.DataFrame:
    if POSITIONS_FILE.exists():
        return pd.read_csv(POSITIONS_FILE)
    return pd.DataFrame(columns=["Ticker", "EntryDate"])


def save_positions(df: pd.DataFrame) -> None:
    df.to_csv(POSITIONS_FILE, index=False)


def manage_positions(candidates: Iterable[Candidate]) -> List[str]:
    positions = load_positions()
    tickers = {c.ticker for c in candidates}
    # Add new positions
    for ticker in tickers - set(positions["Ticker"]):
        positions.loc[len(positions)] = {
            "Ticker": ticker,
            "EntryDate": datetime.utcnow().date(),
        }
    # Check sell rule: close below Kijun
    sell_alerts: List[str] = []
    remaining = positions.copy()
    for idx, row in positions.iterrows():
        ticker = row["Ticker"]
        try:
            history = fetch_history(ticker)
            ich = ichimoku(history)
            last = ich.iloc[-1]
            if last["Close"] < last["Kijun"]:
                sell_alerts.append(ticker)
                remaining = remaining[remaining["Ticker"] != ticker]
        except Exception:
            continue
    save_positions(remaining)
    return sell_alerts


def export_report(candidates: List[Candidate], sells: List[str]) -> Path:
    rows = [c.__dict__ for c in candidates]
    report = pd.DataFrame(rows)
    report["Generated"] = datetime.utcnow().isoformat()
    path = Path(f"ichimoku_report_{datetime.utcnow().date()}.csv")
    report.to_csv(path, index=False)
    if sells:
        sell_path = Path(f"sell_alerts_{datetime.utcnow().date()}.csv")
        pd.DataFrame({"Ticker": sells}).to_csv(sell_path, index=False)
    return path


def send_email_with_attachment(csv_path: Path) -> None:
    server = os.environ.get("SMTP_SERVER")
    port = int(os.environ.get("SMTP_PORT", "587"))
    user = os.environ.get("SMTP_USER")
    password = os.environ.get("SMTP_PASSWORD")
    to_addr = os.environ.get("EMAIL_TO")
    if not all([server, user, password, to_addr]):
        return
    msg = EmailMessage()
    msg["Subject"] = f"Ichimoku Dragon Report {datetime.utcnow().date()}"
    msg["From"] = user
    msg["To"] = to_addr
    msg.set_content("Daily market scan attached.")
    with csv_path.open("rb") as fh:
        msg.add_attachment(
            fh.read(),
            maintype="text",
            subtype="csv",
            filename=csv_path.name,
        )
    with smtplib.SMTP(server, port) as smtp:
        smtp.starttls()
        smtp.login(user, password)
        smtp.send_message(msg)


# TODO: refine exit criteria beyond close below Kijun Sen (see issue placeholder)

def main() -> None:
    candidates = scan()
    sells = manage_positions(candidates)
    csv_path = export_report(candidates, sells)
    send_email_with_attachment(csv_path)


if __name__ == "__main__":
    main()
