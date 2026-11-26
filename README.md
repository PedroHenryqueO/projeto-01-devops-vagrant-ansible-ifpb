# Projeto 01 — Vagrant e Ansible

## 1. Identificação e objetivo

IFPB — Campus João Pessoa · Tecnologia em Redes de Computadores
Administração de Sistemas Abertos · Professor Leonidas Lima · 2026.2
**Aluno:** Pedro Henryque de Oliveira · **Matrícula:** 20251380020

Criar quatro máquinas Debian e configurar os serviços com Vagrant e Ansible. O controlador desta versão é **Ubuntu nativo**, com VirtualBox. Não execute o fluxo pelo Windows/WSL.

## 2. Infraestrutura e serviços

| VM | RAM / CPUs | Rede privada | Serviços |
|---|---|---|---|
| arq | 512 MB / 1 | 192.168.56.120 | DHCP, DNS/DDNS, Chrony, LVM e NFS |
| db | 512 MB / 1 | 192.168.56.121 por reserva DHCP | MariaDB e autofs |
| app | 512 MB / 1 | 192.168.56.122 por reserva DHCP | Apache, página acadêmica e autofs |
| cli | 2048 MB / 2 | DHCP dinâmico, .50–.100 | Firefox ESR, X11 e autofs |

Domínio: `pedro.henryque.devops`. A NAT fornece internet. A rede privada usa `192.168.56.0/24`, adaptador `vboxnet0` e MACs terminados em `20`, `21`, `22` e `23`. SSH pela NAT: portas locais 2220, 2221, 2223 e 2224.

arq tem três discos de 10 GiB, VG `dados`, LV `ifpb` de 15 GiB, ext4 e montagem persistente em `/dados`. `/dados/nfs` é exportado com `sync` e `all_squash` para `nfs-ifpb` (UID/GID 2048). Os clientes usam autofs em `/var/nfs`.

Todas as VMs recebem Chrony com `pool.ntp.br`, timezone `America/Recife`, grupo `ifpb`, usuários `pedro` e `henryque`, chaves individuais, sudo e cliente NFS. SSH aceita chaves, bloqueia root e permite apenas os grupos `vagrant` e `ifpb`.

DHCP tem reservas para db/app e faixa dinâmica para cli. DNS tem zonas direta/reversa, encaminhadores `1.1.1.1` e `8.8.8.8` e DDNS autenticado por TSIG para cli. O DHCP atua somente na interface privada.

**Exceções autorizadas:** cli usa 2048 MB e 2 CPUs. `upgrade: dist` permanece comentado por orientação do professor; os índices APT continuam sendo atualizados.

## 3. Pré-requisitos

Ubuntu x86_64 com virtualização disponível, VirtualBox 7.2, Vagrant 2.4, Ansible Core 2.20, Python 3.12 ou posterior e OpenSSH. O driver `/dev/vboxdrv` precisa funcionar. Reserve pelo menos 20 GiB livres para box/discos e aproximadamente 4,5 GiB de RAM disponível para convidados e margem do hospedeiro; mantenha folga para o Firefox.

Instale VirtualBox e Vagrant pelos procedimentos oficiais. Prepare o controlador:

```bash
sudo apt update
sudo apt install git python3-venv openssh-client xauth dnsutils curl
python3 -m venv ~/.venvs/asa-proj1
source ~/.venvs/asa-proj1/bin/activate
python3 -m pip install ansible-core==2.20.1
```

O Vagrant instala as collections de `ansible/requirements.yml` durante o provisionamento. Não precisa instalar Ruby separadamente: ele acompanha o Vagrant.

Use uma rede isolada. O projeto recusa adaptadores cadastrados em VMs de terceiros, inclusive desligadas, pois o gatilho interrompe o DHCP dessa rede. Não desligue nem altere VMs de outras pessoas para contornar a proteção. Se houver conflito, combine uma rede livre com o professor; o nome pode ser escolhido com `ASA_PROJ1_HOSTONLY_NAME=vboxnet1`, mantendo a sub-rede exigida livre.

## 4. Criar e provisionar

Com o ambiente virtual ativo:

```bash
git clone https://github.com/PedroHenryqueO/projeto-01-devops-vagrant-ansible-ifpb.git
cd projeto-01-devops-vagrant-ansible-ifpb
vagrant up
```

A branch principal (`main`) contém esta versão simplificada. A versão anterior está preservada na branch `backup/main-antes-simplificacao-5883892`.

O VirtualBox executa as máquinas em sequência: arq é criada e provisionada antes de db, app e cli. Antes de cada cliente, o Vagrant confirma que DNS, DHCP, NFS e `/dados` estão disponíveis em arq. Não use `--parallel` nem `--no-provision` na instalação inicial.

