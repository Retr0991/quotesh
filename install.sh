#!/bin/sh
# quotesh installer
# Installs quotesh and adds it to your shell configuration

set -e

# Colors for output (if terminal supports it)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

log_info() {
    printf "${GREEN}[INFO]${NC} %s\n" "$1"
}

log_warn() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

log_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

# Get the directory where this script is located
QUOTESH_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/quotesh"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quotesh"

printf '\n'
printf '╭─────────────────────────────────────╮\n'
printf '│       quotesh installer             │\n'
printf '│   Terminal Greeter with Quotes      │\n'
printf '╰─────────────────────────────────────╯\n'
printf '\n'

# Check dependencies
log_info "Checking dependencies..."

if ! command -v sqlite3 >/dev/null 2>&1; then
    log_error "sqlite3 is required but not installed."
    log_error "Please install sqlite3 and try again."
    exit 1
fi
log_info "sqlite3: OK"

if ! command -v python3 >/dev/null 2>&1; then
    log_warn "python3 not found. Background fetching will not work."
    log_warn "Install python3 for full functionality."
else
    log_info "python3: OK"
fi

# Create directories
log_info "Creating directories..."
mkdir -p "$DATA_DIR/logs"
mkdir -p "$CONFIG_DIR"

# Create default config if not exists
if [ ! -f "$CONFIG_DIR/quotesh.conf" ]; then
    log_info "Creating default configuration..."
    cat > "$CONFIG_DIR/quotesh.conf" <<'EOF'
# quotesh configuration
# This file is sourced by quotesh.sh - use shell syntax

# Enable/disable quotesh (1 = enabled, 0 = disabled)
QUOTESH_ENABLED=1

# Spawn fetcher on terminal start (1 = yes, 0 = no)
QUOTESH_FETCH_ON_START=1

# Box style: simple, double, rounded
QUOTESH_BOX_STYLE="rounded"

# Maximum width of the quote box
QUOTESH_MAX_WIDTH=80

# Python interpreter (if not in PATH)
# QUOTESH_PYTHON="/usr/bin/python3"
EOF
    log_info "Config created at: $CONFIG_DIR/quotesh.conf"
else
    log_info "Config already exists at: $CONFIG_DIR/quotesh.conf"
fi

# Make scripts executable
log_info "Setting permissions..."
chmod +x "$QUOTESH_DIR/quotesh.sh"
chmod +x "$QUOTESH_DIR/fetcher.py"

# Function to add quotesh to shell RC file
add_to_rc() {
    rc_file="$1"
    shell_name="$2"

    if [ -f "$rc_file" ]; then
        if grep -q "quotesh.sh" "$rc_file" 2>/dev/null; then
            log_info "quotesh already configured in $rc_file"
            return 0
        fi

        printf '\n' >> "$rc_file"
        printf '# quotesh - terminal greeter\n' >> "$rc_file"
        printf 'export QUOTESH_DIR="%s"\n' "$QUOTESH_DIR" >> "$rc_file"
        printf '. "%s/quotesh.sh"\n' "$QUOTESH_DIR" >> "$rc_file"

        log_info "Added quotesh to $rc_file"
        return 1  # Return 1 to indicate we made changes
    fi
    return 0
}

# Detect shell and configure
log_info "Configuring shell..."
CHANGES_MADE=0

case "$SHELL" in
    */zsh)
        add_to_rc "$HOME/.zshrc" "zsh" || CHANGES_MADE=1
        ;;
    */bash)
        add_to_rc "$HOME/.bashrc" "bash" || CHANGES_MADE=1
        ;;
    *)
        log_warn "Unknown shell: $SHELL"
        log_warn "Please manually add to your shell RC file:"
        printf '\n'
        printf '    export QUOTESH_DIR="%s"\n' "$QUOTESH_DIR"
        printf '    . "%s/quotesh.sh"\n' "$QUOTESH_DIR"
        printf '\n'
        ;;
esac

# Initialize database
log_info "Initializing database..."
export QUOTESH_DIR
export QUOTESH_ENABLED=0  # Don't show quote during install
. "$QUOTESH_DIR/quotesh.sh"
_quotesh_init
unset QUOTESH_ENABLED

printf '\n'
printf '╭─────────────────────────────────────╮\n'
printf '│     Installation complete!          │\n'
printf '╰─────────────────────────────────────╯\n'
printf '\n'

if [ "$CHANGES_MADE" = "1" ]; then
    log_info "Restart your terminal or run:"
    printf '\n'
    printf '    source %s/quotesh.sh\n' "$QUOTESH_DIR"
    printf '\n'
else
    log_info "Try it now by running: quotesh"
fi

log_info "Configuration: $CONFIG_DIR/quotesh.conf"
log_info "Database: $DATA_DIR/quotes.db"
log_info "Logs: $DATA_DIR/logs/fetcher.log"
printf '\n'
