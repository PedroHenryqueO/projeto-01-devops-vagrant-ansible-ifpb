#!/usr/bin/env bash
# Instala o projeto no Ubuntu nativo. Não destrói VMs nem troca chaves de host.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
STATE="${ASA_PROJ1_STATE_DIR:-$HOME/.local/share/asa-proj1}"
HOSTONLY="${ASA_PROJ1_HOSTONLY_NAME:-vboxnet0}"
BOX_VERSION="${ASA_PROJ1_BOX_VERSION:-12.20250126.1}"
etapa='pré-requisitos'
falhar() { printf 'Erro: %s\n' "$*" >&2; return 1; }
validar_plataforma() {
    [[ "$(uname -s)" == Linux && "$(uname -r)" != *[Mm]icrosoft* && -z "${WSL_INTEROP:-}${WSL_DISTRO_NAME:-}" ]] || falhar 'Este instalador aceita somente Linux nativo; no Windows use o fluxo manual'
    [[ $(id -u) != 0 ]] || falhar 'Execute como usuário normal, não como root'
    [[ "$(uname -m)" == x86_64 ]] || falhar 'A box debian/bookworm64 usada neste projeto requer hospedeiro x86_64'
}
conferir_driver() {
    [[ -r /dev/vboxdrv && -w /dev/vboxdrv ]] || falhar 'Driver VirtualBox indisponível ou sem permissão em /dev/vboxdrv'
}

# Confere as VMs e a rede antes de qualquer criação ou inicialização.
conferir_ambiente() {
python3 - "$ROOT" "$HOSTONLY" <<'PY'
import ipaddress,json,pathlib,re,socket,subprocess,sys
root=pathlib.Path(sys.argv[1]);adapter=sys.argv[2]
def run(*args): return subprocess.check_output(args,text=True)
def require(ok,msg):
 if not ok: raise SystemExit(msg)
def info(uid):
 result={}
 for line in run('VBoxManage','showvminfo',uid,'--machinereadable').splitlines():
  if '=' in line:
   k,v=line.split('=',1)
   result[k.strip('"')]=v.strip('"')
 return result
specs={'arq':(512,1,2220,'022026000020'),'db':(512,1,2221,'022026000021'),'app':(512,1,2223,'022026000022'),'cli':(2048,2,2224,'022026000023')}
owned={};running_ports=set()
require(not (root/'.vagrant').is_symlink(),'.vagrant não pode ser um link para outro ambiente')
for name,spec in specs.items():
 p=root/'.vagrant/machines'/name/'virtualbox/id'
 if not p.exists(): continue
 uid=p.read_text().strip()
 require(bool(re.fullmatch(r'[0-9a-fA-F-]{36}',uid)),'UUID local inválido')
 vm=info(uid)
 require(vm.get('name')=='ASA-Proj1-'+name,'Nome/UUID divergente: '+name)
 require(vm.get('macaddress2','').lower()==spec[3].lower(),'MAC privado divergente: '+name)
 require(vm.get('nic1')=='nat' and vm.get('nic2')=='hostonly' and vm.get('hostonlyadapter2')==adapter,'Rede divergente: '+name)
 require(vm.get('memory')==str(spec[0]) and vm.get('cpus')==str(spec[1]),'Recursos divergentes: '+name+'; não serão alterados automaticamente')
 require(any(',127.0.0.1,'+str(spec[2])+',,22' in v for k,v in vm.items() if k.startswith('Forwarding(')),'Porta SSH divergente: '+name)
 require(vm.get('VMState') in ('running','poweroff'),'Estado não suportado: '+name)
 owned[uid]=vm
 if vm.get('VMState')=='running': running_ports.add(spec[2])
for line in run('VBoxManage','list','vms').splitlines():
 match=re.match(r'^"(.+)"\s+\{([^}]+)\}$',line)
 require(bool(match),'Registro VirtualBox não reconhecido')
 name,uid=match.groups()
 if uid in owned: continue
 require(name not in ['ASA-Proj1-'+n for n in specs],'Nome já usado por VM sem vínculo com este clone: '+name)
 vm=info(uid)
 require(not any(k.startswith('hostonlyadapter') and v==adapter for k,v in vm.items()),'Outra VM usa o adaptador '+adapter+': '+name)
 require(not any(k.startswith('macaddress') and v.lower() in [s[3].lower() for s in specs.values()] for k,v in vm.items()),'MAC do projeto já usado por outra VM')
for port in [s[2] for s in specs.values()]:
 if port in running_ports: continue
 with socket.socket() as sock:
  try: sock.bind(('127.0.0.1',port))
  except OSError: raise SystemExit('Porta SSH ocupada: '+str(port))
for line in run('ss','-H','-lun').splitlines():
 fields=line.split()
 if len(fields)>=5:
  local=fields[3]
  require(local not in ('0.0.0.0:67','*:67','[::]:67','192.168.56.1:67'),'Outro servidor DHCP no hospedeiro pode interferir na rede privada')
subnet=ipaddress.ip_network('192.168.56.0/24')
for link in json.loads(run('ip','-j','address','show')):
 for address in link.get('addr_info',[]):
  if address.get('family')=='inet' and link['ifname']!=adapter:
   require(not subnet.overlaps(ipaddress.ip_network(address['local']+'/'+str(address['prefixlen']),strict=False)),'Outra interface usa a rede do projeto')
for route in json.loads(run('ip','-j','route','show')):
 dest=route.get('dst','default')
 if dest!='default' and route.get('dev')!=adapter:
  require(not subnet.overlaps(ipaddress.ip_network(dest,strict=False)),'Rota de terceiros sobreposta à rede do projeto')
needed=sum(s[0] for n,s in specs.items() if not any(v['name']=='ASA-Proj1-'+n and v.get('VMState')=='running' for v in owned.values()))+1024
available=int(run('free','-m').splitlines()[1].split()[-1])
require(available>=needed,'RAM disponível insuficiente: precisa de '+str(needed)+' MiB incluindo margem')
paths=[str(root),str(pathlib.Path.home())]
for line in run('VBoxManage','list','systemproperties').splitlines():
 if line.startswith('Default machine folder:'):
  p=pathlib.Path(line.split(':',1)[1].strip())
  while not p.exists(): p=p.parent
  paths.append(str(p))
for p in paths:
 free=int(run('df','-Pm',p).splitlines()[-1].split()[3])
 require(free>=20480,'São necessários pelo menos 20 GiB livres em '+p)
print('Identidades, recursos, portas, espaço e conflitos de rede: OK')
PY
}

