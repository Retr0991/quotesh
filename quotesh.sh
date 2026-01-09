#!/bin/sh
# quotesh.sh - Terminal greeter with random quotes
# POSIX-compliant shell script
# Source this file in your .zshrc or .bashrc

# ============================================================
# CONFIGURATION
# ============================================================

QUOTESH_DIR="${QUOTESH_DIR:-$(cd "$(dirname "$0" 2>/dev/null)" && pwd 2>/dev/null)}"
QUOTESH_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/quotesh"
QUOTESH_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/quotesh/quotesh.conf"
QUOTESH_DB="${QUOTESH_DATA_DIR}/quotes.db"
QUOTESH_LOG="${QUOTESH_DATA_DIR}/logs/fetcher.log"
QUOTESH_PYTHON="${QUOTESH_PYTHON:-python3}"

QUOTESH_ENABLED="${QUOTESH_ENABLED:-1}"
QUOTESH_FETCH_ON_START="${QUOTESH_FETCH_ON_START:-1}"
QUOTESH_BOX_STYLE="${QUOTESH_BOX_STYLE:-rounded}"
QUOTESH_MAX_WIDTH="${QUOTESH_MAX_WIDTH:-80}"

# Source user config if exists
[ -f "$QUOTESH_CONFIG" ] && . "$QUOTESH_CONFIG"

# ============================================================
# INITIALIZATION
# ============================================================

_quotesh_init() {
    # Ensure data directories exist
    mkdir -p "$QUOTESH_DATA_DIR/logs" 2>/dev/null

    # Initialize database if needed
    if [ ! -f "$QUOTESH_DB" ]; then
        _quotesh_init_db
    fi
}

_quotesh_init_db() {
    sqlite3 "$QUOTESH_DB" >/dev/null 2>&1 <<'EOSQL'
CREATE TABLE IF NOT EXISTS quotes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    show TEXT NOT NULL,
    character TEXT NOT NULL,
    quote TEXT NOT NULL,
    source_api TEXT,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(show, character, quote)
);

CREATE TABLE IF NOT EXISTS display_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    quote_id INTEGER NOT NULL,
    displayed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (quote_id) REFERENCES quotes(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_display_history_quote_id ON display_history(quote_id);

CREATE TABLE IF NOT EXISTS fetch_metadata (
    api_name TEXT PRIMARY KEY,
    last_fetch TIMESTAMP,
    fetch_count INTEGER DEFAULT 0
);

-- Insert default quotes if empty
INSERT OR IGNORE INTO quotes (show, character, quote) VALUES
    ('quotesh', 'System', 'Welcome to quotesh! Configure your API to fetch more quotes.'),
    ('The Office', 'Michael Scott', 'Would I rather be feared or loved? Easy. Both. I want people to be afraid of how much they love me.'),
    ('Breaking Bad', 'Walter White', 'I am not in danger, Skyler. I am the danger.');
EOSQL
}

# ============================================================
# QUOTE RETRIEVAL (Weighted Random)
# ============================================================

_quotesh_get_random_quote() {
    # Returns: id|show|character|quote
    sqlite3 -separator '|' "$QUOTESH_DB" <<'EOSQL'
WITH quote_weights AS (
    SELECT
        q.id, q.show, q.character, q.quote,
        CASE
            WHEN dh.last_displayed IS NULL THEN 100.0
            WHEN julianday('now') - julianday(dh.last_displayed) > 30 THEN 80.0
            WHEN julianday('now') - julianday(dh.last_displayed) > 7 THEN 50.0
            WHEN julianday('now') - julianday(dh.last_displayed) > 1 THEN 20.0
            ELSE 5.0
        END / (1.0 + COALESCE(dh.display_count, 0)) AS weight
    FROM quotes q
    LEFT JOIN (
        SELECT quote_id, COUNT(*) AS display_count, MAX(displayed_at) AS last_displayed
        FROM display_history GROUP BY quote_id
    ) dh ON q.id = dh.quote_id
),
weighted AS (
    SELECT id, show, character, quote, weight,
        SUM(weight) OVER (ORDER BY id) AS cumulative,
        SUM(weight) OVER () AS total
    FROM quote_weights WHERE weight > 0
),
target AS (
    SELECT (ABS(RANDOM()) % CAST(MAX(total) * 1000 AS INTEGER)) / 1000.0 AS val FROM weighted
)
SELECT w.id, w.show, w.character, w.quote
FROM weighted w, target t
WHERE w.cumulative >= t.val
ORDER BY w.cumulative LIMIT 1;
EOSQL
}

_quotesh_record_display() {
    # Record that a quote was displayed
    # Args: $1 = quote_id
    sqlite3 "$QUOTESH_DB" "INSERT INTO display_history (quote_id) VALUES ($1);" >/dev/null 2>&1
}

# ============================================================
# DISPLAY FUNCTIONS
# ============================================================