O único gatilho DHCP segue a Prática 05, antes de `Vagrant::Action::Builtin::WaitForCommunicator`, com `dhcpserver stop --interface vboxnet0`. O executável pode ser `VBoxManage` ou `vboxmanage`, conforme o sistema. O comando **para o processo**, mantendo o cadastro: não usa `modify --disable`. O cadastro padrão usa servidor `192.168.56.100` e faixa `.101–.254`; o gatilho para esse processo antes do SSH, deixando as concessões para arq. O cadastro necessário é criado apenas em rede livre; configurações existentes divergentes interrompem a instalação.

As chaves e os metadados ficam em `.vagrant/asa`, ignorada pelo Git. O Vagrant obtém a chave pública pelo seu comunicador, testa os IdentityFiles disponíveis e entrega ao Ansible um inventário pela NAT. Assim, mudanças no IP dinâmico de cli não quebram o provisionamento. Não copie `.vagrant` de outro ambiente nem remova a checagem de identidades ou discos.

Se houver falha, corrija a causa indicada e consulte `vagrant status`. Use `vagrant provision arq` para concluir arq antes de repetir `vagrant up`; para uma VM criada mas não provisionada, use `vagrant provision NOME`. Repetir apenas `up` pode não reaplicar playbooks de uma VM já marcada como provisionada. Não use destroy, reset ou formatação forçada como recuperação.

## 5. DNS do Ubuntu e desligamento

A configuração global do hospedeiro não é alterada automaticamente. Antes de demonstrar nomes ou executar o verificador, confira `resolvectl status vboxnet0` e registre os valores anteriores de DNS, Domains e DefaultRoute. Com autorização para usar essa interface isolada, configure somente o domínio do projeto:

```bash
sudo resolvectl default-route vboxnet0 no
sudo resolvectl domain vboxnet0 '~pedro.henryque.devops'
sudo resolvectl dns vboxnet0 192.168.56.120
getent hosts arq.pedro.henryque.devops db.pedro.henryque.devops app.pedro.henryque.devops cli.pedro.henryque.devops
```

Não substitua DNS/domínios de terceiros. Esses comandos exigem systemd-resolved e devem usar o adaptador escolhido. A internet continua usando o DNS geral e a rota padrão do hospedeiro.

Para desligar normalmente, sem fallback forçado:

```bash
vagrant ssh cli -c 'sudo shutdown -h now'
vagrant ssh app -c 'sudo shutdown -h now'
vagrant ssh db -c 'sudo shutdown -h now'
vagrant ssh arq -c 'sudo shutdown -h now'
vagrant status
```

Espere cada VM desligar antes de seguir. Restaure **somente** os valores de DNS registrados antes da apresentação, usando `resolvectl dns`, `domain` e `default-route` na mesma interface. Um valor originalmente vazio pode ser reposto com `''`; não use `revert` indiscriminadamente.

Após todas as VMs do projeto estarem desligadas, reative o DHCP do VirtualBox **somente se ele estava habilitado antes**, na interface conferida:

```bash
VBoxManage dhcpserver start --interface vboxnet0
```

`start` inicia o servidor; `restart` exige que ele já esteja rodando. Não use `--enable` para alterar um cadastro originalmente desabilitado. Para iniciar novamente o projeto, use `vagrant up`: o gatilho para o DHCP concorrente a cada inicialização.

## 6. Verificar e demonstrar

Na pasta do projeto, com o ambiente virtual ativo:

```bash
ansible lab -m ping
ansible-playbook ansible/site.yml --syntax-check
vagrant provision
```

`vagrant provision` reaplica os playbooks. Para verificar idempotência, avalie o resumo de cada VM: tarefas estáveis devem apresentar `changed=0`, sem falhas. Esse resultado foi confirmado nas quatro VMs desta versão.

Confira os serviços e o compartilhamento:

```bash
vagrant ssh arq -c 'sudo pvs; sudo vgs; sudo lvs; findmnt /dados; sudo exportfs -v'
vagrant ssh db -c 'sudo mariadb -Nse "SELECT 1"; cat /var/nfs/pedro.txt'
vagrant ssh app -c 'systemctl is-active apache2; ls -l /var/nfs'
vagrant ssh cli -c 'cat /var/nfs/henryque.txt; dpkg-query -W firefox-esr xauth'
curl http://app.pedro.henryque.devops
```

Abra a página no navegador do Ubuntu. Para o Firefox remoto, use uma sessão gráfica com `DISPLAY` definido:

```bash
ssh -X -i .vagrant/asa/keys/henryque \
  -o "UserKnownHostsFile=$PWD/.vagrant/asa/known_hosts" \
  henryque@cli.pedro.henryque.devops firefox-esr http://app.pedro.henryque.devops
```

Crie a pasta `referencias`, obtenha o verificador original com o professor e salve em `referencias/verifica-proj1.py`; ele não é distribuído no GitHub:

```bash
mkdir -p referencias
```

Depois de salvar o original, execute:

