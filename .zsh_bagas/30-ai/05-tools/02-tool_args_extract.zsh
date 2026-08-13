# ============================================================
#  30-ai/05-tools/02-tool_args_extract.zsh — centralized args extraction + normalization
#  Loaded BEFORE tool implementations and permission check.
#  Provides tolerant field extraction so tools work even when
#  the model places fields at slightly wrong locations.
# ============================================================

# _ai_tool_extract_field args_json field [alternatives...]
# Returns the first non-empty string value from field + alternatives.
# If args_json is not a valid object or all fields are empty → empty string.
_ai_tool_extract_field() {
    local args_json="$1"
    shift
    [ -z "$args_json" ] && return 0
    # Build jq expression: .field1 // .field2 // ... // empty
    local expr="" f
    for f in "$@"; do
        if [ -z "$expr" ]; then
            expr=".$f"
        else
            expr="$expr // .$f"
        fi
    done
    [ -z "$expr" ] && return 0
    expr="($expr) // empty"
    local val
    val=$(printf '%s' "$args_json" | jq -r "$expr" 2>/dev/null) || true
    # Guard: jq returns "null" for missing fields even with // empty in
    # some edge cases; treat "null" as empty.
    [[ "$val" == "null" ]] && val=""
    printf '%s' "$val"
}

# _ai_tool_extract_path args_json
# Path-specific extraction: tries .path, .file, .filename, .dir, .directory
# If args_json is a bare JSON string (not object) → treat as path.
_ai_tool_extract_path() {
    local args_json="$1"
    [ -z "$args_json" ] && return 0

    # Case 1: args is a bare JSON string → treat as path
    local atype
    atype=$(printf '%s' "$args_json" | jq -r 'type' 2>/dev/null) || true
    if [[ "$atype" == "string" ]]; then
        local sval
        sval=$(printf '%s' "$args_json" | jq -r '.' 2>/dev/null) || true
        [ -n "$sval" ] && { printf '%s' "$sval"; return 0; }
    fi

    # Case 2: object → try known path field names
    _ai_tool_extract_field "$args_json" path file filename dir directory
}

# _ai_tool_normalize_args args_json tool_name
# Returns a normalized JSON object for args.
# Rules (safe, limited):
#  - If args is already an object → use as-is, fill missing fields from known alternatives
#  - If args is a bare string and tool is path-based → wrap as {"path":"<string>"}
#  - Never adds unknown fields, never changes valid values.
_ai_tool_normalize_args() {
    local args_json="$1" tool_name="$2"
    [ -z "$args_json" ] && { printf '%s' '{}'; return 0; }

    local atype
    atype=$(printf '%s' "$args_json" | jq -r 'type' 2>/dev/null) || atype=""

    # If args is a bare string → wrap into object for path-based tools
    if [[ "$atype" == "string" ]]; then
        local sval
        sval=$(printf '%s' "$args_json" | jq -r '.' 2>/dev/null) || sval=""
        if [ -n "$sval" ]; then
            case "$tool_name" in
                read_file|write_file|edit_file|count_lines|delete_file|list_dir|patch_file|move_file)
                    printf '%s' "$args_json" | jq -c '{path: .}'
                    return 0
                    ;;
                grep_search|glob_search)
                    printf '%s' "$args_json" | jq -c '{pattern: .}'
                    return 0
                    ;;
                run_command)
                    printf '%s' "$args_json" | jq -c '{command: .}'
                    return 0
                    ;;
                web_fetch)
                    printf '%s' "$args_json" | jq -c '{url: .}'
                    return 0
                    ;;
            esac
        fi
        # Unknown tool or empty string → return empty object
        printf '%s' '{}'
        return 0
    fi

    # If not an object at all → return empty object
    if [[ "$atype" != "object" ]]; then
        printf '%s' '{}'
        return 0
    fi

    # Args is an object → fill missing fields from known alternatives
    local result="$args_json"

    case "$tool_name" in
        read_file|write_file|edit_file|count_lines|delete_file|list_dir|patch_file|move_file)
            # If .path is missing, try .file, .filename, .dir, .directory
            local has_path
            has_path=$(printf '%s' "$result" | jq -r 'has("path")' 2>/dev/null)
            if [[ "$has_path" != "true" ]]; then
                local alt_path
                alt_path=$(_ai_tool_extract_field "$result" file filename dir directory)
                if [ -n "$alt_path" ]; then
                    result=$(printf '%s' "$result" | jq -c --arg p "$alt_path" '. + {path: $p}' 2>/dev/null) || true
                fi
            fi
            ;;
        web_fetch)
            local has_url
            has_url=$(printf '%s' "$result" | jq -r 'has("url")' 2>/dev/null)
            if [[ "$has_url" != "true" ]]; then
                local alt_url
                alt_url=$(_ai_tool_extract_field "$result" link href)
                if [ -n "$alt_url" ]; then
                    result=$(printf '%s' "$result" | jq -c --arg u "$alt_url" '. + {url: $u}' 2>/dev/null) || true
                fi
            fi
            ;;
        run_command)
            local has_cmd
            has_cmd=$(printf '%s' "$result" | jq -r 'has("command")' 2>/dev/null)
            if [[ "$has_cmd" != "true" ]]; then
                local alt_cmd
                alt_cmd=$(_ai_tool_extract_field "$result" cmd)
                if [ -n "$alt_cmd" ]; then
                    result=$(printf '%s' "$result" | jq -c --arg c "$alt_cmd" '. + {command: $c}' 2>/dev/null) || true
                fi
            fi
            ;;
        grep_search)
            local has_pat
            has_pat=$(printf '%s' "$result" | jq -r 'has("pattern")' 2>/dev/null)
            if [[ "$has_pat" != "true" ]]; then
                local alt_pat
                alt_pat=$(_ai_tool_extract_field "$result" query search regex)
                if [ -n "$alt_pat" ]; then
                    result=$(printf '%s' "$result" | jq -c --arg p "$alt_pat" '. + {pattern: $p}' 2>/dev/null) || true
                fi
            fi
            ;;
        glob_search)
            local has_pat2
            has_pat2=$(printf '%s' "$result" | jq -r 'has("pattern")' 2>/dev/null)
            if [[ "$has_pat2" != "true" ]]; then
                local alt_pat2
                alt_pat2=$(_ai_tool_extract_field "$result" glob name filename)
                if [ -n "$alt_pat2" ]; then
                    result=$(printf '%s' "$result" | jq -c --arg p "$alt_pat2" '. + {pattern: $p}' 2>/dev/null) || true
                fi
            fi
            ;;
    esac

    printf '%s' "$result"
}
