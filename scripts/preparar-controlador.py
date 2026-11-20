#!/usr/bin/env python3
"""Testa a chave do Vagrant e prepara o controlador sem trocar chaves de host."""
import argparse
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
source = parser.add_mutually_exclusive_group(required=True)
source.add_argument('--vagrant-key', type=Path)
source.add_argument('--ssh-config', type=Path, help='Saída de vagrant ssh-config arq')
parser.add_argument('--host-key', required=True, help='Chave pública obtida pelo SSH do Vagrant')
args = parser.parse_args()
if not args.host_key.startswith('ssh-ed25519 '):
    parser.error('Fornecer chave pública Ed25519 do servidor')
os.umask(0o077)
state = Path(os.environ.get('ASA_PROJ1_STATE_DIR', Path.home() / '.local/share/asa-proj1')).expanduser()
keys = state / 'keys'
keys.mkdir(parents=True, exist_ok=True, mode=0o700)
(Path.home() / '.cache/asa-proj1/ssh').mkdir(parents=True, exist_ok=True, mode=0o700)
known = state / 'known_hosts'
public = ' '.join(args.host_key.split()[:2])
entry = '192.168.56.120,arq.pedro.henryque.devops ' + public
lines = known.read_text().splitlines() if known.exists() else []
existing = []
for line in lines:
    fields = line.split()
    if fields and set(fields[0].split(',')) & {'192.168.56.120', 'arq.pedro.henryque.devops'}:
        if ' '.join(fields[1:3]) != public:
            raise SystemExit('Chave de host mudou; confira a VM antes de continuar')
        existing.append(line)
target = keys / 'vagrant'
candidates = [target] if target.exists() else []
if args.vagrant_key:
    candidates.append(args.vagrant_key.expanduser())
else:
    for line in args.ssh_config.read_text().splitlines():
        fields = shlex.split(line)
        if len(fields) == 2 and fields[0].lower() == 'identityfile':
            candidates.append(Path(fields[1]).expanduser())
selected = None
# A chave pública veio da VM identificada pelo Vagrant, não de ssh-keyscan.
with tempfile.TemporaryDirectory(prefix='asa-ssh-') as folder:
    trust = Path(folder) / 'known_hosts'
    trust.write_text(entry + '\n')
    probe = Path(folder) / 'identity'
    for candidate in dict.fromkeys(candidates):
        if not candidate.is_file():
            continue
        shutil.copyfile(candidate, probe)
        probe.chmod(0o600)
        try:
            result = subprocess.run([
                'ssh', '-F', 'none', '-T', '-i', str(probe), '-o', 'BatchMode=yes',
                '-o', 'IdentitiesOnly=yes', '-o', 'IdentityAgent=none',
                '-o', 'ControlMaster=no', '-o', 'ControlPath=none',
                '-o', 'StrictHostKeyChecking=yes', '-o', 'ConnectTimeout=10',
                '-o', 'UserKnownHostsFile=' + str(trust),
                'vagrant@192.168.56.120', 'hostname -f'
            ], capture_output=True, text=True, timeout=25)
        except subprocess.TimeoutExpired:
            continue
        if result.returncode == 0 and result.stdout.strip() == 'arq.pedro.henryque.devops':
            selected = candidate
            break
if selected is None:
    raise SystemExit('Nenhuma chave Vagrant autenticou na VM esperada; confira o ssh-config')
if selected != target:
    if target.exists():
        backup = keys / ('vagrant.anterior.' + str(time.time_ns()))
        shutil.copyfile(target, backup)
        backup.chmod(0o600)
    temporary = keys / 'vagrant.novo'
    shutil.copyfile(selected, temporary)
    temporary.chmod(0o600)
    temporary.replace(target)
target.chmod(0o600)
temporary = state / 'known_hosts.novo'
temporary.write_text('\n'.join([line for line in lines if line not in existing] + [entry]) + '\n')
temporary.chmod(0o600)
temporary.replace(known)
for user in ('pedro', 'henryque'):
    target = keys / user
    public_path = Path(str(target) + '.pub')
    if not target.exists():
        if public_path.exists():
            raise SystemExit('Chave pública sem chave privada correspondente: ' + user)
        subprocess.run(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '',
                        '-C', user + '@asa-proj1', '-f', str(target)], check=True)
    target.chmod(0o600)
    public_key = ' '.join(subprocess.check_output(['ssh-keygen', '-y', '-P', '', '-f', str(target)], text=True).split()[:2])
    if public_path.exists():
        if ' '.join(public_path.read_text().split()[:2]) != public_key:
            raise SystemExit('Par de chaves divergente: ' + user)
    else:
        public_path.write_text(public_key + '\n')
print('Controlador preparado; chave Vagrant testada e chaves privadas não exibidas.')
