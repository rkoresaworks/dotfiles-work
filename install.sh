#!/bin/bash

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing dotfiles-work from $DOTFILES_DIR"

# Install Homebrew if not installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Homebrew 6 以降は非公式 tap の formula/cask を trust なしでは読み込まない。
# tap 全体ではなく aerospace の cask のみを対象にする。
if brew trust --help &> /dev/null; then
    brew trust --cask nikitabobko/tap/aerospace
fi

# Install dependencies from Brewfile
echo "Installing dependencies from Brewfile..."
brew bundle --file="$DOTFILES_DIR/Brewfile"

# mise で Node 等をインストール
mkdir -p "$HOME/.config/mise"
ln -sf "$DOTFILES_DIR/config/mise/config.toml" "$HOME/.config/mise/config.toml"
if command -v mise &> /dev/null; then
    echo "Installing runtimes via mise..."
    mise install
fi

mkdir -p "$HOME/.config"

# Link files in home directory
ln -sf "$DOTFILES_DIR/gitconfig" "$HOME/.gitconfig"
ln -sf "$DOTFILES_DIR/zshrc" "$HOME/.zshrc"
ln -sf "$DOTFILES_DIR/zshenv" "$HOME/.zshenv"

# Link .config directories
ln -sfn "$DOTFILES_DIR/config/nvim" "$HOME/.config/nvim"
ln -sf "$DOTFILES_DIR/config/starship.toml" "$HOME/.config/starship.toml"
ln -sfn "$DOTFILES_DIR/config/ghostty" "$HOME/.config/ghostty"
mkdir -p "$HOME/.config/gh"
ln -sf "$DOTFILES_DIR/config/gh/config.yml" "$HOME/.config/gh/config.yml"
ln -sfn "$DOTFILES_DIR/config/aerospace" "$HOME/.config/aerospace"

# herdr はログ・ソケットも ~/.config/herdr に書くため config.toml のみリンク
mkdir -p "$HOME/.config/herdr"
ln -sf "$DOTFILES_DIR/config/herdr/config.toml" "$HOME/.config/herdr/config.toml"

# ~/.gitconfig.local のテンプレート生成 (未作成の場合のみ)
if [ ! -f "$HOME/.gitconfig.local" ]; then
    cat > "$HOME/.gitconfig.local" <<'EOF'
[user]
	name =
	email =
EOF
    echo "NOTE: ~/.gitconfig.local を作成しました。name / email を記入してください。"
fi

echo "Done. マシン固有の設定は ~/.zshrc.local / ~/.gitconfig.local へ。"
