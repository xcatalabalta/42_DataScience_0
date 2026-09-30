# Piscine DataScience Module 0

This repository is a PostgreSQL data-loading project for a data science exercise set. It prepares a local PostgreSQL database, extracts the provided CSV datasets, and loads them into relational tables so the data can be queried and analyzed.

The project is organized around a VM setup step, a data extraction step, and a series of exercise scripts that create tables from customer and item datasets.

## Project purpose

The repository is designed to:

- initialize a PostgreSQL database named `piscineds` for the user `fcatala-`
- configure password-based TCP authentication for localhost connections
- download or place the subject archive containing the dataset
- extract the provided CSV files into the repository data folders
- create PostgreSQL tables that mirror the dataset schemas
- validate dataset consistency and reset the database when needed

It is not a general application framework; it is a focused data engineering exercise built around a fixed dataset and Postgres imports.

---

## Repository structure

```text
DataScience_0/
├── .gitignore
├── README.md
├── Readme_decompress_data.md
├── data/
│   ├── customer/
│   │   ├── data_2022_oct.csv
│   │   ├── data_2022_nov.csv
│   │   ├── data_2022_dec.csv
│   │   └── data_2023_jan.csv
│   └── items/
│       └── item.csv
├── ex00/
│   └── VM-instructions.txt
├── ex01/
│   └── (project notes refer to this directory; automation scripts are under utils/)
├── ex02/
│   └── table.py
├── ex03/
│   └── automatic_table.py
├── ex04/
│   └── items_table.py
├── utils/
│   ├── decompress_data.sh
│   ├── inspect_customer.sh
│   ├── inspect_item.sh
│   ├── reset_db.py
│   ├── reset_project.sh
│   ├── decompress_customer.sh
│   ├── decompress_item.sh
│   └── ...
└── DataScience_0.code-workspace
```

### Key folders

- `data/`: contains extracted CSV datasets used by the exercises
- `ex00/`: VM and PostgreSQL setup guidance
- `ex02/`: single-table import example
- `ex03/`: bulk table creation for all monthly customer files
- `ex04/`: item table creation script
- `utils/`: data extraction, validation, and reset helpers

---

## Database and environment requirements

The repository expects a Linux VM with:

- Alpine Linux OpenRC-based environment
- PostgreSQL 17 installed
- a local PostgreSQL user named `fcatala-`
- a database named `piscineds`
- localhost password authentication enabled via `scram-sha-256`

The setup instructions in `ex00/VM-instructions.txt` describe the required PostgreSQL configuration, including:

- creating the role `"fcatala-"`
- creating the database `piscineds`
- changing `pg_hba.conf` to require password authentication on `127.0.0.1` and `::1`
- testing both successful and failed password-based connections

The expected connection string is:

```bash
psql -U fcatala- -d piscineds -h localhost -W
```

---

## Data model

The dataset contains two groups of files:

### 1) Customer event data

Path:

```text
data/customer/
```

Files:

- `data_2022_oct.csv`
- `data_2022_nov.csv`
- `data_2022_dec.csv`
- `data_2023_jan.csv`

Format:

```csv
event_time,event_type,product_id,price,user_id,user_session
2022-10-01 00:00:00 UTC,cart,5773203,2.62,463240011,26dd6e6e-4dac-4778-8d2c-92e149dab885
```

Suggested PostgreSQL schema used by the exercise scripts:

```sql
CREATE TABLE data_2022_oct (
    event_time   TIMESTAMP     NOT NULL,
    event_type   VARCHAR(32)   NOT NULL,
    product_id   INTEGER,
    price        NUMERIC(10,2),
    user_id      BIGINT,
    user_session UUID
);
```

These CSVs are all intended to share the same structure, which is why the validation scripts check header consistency and row shape across all customer files.

### 2) Item catalog data

Path:

```text
data/items/item.csv
```

Format:

```csv
product_id,category_id,category_code,brand
5712790,1487580005268456192,,f.o.x
```

Suggested schema:

```sql
CREATE TABLE items (
    product_id    INTEGER,
    category_id   BIGINT,
    category_code VARCHAR(64),
    brand         VARCHAR(64)
);
```

`COPY ... FROM STDIN WITH (FORMAT csv, HEADER true, NULL '')` is used to load the CSVs while treating empty values as SQL `NULL`.

---

## Setup workflow

### 1) Configure PostgreSQL

Follow the instructions in `ex00/VM-instructions.txt` to install PostgreSQL, create the database, and enforce password authentication over TCP.

### 2) Download the archive

