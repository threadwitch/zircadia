change-scheduler:
 #!/usr/bin/env bash
 scxctl get
 scxctl switch --sched "$(gum choose $(scxctl list | grep -Po "\\[.*\\]" | jq -rc ".[]"))"

# Update the base image, Flatpaks, and Homebrew packages
update:
 #!/usr/bin/env bash
 set -euo pipefail
 sudo bootc upgrade
 flatpak update -y
 if command -v brew >/dev/null 2>&1; then
   brew update && brew upgrade
 fi
