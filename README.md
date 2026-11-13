# Projeto 01 — DevOps com Vagrant e Ansible

**IFPB — Campus João Pessoa · Tecnologia em Redes de Computadores**
Administração de Sistemas Abertos · Professor Leonidas Lima · 2026.2
Pedro Henryque de Oliveira · Matrícula **20251380020** · Projeto individual.

Infraestrutura como código com quatro Debian 12 Bookworm, VirtualBox, Vagrant
e Ansible pelo Ubuntu WSL2. Usuários pedro e henryque representam o mesmo aluno.

| VM | RAM | CPUs | Rede privada | Serviços |
|---|---:|---:|---|---|
| arq | 512 MB | 1 | 192.168.56.120 estático | DHCP, BIND/DDNS, LVM e NFS |
| db | 512 MB | 1 | .121, reserva MAC 02:20:26:00:00:21 | MariaDB, autofs |
| app | 512 MB | 1 | .122, reserva MAC 02:20:26:00:00:22 | Apache/página acadêmica, autofs |
| cli | 1024 MB | 2 | .50–.100 dinâmico, MAC 02:20:26:00:00:23 | Firefox ESR, xauth/X11, autofs |

Domínio: `pedro.henryque.devops`. NIC1 NAT mantém internet e administração;
NIC2 host-only mantém a rede acadêmica. Portas SSH Windows: 2220/2221/2223/2224,
vinculadas apenas a 127.0.0.1. arq tem três discos extras de 10 GiB, VG dados,
LV ifpb de 15 GiB, ext4 em /dados. NFS /dados/nfs usa sync e all_squash para
nfs-ifpb 2048:2048, sem shell. Autofs monta /var/nfs por demanda.

## Pré-requisitos

Windows com virtualização, VirtualBox e Vagrant; Ubuntu WSL2 com Python, OpenSSH,
Ansible Core 2.20 e WSLg/xauth para demonstração gráfica. Testado neste ambiente
com VirtualBox 7.2.20, Vagrant 2.4.9 e Python controlador 3.14. Chaves públicas
e segredos não precisam existir no clone; serão gerados/preparados localmente.
As versões das collections estão em ansible/requirements.yml.

## Instalação e rede

Clone o repositório e abra PowerShell nessa pasta; no WSL, acesse a mesma pasta.
Instale dependências do controlador conforme sua distribuição e execute:

