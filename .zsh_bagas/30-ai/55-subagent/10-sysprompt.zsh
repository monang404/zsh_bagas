# ============================================================
#  30-ai/55-subagent/10-sysprompt.zsh — narrow sysprompt per subagent role
#  (split out of the old monolithic 30-ai/55-subagent.zsh)
# ============================================================

# Echoes the sysprompt for the given role (§3/§4 design contract in
# 00-design_contract.zsh). Kept as a pure function (no side effects) so
# _ai_subagent_run just does: sysprompt=$(_ai_subagent_build_sysprompt ...)
_ai_subagent_build_sysprompt() {
    local role="$1" sub_goal="$2"
    if [ "$role" = "researcher" ]; then
        echo "You are a readonly research subagent.

Goal:
${sub_goal}

Investigate the repository using only readonly tools (read_file, list_dir, grep_search, glob_search, count_lines).

Do not modify files.
Do not run shell commands.
Do not execute tests.

Return concise findings when enough information has been gathered.

You must respond only as JSON:
{\"thought\": \"...\", \"tool\": \"...\", \"args\": {...}, \"done\": true|false}

When done is true, put your concise findings in \"thought\" -- that becomes the
summary returned to the caller, so make it self-contained and readable on its own."
    else
        echo "You are a coding subagent.

Goal:
${sub_goal}

Inspect only what is necessary.
Implement the requested change.
Use existing tools.
Verify important changes when practical.

Respond only as JSON:
{\"thought\": \"...\", \"tool\": \"...\", \"args\": {...}, \"done\": true|false}

When done is true, put a concise description of what you changed in \"thought\" --
that becomes the summary returned to the caller, so make it self-contained and readable on its own."
    fi
}