preparar_rede() {
    conferir_ambiente
    local listing created
    listing="$(VBoxManage list hostonlyifs)"
    if ! grep -Eq "^Name:[[:space:]]+$HOSTONLY[[:space:]]*$" <<<"$listing"; then
        created="$(VBoxManage hostonlyif create)"
        printf '%s\n' "$created"
        VBoxManage list hostonlyifs | grep -Eq "^Name:[[:space:]]+$HOSTONLY[[:space:]]*$" || falhar "O adaptador criado não é $HOSTONLY; confira antes de continuar"
        VBoxManage hostonlyif ipconfig "$HOSTONLY" --ip 192.168.56.1 --netmask 255.255.255.0
    fi
    python3 - "$HOSTONLY" <<'PY'
import re,subprocess,sys
adapter=sys.argv[1];network='HostInterfaceNetworking-'+adapter
def output(*args): return subprocess.check_output(['VBoxManage',*args],text=True)
def block(text,key,value):
 return next((b for b in re.split(r'\n\s*\n',text) if re.search(r'^'+key+r':\s+'+re.escape(value)+r'\s*$',b,re.M)),None)
b=block(output('list','hostonlyifs'),'Name',adapter)
if not b or not re.search(r'^IPAddress:\s+192\.168\.56\.1\s*$',b,re.M) or not re.search(r'^NetworkMask:\s+255\.255\.255\.0\s*$',b,re.M): raise SystemExit('Adaptador existente divergente; nenhuma correção automática será feita')
b=block(output('list','dhcpservers'),'NetworkName',network)
if b is None:
 subprocess.run(['VBoxManage','dhcpserver','add','--network='+network,'--server-ip=192.168.56.2','--netmask=255.255.255.0','--lower-ip=192.168.56.3','--upper-ip=192.168.56.254','--disable'],check=True)
else:
 for key,value in {'Dhcpd IP':'192.168.56.2','NetworkMask':'255.255.255.0','LowerIPAddress':'192.168.56.3','UpperIPAddress':'192.168.56.254'}.items():
  if not re.search('^'+key+r':\s+'+re.escape(value)+r'\s*$',b,re.M): raise SystemExit('Cadastro DHCP existente divergente: '+key)
 subprocess.run(['VBoxManage','dhcpserver','modify','--network='+network,'--disable'],check=True)
PY
}

