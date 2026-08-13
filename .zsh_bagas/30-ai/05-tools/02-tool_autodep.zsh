# ============================================================
#  30-ai/05-tools/02-tool_autodep.zsh — auto-install dependency
#  yang hilang saat tool / run_command gagal exit 127.
#
#  Mendukung dua environment:
#    - Termux (Android)  → pkg install / apt install
#    - Debian/Ubuntu     → apt-get install (dengan sudo kalau bukan root)
#
#  Alur:
#    1. Tool gagal exit 127 → _ai_agent_exec_run_tool deteksi
#    2. _ai_autodep_extract_missing_cmd() parse nama command dari output
#    3. _ai_autodep_cmd_to_pkg() mapping command → nama paket
#    4. _ai_autodep_install() install paket & cetak progress
#    5. Tool di-retry SEKALI; kalau masih gagal, kembalikan error asli
# ============================================================

# ─── Deteksi package manager ──────────────────────────────────
# Return: "pkg" (Termux), "apt" (Debian/Ubuntu), atau "" (gak tau)
_ai_autodep_pkg_manager() {
    # Termux: $PREFIX selalu di-set ke /data/data/com.termux/files/usr
    if [ -n "${PREFIX:-}" ] && command -v pkg > /dev/null 2>&1; then
        echo "pkg"
        return 0
    fi
    if command -v apt-get > /dev/null 2>&1; then
        echo "apt"
        return 0
    fi
    echo ""
}

# ─── Mapping command → nama paket ─────────────────────────────
# $1 = nama command yang hilang, $2 = pkg_mgr (pkg|apt)
# Echo nama paket, atau "" kalau tidak diketahui
_ai_autodep_cmd_to_pkg() {
    local cmd="$1" pkg_mgr="$2"
    case "$cmd" in
        # coreutils
        head|tail|cut|sort|uniq|wc|tee|tr|nl|cat|cp|mv|rm|mkdir|touch|chmod|chown|stat|du|df|ln|readlink|realpath|basename|dirname|mktemp|date|od|xxd)
            echo "coreutils" ;;
        awk|gawk)
            echo "gawk" ;;
        sed)
            echo "sed" ;;
        grep|egrep|fgrep)
            echo "grep" ;;
        python3|python)
            [ "$pkg_mgr" = "pkg" ] && echo "python" || echo "python3" ;;
        pip3|pip)
            [ "$pkg_mgr" = "pkg" ] && echo "python" || echo "python3-pip" ;;
        git)
            echo "git" ;;
        curl)
            echo "curl" ;;
        wget)
            echo "wget" ;;
        jq)
            echo "jq" ;;
        node|nodejs)
            echo "nodejs" ;;
        npm)
            [ "$pkg_mgr" = "pkg" ] && echo "nodejs" || echo "npm" ;;
        zip)
            echo "zip" ;;
        unzip)
            echo "unzip" ;;
        make)
            echo "make" ;;
        cmake)
            echo "cmake" ;;
        gcc|cc)
            [ "$pkg_mgr" = "pkg" ] && echo "clang" || echo "gcc" ;;
        clang)
            echo "clang" ;;
        find)
            echo "findutils" ;;
        xargs)
            echo "findutils" ;;
        fzf)
            echo "fzf" ;;
        bat)
            echo "bat" ;;
        fd)
            [ "$pkg_mgr" = "pkg" ] && echo "fd" || echo "fd-find" ;;
        rg)
            echo "ripgrep" ;;
        htop)
            echo "htop" ;;
        tmux)
            echo "tmux" ;;
        ssh|scp|ssh-keygen)
            [ "$pkg_mgr" = "pkg" ] && echo "openssh" || echo "openssh-client" ;;
        rsync)
            echo "rsync" ;;
        diff|patch)
            echo "diffutils" ;;
        # Python packages via pip
        psutil)
            echo "pip:psutil" ;;
        requests)
            echo "pip:requests" ;;
        *)
            echo "" ;;
    esac
}

