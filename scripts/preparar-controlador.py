#!/usr/bin/env python3
"""Executar no WSL; copiar chave autorizada e gerar chaves pessoais fora do Git."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--vagrant-key', type=Path, required=True)
parser.add_argument('--host-key', required=True, help='Chave PUBLICA obtida por SSH Windows confiavel')
args = parser.parse_args()
if not args.host_key.startswith('ssh-ed25519 '):
    parser.error('Fornecer chave publica Ed25519 do servidor')
os.umask(0o077)
state = Path(os.environ.get('ASA_PROJ1_STATE_DIR', Path.home() / '.local/share/asa-proj1'))
keys = state / 'keys'
keys.mkdir(parents=True, exist_ok=True, mode=0o700)
(Path.home() / '.cache/asa-proj1/ssh').mkdir(parents=True, exist_ok=True, mode=0o700)
known = state / 'known_hosts'
entry = '192.168.56.120 ' + ' '.join(args.host_key.split()[:2]) + '\n'
lines = known.read_text().splitlines() if known.exists() else []
existing = [line for line in lines if '192.168.56.120' in line.split()[0].split(',')]
if existing and existing != [entry.strip()]:
    raise SystemExit('Host key mudou: conferir identidade antes de substituir known_hosts')
if not existing:
    known.write_text('\n'.join(lines + [entry.strip()]) + '\n')
known.chmod(0o600)
target = keys / 'vagrant'
if not target.exists():
    shutil.copyfile(args.vagrant_key, target)
target.chmod(0o600)
for user in ('pedro', 'henryque'):
    target = keys / user
    if not target.exists():
        subprocess.run(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '',
                        '-C', user + '@asa-proj1', '-f', str(target)], check=True)
    target.chmod(0o600)
print('Controlador preparado; nenhum segredo exibido.')