# Salva e restaura somente o DNS do adaptador usado por este projeto.
dns_projeto() {
python3 - "$1" "$HOSTONLY" "$STATE" <<'PY'
import json,pathlib,subprocess,sys
mode,adapter,folder=sys.argv[1:];path=pathlib.Path(folder)/'dns.json'
def run(*args): return subprocess.check_output(args,text=True).strip()
def values(command): return run('resolvectl',command,adapter).split(':',1)[1].split()
def current():
 result={'dns':values('dns'),'domain':values('domain'),'default-route':values('default-route')}
 if result['default-route'] not in (['yes'],['no']): raise SystemExit('Não foi possível interpretar default-route')
 return result
index=json.loads(run('ip','-j','link','show','dev',adapter))[0]['ifindex']
now=current();applied={'dns':['192.168.56.120'],'domain':['~pedro.henryque.devops'],'default-route':['no']}
if path.exists():
 saved=json.loads(path.read_text())
 if saved['adapter']!=adapter or saved['ifindex']!=index: raise SystemExit('Identidade do adaptador DNS mudou')
 before=saved['before']
else:
 if mode=='restore':
  print('Não há configuração DNS aplicada pelo instalador.');sys.exit(0)
 if now['dns'] not in ([],applied['dns']) or now['domain'] not in ([],applied['domain']): raise SystemExit('DNS/domínios de terceiros no adaptador; nenhuma alteração feita')
 before=now
 path.write_text(json.dumps({'adapter':adapter,'ifindex':index,'before':before},indent=2))
 path.chmod(0o600)
for key in applied:
 if now[key]!=applied[key] and now[key]!=before[key]: raise SystemExit('DNS foi alterado por terceiros; restauração/aplicação automática interrompida')
target=before if mode=='restore' else applied
for key in ['default-route','domain','dns']:
 if now[key]!=target[key]: subprocess.run(['sudo','-n','resolvectl',key,adapter,*(target[key] or [''])],check=True)
if current()!=target: raise SystemExit('Configuração DNS final divergente')
print('DNS específico '+('restaurado' if mode=='restore' else 'configurado')+' em '+adapter)
PY
}

dados_guest() {
python3 - "$1" "$2" "$STATE" <<'PY'
import ipaddress,json,pathlib,shlex,subprocess,sys,time
name,mac,folder=sys.argv[1:]
code='''import json,pathlib,subprocess
print(json.dumps({"hostname":subprocess.check_output(["hostname","-f"],text=True).strip(),"key":pathlib.Path("/etc/ssh/ssh_host_ed25519_key.pub").read_text().strip(),"interfaces":json.loads(subprocess.check_output(["ip","-j","-4","address"],text=True))}))'''
for attempt in range(12):
 result=subprocess.run(['vagrant','ssh',name,'-c','python3 -c '+shlex.quote(code)],capture_output=True,text=True,timeout=40)
 if result.returncode==0:
  data=json.loads(result.stdout.strip())
  ips=[a['local'] for nic in data['interfaces'] if nic.get('address','').lower()==mac.lower() for a in nic.get('addr_info',[]) if a['family']=='inet' and ipaddress.ip_address(a['local']) in ipaddress.ip_network('192.168.56.0/24')]
  if len(ips)==1:
   ip=ips[0];expected={'arq':'192.168.56.120','db':'192.168.56.121','app':'192.168.56.122'}
   if data['hostname']!=name+'.pedro.henryque.devops' or not data['key'].startswith('ssh-ed25519 '): raise SystemExit('Identidade do convidado divergente: '+name)
   if name in expected and ip!=expected[name]: raise SystemExit('Endereço divergente: '+name)
   if name=='cli' and not 50<=int(ip.split('.')[-1])<=100: raise SystemExit('Concessão de cli fora da faixa')
   record={'name':name,'ip':ip,'hostkey':data['key']}
   (pathlib.Path(folder)/(name+'.json')).write_text(json.dumps(record))
   print(name+': '+ip);break
 time.sleep(3)
else: raise SystemExit('Não foi possível obter o IP/chave de '+name)
PY
}

