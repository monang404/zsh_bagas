#!/bin/zsh
source ./.zsh_bagas/30-ai/50-agent/10-state.zsh
pdir=$(_ai_agent_parse "{\"thought\": \"test\", \"tool\": \"todo_write\", \"args\": {\"items\": []}}")
echo "TOOL:"
cat "$pdir/tool"
echo
echo "ARGS:"
cat "$pdir/args"
echo
rm -rf "$pdir"
