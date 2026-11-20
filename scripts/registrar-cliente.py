#!/usr/bin/env python3
"""Registra o IP e a chave pública do cliente para o acesso pelo Ansible."""
import json,sys,re,os
from pathlib import Path
import ipaddress
data=json.loads(Path(sys.argv[1]).read_text(encoding='utf-8-sig'))
name=data['name']; ip=data['ip']; key=data['hostkey']
assert name in ('db','app','cli')
assert ip.startswith('192.168.56.') and key.startswith('ssh-ed25519 ')
assert (name=='cli' and 50<=int(ip.split('.')[-1])<=100) or ip=={'db':'192.168.56.121','app':'192.168.56.122'}.get(name)
state=Path(os.environ.get('ASA_PROJ1_STATE_DIR', Path.home()/'.local/share/asa-proj1'))
known=state/'known_hosts'
lines=known.read_text().splitlines()
alias=f'{name}.pedro.henryque.devops'
public=' '.join(key.split()[:2])
entry=f'{ip},{alias} {public}'
updated=[]
for line in lines:
    fields=line.split()
    if not fields or fields[0].startswith('#'):
        updated.append(line)
        continue
    hosts=fields[0].split(',')
    if ip in hosts or alias in hosts:
        if ' '.join(fields[1:3]) != public:
            raise SystemExit('Chave de host divergente; confira a identidade da VM')
        for host in hosts:
            if host != alias:
                try: address=ipaddress.ip_address(host)
                except ValueError: raise SystemExit('Entrada compartilhada de host; revisão manual necessária')
                if str(address) != ip and not (name=='cli' and address in ipaddress.ip_network('192.168.56.0/24') and 50<=int(str(address).split('.')[-1])<=100):
                    raise SystemExit('Endereço anterior inesperado no known_hosts')
    else:
        updated.append(line)
temporary=state/'known_hosts.novo'
temporary.write_text('\n'.join(updated+[entry])+'\n')
temporary.chmod(0o600)
temporary.replace(known)
inventory=Path(__file__).resolve().parent.parent/'ansible/inventory.ini'
content=inventory.read_text()
line=f'{name} ansible_host={ip} ansible_user=vagrant'
if re.search(r'^'+name+r'\s',content,re.M):
    content=re.sub(r'^'+name+r'\s.*$',line,content,flags=re.M)
else: content=content.replace('[clients]','[clients]\n'+line)
inventory.write_text(content)
print(name,ip,'registrado com host key conferida')