```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

No Ubuntu, os pacotes do controlador incluem `python3`, `python3-venv`,
`openssh-client`, `dnsutils`, `xauth` e Ansible Core 2.20. Se o pacote Ansible
da distribuição for diferente, instalar a versão compatível em virtualenv
(`python3 -m venv ~/.venvs/asa-proj1`, ativar e instalar `ansible-core==2.20.1`).

Antes de qualquer VM, examine `VBoxManage list hostonlyifs`, `list dhcpservers`
e `list vms`. A rede deve estar em 192.168.56.1/24, sem conflitos. A proposta
exige um cadastro DHCP VirtualBox em .2, faixa .3–.254, que o gatilho desabilita
sem remover. **Não alterar adaptadores compartilhados sem avaliar impacto.**
Em ambiente novo, criar/configurar esse adaptador e cadastro exige autorização
do administrador; a automação interrompe se houver divergência, não corrige
recursos globais silenciosamente. ASA_PROJ1_HOSTONLY_NAME parametriza seu nome.

Somente num computador novo e após aprovar uma rede sem conflitos, os comandos
abaixo preparam o adaptador. Substituir ADAPTADOR pelo nome retornado; se já
existir rede/DHCP compartilhado, inspecionar e obter aprovação específica.

```powershell
VBoxManage hostonlyif create
VBoxManage hostonlyif ipconfig "ADAPTADOR" --ip 192.168.56.1 --netmask 255.255.255.0
VBoxManage dhcpserver add --network="HostInterfaceNetworking-ADAPTADOR" --server-ip=192.168.56.2 --netmask=255.255.255.0 --lower-ip=192.168.56.3 --upper-ip=192.168.56.254 --disable
$env:ASA_PROJ1_HOSTONLY_NAME = "ADAPTADOR"
```

Vagrantfile é a fonte definitiva. O estado padrão .vagrant é local/ignorado.
Nunca reutilizar metadados de outro computador.

## Ordem de criação e configuração

1. Windows: `scripts\projeto.cmd up-arq --aprovar-vm --aprovar-dhcp`.
   O gatilho afeta somente o DHCP host-only aprovado; a chave da box é mantida.
2. `vagrant ssh-config arq`: obter o caminho IdentityFile da chave fornecida pelo
   Vagrant. `vagrant ssh arq -c 'cat /etc/ssh/ssh_host_ed25519_key.pub'`: obter a
   chave **pública** do host pelo canal administrativo confiável.
3. No WSL, converter o caminho da chave Windows com wslpath quando necessário:

```bash
python3 scripts/preparar-controlador.py --vagrant-key CAMINHO_DA_CHAVE --host-key 'ssh-ed25519 CHAVE_PUBLICA'
bash scripts/ansible.sh ping
bash scripts/ansible.sh syntax
# Primeiro base/DHCP/DNS, sem operar discos:
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook ansible/site.yml --tags base,dhcp,dns
# Descoberta por UUID VirtualBox e serial, sem escrita nos discos:
python3 scripts/manifesto-discos.py
# Só depois de autorizar os três discos novos e o LV:
bash scripts/ansible.sh storage
bash scripts/ansible.sh verify-storage
```

O manifesto ansible/host_vars/arq.yml é gerado por instância e ignorado no Git.
O validador rejeita ancestrais do disco do SO, tamanhos/seriais diferentes,
partições/assinaturas desconhecidas e LVM externo. Não usar force para contornar
um bloqueio. Reaplicações aceitam os PVs/LV esperados sem reformatação.

4. Com DHCP/DNS/NFS de arq prontos, criar **uma por vez**:
   `scripts\projeto.cmd up-db --aprovar-vm --aprovar-dhcp`, depois up-app e up-cli.
   O bootstrap só configura DHCP privado e preserva o default NAT.
5. Para cada cliente, obter IP e chave pública pelo `vagrant ssh NOME`; registrar
   em JSON local `{"name":"db","ip":"192.168.56.121","hostkey":"ssh-ed25519 ..."}`.
   No WSL, `python3 scripts/registrar-cliente.py CAMINHO_JSON` registra inventário
   e known_hosts; depois `bash scripts/configurar-cliente.sh db` e
   `bash scripts/verificar-cliente.sh db`. Repetir para app e cli.
   cli permanece DHCP dinâmico: atualizar inventário se sua concessão mudar.

As chaves individuais são geradas em ~/.local/share/asa-proj1/keys, modo 600,
fora do repositório; ASA_PROJ1_STATE_DIR permite outro diretório protegido.
A chave da box é criada/disponibilizada pelo próprio Vagrant, não depende de
uma chave pessoal do autor. TSIG é gerada no convidado, nunca versionada.

## DNS e Firefox

Clientes recebem DNS .120 por DHCP; cli tem A/PTR atualizados por TSIG.
Consultas explícitas: `dig @192.168.56.120 cli.pedro.henryque.devops`.
Para resolução **normal** no Windows/WSL, este ambiente usa somente a regra NRPT
`.pedro.henryque.devops` → `192.168.56.120`, comentário `ASA-Proj1`. Ela foi
criada com autorização em 12/11/2026; os DNS gerais e as demais regras foram
comparados antes/depois e permaneceram inalterados. Os quatro nomes resolveram
normalmente no Windows e no WSL, e o acesso externo HTTPS retornou 200 em ambos.
Em outro computador, WSL com DNS tunneling pode herdar a política; testar antes
de assumir. Não modificar resolv.conf, servidores DNS gerais ou adaptadores
como tentativa automática de correção.

Criação idempotente, em PowerShell **como administrador**, após autorização:

```powershell
$rules = @(Get-DnsClientNrptRule | Where-Object {
    @($_.Namespace) -contains '.pedro.henryque.devops'
})
if ($rules.Count -eq 0) {
    Add-DnsClientNrptRule -Namespace '.pedro.henryque.devops' -NameServers '192.168.56.120' -Comment 'ASA-Proj1'
} elseif ($rules.Count -ne 1 -or @($rules[0].Namespace).Count -ne 1 -or
          $rules[0].Comment -ne 'ASA-Proj1' -or
          (@($rules[0].NameServers) -join ',') -ne '192.168.56.120') {
    throw 'Regra existente divergente; interromper sem substituir.'
}
'arq','db','app','cli' | ForEach-Object {
    Resolve-DnsName "${_}.pedro.henryque.devops" -Type A
}
Resolve-DnsName deb.debian.org -Type A
```

Remoção **somente dessa regra**, também como administrador e após autorização.
O filtro confere domínio, destino e comentário; divergência interrompe a operação:

```powershell
$rules = @(Get-DnsClientNrptRule | Where-Object {
    @($_.Namespace) -contains '.pedro.henryque.devops'
})
if ($rules.Count -ne 1 -or @($rules[0].Namespace).Count -ne 1 -or
    $rules[0].Comment -ne 'ASA-Proj1' -or
    (@($rules[0].NameServers) -join ',') -ne '192.168.56.120') {
    throw 'Nao foi encontrada uma unica regra correspondente; nada removido.'
}
Remove-DnsClientNrptRule -Name $rules[0].Name -Force
```

Após removê-la, os nomes privados deixam de resolver normalmente no hospedeiro;
os DNS gerais permanecem como estavam. Consultas explícitas a .120 ainda podem
ser usadas. No WSL, validar com `getent ahostsv4 arq.pedro.henryque.devops` e
repetir para db/app/cli, além de `curl -I https://deb.debian.org/debian/`.

