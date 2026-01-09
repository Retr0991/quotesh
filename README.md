# quotesh

A fast, offline-capable terminal greeter that displays random quotes from TV shows and movies. Designed for minimal startup overhead using a local SQLite database with background API fetching.

## Features

- 🚀 **Fast startup** - Quotes are stored locally, no network delay on terminal open
- 📦 **Offline-capable** - Works even when APIs are unavailable
- 🎲 **Smart selection** - Weighted random algorithm prevents quote repetition
- 🔄 **Background updates** - Automatically fetches new quotes in the background
- 🎨 **Customizable** - Multiple box styles and configurable width
- 🧩 **Extensible** - Easy to add custom API fetchers
- 📊 **XDG compliant** - Follows XDG Base Directory Specification

## Installation

### Quick Install

Run the installation script:

```bash
./install.sh
```

This will:
- Check for dependencies (sqlite3, python3)
- Create necessary directories
- Set up configuration files
- Add quotesh to your shell configuration (`.zshrc` or `.bashrc`)
- Initialize the database with default quotes

### Manual Install

1. Clone or download this repository
2. Source `quotesh.sh` in your shell configuration:

```bash
# For zsh
echo 'export QUOTESH_DIR="/path/to/quotesh"' >> ~/.zshrc
echo '. "$QUOTESH_DIR/quotesh.sh"' >> ~/.zshrc

# For bash
echo 'export QUOTESH_DIR="/path/to/quotesh"' >> ~/.bashrc
echo '. "$QUOTESH_DIR/quotesh.sh"' >> ~/.bashrc
```

3. Restart your terminal or source your shell config

## Configuration

Configuration is stored in `~/.config/quotesh/quotesh.conf`. Copy the default config:

```bash
cp config/quotesh.conf.default ~/.config/quotesh/quotesh.conf
```

### Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `QUOTESH_ENABLED` | `1` | Enable/disable greeter (1 = enabled, 0 = disabled) |
| `QUOTESH_FETCH_ON_START` | `1` | Run fetcher on terminal open (1 = yes, 0 = no) |
| `QUOTESH_BOX_STYLE` | `rounded` | Box style: `simple`, `double`, or `rounded` |
| `QUOTESH_MAX_WIDTH` | `80` | Maximum width of the quote box |
| `QUOTESH_PYTHON` | `python3` | Python interpreter path (if not in PATH) |


## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
