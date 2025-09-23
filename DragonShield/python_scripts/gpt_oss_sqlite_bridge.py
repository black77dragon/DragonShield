#!/usr/bin/env python3
"""
Bridge LM Studio (gpt-oss-20b) ↔ DragonShield SQLite DB (READ-ONLY, TEXT-ONLY MODE).

- No OpenAI "tools" parameter used → prevents LM Studio's <|channel|> tool markup.
- Model asks for SELECTs in plain text; we parse, run safely, return a tiny "DATA NOTE",
  then force a clean, human-readable summary (no JSON/markup).
"""

import os
import sys
import json
import re
import ast
import argparse
from typing import Any, Dict, List, Optional

# ---------- Defaults ----------
DEFAULT_BASE_URL = os.environ.get("LLM_BASE_URL", "http://localhost:1234/v1")
DEFAULT_MODEL    = os.environ.get("LLM_MODEL",    "openai/gpt-oss-20b")
DEFAULT_DB       = os.environ.get(
    "DRAGONSHIELD_DB",
    "/Users/renekeller/Library/Containers/com.rene.DragonShield/Data/Library/Application Support/DragonShield/dragonshield.sqlite"
)

# ---------- DB (unencrypted SQLite) ----------
import sqlite3 as sqlite

# Optional SQL parser for extra safety
try:
    import sqlglot
    from sqlglot import exp
    HAVE_SQLGLOT = True
except Exception:
    HAVE_SQLGLOT = False

# OpenAI-compatible client (LM Studio exposes this locally)
from openai import OpenAI


# ---------- DB helpers ----------
def connect_db(db_path: str):
    if not db_path:
        raise RuntimeError("Missing --db path or DRAGONSHIELD_DB env var.")
    # Handle spaces via URI + read-only
    uri = db_path if db_path.startswith("file:") else "file:{}?mode=ro".format(db_path)
    conn = sqlite.connect(uri, uri=True)
    conn.row_factory = lambda cur, row: {cur.description[i][0]: row[i] for i in range(len(row))}
    # smoke test
    cur = conn.cursor()
    cur.execute("SELECT 1 AS ok;")
    _ = cur.fetchone()
    return conn

def schema_dict(conn) -> Dict[str, List[str]]:
    cur = conn.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type IN ('table','view') AND name NOT LIKE 'sqlite_%';")
    tables = [r["name"] for r in cur.fetchall()]
    out: Dict[str, List[str]] = {}
    for t in tables:
        try:
            cur.execute("PRAGMA table_info('{}');".format(t.replace("'", "''")))
            out[t] = [r["name"] for r in cur.fetchall()]
        except Exception:
            pass
    return out

def validate_select(sql_stmt: str, allowed_tables: set):
    s = (sql_stmt or "").strip().rstrip(";")
    if not s.lower().startswith("select"):
        raise ValueError("Only SELECT statements are allowed.")

    # hard forbid tokens regardless of parser
    forbidden = r"(;|--|\battach\b|\bpragma\b|\bdrop\b|\bdelete\b|\binsert\b|\bupdate\b|\balter\b|\bvacuum\b)"
    if re.search(forbidden, s, re.IGNORECASE):
        raise ValueError("Forbidden tokens found in query.")

    # forbid any reference to sqlite_* internals
    if re.search(r"\bsqlite_[_a-z0-9]*\b", s, re.IGNORECASE):
        raise ValueError("Internal SQLite tables (sqlite_*) are not allowed.")

    if not HAVE_SQLGLOT:
        return

    tree = sqlglot.parse_one(s, read="sqlite")
    if not isinstance(tree, exp.Select) and not tree.find(exp.Select):
        raise ValueError("Only SELECT is permitted.")
    for tbl in tree.find_all(exp.Table):
        name = getattr(tbl.this, "name", str(tbl.this))
        if name.lower().startswith("sqlite_"):
            raise ValueError("Internal SQLite tables (sqlite_*) are not allowed.")
        if name not in allowed_tables:
            raise ValueError("Table not allowed or does not exist: {}".format(name))

