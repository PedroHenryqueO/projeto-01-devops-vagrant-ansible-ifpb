# Projeto 01 — DevOps com Vagrant e Ansible

## 1. Identificação

IFPB — Campus João Pessoa · Tecnologia em Redes de Computadores
Administração de Sistemas Abertos · Professor Leonidas Lima · 2026.2
**Aluno:** Pedro Henryque de Oliveira · **Matrícula:** 20251380020

Projeto individual, com os usuários `pedro` e `henryque`. Entrega: **20/11/2026**. Apresentação: **23/11/2026**, no Ubuntu do professor.

## 2. Objetivo

Criar quatro máquinas Debian com Vagrant e configurar serviços Linux com Ansible. A execução principal é no Ubuntu nativo; Windows com WSL permanece como alternativa manual.

## 3. Infraestrutura

| VM | RAM | CPUs | IP privado | Serviços |
|---|---:|---:|---|---|
| arq | 512 MB | 1 | 192.168.56.120 | DHCP, DNS/DDNS, LVM e NFS |
| db | 512 MB | 1 | 192.168.56.121, reserva DHCP | MariaDB e autofs |
| app | 512 MB | 1 | 192.168.56.122, reserva DHCP | Apache, página acadêmica e autofs |
| cli | 2048 MB | 2 | DHCP, faixa .50–.100 | Firefox ESR, X11 e autofs |

Domínio: `pedro.henryque.devops`. NAT mantém o acesso à internet; a rede host-only usa `192.168.56.0/24`. Portas SSH locais: 2220, 2221, 2223 e 2224, nessa ordem.

arq recebe três discos de 10 GiB. O VG `dados` contém o LV `ifpb`, com 15 GiB, ext4 e montagem em `/dados`. `/dados/nfs` é exportado para a rede privada com `sync` e `all_squash`, usando `nfs-ifpb` (UID/GID 2048). Os clientes acessam `/var/nfs` por autofs.

## 4. Ferramentas utilizadas

Ambiente da implantação manual realizada no laboratório em 18/11/2026:

| Ferramenta | Versão |
|---|---|
| Ubuntu | 26.04.1 LTS |
| VirtualBox | 7.2.6 |
| Vagrant | 2.4.9 |
| Ansible Core | 2.20.1 |
| Python | 3.14.4 |
| ansible.posix / community.general | 2.1.0 / 12.1.0 |
| debian/bookworm64 | 12.20250126.1 |

Use um hospedeiro x86_64. Instale VirtualBox e Vagrant previamente, com `VBoxManage` e `vagrant` disponíveis no terminal. O instalador aceita as séries Vagrant 2.4, VirtualBox 7.2 e Ansible Core 2.20. O driver `/dev/vboxdrv` deve estar acessível ao usuário. Problemas de módulos do kernel ou Secure Boot precisam ser resolvidos antes da instalação do projeto.

Prepare o Ansible no Ubuntu:

```bash
sudo apt update
sudo apt install python3-venv openssh-client xauth dnsutils
python3 -m venv ~/.venvs/asa-proj1
source ~/.venvs/asa-proj1/bin/activate
python3 -m pip install ansible-core==2.20.1
```

São necessários acesso a sudo, internet e espaço para a box e os discos dinâmicos. O instalador exige pelo menos 20 GiB livres nas localizações verificadas e RAM suficiente para iniciar as VMs, com margem de 1 GiB. O laboratório tinha aproximadamente 12 GiB disponíveis e 68 GB livres. Deixe folga: os discos podem crescer durante o uso.

## 5. Serviços configurados

Todas as VMs recebem Chrony com `pool.ntp.br`, timezone `America/Recife`, grupo `ifpb`, usuários e chaves individuais, sudo e cliente NFS. SSH aceita somente chaves, bloqueia root e permite os grupos `vagrant` e `ifpb`.

arq fornece DHCP autoritativo, reservas de db/app e DNS direto/reverso. cli continua com IP dinâmico e usa DDNS autenticado por TSIG. Os encaminhadores são `1.1.1.1` e `8.8.8.8`. O DHCP atua apenas na interface privada.

**Por orientação do professor, `upgrade: dist` está comentado.** O Ansible continua atualizando os índices do APT para instalar os pacotes. As reaplicações não reiniciam automaticamente as máquinas.

## 6. Como executar o projeto

### Instalação no Ubuntu nativo

Com o ambiente virtual do Ansible ativo:

```bash
git clone https://github.com/PedroHenryqueO/projeto-01-devops-vagrant-ansible-ifpb.git
cd projeto-01-devops-vagrant-ansible-ifpb
bash scripts/instalar.sh --verificar
bash scripts/instalar.sh --aprovar
```

Execute como usuário normal. O script usa sudo somente para o DNS do hospedeiro. Ele recusa Windows/WSL, root, conflitos de rede/portas e VMs sem vínculo com os metadados deste clone.

O instalador:

