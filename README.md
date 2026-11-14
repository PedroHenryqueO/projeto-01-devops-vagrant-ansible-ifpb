# Projeto 01 — DevOps com Vagrant e Ansible

## 1. Identificação

- **Instituição:** IFPB — Campus João Pessoa
- **Curso:** Tecnologia em Redes de Computadores
- **Disciplina:** Administração de Sistemas Abertos
- **Professor:** Leonidas Lima
- **Período:** 2026.2
- **Aluno:** Pedro Henryque de Oliveira
- **Matrícula:** 20251380020

Projeto individual. Os usuários adotados são `pedro` e `henryque`.

## 2. Objetivo

Criar quatro máquinas Debian com Vagrant e automatizar serviços Linux com Ansible: DHCP, DNS, LVM, NFS, MariaDB, Apache e acesso remoto por SSH.

## 3. Infraestrutura

| Máquina | RAM | CPUs | Endereço privado | Função |
|---|---:|---:|---|---|
| arq | 512 MB | 1 | 192.168.56.120 | Rede e armazenamento |
| db | 512 MB | 1 | 192.168.56.121, reserva DHCP | Banco de dados |
| app | 512 MB | 1 | 192.168.56.122, reserva DHCP | Servidor web |
| cli | 1024 MB | 2 | DHCP, faixa .50–.100 | Cliente com Firefox |

Domínio: `pedro.henryque.devops`.

Cada VM tem uma interface NAT para internet e outra host-only para a rede do projeto. As portas SSH no Windows são 2220, 2221, 2223 e 2224, respectivamente, acessíveis por `127.0.0.1`.

arq tem três discos adicionais de 10 GiB. As máquinas usam linked clones da box `debian/bookworm64`.

## 4. Ferramentas utilizadas

- Windows com VirtualBox e Vagrant.
- Ubuntu WSL2 com Python, OpenSSH e Ansible.
- WSLg e xauth para executar Firefox remotamente.
- Collections `ansible.posix` e `community.general`.

O ambiente foi validado com VirtualBox 7.2.20, Vagrant 2.4.9 e Ansible Core 2.20.1.

No Ubuntu WSL, prepare o controlador:

```bash
sudo apt update
sudo apt install python3-venv openssh-client dnsutils xauth
python3 -m venv ~/.venvs/asa-proj1
source ~/.venvs/asa-proj1/bin/activate
python3 -m pip install ansible-core==2.20.1
```

Ative esse ambiente virtual nas sessões usadas para executar o Ansible.

## 5. Serviços configurados

**Todas as máquinas:** atualização do sistema, Chrony com `pool.ntp.br`, timezone `America/Recife`, grupo `ifpb`, usuários e chaves individuais, sudo e cliente NFS.

O SSH permite autenticação por chave, bloqueia root e restringe o acesso aos grupos `vagrant` e `ifpb`. A mensagem exigida pelo enunciado é preservada.

**arq:** DHCP autoritativo na interface privada, reservas de db/app, DNS direto e reverso, encaminhadores `1.1.1.1` e `8.8.8.8` e DDNS de cli autenticado por TSIG. O armazenamento usa VG `dados`, LV `ifpb` de 15 GiB, ext4 em `/dados` e NFS em `/dados/nfs`, com `sync` e `all_squash` para `nfs-ifpb`.

**db:** MariaDB e autofs em `/var/nfs`.

**app:** Apache, página acadêmica e autofs em `/var/nfs`.

**cli:** Firefox ESR, xauth, encaminhamento X11 e autofs em `/var/nfs`.

## 6. Como executar o projeto

### Preparar a pasta e a rede

Clone pelo Windows e acesse a mesma pasta pelo WSL:

```powershell
git clone https://github.com/PedroHenryqueO/projeto-01-devops-vagrant-ansible-ifpb.git
cd projeto-01-devops-vagrant-ansible-ifpb
```

Vagrant e VBoxManage devem estar disponíveis no terminal do Windows.

Antes de criar as VMs, confira:

```powershell
VBoxManage list hostonlyifs
VBoxManage list dhcpservers
```

A rede host-only deve usar `192.168.56.1/24`. O cadastro DHCP do VirtualBox deve ter servidor `.2` e faixa `.3–.254`; o gatilho do projeto o desabilita para permitir o DHCP de arq.

Em outro computador, se essa rede ainda não existir, prepare-a após verificar conflitos:

```powershell
VBoxManage hostonlyif create
VBoxManage hostonlyif ipconfig "ADAPTADOR" --ip 192.168.56.1 --netmask 255.255.255.0
VBoxManage dhcpserver add --network="HostInterfaceNetworking-ADAPTADOR" --server-ip=192.168.56.2 --netmask=255.255.255.0 --lower-ip=192.168.56.3 --upper-ip=192.168.56.254 --disable
$env:ASA_PROJ1_HOSTONLY_NAME = "ADAPTADOR"
```

Substitua `ADAPTADOR` pelo nome real. Não altere uma rede compartilhada sem avaliar seu uso. Se já houver cadastro DHCP, confira seus parâmetros em vez de tentar criá-lo novamente.

### Criar e configurar arq

No Windows:

```powershell
scripts\projeto.cmd up-arq --aprovar-vm --aprovar-dhcp
vagrant ssh-config arq
vagrant ssh arq -c "cat /etc/ssh/ssh_host_ed25519_key.pub"
```

Use o `IdentityFile` mostrado pelo Vagrant e a chave **pública** retornada pelo último comando.

No WSL, dentro da pasta do projeto:

