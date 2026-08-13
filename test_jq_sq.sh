printf '%s' '{"path": "it'\''s.txt"}' | jq -r '(.path) // empty'