The data extraction scripts expect the assignment archive to be available at:

```bash
~/data_postgres/subject.zip
```

This is the project archive provided by the exercise subject. It is not tracked in Git and is ignored by the repository.

### 3) Extract the data

The extraction helper is provided in `utils/decompress_data.sh`.

Example:

```bash
cd /path/to/DataScience_0
./utils/decompress_data.sh
```

This extracts the archive into the repository and makes the data available at:

```text
data/customer/
data/items/
```

A `--force` option can be used to re-extract the files.

---

## Exercise scripts

### `ex02/table.py`

Creates and loads a single table, `data_2022_oct`, from the October customer CSV.

What it does:

- resolves the CSV path relative to the script location
- prompts for the database password if needed
- connects to PostgreSQL on localhost
- drops the table if it exists
- creates the schema
- loads the CSV using `COPY`
- prints row counts before and after import

Usage:

```bash
cd ex02
python3 table.py
```

### `ex03/automatic_table.py`

Loads all customer CSV files in `data/customer/` into matching PostgreSQL tables whose names are derived from the file names.

Examples:

- `data_2022_oct.csv` -> `data_2022_oct`
- `data_2022_nov.csv` -> `data_2022_nov`
- `data_2023_jan.csv` -> `data_2023_jan`

This script handles each file in sequence and continues after errors instead of aborting the whole run.

Usage:

```bash
cd ex03
python3 automatic_table.py
```

### `ex04/items_table.py`

Creates the `items` table from the item catalog CSV.

Usage:

```bash
cd ex04
python3 items_table.py
```

---

## Utility scripts

### `utils/decompress_data.sh`

Main data extraction helper for the project. It locates the repository root dynamically and extracts the subject archive into `data/customer` and `data/items`.

### `utils/inspect_customer.sh`

Checks that all customer CSV files share the same header and structure. It also reports missing values and validates the expected numeric and UUID-shaped fields.

### `utils/reset_db.py`

Drops every table in the `public` schema of `piscineds` while leaving the database itself and the PostgreSQL configuration intact.

Usage:

```bash
./utils/reset_db.py
./utils/reset_db.py --yes
```

### `utils/reset_project.sh`

Removes the data directory and lists the project tree again. It is a broad cleanup script for the project state rather than a database reset.

### `utils/inspect_item.sh` and `utils/decompress_*` helpers

These scripts support the same project workflow for item extraction and inspection, and follow the same self-locating repository-root pattern as the other utilities.

---

## Validation and quality checks

The repository includes several defensive checks for correctness:

- schema validation for customer CSV files
- checks that row counts match CSV sizes
- validation of header consistency across customer data files
- verification that event data columns contain expected types and UUID-like values
- idempotent database setup and import scripts

Example validation:

```bash
./utils/inspect_customer.sh
```

This helps confirm that the CSV files are consistent before the PostgreSQL schema is reused across all monthly files.

---

## Typical workflow

```bash
# 1. configure PostgreSQL and create the database
# see ex00/VM-instructions.txt

# 2. download the subject archive into ~/data_postgres

# 3. extract project data
./utils/decompress_data.sh

# 4. inspect data consistency
./utils/inspect_customer.sh
./utils/inspect_item.sh

# 5. create the monthly customer tables
# To follow exactly the result of the ls -lAr command:
./utils/decompress_customer.sh
cd ex03 && python3 automatic_table.py

# 6. create the items table
# To follow exactly the result of the ls -lAr command:
./utils/decompress_item.sh
cd ../ex04 && python3 items_table.py


```

---

## Detailed decompression notes

For more technical details about the archive extraction workflow, including the repository-root detection logic, `--force` behavior, and the shell safety checks used by the decompression helper, see [Readme_decompress_data.md](Readme_decompress_data.md).

This companion document explains the inner workings of the extraction script in greater depth and is useful when troubleshooting unexpected archive-layout or path issues.

---

## Notes

- `data/` and `*.csv` are intentionally ignored by Git via `.gitignore`.
- The repository relies on a local database setup rather than Docker.
- Scripts are implemented to be self-locating, so they work when launched from different working directories.
- Most scripts prefer environment variables or interactive password prompts rather than storing credentials in the source files.

---

## Summary

This project is a data ingestion and schema-validation exercise built around PostgreSQL and customer/event datasets. The main emphasis is on:

- setting up a database environment
- extracting external CSV data into a repo-local structure
- creating typed database tables that match the source data
- validating consistency and reloading data cleanly when necessary

It is a compact, practical PostgreSQL data-loading repository rather than a production application.
