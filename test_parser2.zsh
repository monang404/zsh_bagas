#!/bin/zsh
source ./.zsh_bagas/30-ai/50-agent/10-state.zsh
pdir=$(_ai_agent_parse "{\"tool\": \"run_test\", \"cmd\": \"pytest\"}")
echo "TOOL:"
cat "$pdir/tool"
echo
echo "ARGS:"
cat "$pdir/args"
echo
echo "COMPAT:"
cat "$pdir/compat"
echo
rm -rf "$pdir"