Teste manual no WSL (substituir IP se a concessão mudar):

```bash
ssh -X -i "$HOME/.local/share/asa-proj1/keys/henryque" \
  -o "UserKnownHostsFile=$HOME/.local/share/asa-proj1/known_hosts" \
  henryque@192.168.56.50 firefox-esr http://app.pedro.henryque.devops
```

Não exige instalação de servidor X no Windows: o ambiente testado usa WSLg.
Se DISPLAY estiver vazio, abrir sessão WSLg funcional. Não desabilitar controles
de segurança para resolver erros gráficos. A página foi confirmada visualmente pelo aluno em 12/11/2026; em outra
instalação, repetir o teste manual, além da verificação dos pacotes.

cli usa 2 CPUs após ajuste autorizado em 12/11/2026; mantém os 1024 MB do
enunciado, que não especifica quantidade de CPUs. O aluno confirmou visualmente
melhora significativa após o ajuste. O encaminhamento X11 ainda pode ter latência.
As demais VMs mantêm seus recursos. Para apresentar, fechar manualmente programas
desnecessários no hospedeiro, demonstrar Firefox remoto pelo comando acima e
depois usar o navegador do Windows em `http://app.pedro.henryque.devops` para
exibir a página com maior fluidez. Não requer alteração do DNS ou dos serviços.

## Testes e verificador

```bash
bash scripts/ansible.sh verify
bash scripts/ansible.sh verify-storage
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook ansible/verify-integration.yml
# Reaplicação: esperar changed=0 depois de completar configuração.
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook ansible/client-site.yml
```

Inspecionar pvs/vgs/lvs, findmnt /dados, exportfs -v, chronyc sources,
systemctl status, HTTP e logs. Os testes NFS temporários limpam os próprios
arquivos; a integração deixa pedro.txt/henryque.txt para demonstração.