```bash
export ANSIBLE_CONFIG="$PWD/ansible.cfg"
ansible-galaxy collection install -r ansible/requirements.yml
python3 scripts/preparar-controlador.py \
  --vagrant-key "$(wslpath 'CAMINHO_IDENTITYFILE')" \
  --host-key 'ssh-ed25519 CHAVE_PUBLICA_ARQ'
ansible-playbook ansible/site.yml --tags base,dhcp,dns
python3 scripts/manifesto-discos.py
```

Mantenha `ANSIBLE_CONFIG` definido nas sessões usadas para o projeto. O manifesto identifica os discos desta VM e gera `ansible/host_vars/arq.yml` localmente; ele não é versionado.

Confira a identificação dos três discos antes de executar:

```bash
ansible-playbook ansible/site.yml --tags storage,nfs
```

Essa etapa cria o LVM e o filesystem. O validador bloqueia discos inesperados; não use opções forçadas para contornar uma divergência. As chaves e o manifesto devem ser preparados neste ambiente, sem copiar metadados de outra instalação.

### Criar e configurar os clientes

Crie uma máquina por vez, depois que DHCP, DNS e NFS de arq estiverem funcionando:

```powershell
scripts\projeto.cmd up-db --aprovar-vm --aprovar-dhcp
```

Pelo `vagrant ssh db`, consulte o endereço privado e a chave pública do host:

```bash
ip -4 address
cat /etc/ssh/ssh_host_ed25519_key.pub
```

No WSL, salve um JSON local, por exemplo `/tmp/db.json`:

```json
{"name":"db","ip":"192.168.56.121","hostkey":"ssh-ed25519 CHAVE_PUBLICA_DB"}
```

Registre e configure:

```bash
python3 scripts/registrar-cliente.py /tmp/db.json
ansible-playbook ansible/client-site.yml --limit db
```

Repita o procedimento para app e depois cli, usando `up-app` e `up-cli`, os nomes e IPs correspondentes no JSON e `--limit app` ou `--limit cli`. cli usa DHCP dinâmico; confira sua concessão e atualize o inventário quando necessário.

As chaves ficam em `~/.local/share/asa-proj1/keys`, fora do repositório. Se uma chave de host mudar, confira a identidade da VM antes de substituir o registro.

### Resolver os nomes no Windows e WSL

Os convidados recebem o DNS de arq. No Windows, a regra NRPT encaminha apenas o domínio do projeto para esse servidor.

Em PowerShell como administrador, consulte as regras existentes:

```powershell
Get-DnsClientNrptRule
```

Se não houver regra para esse domínio, crie:

```powershell
Add-DnsClientNrptRule -Namespace '.pedro.henryque.devops' -NameServers '192.168.56.120' -Comment 'ASA-Proj1'
```

Se já existir, confira namespace, servidor e comentário antes de reutilizá-la. Não substitua os DNS gerais.

Confira a resolução:

```powershell
Resolve-DnsName app.pedro.henryque.devops
```

No WSL:

```bash
getent ahostsv4 app.pedro.henryque.devops
```

O WSL com DNS tunneling pode utilizar a regra do Windows. Confirme o funcionamento antes de executar o verificador.

Para remover a regra posteriormente, consulte seu identificador com `Get-DnsClientNrptRule` e use `Remove-DnsClientNrptRule -Name IDENTIFICADOR`, somente após conferir que corresponde ao domínio, servidor e comentário acima.

### Acessar a página

No Windows: `http://app.pedro.henryque.devops`.

Para executar Firefox em cli pelo WSLg:

```bash
ssh -X -i "$HOME/.local/share/asa-proj1/keys/henryque" \
  -o "UserKnownHostsFile=$HOME/.local/share/asa-proj1/known_hosts" \
  henryque@192.168.56.50 firefox-esr http://app.pedro.henryque.devops
```

Substitua `.50` caso a concessão de cli seja diferente. Inicie arq antes dos clientes e desligue-a por último.

## 7. Verificação do funcionamento

No ambiente utilizado, foram comprovados DHCP, reservas, DDNS real de cli, DNS direto/reverso, SSH, sudo, Chrony, LVM, montagem persistente, NFS/autofs, escrita por app e leitura por db/cli, mapeamento para `nfs-ifpb`, MariaDB, Apache e Firefox remoto. Também foram verificadas a persistência após reinicializações e a reaplicação Ansible sem alterações.

O verificador original do professor foi executado em **12/11/2026**, com DNS normal: **retorno 0, STDERR vazio e nenhuma mensagem de falha reportada**.

Para executá-lo novamente, obtenha o original pelo professor/Classroom e coloque-o em `referencias/verifica-proj1.py`. Crie a pasta `referencias` se necessário. O original não é distribuído por falta de autorização de redistribuição.

Use uma sessão WSLg com display funcional. O auxiliar exige ausência prévia de `intruso`, de seu home e da chave temporária. Também espera os arquivos `pedro.txt` e `henryque.txt` existentes no NFS.

Em uma instalação nova, crie esses arquivos de demonstração somente se estiverem ausentes:

```bash
ansible app -b -m ansible.builtin.shell \
  -a 'for u in pedro henryque; do test -e /var/nfs/$u.txt || touch /var/nfs/$u.txt; done'
```

Execute:

```bash
python3 scripts/verificador-oficial.py
```

O auxiliar executa o original sem modificá-lo, preserva os arquivos NFS e realiza a limpeza posterior. Os logs ficam locais.

O retorno do verificador não substitui todas as verificações: ele oculta alguns erros e abre Firefox em segundo plano.

**Uma implantação integral em ambiente novo ainda não foi testada.**