1. Confere ferramentas, recursos, VMs e rede. Instala as collections no estado local e baixa a box fixada, se necessário.
2. Valida o Vagrantfile e os playbooks; prepara o adaptador e o cadastro DHCP do projeto quando ausentes. Não corrige silenciosamente cadastros existentes divergentes.
3. Cria arq, obtém sua chave pública pelo Vagrant e testa as chaves privadas disponíveis. Na box usada no laboratório, a RSA funcionou e a Ed25519 não autenticou.
4. Configura base, DHCP e DNS. Identifica os três discos e configura LVM/NFS usando as validações existentes.
5. Cria db, app e cli, nessa ordem, registra IPs/chaves públicas e executa `client-site.yml` nos três clientes em paralelo.
6. Configura o DNS específico do hospedeiro e verifica comunicação, DNS, HTTP, MariaDB e NFS. Cria os arquivos de demonstração somente se ausentes; os testes temporários não substituem esses arquivos.

O adaptador padrão é `vboxnet0` no Linux. Para usar outro adaptador, defina antes:

```bash
export ASA_PROJ1_HOSTONLY_NAME=vboxnet1
```

O adaptador deve estar livre para o projeto e usar `192.168.56.1/24`. O cadastro DHCP do VirtualBox usa `.2`, faixa `.3–.254`, e fica desativado. Se outra VM usar o adaptador, o script interrompe antes de alterá-lo.

As chaves, os registros de convidados e o estado do DNS ficam em `~/.local/share/asa-proj1`. Para separar outro ambiente, defina `ASA_PROJ1_STATE_DIR` antes de instalar. O estado é vinculado à pasta do clone; não copie `.vagrant`, chaves ou manifestos de outro computador.

Em outra sessão, reative o ambiente virtual e configure o Ansible:

```bash
source ~/.venvs/asa-proj1/bin/activate
export ASA_PROJ1_STATE_DIR="${ASA_PROJ1_STATE_DIR:-$HOME/.local/share/asa-proj1}"
export ANSIBLE_CONFIG="$PWD/ansible.cfg"
export ANSIBLE_COLLECTIONS_PATH="$ASA_PROJ1_STATE_DIR/collections"
```

### DNS do hospedeiro

O instalador aplica somente em `vboxnet0` (ou no adaptador escolhido):

```bash
sudo resolvectl default-route vboxnet0 no
sudo resolvectl domain vboxnet0 '~pedro.henryque.devops'
sudo resolvectl dns vboxnet0 192.168.56.120
```

Esses comandos mostram a configuração utilizada; normalmente não é necessário executá-los à parte. O instalador salva os valores anteriores. DNS/domínios preexistentes de terceiros interrompem a operação; os DNS gerais e `/etc/resolv.conf` não são alterados.

Para restaurar somente os valores salvos pelo projeto:

```bash
bash scripts/instalar.sh --restaurar-dns
```

A restauração é recusada se o adaptador ou seus valores tiverem mudado de forma inesperada. Não use uma restauração genérica para apagar configurações de terceiros.

### Iniciar e desligar VMs já instaladas

Na pasta do mesmo clone, confira `vagrant status`. Para iniciar sem provisionamento:

```bash
export ASA_PROJ1_EXECUTION_APPROVED=1
export ASA_PROJ1_DHCP_CHANGE_APPROVED=1
export ASA_PROJ1_CLIENT_BOOTSTRAP_READY=1
vagrant up arq --no-provision
vagrant ssh arq -c 'sudo sh -c '\''set -e; for s in named isc-dhcp-server chrony nfs-server; do systemctl is-active --quiet "$s"; done; findmnt --mountpoint /dados'\'''
vagrant up db app cli --no-provision
bash scripts/instalar.sh --configurar-dns
```

Se cli receber outro IP, consulte-o com `vagrant ssh cli -c 'ip -4 address'`. Atualize seu JSON de registro com a chave pública conferida pelo SSH do Vagrant e use `python3 scripts/registrar-cliente.py CAMINHO_JSON`. Não ignore erros de chave de host.

Desligue normalmente, uma máquina por vez, na ordem cli, app, db e arq:

```bash
vagrant ssh cli -c 'sudo shutdown -h now'
vagrant ssh app -c 'sudo shutdown -h now'
vagrant ssh db -c 'sudo shutdown -h now'
vagrant ssh arq -c 'sudo shutdown -h now'
bash scripts/instalar.sh --restaurar-dns
```

Espere cada máquina desligar antes da seguinte, conferindo `vagrant status`. A conexão SSH pode fechar durante o desligamento. Não use reset, destroy ou desligamento forçado para contornar uma falha.

### Demonstração

No navegador do hospedeiro: `http://app.pedro.henryque.devops`.

Firefox remoto, em uma sessão gráfica Ubuntu com `DISPLAY` definido e xauth instalado:

```bash
ssh -X -i "$ASA_PROJ1_STATE_DIR/keys/henryque" \
  -o "UserKnownHostsFile=$ASA_PROJ1_STATE_DIR/known_hosts" \
  henryque@cli.pedro.henryque.devops firefox-esr http://app.pedro.henryque.devops
```

O Firefox funcionou no Ubuntu com Wayland, `DISPLAY=:0` e 2 GB em cli. O encaminhamento X11 ainda pode ter latência.

### Recuperar uma instalação parcial

