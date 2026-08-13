# ============================================================
#  30-ai/05-tools/30-tool_process.zsh — shell-safety helper + exec_process / run_command
#  (split out of the old monolithic 30-ai/05-tools.zsh)
# ============================================================

_ai_yolo_shell_safe() {
    local cmd="$1" tok
    [[ "$cmd" != *';'* && "$cmd" != *'|'* && "$cmd" != *'&'* && "$cmd" != *'<'* && "$cmd" != *'>'* && "$cmd" != *'`'* && "$cmd" != *'$'* && "$cmd" != *$'\n'* ]] || return 1
    local -a tokens
    tokens=(${(z)cmd})
    [ ${#tokens[@]} -gt 0 ] || return 1
    local base="${tokens[1]:t}"
    case "$base" in
        git|rg|grep|sed|awk|cat|head|tail|wc|ls|pwd|find|sort|uniq|cut|tr|diff) ;;
        *) return 1 ;;
    esac
    for tok in "${tokens[@]}"; do
        case "$tok" in
            sh|bash|zsh|fish|dash|ksh|eval|source|.|exec|env|sudo|su|doas|-c|--command|-e|--eval|--exec|--git-dir=*|-C|-exec|-execdir|-delete|-ok|-okdir) return 1 ;;
            ../*|*/../*|*/..) return 1 ;;
            /etc/*|/root/*|/home/*/.ssh/*|/proc/*|/sys/*|/dev/*) return 1 ;;
        esac
    done
    return 0
}

_ai_tool_exec_process() {
    local args_json="$1" program cwd timeout_s
    program=$(_ai_tool_extract_field "$args_json" program) || return 1
    cwd=$(_ai_tool_extract_field "$args_json" cwd) || true
    [ -z "$cwd" ] && cwd="."
    timeout_s=$(_ai_tool_extract_field "$args_json" timeout) || true
    [ -z "$timeout_s" ] && timeout_s=30

    local root real_cwd resolved
    root=$(_ai_project_root) || { echo "ERROR: project root tidak bisa ditentukan"; return 1; }
    _ai_path_within_project "$cwd" || {
        echo "ERROR: cwd berada di luar project boundary"
        return 1
    }
    real_cwd=$(_ai_canonical_path "$cwd") || return 1
    resolved=$(command -v -- "$program" 2>/dev/null) || {
        echo "ERROR: executable '$program' tidak ditemukan di PATH"
        return 1
    }
    # Never execute a project-local executable through the generic process
    # capability: this blocks a modified ./git/node/etc. from shadowing PATH.
    if _ai_path_within_project "$resolved"; then
        echo "ERROR: executable '$program' resolves inside project; PATH hijacking protection"
        return 1
    fi

    case "$program" in
        git|python|python3|node|npm|pnpm|yarn|bun|cargo|go|pytest|rg|grep|sed|awk|make)
            ;;
        *)
            echo "ERROR: executable '$program' belum masuk process allowlist"
            return 1
            ;;
    esac

    local -a args
    args=("${(@f)$(jq -r '.args[]?' <<<"$args_json")}")
    local out rc
    if command -v timeout >/dev/null 2>&1; then
        out=$(cd -- "$real_cwd" && timeout -- "$timeout_s" "$resolved" "${args[@]}" 2>&1)
        rc=$?
    else
        # No shell is involved. Without a portable timeout primitive, execute
        # directly and report that the platform lacks process timeout support.
        out=$(cd -- "$real_cwd" && "$resolved" "${args[@]}" 2>&1)
        rc=$?
    fi
    out=$(printf '%s' "$out" | head -c 3000)
    if [ "$rc" -eq 0 ]; then
        printf '%s\n' "${out:-OK (exit 0, no output)}"
        return 0
    fi
    printf 'ERROR (exit %s):\n%s\n' "$rc" "$out"
    return 1
}

_ai_tool_run_command() {
    local args_json="$1"
    local command
    command=$(_ai_tool_extract_field "$args_json" command cmd)
    if [ -z "$command" ]; then
        echo "ERROR: run_command membutuhkan args.command (string non-empty). Diterima: $(printf '%s' "$args_json" | head -c 200)"
        return 1
    fi

    if _ai_agent_is_dangerous "$command"; then
        echo "ERROR: command diblokir sistem keamanan (destruktif)"
        return 1
    fi

    if [[ "${AI_AGENT_YOLO_MODE:-0}" == "1" ]] && ! _ai_yolo_shell_safe "$command"; then
        echo "ERROR: command tidak memenuhi safe-shell policy untuk --yolo; konfirmasi manual diperlukan."
        _ai_perm_ask "Jalankan command yang tidak termasuk safe-shell allowlist?" || return 1
    fi

    local out rc
    out=$(zsh -f -c -- "$command" 2>&1)
    rc=$?
    out=$(printf '%s' "$out" | head -c 3000)

    if [ $rc -eq 0 ]; then
        if [ -z "$out" ]; then
            echo "OK (exit 0, no output)"
        else
            echo "$out"
        fi
    else
        echo "ERROR (exit $rc):"
        echo "$out"
        return 1
    fi
}