_quotesh_repeat_char() {
    # Repeat a character N times (POSIX-compatible)
    _qr_char="$1"
    _qr_count="$2"
    _qr_i=0
    while [ "$_qr_i" -lt "$_qr_count" ]; do
        printf '%s' "$_qr_char"
        _qr_i=$((_qr_i + 1))
    done
}

_quotesh_draw_box() {
    # Draw ASCII box around text
    # Args: $1 = quote, $2 = character, $3 = show
    _qd_quote="$1"
    _qd_character="$2"
    _qd_show="$3"
    _qd_width="${QUOTESH_MAX_WIDTH:-80}"
    _qd_inner_width=$((_qd_width - 4))

    # Box characters based on style
    case "$QUOTESH_BOX_STYLE" in
        double)
            _qd_tl="╔" _qd_tr="╗" _qd_bl="╚" _qd_br="╝" _qd_h="═" _qd_v="║"
            ;;
        simple)
            _qd_tl="+" _qd_tr="+" _qd_bl="+" _qd_br="+" _qd_h="-" _qd_v="|"
            ;;
        *)  # rounded (default)
            _qd_tl="╭" _qd_tr="╮" _qd_bl="╰" _qd_br="╯" _qd_h="─" _qd_v="│"
            ;;
    esac

    # Draw top border
    printf '%s' "$_qd_tl"
    _quotesh_repeat_char "$_qd_h" $((_qd_width - 2))
    printf '%s\n' "$_qd_tr"

    # Empty line after top border
    printf '%s %-*s %s\n' "$_qd_v" "$_qd_inner_width" "" "$_qd_v"

    # Draw wrapped quote with proper indentation
    printf '%s' "$_qd_quote" | fold -s -w "$_qd_inner_width" | while IFS= read -r _qd_line || [ -n "$_qd_line" ]; do
        printf '%s  %-*s %s\n' "$_qd_v" "$((_qd_inner_width - 1))" "$_qd_line" "$_qd_v"
    done

    # Empty line before attribution
    printf '%s %-*s %s\n' "$_qd_v" "$_qd_inner_width" "" "$_qd_v"

    # Draw attribution line (right-aligned)
    _qd_attribution="— $_qd_character ($_qd_show)"
    printf '%s %*s %s\n' "$_qd_v" "$_qd_inner_width" "$_qd_attribution" "$_qd_v"

    # Empty line after attribution
    printf '%s %-*s %s\n' "$_qd_v" "$_qd_inner_width" "" "$_qd_v"

    # Draw bottom border
    printf '%s' "$_qd_bl"
    _quotesh_repeat_char "$_qd_h" $((_qd_width - 2))
    printf '%s\n' "$_qd_br"
}

# ============================================================
# BACKGROUND FETCHER
# ============================================================

_quotesh_spawn_fetcher() {
    # Spawn background Python fetcher (fully detached)
    # & inside subshell avoids job control notifications in zsh
    if [ "$QUOTESH_FETCH_ON_START" = "1" ] && [ -d "$QUOTESH_DIR/fetcher" ]; then
        (
            cd "$QUOTESH_DIR" && \
            "$QUOTESH_PYTHON" -m fetcher \
                --db "$QUOTESH_DB" \
                --log "$QUOTESH_LOG" \
                </dev/null >/dev/null 2>&1 &
        )
    fi
}

# ============================================================
# MAIN ENTRY POINT
# ============================================================

quotesh() {
    # Main function - display a random quote
    [ "$QUOTESH_ENABLED" != "1" ] && return 0

    # Check for sqlite3
    if ! command -v sqlite3 >/dev/null 2>&1; then
        printf 'quotesh: sqlite3 not found\n' >&2
        return 1
    fi

    # Initialize if needed
    _quotesh_init

    # Get random quote
    _qs_result="$(_quotesh_get_random_quote)"

    if [ -n "$_qs_result" ]; then
        # Parse pipe-separated values
        _qs_quote_id="${_qs_result%%|*}"
        _qs_rest="${_qs_result#*|}"
        _qs_show="${_qs_rest%%|*}"
        _qs_rest="${_qs_rest#*|}"
        _qs_character="${_qs_rest%%|*}"
        _qs_quote_text="${_qs_rest#*|}"

        # Display the quote
        _quotesh_draw_box "$_qs_quote_text" "$_qs_character" "$_qs_show"

        # Record display (in background to not block, & inside subshell to avoid job notification)
        ( _quotesh_record_display "$_qs_quote_id" >/dev/null 2>&1 & )
    fi

    # Spawn background fetcher
    _quotesh_spawn_fetcher
}

# Auto-run on source (only if interactive shell and not already run)
case "$-" in
    *i*)
        if [ -z "$QUOTESH_SOURCED" ]; then
            QUOTESH_SOURCED=1
            export QUOTESH_SOURCED
            quotesh
        fi
        ;;
esac
