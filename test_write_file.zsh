#!/usr/bin/env zsh
source ~/.zshrc 2>/dev/null

echo "--- Uji coba write_file via dispatch ---"
_ai_tool_dispatch write_file '{"path":"test_dummy.txt", "content":"halo"}' 2>test_stderr.txt
echo "RC: $?"
echo "--- Stderr yang ditangkap ---"
cat test_stderr.txt