Obter o script original do professor conforme referencias/README.md. Ele cria/
remove intruso e sobrescreve arquivos NFS; executar apenas com autorização,
conta/home intruso ausentes e dados preexistentes preservados. Com DNS normal,
chaves e DISPLAY prontos: `python3 scripts/verificador-oficial.py` no WSL.
O runner executa o original intacto em diretório com keys, captura sua saída e
prepara SSH não interativo. O código de saída não representa nota: o original
oculta erros e tem limitações de quoting e de testes sem chave; usar os testes
independentes para distinguir defeito real de limitação do avaliador.

O runner restaura os arquivos NFS preservados e remove a conta temporária ao
terminar. Teste complementar
real da restrição de grupos (exige a chave intruso gerada pelo original):

```bash
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook ansible/testar-intruso.yml
```

## Reinício e desligamento

Só com autorização: `bash scripts/validar-reboots.sh` reinicia normalmente arq,
valida-a e depois db/app/cli uma por vez. Não faz reset forçado. Para desligar,
usar `vagrant halt cli`, `app`, `db`, e arq por último; iniciar arq antes dos
clientes. Nunca usar destroy para resolver uma indisponibilidade sem aprovação.

## Estado, limites e entrega

Resultados detalhados: [matriz de requisitos](docs/MATRIZ-REQUISITOS.md).
No ambiente original, os quatro convidados passaram pelos testes de SSH/sudo,
Chrony, DHCP/DNS/DDNS, armazenamento e serviços após reinícios normais. A última
reaplicação Ansible terminou com changed=0, failed=0 e unreachable=0 nas quatro
VMs. O verificador original retornou 0, complementado pelos testes independentes
documentados acima. Código 0 não equivale a uma nota automática.

Última execução do original: **12/11/2026**, com DNS normal do WSL e cli com
2 CPUs/1024 MB, usando o argumento `pedro.henryque`. O arquivo original manteve
seu hash; retorno **0**, sem mensagens de falha reportadas e STDERR vazio.
Os pré-requisitos incluíram chaves com modo 600, DNS dos quatro hosts, SSH/X11
funcional e ausência prévia de conta/home intruso. Os arquivos NFS pedro.txt e
henryque.txt foram preservados antes da execução e restaurados depois, com
SHA-256, tamanho, UID/GID e modo idênticos. Conta intruso, home e chave temporária
ficaram ausentes nas quatro VMs. Não houve reinício ou alteração de hardware.
A saída integral e os manifestos de conferência permanecem locais e ignorados
pelo Git. As limitações de quoting, erros ocultos e Firefox assíncrono do
verificador impedem tratar apenas seu retorno como prova de todos os requisitos.

Collections atuais emitem avisos de depreciação não bloqueantes. Para indisponibilidade,
verificar memória, journal do convidado e logs do VirtualBox antes de atribuir a
causa a recursos ou fazer qualquer reinício forçado.

**Uma reprodução integral a partir de clone limpo não foi executada.** Os comandos
e descoberta de identidades foram preparados/validados sem destruir as VMs atuais.
Ainda é necessário validar esse fluxo num outro ambiente autorizado.
Originais do professor, logs brutos, metadados, discos, chaves e manifesto local
estão excluídos do Git. Publicação remota exige autorização final do aluno.

O repositório contém a implementação, os auxiliares de implantação/verificação
e a documentação de entrega. PROGRESSO.md, planos intermediários, relatórios
operacionais e evidências brutas são registros locais, não distribuídos. As
menções a PROGRESSO.md na página do ambiente original referem-se a esses registros;
a síntese pública está nesta seção e na matriz. Nenhum registro local é necessário
para executar os playbooks ou reproduzir a configuração.

Para a entrega, revisar `git diff --cached --stat`, `git diff --cached` e
`git status`. Após aprovar o conteúdo, o destino e a visibilidade, criar o
commit, configurar o remote aprovado e publicar a branch principal. Os materiais
do professor devem ser obtidos separadamente: não há licença de redistribuição
comprovada. Não incluir evidências brutas ou arquivos ignorados usando `git add -f`.