def run_select(conn, sql_stmt: str, params: Optional[List[Any]] = None, limit: int = 1000):
    cur = conn.cursor()
    final = "{} LIMIT {}".format(sql_stmt.strip().rstrip(";"), int(limit))
    cur.execute(final, params or [])
    return cur.fetchall()


# ---------- Text fallback extractor ----------
def maybe_extract_tool_call_from_content(content: str):
    """
    Supports:
      <|channel|>commentary to=repo.run_sql_select_safe ... >SELECT ...;
      <|channel|>analysis to=functions.run_sql_select_safe code<|message|>{"query":"..."}
      {"name":"run_sql_select_safe","arguments":{"sql":"..."}}
      {"action":"run_sql_select_safe","query":"..."}
      {"sql":"SELECT ..."}
    Returns: {"name":"run_sql_select_safe","arguments":{"sql": "...", ...}} or None.
    """
    if not content:
        return None
    text = content.strip()

    # A) 'to=...run_sql_select_safe ... >SELECT ...' (covers repo/assistant/functions.*)
    m = re.search(r"to=.*run_sql_select_safe[^\>]*>([\s\S]+)$", text, re.IGNORECASE)
    if m:
        sql_candidate = m.group(1).strip().splitlines()[0].strip()
        if sql_candidate.lower().startswith("select"):
            return {"name": "run_sql_select_safe", "arguments": {"sql": sql_candidate}}

    # B) JSON-ish block with query/sql/params/limit
    if "{" in text and "}" in text:
        try:
            json_part = text[text.index("{"): text.rindex("}")+1]
            try:
                obj = json.loads(json_part)
            except Exception:
                obj = ast.literal_eval(json_part)
            if isinstance(obj, dict):
                if obj.get("name") == "run_sql_select_safe" and "arguments" in obj:
                    return {"name": "run_sql_select_safe", "arguments": obj["arguments"]}
                if obj.get("action") == "run_sql_select_safe":
                    args = {}
                    if "query" in obj:  args["sql"] = obj["query"]
                    if "params" in obj: args["params"] = obj["params"]
                    if "limit" in obj:  args["limit"] = obj["limit"]
                    if "sql" in args:
                        return {"name":"run_sql_select_safe","arguments":args}
                if "sql" in obj and isinstance(obj["sql"], str):
                    return {"name":"run_sql_select_safe","arguments":{"sql": obj["sql"]}}
        except Exception:
            pass
    return None


# ---------- Conversation setup ----------
def initial_messages(schema: Dict[str, List[str]]) -> List[Dict[str, str]]:
    system = (
        "You are a precise portfolio analyst. "
        "Use SQL ONLY by asking me in plain text for a SELECT; I will run it and return a brief data note. "
        "Never query sqlite_master or any sqlite_* internal tables; they are blocked. "
        "Use only the tables listed in the provided schema below. "
        "IMPORTANT: Do NOT print tool calls, JSON, code blocks, or special channel markup in your final answers. "
        "Once you have run a few queries, stop asking for more and give a concise, human-readable summary."
    )


    user = (
        "Run up to five COUNT(*) queries to estimate table sizes for: "
        "Portfolios, Accounts, Transactions, PortfolioInstruments, LatestExchangeRates (or the nearest price/FX table you find). "
        "Then produce a concise English summary of where transactions (trades/ledger rows) and prices/FX usually live. "
        "Do not claim that prices are stored in Transactions unless a dedicated price table is missing."
    )
    return [
        {"role":"system","content": system},
        {"role":"system","content": "Database schema (tables→columns): {}".format(json.dumps(schema)[:4000])},
        {"role":"user","content": user}
    ]

