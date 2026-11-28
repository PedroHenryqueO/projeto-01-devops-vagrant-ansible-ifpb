# Projeto 01 — Vagrant e Ansible

## 1. Identificação e objetivo

IFPB — Campus João Pessoa · Tecnologia em Redes de Computadores

Administração de Sistemas Abertos · Professor Leonidas Lima · 2026.2

**Aluno:** Pedro Henryque de Oliveira · **Matrícula:** 20251380020

Provisionar quatro VMs Debian com Vagrant e configurar serviços Linux com Ansible. Esta versão usa **Ubuntu nativo como controlador**, com VirtualBox.

## 2. Infraestrutura

| VM | RAM / CPUs | Rede privada | Serviços |
|---|---|---|---|
| arq | 512 MB / 1 | 192.168.56.120 | DHCP, DNS/DDNS, Chrony, LVM e NFS |
| db | 512 MB / 1 | 192.168.56.121 por reserva DHCP | MariaDB e autofs |
| app | 512 MB / 1 | 192.168.56.122 por reserva DHCP | Apache, página acadêmica e autofs |
| cli | 2048 MB / 2 | DHCP dinâmico, .50–.100 | Firefox ESR, X11 e autofs |

Domínio: `pedro.henryque.devops`. A NAT fornece internet; a rede privada é `192.168.56.0/24`. O adaptador padrão é `vboxnet0`. As portas SSH locais são 2220, 2221, 2223 e 2224, respectivamente.

arq usa três discos de 10 GiB, VG `dados`, LV `ifpb` de 15 GiB, ext4 e montagem em `/dados`. O NFS exporta `/dados/nfs` com escrita síncrona e `all_squash` para `nfs-ifpb` (UID/GID 2048). Os clientes montam esse compartilhamento por autofs em `/var/nfs`.

Todas as VMs recebem Chrony com `pool.ntp.br`, timezone `America/Recife`, usuários `pedro` e `henryque`, grupo `ifpb`, chaves individuais, sudo e cliente NFS. SSH bloqueia root e senhas, permitindo os grupos `vagrant` e `ifpb`. O DDNS de cli usa TSIG; o DHCP atua somente na interface privada. Os encaminhadores DNS são `1.1.1.1` e `8.8.8.8`.

cli usa 2048 MB e 2 CPUs, conforme a alteração autorizada. `upgrade: dist` permanece comentado; os índices APT continuam sendo atualizados.

## 3. Pré-requisitos

Ubuntu x86_64 com virtualização disponível, VirtualBox 7.2 funcionando (`/dev/vboxdrv`), Vagrant 2.4, Python 3.12 ou posterior, Ansible Core 2.20 e VS Code com o comando `code` disponível. Reserve pelo menos 20 GiB livres e cerca de 4,5 GiB de RAM disponível, além da folga para o Firefox e o hospedeiro.

Instale VirtualBox, Vagrant e VS Code pelos procedimentos oficiais. Prepare o Ansible:

```bash
sudo apt update
sudo apt install git python3-venv openssh-client xauth dnsutils curl
python3 -m venv ~/.venvs/asa-proj1
source ~/.venvs/asa-proj1/bin/activate
python3 -m pip install ansible-core==2.20.1
```

O Vagrant instala as collections de `ansible/requirements.yml` durante o provisionamento. Para mostrar o Firefox, use um desktop Linux ou uma sessão SSH com encaminhamento X11 e `DISPLAY` válido. Ubuntu Server sem desktop precisa de um servidor X na máquina de origem, como o WSLg; mantenha essa conexão aberta.

## 4. Roteiro da apresentação

### Clonar e abrir no VS Code

```bash
git clone https://github.com/PedroHenryqueO/projeto-01-devops-vagrant-ansible-ifpb.git
cd projeto-01-devops-vagrant-ansible-ifpb
code .
source ~/.venvs/asa-proj1/bin/activate
```

### Criar as quatro VMs

Antes de iniciar, confira as VMs e o DHCP existentes e anote o estado da rede que será usada:

```bash
VBoxManage list vms
VBoxManage list dhcpservers
pgrep -a VBoxNetDHCP
```

Use uma rede isolada. O projeto bloqueia adaptadores usados por VMs de terceiros, mesmo desligadas. Não altere máquinas de outros alunos para contornar a proteção. Se `vboxnet0` estiver ocupado, combine outra interface livre com o professor e defina `ASA_PROJ1_HOSTONLY_NAME` antes de iniciar; a sub-rede `192.168.56.0/24` também precisa estar livre.

```bash
vagrant up
vagrant status
```

O provisionamento é sequencial: arq fica pronta antes de db, app e cli. Não use `--parallel` nem `--no-provision` na criação inicial. O gatilho para o processo DHCP do VirtualBox antes do SSH, deixando as concessões para arq; ele não desabilita o cadastro. Não copie a pasta `.vagrant` de outro computador.

Se houver falha, leia o erro e conclua a VM afetada com `vagrant provision NOME` antes de continuar com `vagrant up`. Não use destruição ou formatação como recuperação de erros.

### Preparar o DNS do Ubuntu

