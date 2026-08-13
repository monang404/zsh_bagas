#!/usr/bin/env bash
# ==============================================================================
# install.sh — Script instalasi dan update otomatis untuk zsh_bagas
# ==============================================================================

set -e

REPO_URL="https://github.com/monang404/zsh_bagas.git"
TARGET_DIR="$HOME/zsh_bagas"
ZSH_BAGAS_LINK="$HOME/.zsh_bagas"
ZSHRC_TARGET="$HOME/.zshrc"

echo "Mempersiapkan instalasi/update zsh_bagas..."

# 1. Clone atau Update repo di ~/zsh_bagas (TANPA TITIK)
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
    echo "⬇ Mengunduh repositori zsh_bagas ke $TARGET_DIR..."
    git clone "$REPO_URL" "$TARGET_DIR"
fi

# 2. Buat symlink untuk folder ~/.zsh_bagas
echo "🔗 Membuat symlink untuk folder ~/.zsh_bagas..."
if [ -L "$ZSH_BAGAS_LINK" ] && [ "$(readlink -f "$ZSH_BAGAS_LINK")" = "$TARGET_DIR/.zsh_bagas" ]; then
    echo "✔ Folder ~/.zsh_bagas sudah ter-symlink dengan benar."
else
    if [ -d "$ZSH_BAGAS_LINK" ] || [ -f "$ZSH_BAGAS_LINK" ] || [ -L "$ZSH_BAGAS_LINK" ]; then
        echo "Membuat backup ~/.zsh_bagas lama ke ~/.zsh_bagas.bak.$$"
        mv "$ZSH_BAGAS_LINK" "$ZSH_BAGAS_LINK.bak.$$"
    fi
    ln -s "$TARGET_DIR/.zsh_bagas" "$ZSH_BAGAS_LINK"
    echo "✔ Symlink folder ~/.zsh_bagas berhasil dibuat."
fi

# 3. Symlink .zshrc
echo "🔗 Membuat symlink untuk .zshrc..."
if [ -L "$ZSHRC_TARGET" ] && [ "$(readlink -f "$ZSHRC_TARGET")" = "$TARGET_DIR/.zshrc" ]; then
    echo "✔ .zshrc sudah ter-symlink dengan benar."
else
    if [ -f "$ZSHRC_TARGET" ] || [ -L "$ZSHRC_TARGET" ]; then
        echo "Membuat backup .zshrc lama ke .zshrc.bak.$$"
        mv "$ZSHRC_TARGET" "$ZSHRC_TARGET.bak.$$"
    fi
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
