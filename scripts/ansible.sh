#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"
# DrvFS pode ser world-writable; selecionar o arquivo explicitamente.
export ANSIBLE_CONFIG="$project_dir/ansible.cfg"
export PYTHONDONTWRITEBYTECODE=1
case "${1:-}" in
  ping) exec ansible arq -m ansible.builtin.ping ;;
  syntax) exec ansible-playbook ansible/site.yml --syntax-check ;;
  apply) exec ansible-playbook ansible/site.yml --limit arq ;;
  verify) exec ansible-playbook ansible/verify.yml --limit arq ;;
  storage) exec ansible-playbook ansible/site.yml --limit arq --tags storage,nfs ;;
  verify-storage) exec ansible-playbook ansible/verify-storage.yml --limit arq ;;
  *) echo "Uso: bash scripts/ansible.sh ping|syntax|apply|verify|storage|verify-storage" >&2; exit 2 ;;
esac