```bash
python3 scripts/verificador-oficial.py
```

O auxiliar executa o original com `pedro.henryque`, usando DNS normal. Antes, exige ausência de `intruso` e faz backup de `pedro.txt` e `henryque.txt`; depois limpa o usuário temporário e restaura os arquivos NFS. Chaves, backup e logs não são publicados. Não execute diretamente o original sobre dados importantes sem essa proteção.

## 7. Entender os arquivos

| Arquivo | O que explicar |
|---|---|
| `Vagrantfile` | Recursos, NAT/rede privada, ordem, gatilho DHCP e provisionamento; funções de proteção conferem VMs, chaves e discos. |
| `ansible.cfg` e `ansible/inventory.ini` | Configuração e referência dos hosts; o inventário NAT de execução é gerado em `.vagrant/asa/inventory.ini`. |
| `ansible/site.yml` | Importa os quatro playbooks na ordem; o Vagrant limita cada execução à VM atual. |
| `ansible/base.yml` | APT, Chrony, timezone, usuários, chaves, sudo e SSH. |
| `ansible/dhcp-dns.yml` | Interface privada, DHCP, TSIG, zonas e validações de sintaxe. |
| `ansible/lvm-nfs.yml` | Valida discos, cria PV/VG/LV sem forçar, monta ext4 e exporta NFS. |
| `ansible/clientes.yml` | autofs, MariaDB, Apache, Firefox e arquivos de demonstração. |
| `ansible/group_vars/all.yml` | Domínio, usuários, IPs, MACs e parâmetros compartilhados. |
| `ansible/templates/` e `ansible/files/` | Configurações dos serviços, página HTML e validador dos discos. |
| `scripts/bootstrap-client.sh` | Ativa DHCP privado pelo MAC, preservando a rota padrão NAT. |
| `scripts/verificador-oficial.py`, `pre-verificador.yml` e `pos-verificador.yml` | Protegem os dados e executam o verificador sem modificá-lo. |

`hosts` escolhe os alvos; `become` usa sudo; `tasks` lista as tarefas; `loop` repete uma tarefa; `when` escolhe a VM; `notify` chama um handler somente quando há mudança. `template` preenche variáveis; `copy` instala arquivos; `apt` instala pacotes; `service` habilita/inicia serviços. Não há dependência de roles.

## 8. Resultados e limites desta versão

A implantação **manual anterior** foi validada pelo aluno no laboratório em 18/11/2026: serviços, verificador, idempotência e persistência após reinicialização. Isso ocorreu antes de comentar `upgrade: dist`. Esses resultados não comprovam o novo fluxo de `vagrant up`.

Em 26/11/2026, esta branch foi testada com VirtualBox aninhado em Ubuntu Server 24.04.5, dentro do Hyper-V, com 6 GiB e 4 CPUs. `vagrant up` criou as quatro VMs com os recursos da tabela. A instalação exigiu um ajuste na criação dos arquivos de demonstração NFS em app; após `vagrant provision app`, outro `vagrant up` concluiu cli. Portanto, foi uma implantação real com correção e retomada, não uma execução limpa do início ao fim da versão final corrigida.

Passaram os testes de DHCP (reservas de db/app e cli em `192.168.56.50`), DDNS, DNS direto/reverso pelo resolvedor normal, LVM/ext4, NFS/autofs, escrita e leitura pelos usuários com mapeamento UID/GID 2048, Chrony, SSH/sudo, MariaDB e HTTP. A internet continuou pela NAT. `ansible lab -m ping` respondeu nas quatro VMs; `vagrant provision` terminou com `changed=0`, `unreachable=0` e `failed=0` em todas.

O verificador original, sem alterações, terminou com código 0 e sem mensagens de falha. Depois, foi confirmada a ausência de `intruso` e a preservação dos arquivos NFS por comparação com os backups. O código de saída do script não representa uma nota. O aluno confirmou visualmente que o Firefox remoto abriu por X11/WSLg e carregou a página do Apache. Após simplificar o HTML, foram confirmados HTTP 200 e o conteúdo servido idêntico ao arquivo de origem.

Também passaram `vagrant validate`, a sintaxe dos sete playbooks, a renderização dos seis templates e 17 simulações isoladas. As VMs não foram reiniciadas neste teste; a persistência após reinicialização desta refatoração ainda não foi comprovada. O teste com WSLg deixou pouca RAM livre no Windows: prefira um Ubuntu físico com memória disponível para a apresentação.

Para testar no Ubuntu do Hyper-V, confira primeiro memória/disco, SSH, `/dev/kvm`, flags `vmx`/`svm`, `/dev/vboxdrv` e suporte à virtualização aninhada. A presença das flags, sozinha, não prova que o VirtualBox executa convidados. A exposição dessas extensões e a criação de convidados de teste dependem de autorização. Se o Hyper-V não permitir o teste, use um Ubuntu físico isolado.
