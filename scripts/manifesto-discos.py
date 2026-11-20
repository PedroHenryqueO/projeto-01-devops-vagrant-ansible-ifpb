#!/usr/bin/env python3
"""Identifica os discos de arq sem formatar ou alterar seu conteúdo."""
import json, pathlib, re, shutil, subprocess, argparse
p=argparse.ArgumentParser(); p.add_argument('--vboxmanage',default=shutil.which('VBoxManage') or shutil.which('VBoxManage.exe')); a=p.parse_args()
if not a.vboxmanage: p.error('VBoxManage não encontrado; informe --vboxmanage CAMINHO')
root=pathlib.Path(__file__).resolve().parent.parent
vm=(root/'.vagrant/machines/arq/virtualbox/id').read_text().strip()
def vbox(*args): return subprocess.check_output([a.vboxmanage,*args],text=True)
info=vbox('showvminfo',vm,'--machinereadable')
assert 'name="ASA-Proj1-arq"' in info
ids=re.findall(r'^"SATA Controller-ImageUUID-[123]-0"="([a-f0-9-]+)"',info,re.M)
assert len(ids)==3
assert len(set(ids))==3
# Os discos adicionais não podem estar ligados a outra VM.
for line in vbox('list','vms').splitlines():
    match=re.match(r'^".*"\s+\{([a-fA-F0-9-]+)\}$',line)
    assert match, 'Registro de VM não reconhecido'
    if match[1].lower()==vm.lower(): continue
    other=vbox('showvminfo',match[1],'--machinereadable')
    attached={line.split('=',1)[1].strip('"').lower() for line in other.splitlines() if 'ImageUUID-' in line and '=' in line}
    assert not attached.intersection(uid.lower() for uid in ids), 'Disco adicional também ligado a outra VM; interrompido'
disks=[]
for uid in ids:
    medium=vbox('showmediuminfo','disk',uid)
    assert re.search(r'^Capacity:\s+10240 MBytes',medium,re.M)
    assert re.search(r'^Parent UUID:\s+base',medium,re.M)
    assert 'ASA-Proj1-arq-dados-' in medium and 'ASA-Proj1-arq' in medium
    tail=uid.replace('-','')[-8:]
    serial='VB'+uid[:8]+'-'+''.join(reversed([tail[i:i+2] for i in range(0,8,2)]))
    disks.append({'serial':serial,'media_uuid':uid})
# Salva os dados em JSON, que também é um formato YAML válido.
dest=root/'ansible/host_vars/arq.yml'
dest.parent.mkdir(exist_ok=True)
data={'storage_disks':disks,'nfs_uid':2048,'nfs_gid':2048}
if dest.exists():
    previous=json.loads(dest.read_text())
    assert previous==data, 'Manifesto anterior divergente; confira os discos antes de substituir'
else:
    dest.write_text(json.dumps(data,indent=2)+'\n')
print('Manifesto local gerado a partir dos discos exclusivos da VM arq; validar antes de gravar.')
