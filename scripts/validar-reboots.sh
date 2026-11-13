#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export ANSIBLE_CONFIG="$PWD/ansible.cfg"
mkdir -p docs/evidencias
exec > >(tee docs/evidencias/final-reboots.log) 2>&1
ansible arq -b -m ansible.builtin.reboot -a 'reboot_timeout=360 connect_timeout=10'
ansible-playbook ansible/verify-storage.yml --limit arq
ansible-playbook ansible/verify.yml --limit arq
for host in db app cli; do
  ansible "$host" -b -m ansible.builtin.reboot -a 'reboot_timeout=360 connect_timeout=10'
  ansible-playbook ansible/verify-clients.yml --limit "$host"
done
ansible-playbook ansible/verify-integration.yml
ansible all -b -m ansible.builtin.command -a 'uname -r'
