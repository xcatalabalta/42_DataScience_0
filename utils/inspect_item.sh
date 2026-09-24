#!/bin/sh
# inspect_item.sh  (utils)
# -----------------------------------------------------------------------------
# Inspects the CSV file(s) in data/item/ (normally a single item.csv), mirroring
# the logic of inspect_customer.sh. Consistency / structure check for defense.
#
# The reference structure is taken from the FIRST file (alphabetically), not
# hardcoded:
#   - EXPECTED_HEADER  = that file's header line
#   - EXPECTED_FIELDS  = number of columns in that header
# Any further files are checked to match. (With a single item.csv the header
# check is trivially satisfied; the logic is kept identical to the customer
# inspector so both scripts behave the same and stay correct if more files
# are ever added.)
#
# Checks performed per file:
#   1. Header identical to the reference file's header.
#   2. Every data row has exactly EXPECTED_FIELDS fields.
#   3. Row count reported.
#   4. Empty-value count per column. For item, empties are EXPECTED and normal
#      (category_id ~38% empty, category_code ~99% empty), so this is purely
#      informative and never treated as an error.
#   5. Type-shape sanity (only for the known 4-column item layout:
#      product_id,category_id,category_code,brand):
#        product_id (col1) int, category_id (col2) int (both when non-empty);
#        category_code (col3) and brand (col4) are free text -> not shape-checked.
#      Column semantics cannot be auto-derived, so this runs only for 4 columns.
#
# Exits 0 if consistent, non-zero if any problem is found.
# Self-locating: finds data/item relative to the repo root (script in utils/).
#
# Run:  ./utils/inspect_item.sh   |   sh utils/inspect_item.sh
# -----------------------------------------------------------------------------
set -eu

# --- Locate data/item relative to the repo root -----------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"   # utils/
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"   # repo root
DATA_DIR="${REPO_ROOT}/data/item"

if [ ! -d "${DATA_DIR}" ]; then
    echo "ERROR: ${DATA_DIR} not found. Run the decompress step first." >&2
    exit 1
fi

# Collect the CSV files (sorted, stable order)
CSV_FILES="$(find "${DATA_DIR}" -maxdepth 1 -name '*.csv' | sort)"
if [ -z "${CSV_FILES}" ]; then
    echo "ERROR: no CSV files in ${DATA_DIR}" >&2
    exit 1
fi

# --- Derive the reference structure from the FIRST file ---------------------
FIRST_FILE="$(printf '%s\n' ${CSV_FILES} | head -1)"
EXPECTED_HEADER="$(head -1 "${FIRST_FILE}")"
EXPECTED_FIELDS="$(printf '%s' "${EXPECTED_HEADER}" | awk -F',' '{print NF}')"

echo "Inspecting CSV files in ${DATA_DIR}"
echo "Reference file  : $(basename "${FIRST_FILE}")"
echo "Expected header : ${EXPECTED_HEADER}"
echo "Expected fields : ${EXPECTED_FIELDS}"
echo "-------------------------------------------------------------------------"

problems=0

for f in ${CSV_FILES}; do
    name="$(basename "${f}")"
    echo ""
    echo "== ${name} =="

    # --- Check 1: header matches the reference
    header="$(head -1 "${f}")"
    if [ "${header}" = "${EXPECTED_HEADER}" ]; then
        echo "  header      : OK"
    else
        echo "  header      : MISMATCH"
        echo "                got: ${header}"
        problems=$((problems + 1))
    fi

    # --- Check 2: every data row has exactly EXPECTED_FIELDS fields
    bad_fields="$(tail -n +2 "${f}" | awk -F',' -v n="${EXPECTED_FIELDS}" \
        'NF!=n{c++} END{print c+0}')"
    if [ "${bad_fields}" -eq 0 ]; then
        echo "  field count : OK (all rows have ${EXPECTED_FIELDS} fields)"
    else
        echo "  field count : ${bad_fields} row(s) NOT ${EXPECTED_FIELDS} fields"
        problems=$((problems + 1))
    fi

    # --- Check 3: row count (data rows, excluding header)
    rows="$(tail -n +2 "${f}" | wc -l)"
    echo "  data rows   : ${rows}"

    # --- Check 4: empty-value count per column (informative; empties expected)
    echo "  empty per column:"
    tail -n +2 "${f}" | awk -F',' -v n="${EXPECTED_FIELDS}" -v hdr="${EXPECTED_HEADER}" '
        BEGIN { split(hdr, names, ",") }
        {
            for (i = 1; i <= n; i++)
                if ($i == "") empty[i]++
        }
        END {
            for (i = 1; i <= n; i++)
                printf "                %-14s : %d\n", names[i], empty[i]+0
        }'

    # --- Check 5: type-shape sanity, only for the known 4-column item shape
    if [ "${EXPECTED_FIELDS}" -eq 4 ]; then
        shape="$(tail -n +2 "${f}" | awk -F',' '
            $1 != "" && $1 !~ /^[0-9]+$/ { badp++ }
            $2 != "" && $2 !~ /^[0-9]+$/ { badc++ }
            END { printf "%d %d", badp+0, badc+0 }')"
        set -- ${shape}
        badp=$1; badc=$2
        if [ "${badp}" -eq 0 ] && [ "${badc}" -eq 0 ]; then
            echo "  type shapes : OK (product_id & category_id integer when present)"
        else
            echo "  type shapes : product_id bad=${badp}, category_id bad=${badc}"
            problems=$((problems + 1))
        fi
    else
        echo "  type shapes : skipped (only checked for the known 4-column shape)"
    fi
done

echo ""
echo "-------------------------------------------------------------------------"
if [ "${problems}" -eq 0 ]; then
    echo "RESULT: file(s) OK (header + field count$( [ "${EXPECTED_FIELDS}" -eq 4 ] && printf ' + valid shapes')). Empty counts reported above."
    exit 0
else
    echo "RESULT: ${problems} problem(s) found. See details above."
    exit 1
fi