ssh_arq() {
    ssh -F none -T -i "$STATE/keys/vagrant" -o BatchMode=yes -o IdentitiesOnly=yes \
        -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$STATE/known_hosts" \
        -o ConnectTimeout=10 vagrant@192.168.56.120 "$1"
}

colecoes_corretas() {
python3 - "$STATE/collections.json" "$STATE/collections" <<'PY'
import json,sys
data=json.load(open(sys.argv[1]))
found={name:info['version'] for path,entries in data.items() if path.startswith(sys.argv[2]+'/') for name,info in entries.items()}
sys.exit(0 if found.get('ansible.posix')=='2.1.0' and found.get('community.general')=='12.1.0' else 1)
PY
}

main() {
    [[ $# == 1 && "$1" =~ ^(--aprovar|--verificar|--configurar-dns|--restaurar-dns)$ ]] || { echo 'Uso: bash scripts/instalar.sh --aprovar | --verificar | --configurar-dns | --restaurar-dns'; return 2; }
    validar_plataforma
    [[ "$HOSTONLY" =~ ^vboxnet[0-9]+$ ]] || falhar 'Nome host-only inválido; use vboxnetN'
    cd "$ROOT"
    export VAGRANT_CWD="$ROOT" VAGRANT_VAGRANTFILE=Vagrantfile VAGRANT_DOTFILE_PATH="$ROOT/.vagrant"
    command -v python3 >/dev/null || falhar 'Python 3 não encontrado'
    STATE="$(python3 - "$ROOT" "$STATE" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1]).resolve();state=Path(sys.argv[2]).expanduser().resolve()
if state==root or root in state.parents: raise SystemExit('Use ASA_PROJ1_STATE_DIR fora do repositório para proteger o estado local')
print(state)
PY
    )"
    export LC_ALL=C.UTF-8 ANSIBLE_CONFIG="$ROOT/ansible.cfg" PYTHONDONTWRITEBYTECODE=1
    export ASA_PROJ1_HOSTONLY_NAME="$HOSTONLY" ASA_PROJ1_STATE_DIR="$STATE"
    if [[ "$1" == --restaurar-dns || "$1" == --configurar-dns ]]; then
        [[ -f "$STATE/projeto" && "$(cat "$STATE/projeto")" == "$ROOT" ]] || falhar 'Estado não pertence a este clone'
        exec 9>"$STATE/instalar.lock"
        flock -n 9 || falhar 'Já existe uma operação em andamento'
        sudo -v
        if [[ "$1" == --restaurar-dns ]]; then dns_projeto restore
        else
            conferir_ambiente
            ssh_arq 'sudo -n systemctl is-active --quiet named'
            dns_projeto apply
        fi
        return
    fi
    for tool in vagrant VBoxManage python3 ssh ssh-keygen xauth ansible ansible-playbook ansible-galaxy resolvectl sudo flock ip free df dig ss; do
        command -v "$tool" >/dev/null || falhar "Ferramenta ausente: $tool; veja o README"
    done
    export VBOXMANAGE="$(command -v VBoxManage)"
    conferir_driver
    python3 - <<'PY'
import re,subprocess,sys
for command,pattern,minimum in [(['vagrant','--version'],r'(\d+\.\d+)',(2,4)),(['VBoxManage','--version'],r'(\d+\.\d+)',(7,2)),(['ansible','--version'],r'core (\d+\.\d+)',(2,20))]:
 text=subprocess.check_output(command,text=True);match=re.search(pattern,text)
 if not match or tuple(map(int,match[1].split('.')))!=minimum: raise SystemExit('Versão fora da série validada: '+command[0])
 print(command[0]+': '+match[1])
if sys.version_info<(3,12): raise SystemExit('Python 3.12 ou mais recente é necessário')
PY
    conferir_ambiente
    if [[ "$1" == --verificar ]]; then
        vagrant box list
        ansible-galaxy collection list
        VBoxManage list hostonlyifs
        VBoxManage list dhcpservers
        echo 'Pré-verificação concluída; confira os cadastros exibidos. Nenhuma configuração foi alterada.'
        return
    fi
    umask 077
    if [[ -f "$STATE/projeto" ]]; then
        [[ "$(cat "$STATE/projeto")" == "$ROOT" ]] || falhar 'Diretório de estado já pertence a outro clone'
    elif [[ -d "$STATE/keys" && ! -f .vagrant/machines/arq/virtualbox/id ]]; then
        falhar 'Chaves preexistentes sem vínculo com este clone; escolha outro ASA_PROJ1_STATE_DIR'
    fi
    [[ ! -e "$STATE" || ( -d "$STATE" && -O "$STATE" && ! -L "$STATE" ) ]] || falhar 'Diretório de estado inválido'
    mkdir -p "$STATE"
    STATE="$(cd "$STATE" && pwd -P)";export ASA_PROJ1_STATE_DIR="$STATE"
    exec 9>"$STATE/instalar.lock"
    flock -n 9 || falhar 'Já existe uma instalação em andamento'
    printf '%s\n' "$ROOT" > "$STATE/projeto"
    trap 'printf "Falha na etapa: %s. As VMs foram preservadas; corrija o erro e repita --aprovar.\n" "$etapa" >&2' ERR
    sudo -v
    etapa='dependências e rede'
    export ANSIBLE_COLLECTIONS_PATH="$STATE/collections"
    mkdir -p "$STATE/collections"
    ansible-galaxy collection list -p "$STATE/collections" --format json > "$STATE/collections.json"
    if ! colecoes_corretas; then
        ansible-galaxy collection install -r ansible/requirements.yml -p "$STATE/collections"
        ansible-galaxy collection list -p "$STATE/collections" --format json > "$STATE/collections.json"
        colecoes_corretas || falhar 'As versões das collections não correspondem ao requirements.yml'
    fi
    if ! vagrant box list | grep -Eq "^debian/bookworm64[[:space:]]+\(virtualbox,[[:space:]]+$BOX_VERSION\)"; then
        vagrant box add debian/bookworm64 --provider virtualbox --box-version "$BOX_VERSION"
    fi
    vagrant validate
    for play in site client-site; do ansible-playbook "ansible/$play.yml" --syntax-check; done
    preparar_rede
    export ASA_PROJ1_EXECUTION_APPROVED=1 ASA_PROJ1_DHCP_CHANGE_APPROVED=1
    etapa='arq: acesso e serviços de rede'
    conferir_ambiente
    vagrant up arq --provider virtualbox --no-provision
    conferir_ambiente
    dados_guest arq 02:20:26:00:00:20
    vagrant ssh-config arq > "$STATE/arq-ssh.config"
    local key
    key="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["hostkey"])' "$STATE/arq.json")"
    python3 scripts/preparar-controlador.py --ssh-config "$STATE/arq-ssh.config" --host-key "$key"
    ansible-playbook ansible/site.yml --tags base,dhcp,dns
    etapa='arq: discos e NFS'
    python3 scripts/manifesto-discos.py --vboxmanage "$(command -v VBoxManage)"
    ansible-playbook ansible/site.yml --tags storage,nfs
    ssh_arq 'sudo -n sh -c '\''set -e; for s in named isc-dhcp-server chrony nfs-server; do systemctl is-active --quiet "$s"; done; chronyc waitsync 15 1 0 2; findmnt --mountpoint /dados; lvs dados/ifpb; exportfs -v'\'''
    export ASA_PROJ1_CLIENT_BOOTSTRAP_READY=1
    local name mac
    for name in db app cli; do
        etapa="criação de $name"
        conferir_ambiente
        vagrant up "$name" --provider virtualbox
        conferir_ambiente
        case "$name" in db) mac=02:20:26:00:00:21;; app) mac=02:20:26:00:00:22;; cli) mac=02:20:26:00:00:23;; esac
        dados_guest "$name" "$mac"
        python3 scripts/registrar-cliente.py "$STATE/$name.json"
    done
    etapa='configuração dos clientes'
    ansible-playbook ansible/client-site.yml
    etapa='DNS do hospedeiro'
    conferir_ambiente
    sudo -v
    dns_projeto apply
    etapa='verificações finais'
    ansible lab -m ansible.builtin.ping
    ansible clients -b -m ansible.builtin.shell -a 'set -e; chronyc waitsync 15 1 0 2; grep -q "inet dhcp" /etc/network/interfaces.d/asa-private; ls /var/nfs/ >/dev/null; findmnt -T /var/nfs'
    ansible db -b -m ansible.builtin.command -a 'mariadb -Nse "SELECT 1"'
    ansible cli -m ansible.builtin.command -a 'dpkg-query -W firefox-esr xauth'
    ansible app -b -m ansible.builtin.shell -a 'set -e; for u in pedro henryque; do test -e /var/nfs/$u.txt || runuser -u "$u" -- touch /var/nfs/$u.txt; done'
    ansible clients -m ansible.builtin.shell -a 'test -r /var/nfs/pedro.txt && test -r /var/nfs/henryque.txt'
    ssh_arq 'test "$(stat -c %u:%g /dados/nfs/pedro.txt)" = 2048:2048 && test "$(stat -c %u:%g /dados/nfs/henryque.txt)" = 2048:2048'
    python3 - "$STATE" <<'PY'