Corrija a causa indicada e repita `bash scripts/instalar.sh --aprovar`. O script reaproveita as VMs identificadas e os playbooks são idempotentes. Ele não destrói VMs, não sobrescreve um manifesto diferente e não substitui chaves de host divergentes.

- **Nome, MAC ou porta em uso:** não apague VMs de terceiros. Resolva o conflito antes de repetir.
- **Estado de outro clone:** volte à pasta original ou escolha outro diretório de estado; os nomes de VMs existentes ainda precisam estar livres.
- **Chave SSH:** o controlador testa as identidades do `vagrant ssh-config`; não habilita autenticação insegura nem algoritmos legados para forçar uma conexão.
- **Rede ou DHCP divergente:** confira `VBoxManage list hostonlyifs` e `VBoxManage list dhcpservers`. Ajustes em redes compartilhadas exigem revisão manual.
- **DNS:** confira `resolvectl status vboxnet0`. A configuração do professor não deve ser substituída para contornar erros.
- **Disco/manifesto inesperado:** pare e confira os UUIDs/seriais. Não remova a proteção nem use formatação forçada.
- **Pacotes, box ou NTP indisponíveis:** confira internet, repositórios e regras da rede da faculdade. A primeira instalação pode demorar por causa dos downloads.

### Alternativa Windows com WSL

Use o mesmo Vagrantfile; ele seleciona o nome padrão do adaptador Windows. O instalador Linux não deve ser executado no WSL.

No Windows, use `scripts\projeto.cmd up-arq --aprovar-vm --aprovar-dhcp`, obtenha o `IdentityFile` com `vagrant ssh-config arq` e a chave pública com `vagrant ssh arq -c "cat /etc/ssh/ssh_host_ed25519_key.pub"`.

No WSL, ative o Ansible, defina `ANSIBLE_CONFIG` e instale `ansible/requirements.yml`. Prepare o controlador com `preparar-controlador.py --vagrant-key CAMINHO_LINUX_DA_CHAVE --host-key 'ssh-ed25519 CHAVE_PUBLICA'` (converta caminhos com `wslpath`). Execute:

```bash
ansible-playbook ansible/site.yml --tags base,dhcp,dns
python3 scripts/manifesto-discos.py --vboxmanage '/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe'
ansible-playbook ansible/site.yml --tags storage,nfs
```

Crie db, app e cli pelo `projeto.cmd`, uma por vez. Obtenha IP e chave pública por `vagrant ssh NOME`. Salve um JSON local como `{"name":"db","ip":"192.168.56.121","hostkey":"ssh-ed25519 CHAVE_PUBLICA"}`, registre com `python3 scripts/registrar-cliente.py CAMINHO_JSON` e aplique `ansible-playbook ansible/client-site.yml` após registrar os três clientes.

O Windows usa NRPT para `.pedro.henryque.devops`, servidor `192.168.56.120`, comentário `ASA-Proj1`. Confira regras existentes antes de criar a regra específica com `Add-DnsClientNrptRule`; não troque os DNS gerais. Para removê-la, confira namespace, servidor e comentário e use `Remove-DnsClientNrptRule -Name IDENTIFICADOR` somente nessa regra.

## 7. Resultados e verificador oficial

**Implantação manual comprovada:** em 18/11/2026 o aluno implantou as quatro VMs a partir de um clone limpo no laboratório. Foram demonstrados DHCP/reservas, DDNS, DNS direto/reverso e do hospedeiro, SSH/sudo, Chrony, LVM, NFS/autofs, MariaDB, Apache/HTTP 200 e Firefox remoto. Desligar e iniciar novamente confirmou a persistência.

| VM | ok | changed | unreachable | failed |
|---|---:|---:|---:|---:|
| arq | 60 | 0 | 0 | 0 |
| db | 25 | 0 | 0 | 0 |
| app | 26 | 0 | 0 | 0 |
| cli | 24 | 0 | 0 | 0 |

Esses resultados foram informados pelo aluno e ocorreram **antes de comentar `upgrade: dist`**. Não foi necessário alterar os playbooks para compatibilidade com Linux nativo.

**Instalador automatizado:** ainda não foi validado integralmente com VMs reais. Verificações estáticas e simulações não comprovam uma implantação real nem a compatibilidade com toda máquina Ubuntu.

O verificador original retornou **0**, sem erros reportados na implantação manual. Obtenha-o com o professor/Classroom e coloque-o em `referencias/verifica-proj1.py` (crie a pasta se necessário). Ele não é distribuído por falta de autorização de redistribuição.

Com as variáveis do Ansible acima definidas e o display gráfico funcionando:

```bash
python3 scripts/verificador-oficial.py
```

O auxiliar exige ausência de conta/home `intruso` e chave temporária. Os arquivos `pedro.txt` e `henryque.txt` precisam existir no NFS; o instalador os prepara sem substituir conteúdo existente. O auxiliar mantém o original intacto, faz backup dos arquivos e realiza a limpeza posterior. Logs e estado local não devem ser publicados.

Retorno 0 não representa nota automática: o original oculta alguns erros e abre Firefox em segundo plano. Preserve a confirmação visual e os demais resultados demonstrados.
