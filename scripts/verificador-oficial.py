#!/usr/bin/env python3
"""Confere os pré-requisitos e executa o verificador original sem modificá-lo."""
import os, pathlib, socket, subprocess, tempfile, shutil, sys, json
root=pathlib.Path(__file__).resolve().parent.parent
state=pathlib.Path(os.environ.get('ASA_PROJ1_STATE_DIR',pathlib.Path.home()/'.local/share/asa-proj1'))
hosts=['arq','app','db','cli']; suffix='.pedro.henryque.devops'
inventory=json.loads(subprocess.check_output(['ansible-inventory','-i',str(root/'ansible/inventory.ini'),'--list'],text=True))['_meta']['hostvars']
for h in hosts:
    ip=socket.gethostbyname(h+suffix)
    if ip != inventory[h]['ansible_host']: raise SystemExit('DNS diverge do inventario aprovado: '+h)
for user in ['pedro','henryque']:
    if not (state/'keys'/user).is_file(): raise SystemExit('Chave ausente: '+user)
if not os.environ.get('DISPLAY'): raise SystemExit('DISPLAY ausente; usar WSLg')
if not (root/'referencias/verifica-proj1.py').is_file(): raise SystemExit('Obter original com o professor')
os.environ['ANSIBLE_CONFIG']=str(root/'ansible.cfg')
subprocess.run(['ansible-playbook',str(root/'ansible/pre-verificador.yml')],cwd=root,check=True)
# Evita prompts e chaves extras que poderiam alterar os testes de autenticação.
with tempfile.TemporaryDirectory(prefix='asa-verificador-') as folder:
    folder=pathlib.Path(folder); config=folder/'ssh.conf'
    known=(state/'known_hosts').read_text()
    for line in known.splitlines():
        if line.startswith('192.168.56.120 '):
            known+='arq'+suffix+' '+line.split(' ',1)[1]+'\n'
    (folder/'known_hosts').write_text(known)
    config.write_text(f'Host *\n  BatchMode yes\n  ConnectTimeout 10\n  StrictHostKeyChecking yes\n  IdentityAgent none\n  IdentityFile none\n  IdentitiesOnly yes\n  UserKnownHostsFile {folder}/known_hosts\n  LogLevel ERROR\n')
    for binary in ['ssh','scp']:
        wrapper=folder/binary
        wrapper.write_text(f'#!/bin/sh\nexec /usr/bin/{binary} -F "{config}" "$@"\n'); wrapper.chmod(0o700)
    env=dict(os.environ,PATH=str(folder)+os.pathsep+os.environ['PATH'])
    try:
        result=subprocess.run(['python3',str(root/'referencias/verifica-proj1.py'),'pedro.henryque'],cwd=state,env=env,capture_output=True,text=True,timeout=240)
    finally:
        subprocess.run(['ansible-playbook',str(root/'ansible/pos-verificador.yml')],cwd=root,check=True)
    log=root/'docs/evidencias/verificador-oficial.log'
    log.parent.mkdir(parents=True,exist_ok=True)
    log.write_text(result.stdout+'\nSTDERR:\n'+result.stderr)
    print(result.stdout); print(result.stderr,file=sys.stderr)
    print('Codigo de saida:',result.returncode,'(nao e uma pontuacao; analisar cada teste)')
    raise SystemExit(result.returncode)
