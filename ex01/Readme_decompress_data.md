# `decompress_data.sh` — ex01 data setup helper

## Purpose

Reconstructs the project's data folders from the subject archive so the later
exercises (ex02, ex03, ex04) can read the CSVs through the relative paths
`customer/` and `item/`.

The subject ships its data as a single ZIP (`subject.zip`) whose contents are
nested under a top-level `subject/` directory:

```
subject/
├── customer/
│   ├── data_2022_dec.csv
│   ├── data_2022_nov.csv
│   ├── data_2022_oct.csv
│   └── data_2023_jan.csv
└── item/
    └── item.csv
```

This script extracts that archive and **strips the leading `subject/`**, so the
folders land as `customer/` and `item/` **at the repository root**.

## Prerequisite

The archive must already be downloaded to `~/data_postgres/subject.zip`. This is
a one-time VM setup step, documented in `ex00/VM-instructions.txt`. Neither the
archive nor the extracted CSVs are tracked in git (see the repo `.gitignore`);
they are input data, not deliverables.

## How to run

The script lives in `ex01/` and can be launched from either location — it
locates itself and always operates on the repository root:

```sh
# from inside ex01/
./decompress_data.sh

# or from the repository root
./ex01/decompress_data.sh

# force a fresh re-extraction even if customer/ and item/ already exist
./decompress_data.sh --force
```

After running, `customer/` and `item/` exist at the repo root and
`git status` should report nothing about them (proving they are ignored).

---

## Line-by-line explanation of the main commands

### `set -eu`

Two shell safety switches:

- **`-e` (errexit)** — the script exits immediately if any command returns a
  non-zero (failure) status, instead of continuing past an error. Prevents a
  failed extraction from cascading into further broken steps.
- **`-u` (nounset)** — referencing an undefined variable is treated as an error
  rather than silently expanding to an empty string. Catches typos in variable
  names. (This is why optional arguments are read as `${1:-}` — the `:-`
  supplies an empty default so `-u` does not complain when no argument is given.)

Together: **fail fast and loud** rather than limp on quietly.

### `[ "${1:-}" = "--force" ] && FORCE=1`

Sets the `FORCE` flag. `FORCE` starts at `0` (off). `${1:-}` is "the first
command-line argument, or empty if there is none". If it equals `--force`,
`FORCE` becomes `1`, which later bypasses the "already populated, skip" check so
the data is re-extracted.

### Locating the repository root

```sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"   # absolute path to ex01/
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"   # its parent = repo root
cd "${REPO_ROOT}"
```

- **`$0`** — the path by which the script was invoked (may be relative).
- **`dirname "$0"`** — strips the filename, leaving the directory part.
- **`cd "$(dirname "$0")" && pwd`** — moves into that directory, then prints its
  **absolute, fully-resolved** path (`pwd` always outputs a clean path with no
  `..` or relative pieces). The `&&` runs `pwd` only if the `cd` succeeded.
- **`"$( ... )"`** — command substitution captures that printed path as a string.

So `SCRIPT_DIR` becomes the absolute path of `ex01/`, and `REPO_ROOT` becomes the
absolute path of its parent (the repo root), computed the same way via
`${SCRIPT_DIR}/..`.

Note: the `cd` inside `$( ... )` runs in a **subshell**, so it does not move the
running script — it only computes the path. The separate `cd "${REPO_ROOT}"`
afterwards is what actually relocates the script to the repo root, so `customer/`
and `item/` land there regardless of the caller's current directory.

### Archive presence check

```sh
if [ ! -f "${ARCHIVE}" ]; then
    echo "ERROR: archive not found at ${ARCHIVE}" >&2
    exit 1
fi
```

- **`[ ! -f "${ARCHIVE}" ]`** — true if the archive file does **not** exist
  (`-f` tests for a regular file; `!` negates).
- **`>&2`** — sends the message to **stderr** (the error stream) rather than
  stdout, the conventional place for error output.
- **`exit 1`** — stop with a non-zero status, signalling failure.

### `unzip` availability check

```sh
if ! command -v unzip >/dev/null 2>&1; then ...
```

- **`command -v unzip`** — the portable way to test whether `unzip` is on the
  `PATH`; prints its location if found.
- **`>/dev/null 2>&1`** — discard both stdout (`>/dev/null`) and stderr
  (`2>&1` = "send stderr to the same place as stdout"), so only the exit status
  matters.
- **`! ... ; then`** — run the error branch when the command is **not** found.

### "Already populated?" skip check

```sh
if [ "${FORCE}" -eq 0 ] && [ -d customer ] && [ -n "$(ls -A customer 2>/dev/null)" ] \
   && [ -d item ] && [ -n "$(ls -A item 2>/dev/null)" ]; then
    echo "customer/ and item/ already populated. Nothing to do."
    exit 0
fi
```

Skips the work only when **all** are true: force is off, and both folders exist
**and are non-empty**.

- **`[ -d customer ]`** — `customer/` exists and is a directory.
- **`ls -A customer`** — list its contents; `-A` = "almost all" (includes hidden
  dotfiles but excludes the `.` and `..` entries), giving a true content listing.
- **`2>/dev/null`** — silence errors if the folder is missing.
- **`[ -n "$(...)" ]`** — `-n` is true when the string is **non-empty**, i.e. the
  listing produced something → the folder actually has content.

The extra non-empty test matters because `[ -d ]` alone would treat an empty
left-over folder from a half-failed run as "already done".

### Extraction

```sh
unzip -q -o "${ARCHIVE}" -d "${TMPDIR}"
```

- **`-q` (quiet)** — suppress unzip's per-file output (the script prints its own
  tidy status messages instead).
- **`-o` (overwrite)** — overwrite existing files **without prompting**. Without
  it, unzip would stop and interactively ask, which would hang a script.
- **`-d "${TMPDIR}"`** — extract **into** the given directory rather than the
  current one. Everything lands under a temp dir first, then the inner
  `subject/customer` and `subject/item` are moved into place.

### Moving the folders into place

```sh
rm -rf customer item
mv "${TMPDIR}/subject/customer" customer
mv "${TMPDIR}/subject/item" item
rm -rf "${TMPDIR}"
```

Removes any previous targets, then moves the extracted inner folders up to the
repo root under the desired names (dropping the `subject/` prefix), and cleans up
the temp directory.

---

## Design properties

- **Self-locating** — works whether run from `ex01/` or the repo root, because it
  derives all paths from the script's own location, not the caller's directory.
- **Idempotent** — safe to re-run; skips if already populated, `--force` to redo.
- **Fails fast** — `set -eu`, explicit precondition checks, and clear error
  messages on stderr.
- **Non-interactive** — `-q`/`-o` ensure it never stalls waiting for input, so it
  runs cleanly unattended.

## Quick reference

| Element | Meaning |
|---|---|
| `set -e` | exit on any command failure |
| `set -u` | error on undefined variable |
| `${1:-}` | first arg, or empty (safe under `-u`) |
| `$(cd DIR && pwd)` | absolute, resolved path of DIR |
| `$( ... )` | command substitution (runs in a subshell) |
| `-f FILE` | test: FILE exists and is a regular file |
| `-d DIR` | test: DIR exists and is a directory |
| `-n STR` | test: STR is non-empty |
| `command -v X` | portable "is X on PATH?" |
| `>&2` | write to stderr |
| `>/dev/null 2>&1` | discard stdout and stderr |
| `ls -A` | list contents incl. dotfiles, excl. `.`/`..` |
| `unzip -q` | quiet |
| `unzip -o` | overwrite without prompting |
| `unzip -d DIR` | extract into DIR |