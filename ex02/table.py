#!/usr/bin/env python3
"""
ex02 / table.py

Creates the PostgreSQL table `data_2022_oct`
It loads it from the customer CSV.

Schema requirement (subject):
  - DATETIME column as the mandatory FIRST column
  - at least SIX different data types

Columns / types chosen (six distinct types):
  event_time    TIMESTAMP      datetime, first column
  event_type    VARCHAR(32)    short label:
                cart / view / purchase / remove_from_cart
  product_id    INTEGER        max ~5.9M across all months -> fits INTEGER
  price         NUMERIC(10,2)  exact money (negatives allowed; no CHECK)
  user_id       BIGINT         max ~609M and growing -> BIGINT for headroom
  user_session  UUID           native UUID type

Run it (both work; the script has a shebang and is executable):
    ./table.py
    python3 table.py

Connection:
  Connects as user 'fcatala-' to database 'piscineds' over TCP (localhost:5432)
  which uses password authentication (scram-sha-256). The password is requested
  interactively without echo (getpass). If a ~/.pgpass entry exists, psycopg2
  uses it automatically and the prompt still appears only as a fallback when no
  password is otherwise available. The password is never stored in this file.

Idempotent: DROP TABLE IF EXISTS then CREATE, so re-running gives a clean load.
Self-locating: finds customer/data_2022_oct.csv relative to this script's
location, so it works whether run from ex02/ or from the repo root.
"""

import os
import sys
import getpass
import psycopg2

# --- Configuration ----------------------------------------------------------
DB_NAME = "piscineds"
DB_USER = "fcatala-"
DB_HOST = "localhost"
DB_PORT = 5432

TABLE_NAME = "data_2022_oct"
CSV_RELATIVE = os.path.join("customer", "data_2022_oct.csv")

CREATE_SQL = f"""
CREATE TABLE {TABLE_NAME} (
    event_time      TIMESTAMP     NOT NULL,
    event_type      VARCHAR(32)   NOT NULL,
    product_id      INTEGER,
    price           NUMERIC(10,2),
    user_id         BIGINT,
    user_session    UUID
);
"""

COPY_SQL = f"""
COPY {TABLE_NAME} (event_time, event_type, product_id, price, user_id,
user_session)
FROM STDIN WITH (FORMAT csv, HEADER true, NULL '');
"""


def find_csv_path():
    """
    Resolve the CSV relative to the repo root, derived from this script's
    location (script lives in ex02/, so the repo root is its parent).
    Arguments:
        None
    Returns:
        the absolute path to the CSV (string) if found,
    or exits with an error if not found.
    """
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(script_dir)  # parent of ex02/
    csv_path = os.path.join(repo_root, CSV_RELATIVE)
    if not os.path.isfile(csv_path):
        sys.exit(f"ERROR: CSV not found at {csv_path}\n"
                 f"Did you run ex01/decompress_data.sh first?")
    return csv_path


def get_password():
    """
    Prefer PGPASSWORD if already set in the environment; otherwise prompt
    without echoing. psycopg2 will also consult ~/.pgpass on its own.
    Arguments:
        None
    Returns:
        the password (string)
    """
    env_pw = os.environ.get("PGPASSWORD")
    if env_pw:
        return env_pw
    return getpass.getpass(f"Password for PostgreSQL user '{DB_USER}': ")


def main():
    """
    Main function to execute the table creation and data loading process.
    Arguments:
        None
    Returns:
        None
    """
    csv_path = find_csv_path()
    password = get_password()

    try:
        conn = psycopg2.connect(
            dbname=DB_NAME, user=DB_USER, password=password,
            host=DB_HOST, port=DB_PORT,
        )
    except psycopg2.OperationalError as e:
        sys.exit(f"ERROR: could not connect to the database.\n{e}")

    try:
        # commits on success, rolls back on error
        with conn:
            with conn.cursor() as cur:
                print(f"Dropping table {TABLE_NAME} if it exists ...")
                cur.execute(f"DROP TABLE IF EXISTS {TABLE_NAME};")

                print(f"Creating table {TABLE_NAME} ...")
                cur.execute(CREATE_SQL)

                print(f"Loading data from {csv_path} ...")
                with open(csv_path, "r") as f:
                    cur.copy_expert(COPY_SQL, f)

                cur.execute(f"SELECT count(*) FROM {TABLE_NAME};")
                (rowcount,) = cur.fetchone()
                print(f"Done. {TABLE_NAME} now contains {rowcount} rows.")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
