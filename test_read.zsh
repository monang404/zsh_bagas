printf '%s' '{"path":"hello.txt"}' | while IFS= read -r -u 0 -k 1 byte; do printf '%s' "$byte"; done
