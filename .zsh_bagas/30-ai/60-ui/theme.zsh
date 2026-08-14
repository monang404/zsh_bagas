# ============================================================
# 30-ai/60-ui/theme.zsh — Theme Engine
# ============================================================

typeset -g UI_C_RESET="\e[0m"
typeset -g UI_C_BOLD="\e[1m"
typeset -g UI_C_DIM="\e[2m"

# Hex to TrueColor ANSI
# Format: \e[38;2;R;G;Bm for text, \e[48;2;R;G;Bm for background
typeset -g UI_BG_MAIN="\e[48;2;13;17;23m"
typeset -g UI_BG_SURFACE="\e[48;2;22;27;34m"
typeset -g UI_FG_TEXT="\e[38;2;230;237;243m"
typeset -g UI_FG_MUTED="\e[38;2;139;148;158m"

typeset -g UI_C_PRIMARY="\e[38;2;47;129;247m"
typeset -g UI_C_SUCCESS="\e[38;2;63;185;80m"
typeset -g UI_C_WARNING="\e[38;2;210;153;34m"
typeset -g UI_C_DANGER="\e[38;2;248;81;73m"
typeset -g UI_C_BORDER="\e[38;2;48;54;61m"

# ui_color token
# Usage: echo "$(ui_color primary)Hello$(ui_color reset)"
ui_color() {
    local token="$1"
    case "$token" in
        primary) echo -n "$UI_C_PRIMARY" ;;
        success) echo -n "$UI_C_SUCCESS" ;;
        warning) echo -n "$UI_C_WARNING" ;;
        danger) echo -n "$UI_C_DANGER" ;;
        text) echo -n "$UI_FG_TEXT" ;;
        muted) echo -n "$UI_FG_MUTED" ;;
        bg_main) echo -n "$UI_BG_MAIN" ;;
        bg_surface) echo -n "$UI_BG_SURFACE" ;;
        border) echo -n "$UI_C_BORDER" ;;
        reset) echo -n "$UI_C_RESET" ;;
        bold) echo -n "$UI_C_BOLD" ;;
        dim) echo -n "$UI_C_DIM" ;;
        *) echo -n "" ;;
    esac
}