def extract_sql_statements(text: str, max_stmts: int = 5) -> List[str]:
    """
    Finds SQL queries proposed by the model (backticks, code fences, or plain lines).
    Returns a list of 'SELECT ...;' strings (up to max_stmts).
    """
    if not text:
        return []
    stmts: List[str] = []
    # 1) fenced ```sql ...``` and inline `...`
    blocks = re.findall(r"```(?:sql)?\s*([\s\S]*?)```", text, flags=re.IGNORECASE)
    blocks += re.findall(r"`([^`]+)`", text)
    # 2) also scan entire text split into lines (handles “SELECT …;  SELECT …;” lists)
    blocks += text.splitlines()

    for frag in blocks:
        # capture all SELECT ...; in each fragment
        for m in re.findall(r"(?is)\bSELECT\b[\s\S]*?;", frag):
            s = m.strip()
            if s.lower().startswith("select") and "sqlite_" not in s.lower():
                if s not in stmts:
                    stmts.append(s)
            if len(stmts) >= max_stmts:
                break
        if len(stmts) >= max_stmts:
            break
    return stmts


def tool_loop(client: OpenAI, model: str, messages: List[Dict[str, str]], tools: list, conn, allowed_tables: set):
    """
    TEXT-ONLY, Python 3.9-compatible multi-round loop.
    - Never passes 'tools' to the API → prevents LM Studio <|channel|> tool markup.
    - Detects DB requests in plain text via:
        1) JSON/wrapper-style detection (embedded {"sql": ...} or to=...run_sql_select_safe ... >SELECT ...)
        2) Plain-text SELECTs in code fences/backticks/lines
    - Enforces SELECT-only and blocks sqlite_* internals.
    - Executes a small batch of queries, then returns a clean, human summary (no JSON/markup).

    Requirements (provided elsewhere in your file):
      - validate_select(sql_stmt: str, allowed_tables: set) -> None
      - run_select(conn, sql_stmt: str, params: Optional[List[Any]] = None, limit: int = 1000) -> List[Dict]
      - imports: json, re, List, Dict (typing)
    """
    MAX_ROUNDS = 8
    MAX_EXEC   = 5   # run up to 5 queries, then summarize

    # ---------- inner helpers (self-contained) ----------
    def ask_model(msgs: List[Dict[str, str]], max_tokens: int = 500):
        # IMPORTANT: no 'tools' arg here → no tool wrappers from LM Studio
        resp = client.chat.completions.create(model=model, messages=msgs, max_tokens=max_tokens)
        return resp.choices[0].message

    def summarize_now() -> str:
        """Force a clean, plain-English summary and strip any stray wrappers."""
        messages.append({
            "role": "assistant",
            "content": "Provide a concise, human-readable summary now (no JSON, no code, no special markup)."
        })
        final = ask_model(messages, max_tokens=700)
        txt = (final.content or "").strip()
        return re.sub(r"<\|.*?\|>", "", txt).strip()

    def parse_tool_call_from_text(content: str):
        """
        Detect common wrapper/JSON styles and return {"sql": "..."} or None.
        Supports:
          - <|channel|>... to=repo/assistant/functions.run_sql_select_safe ... >SELECT ...;
          - {"name":"run_sql_select_safe","arguments":{"sql":"..."}}
          - {"action":"run_sql_select_safe","query":"..."}
          - {"sql":"SELECT ..."}
        """
        if not content:
            return None
        text = content.strip()

        # A) wrapper: ... to=...run_sql_select_safe ... >SELECT ...;
        m = re.search(r"to=.*run_sql_select_safe[^\>]*>([\s\S]+)$", text, re.IGNORECASE)
        if m:
            sql_candidate = m.group(1).strip().splitlines()[0].strip()
            if sql_candidate.lower().startswith("select"):
                return {"sql": sql_candidate}

        # B) JSON-ish block
        if "{" in text and "}" in text:
            try:
                json_part = text[text.index("{"): text.rindex("}")+1]
                try:
                    obj = json.loads(json_part)
                except Exception:
                    import ast
                    obj = ast.literal_eval(json_part)
                if isinstance(obj, dict):
                    if obj.get("name") == "run_sql_select_safe" and "arguments" in obj:
                        args = obj["arguments"] or {}
                        if isinstance(args, dict) and "sql" in args and isinstance(args["sql"], str):
                            return {"sql": args["sql"]}
                    if obj.get("action") == "run_sql_select_safe" and "query" in obj:
                        return {"sql": obj["query"]}
                    if "sql" in obj and isinstance(obj["sql"], str):
                        return {"sql": obj["sql"]}
            except Exception:
                pass
        return None

    def extract_sql_statements(text: str, max_stmts: int = 5) -> List[str]:
        """
        Finds SQL queries proposed by the model (in backticks, code fences, or plain lines).
        Returns a list of 'SELECT ...;' strings (up to max_stmts).
        """
        if not text:
            return []
        stmts: List[str] = []
        blocks = re.findall(r"```(?:sql)?\s*([\s\S]*?)```", text, flags=re.IGNORECASE)
        blocks += re.findall(r"`([^`]+)`", text)
        blocks += text.splitlines()  # capture bare lines like "SELECT ...;"
        for frag in blocks:
            for m in re.findall(r"(?is)\bSELECT\b[\s\S]*?;", frag):
                s = m.strip()
                if s.lower().startswith("select") and "sqlite_" not in s.lower():
                    if s not in stmts:
                        stmts.append(s)
                if len(stmts) >= max_stmts:
                    break
            if len(stmts) >= max_stmts:
                break
        return stmts

    def preview_from_rows(data) -> str:
        """Compact, non-JSON preview for the model (or for local summary)."""
        if isinstance(data, list):
            if len(data) == 1 and isinstance(data[0], dict) and len(data[0]) == 1:
                k = list(data[0].keys())[0]
                return f"{k}={data[0][k]}"
            rows = []
            for r in data[:2]:
                if isinstance(r, dict):
                    items = list(r.items())[:5]
                    rows.append(", ".join(f"{k}={v}" for k, v in items))
                else:
                    rows.append(str(r))
            return " | ".join(rows) if rows else "(no rows)"
        return "(no rows)"

    # ---------- main loop ----------
    exec_count = 0
    for _ in range(MAX_ROUNDS):
        msg = ask_model(messages, max_tokens=300)
        raw = (msg.content or "").strip()

        # 1) JSON/wrapper-style request
        tc = parse_tool_call_from_text(raw)
        if tc and tc.get("sql"):
            sql_stmt = tc["sql"]
            try:
                validate_select(sql_stmt, allowed_tables)
            except Exception as e:
                messages.extend([
                    {"role":"assistant","content": f"Your SQL was blocked: {str(e)}."},
                    {"role":"assistant","content": "Do not use sqlite_*; re-issue a valid SELECT using only the provided schema."}
                ])
                continue

            if exec_count >= MAX_EXEC:
                return summarize_now()

            print("[bridge][SQL]", sql_stmt)
            try:
                data = run_select(conn, sql_stmt, params=None, limit=1000)
            except Exception as e:
                messages.append({"role":"assistant","content": f"Query failed: {repr(e)}. Try a simpler SELECT with COUNT(*) or small aggregates."})
                continue

            exec_count += 1
            messages.extend([
                {"role":"assistant", "content": f"DATA NOTE: {preview_from_rows(data)}"},
                {"role":"assistant", "content": "Summarize the findings in plain English. Do not print JSON or tool calls."}
            ])
            # Instead of looping back (which may cause "please run ..."), force summary now:
            return summarize_now()

        # 2) Plain-text SELECTs (code fences/backticks/lines)
        sql_list = extract_sql_statements(raw, max_stmts=MAX_EXEC)
        if sql_list:
            previews = []
            counts = []  # (table, count) best-effort
            for sql_stmt in sql_list:
                try:
                    validate_select(sql_stmt, allowed_tables)
                except Exception as e:
                    messages.append({"role":"assistant","content": f"SQL blocked: {str(e)}"})
                    continue

                if exec_count >= MAX_EXEC:
                    break

                print("[bridge][SQL]", sql_stmt)
                try:
                    data = run_select(conn, sql_stmt, params=None, limit=1000)
                except Exception as e:
                    messages.append({"role":"assistant","content": f"Query failed: {repr(e)}"})
                    continue

                exec_count += 1
                previews.append(preview_from_rows(data))

                # Try to build deterministic counts summary (if it's COUNT(*))
                if isinstance(data, list) and data:
                    row = data[0]
                    if isinstance(row, dict) and len(row) == 1:
                        # attempt to extract table name from SQL
                        m = re.search(r"from\s+([A-Za-z0-9_]+)", sql_stmt, flags=re.IGNORECASE)
                        tbl = m.group(1) if m else "?"
                        cnt_key = list(row.keys())[0]
                        counts.append((tbl, row[cnt_key]))

            # If we gathered counts, synthesize a local, clean summary and return it immediately
            if counts:
                lines = [f"- {t}: {c}" for t, c in counts]
                table_names = {t.lower() for t, _ in counts if isinstance(t, str)}
                likely_price_tbl = None
                for cand in ["LatestExchangeRates", "ExchangeRates", "FxRateUpdates", "InstrumentPrices", "Prices"]:
                    if cand.lower() in table_names:
                        likely_price_tbl = cand
                        break
                tx_tbl = "Transactions" if "transactions" in table_names else next((t for t in table_names if "transact" in t), "Transactions")

                summary = []
                summary.append("Row counts (sample):")
                summary.extend(lines)
                summary.append("")
                if likely_price_tbl:
                    summary.append(
                        f"Interpretation: Transaction rows are in **{tx_tbl}**; price/FX data is kept in **{likely_price_tbl}**. "
                        "Accounts/Portfolios define structure; PortfolioInstruments links holdings to portfolios."
                    )
                else:
                    summary.append(
                        f"Interpretation: Transaction rows are in **{tx_tbl}**; prices likely live in a dedicated price/FX table "
                        "(e.g., LatestExchangeRates/ExchangeRates/InstrumentPrices) even if not counted above."
                    )
                return "\n".join(summary)

            # Otherwise fall back to asking the model to summarize the previews once, then return.
            if previews:
                messages.extend([
                    {"role":"assistant", "content": "DATA NOTE: " + " ; ".join(previews)},
                    {"role":"assistant", "content": "Summarize findings in plain English. No JSON, no tool calls."}
                ])
                return summarize_now()

        # 3) No DB action requested → treat as final answer, with wrapper cleanup
        txt = re.sub(r"<\|.*?\|>", "", raw).strip()
        if "run_sql_select_safe" in txt or txt.startswith("{") or txt.lower().startswith("select"):
            # Model still trying to show tools/SQL; force a clean summary
            return summarize_now()
        return txt  # clean human answer

    # Safety net if the loop didn't settle
    return summarize_now()


# ---------- Main ----------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base-url", default=DEFAULT_BASE_URL)
    ap.add_argument("--model",    default=DEFAULT_MODEL)
    ap.add_argument("--db",       default=DEFAULT_DB)
    args = ap.parse_args()

    print("[bridge] Using endpoint: {}  model: {}".format(args.base_url, args.model))
    print("[bridge] Opening DB (read-only): {}".format(args.db))

    conn = connect_db(args.db)
    schema = schema_dict(conn)
    print("[bridge] Introspected {} tables/views.".format(len(schema)))

    client = OpenAI(base_url=args.base_url, api_key="not-needed")
    tools: list = []  # unused in text-only mode
    messages = initial_messages(schema)

    out = tool_loop(client, args.model, messages, tools, conn, set(schema.keys()))
    print("\n=== MODEL OUTPUT ===\n")
    print(out)

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print("Fatal:", repr(e), file=sys.stderr)
        sys.exit(1)