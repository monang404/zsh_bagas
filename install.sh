#!/usr/bin/env bash
# ==============================================================================
# install.sh — Script instalasi dan update otomatis untuk zsh_bagas
# ==============================================================================

set -e

REPO_URL="https://github.com/monang404/zsh_bagas.git"
TARGET_DIR="$HOME/.zsh_bagas"
ZSHRC_TARGET="$HOME/.zshrc"

echo "Mempersiapkan instalasi/update zsh_bagas..."

# 1. Clone atau Update repo di ~/.zsh_bagas
if [ -d "$TARGET_DIR/.git" ]; then
    echo "✔ Repositori ditemukan di $TARGET_DIR. Menjalankan git pull..."
    cd "$TARGET_DIR"
    git pull origin main
else
    if [ -d "$TARGET_DIR" ]; then
        echo "⚠ Peringatan: $TARGET_DIR sudah ada tapi bukan repositori git."
        echo "Membuat backup ke $TARGET_DIR.bak.$$"
        mv "$TARGET_DIR" "$TARGET_DIR.bak.$$"
    fi
    echo "⬇ Mengunduh zsh_bagas ke $TARGET_DIR..."
    git clone "$REPO_URL" "$TARGET_DIR"
fi

# 2. Symlink .zshrc
echo "🔗 Membuat symlink untuk .zshrc..."
if [ -f "$ZSHRC_TARGET" ] || [ -L "$ZSHRC_TARGET" ]; then
    # Jika sudah ada symlink dan mengarah ke tempat yang benar, lewati
    if [ -L "$ZSHRC_TARGET" ] && [ "$(readlink -f "$ZSHRC_TARGET")" = "$TARGET_DIR/.zshrc" ]; then
        echo "✔ .zshrc sudah ter-symlink dengan benar."
    else
        echo "Membuat backup .zshrc lama ke .zshrc.bak.$$"
        mv "$ZSHRC_TARGET" "$ZSHRC_TARGET.bak.$$"
        ln -s "$TARGET_DIR/.zshrc" "$ZSHRC_TARGET"
        echo "✔ Symlink .zshrc berhasil dibuat."
    fi
else
    ln -s "$TARGET_DIR/.zshrc" "$ZSHRC_TARGET"
    echo "✔ Symlink .zshrc berhasil dibuat."
fi

# 3. Ubah permission file secrets (jika ada)
if [ -f "$HOME/.secrets.zsh" ]; then
    chmod 600 "$HOME/.secrets.zsh"
fi

echo ""
echo "🎉 Selesai! Zsh kamu sudah terhubung langsung dengan repositori GitHub."
echo "Untuk menerapkan perubahan, silakan ketik: exec zsh"
