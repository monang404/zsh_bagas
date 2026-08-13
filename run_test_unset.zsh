#!/bin/zsh
source ~/.zshrc
unset AI_PERM_WRITE_MODE
echo "before: ${AI_PERM_WRITE_MODE:-unset}"
AI_SPINNER_ENABLE=0 AI_VERBOSE=1 ai agent "buat file hello.txt berisi hello"
echo "after: ${AI_PERM_WRITE_MODE:-unset}"
