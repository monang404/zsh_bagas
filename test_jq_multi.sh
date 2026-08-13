printf %s '{
  "path": "hello.txt"
}' | jq -r '(.path) // empty'