import json,pathlib,re,shlex,socket,subprocess,sys,urllib.request
state=pathlib.Path(sys.argv[1])
for name in ['arq','db','app','cli']:
 ip=json.loads((state/(name+'.json')).read_text())['ip'];fqdn=name+'.pedro.henryque.devops'
 if socket.gethostbyname(fqdn)!=ip: raise SystemExit('DNS direto divergente: '+name)
 ptr=subprocess.check_output(['dig','@192.168.56.120','+short','-x',ip],text=True).strip()
 if ptr!=fqdn+'.': raise SystemExit('DNS reverso divergente: '+name)
with urllib.request.urlopen('http://app.pedro.henryque.devops/',timeout=15) as response:
 if response.status!=200 or b'20251380020' not in response.read(): raise SystemExit('Página HTTP divergente')
socket.gethostbyname('deb.debian.org')
with urllib.request.urlopen('https://deb.debian.org/debian/',timeout=20) as response:
 if response.status!=200: raise SystemExit('Acesso externo indisponível')
def ssh(user,name,key,command):
 return subprocess.check_output(['ssh','-F','none','-T','-i',str(state/'keys'/key),'-o','BatchMode=yes','-o','IdentitiesOnly=yes','-o','StrictHostKeyChecking=yes','-o','UserKnownHostsFile='+str(state/'known_hosts'),'-o','ConnectTimeout=10',user+'@'+name+'.pedro.henryque.devops',command],text=True,timeout=30).strip()
