#!/usr/bin/env python3
"""Registra o IP e a chave pública do cliente para o acesso pelo Ansible."""
import json,sys,re,os
from pathlib import Path
data=json.loads(Path(sys.argv[1]).read_text(encoding='utf-8-sig'))
name=data['name']; ip=data['ip']; key=data['hostkey']
assert name in ('db','app','cli')
assert ip.startswith('192.168.56.') and key.startswith('ssh-ed25519 ')
assert (name=='cli' and 50<=int(ip.split('.')[-1])<=100) or ip=={'db':'192.168.56.121','app':'192.168.56.122'}.get(name)
state=Path(os.environ.get('ASA_PROJ1_STATE_DIR', Path.home()/'.local/share/asa-proj1'))
known=state/'known_hosts'
lines=known.read_text().splitlines()
entry=f'{ip},{name}.pedro.henryque.devops {key}'
existing=[line for line in lines if line.split()[0].split(',')[0]==ip]
if existing and existing != [entry]: raise SystemExit('Host key divergente; interrompido')
if not existing: known.write_text('\n'.join(lines+[entry])+'\n')
inventory=Path(__file__).resolve().parent.parent/'ansible/inventory.ini'
content=inventory.read_text()
line=f'{name} ansible_host={ip} ansible_user=vagrant'
if re.search(r'^'+name+r'\s',content,re.M):
    content=re.sub(r'^'+name+r'\s.*$',line,content,flags=re.M)
else: content=content.replace('[clients]','[clients]\n'+line)
inventory.write_text(content)
print(name,ip,'registrado com host key conferida')