# ─── Helper: jalankan install command ─────────────────────────
_ai_autodep_run_install() {
    local pkg_mgr="$1" pkg_name="$2"
    local install_out install_rc

    case "$pkg_mgr" in
        pkg)
            install_out=$(pkg install -y "$pkg_name" 2>&1)
            install_rc=$?
            ;;
        apt)
            if [ "$(id -u)" = "0" ]; then
                install_out=$(apt-get install -y "$pkg_name" 2>&1)
                install_rc=$?
            elif command -v sudo > /dev/null 2>&1; then
                install_out=$(sudo apt-get install -y "$pkg_name" 2>&1)
                install_rc=$?
            else
                install_out=$(apt-get install -y "$pkg_name" 2>&1)
                install_rc=$?
            fi
            ;;
        *)
            return 1 ;;
    esac

    if [ "$install_rc" -ne 0 ]; then
        echo "[autodep] install gagal (exit $install_rc): $(printf '%s' "$install_out" | tail -3)"
        return 1
    fi
    return 0
}

# ─── Main: install command yang hilang ────────────────────────
# $1 = nama command yang missing
# Cetak progress ke stdout biar masuk ke $output agent.
# Return 0 = berhasil install, 1 = gagal/tidak diketahui.
_ai_autodep_install_missing() {
    local missing_cmd="$1"
    [ -z "$missing_cmd" ] && return 1

    # ── Cek dulu dengan which/command -v ──────────────────────────
    # Kalau command ADA di sistem tapi masih exit 127, berarti bukan
    # masalah "package belum install" -- mungkin PATH subshell beda,
    # atau agent policy yang memblokir. Jangan auto-install; kasih tau
    # lokasi sebenarnya biar LLM & user bisa debug.
    local _which_path
    _which_path=$(command -v "$missing_cmd" 2>/dev/null)
    if [ -z "$_which_path" ] && command -v which > /dev/null 2>&1; then
        _which_path=$(which "$missing_cmd" 2>/dev/null)
    fi
    if [ -n "$_which_path" ]; then
        echo "[autodep] '$missing_cmd' sebenarnya ADA di: $_which_path"
        echo "[autodep] exit 127 bukan karena package hilang (mungkin PATH subshell berbeda atau diblokir policy). Skip install."
        return 1
    fi

    local pkg_mgr pkg_spec
    pkg_mgr=$(_ai_autodep_pkg_manager)
    if [ -z "$pkg_mgr" ]; then
        echo "[autodep] package manager tidak dikenali, skip auto-install '$missing_cmd'"
        return 1
    fi

    pkg_spec=$(_ai_autodep_cmd_to_pkg "$missing_cmd" "$pkg_mgr")

    if [ -z "$pkg_spec" ]; then
        echo "[autodep] tidak tahu package untuk command '$missing_cmd', skip"
        return 1
    fi

    # Paket pip (prefix "pip:") → install via pip3
    if [[ "$pkg_spec" == pip:* ]]; then
        local pip_pkg="${pkg_spec#pip:}"
        echo "[autodep] install Python package '$pip_pkg' via pip3..."
        local pip_out pip_rc
        pip_out=$(pip3 install "$pip_pkg" 2>&1)
        pip_rc=$?
        if [ "$pip_rc" -eq 0 ]; then
            echo "[autodep] '$pip_pkg' berhasil di-install via pip3"
            return 0
        else
            echo "[autodep] pip3 install '$pip_pkg' gagal: $(printf '%s' "$pip_out" | tail -2)"
            return 1
        fi
    fi

    echo "[autodep] '$missing_cmd' tidak ditemukan → install '$pkg_spec' via $pkg_mgr..."
    if _ai_autodep_run_install "$pkg_mgr" "$pkg_spec"; then
        echo "[autodep] '$pkg_spec' berhasil di-install"
        return 0
    fi
    return 1
}

# ─── Parse "command not found" dari output tool ───────────────
# Output: nama command yang hilang, atau "" kalau tidak ketemu
_ai_autodep_extract_missing_cmd() {
    local output="$1"
    printf '%s\n' "$output" \
        | grep -o 'command not found: [^ ]*' \
        | command awk 'NR==1{sub("command not found: ",""); print}' 2>/dev/null
}