for user in ['pedro','henryque']:
 path=ssh(user,'app',user,'mktemp /var/nfs/.asa-proj1-XXXXXXXX')
 if not re.fullmatch(r'/var/nfs/\.asa-proj1-[A-Za-z0-9]+',path): raise SystemExit('Nome de teste NFS inesperado')
 try:
  ssh(user,'app',user,'printf projeto-01 > '+shlex.quote(path))
  for name in ['db','cli']:
   if ssh(user,name,user,'cat '+shlex.quote(path))!='projeto-01': raise SystemExit('Leitura NFS divergente: '+name)
  if ssh('vagrant','arq','vagrant','stat -c %u:%g '+shlex.quote(path.replace('/var/nfs/','/dados/nfs/')) )!='2048:2048': raise SystemExit('Mapeamento NFS divergente')
 finally:
  ssh(user,'app',user,'rm -- '+shlex.quote(path))
print('DNS direto/reverso, HTTP 200 e escrita/leitura NFS com all_squash: OK')
PY
    printf '\nInstalação concluída. DHCP, DNS, LVM/NFS, Ansible, MariaDB e HTTP conferidos.\n'
    printf 'Estado: %s\nAtive export ANSIBLE_COLLECTIONS_PATH="%s/collections" ao usar o Ansible em outra sessão.\n' "$STATE" "$STATE"
    printf 'Demonstre o Firefox manualmente pelo SSH -X. O verificador do professor não foi executado automaticamente.\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
