#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$(dirname "$0")/../docs/evidencias"
cd "$(dirname "$0")/.."
export ANSIBLE_CONFIG="$PWD/ansible.cfg"
case "${1:-}" in db|app|cli) ;; *) exit 2;; esac
ansible "$1" -m ansible.builtin.ping
ansible-playbook ansible/verify-clients.yml --limit "$1" | tee "docs/evidencias/etapa7-$1-verify.log"
ansible-playbook ansible/client-site.yml --limit "$1" | tee "docs/evidencias/etapa7-$1-idempotencia.log"