Use a interface escolhida para o projeto e confirme o endereço `192.168.56.1/24`. Antes de alterar o resolvedor, **anote DNS, Domains e DefaultRoute anteriores**:

```bash
iface="${ASA_PROJ1_HOSTONLY_NAME:-vboxnet0}"
ip -4 address show "$iface"
resolvectl status "$iface"
sudo resolvectl default-route "$iface" no
sudo resolvectl domain "$iface" '~pedro.henryque.devops'
sudo resolvectl dns "$iface" 192.168.56.120
getent hosts arq.pedro.henryque.devops db.pedro.henryque.devops app.pedro.henryque.devops cli.pedro.henryque.devops
```

Não substitua configurações de terceiros. Os comandos exigem `systemd-resolved` e afetam somente a interface indicada. O DNS geral e a rota padrão da internet permanecem separados.

### Preparar o SSH e executar o verificador original

`verifica-proj1.py` está na raiz, junto ao Vagrantfile, sem alterações no código original. Ele procura `keys/` na pasta de execução; por isso, execute a partir de `.vagrant/asa`, onde o projeto já gerou as chaves.

Cadastre as chaves de host obtidas pelo Vagrant, sem apagar os registros existentes:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cat .vagrant/asa/known_hosts >> ~/.ssh/known_hosts
chmod 600 ~/.ssh/known_hosts
```

O verificador sobrescreve `pedro.txt` e `henryque.txt` no NFS e tenta criar/remover o usuário `intruso`. Use os dados de demonstração do ambiente recém-criado. Se houver dados anteriores, faça backup e restaure-os depois; confirme também que `intruso`, `/home/intruso` e `/tmp/intruso.pub` não existiam antes do teste.

```bash
(
    cd .vagrant/asa || exit 1
    env -u SSH_AUTH_SOCK python3 ../../verifica-proj1.py pedro.henryque
)
```

O agente SSH fica fora desse teste para não autenticar os acessos que o script espera bloquear. Leia a saída de cada host: o código de retorno não representa uma nota. O original abre o Firefox em segundo plano e oculta seus erros. Se precisar abrir a página separadamente e ver possíveis erros, use:

```bash
ssh -X -i .vagrant/asa/keys/henryque \
  -o "UserKnownHostsFile=$PWD/.vagrant/asa/known_hosts" \
  henryque@cli.pedro.henryque.devops firefox-esr http://app.pedro.henryque.devops
```

### Encerrar e remover somente as VMs deste clone

Feche o Firefox. Restaure os valores anotados de DNS, Domains e DefaultRoute **somente na interface do projeto**, usando `resolvectl dns`, `resolvectl domain` e `resolvectl default-route`. Para um DNS ou domínio originalmente vazio, use `''`. Não aplique `resolvectl revert` indiscriminadamente nem altere os servidores DNS gerais.

Na mesma pasta do clone, confira que `vagrant status` lista apenas arq, db, app e cli. O comando abaixo apaga essas quatro VMs e seus dados exclusivos; não execute em um ambiente com dados que precisam ser mantidos:

```bash
vagrant status
vagrant destroy -f arq db app cli
```

Depois que as quatro VMs forem removidas, inicie novamente o DHCP do VirtualBox **somente se ele estava rodando nessa interface antes da apresentação**:

```bash
VBoxManage dhcpserver start --interface "$iface"
```

Se não havia esse servidor rodando antes, não o inicie. Não exclua boxes, interfaces, servidores DHCP ou máquinas de outros projetos.

## 5. Organização e resultados

- `Vagrantfile`: recursos, rede, ordem, gatilho DHCP e proteções de identidade, chaves e discos.
- `ansible/site.yml`: importa `base.yml`, `dhcp-dns.yml`, `lvm-nfs.yml` e `clientes.yml`.
- `ansible/group_vars`, `templates` e `files`: variáveis e configurações dos serviços, HTML e validação dos discos.
- `ansible/requirements.yml`: collections necessárias.
- `scripts/bootstrap-client.sh`: DHCP privado sem perder a rota NAT.
- `verifica-proj1.py`: verificador original do professor.

As chaves, inventário de execução e manifesto dos discos ficam em `.vagrant/asa`, fora do Git. Não há dependência de roles nem do instalador antigo.

A implantação manual anterior foi validada pelo aluno no laboratório em 18/11/2026, antes de comentar `upgrade: dist`. O teste posterior no Ubuntu Server do Hyper-V criou e configurou as quatro VMs com `vagrant up`, mas exigiu correções e retomadas. **Ainda não foi comprovada uma instalação limpa da versão final nem sua persistência após reinicialização.**

Nos testes anteriores passaram DHCP/DDNS, DNS direto/reverso, LVM/ext4, NFS/autofs, Chrony, SSH/sudo, MariaDB e HTTP. A reaplicação apresentou `changed=0` nas quatro VMs. O original foi executado sem alterações e terminou com código 0, sem mensagens de falha; os dados NFS foram restaurados e `intruso` estava ausente ao final. O aluno confirmou o Firefox visível por X11/WSLg. Esses resultados são históricos; a inclusão do verificador na raiz foi validada por sintaxe e conferência dos caminhos, sem uma nova execução completa.
