#!/bin/bash -u

set -e

function edit_ssh_config() {
  local file="/etc/ssh/sshd_config"
  local port="${SSH_PORT:-22}"

  echo "Creating backup for '$file'..."
  if [ -f "$file" ]; then
    cp "$file" "${file}.backup"
  else
    echo "File $file not found." >&2
    exit 1
  fi

  echo "Editing '$file'..."
  for param in "PasswordAuthentication" "PermitRootLogin" "Port"; do
    sed -i '/^'"${param}"'/d' "$file"
    echo "All lines beginning with '${param}' were deleted from $file."
  done
  cat >>"$file" <<EOF
PasswordAuthentication no
PermitRootLogin no
Port $port
EOF

  sudo systemctl restart sshd
}

edit_ssh_config
