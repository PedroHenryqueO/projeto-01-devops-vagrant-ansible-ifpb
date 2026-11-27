# -*- mode: ruby -*-
# Cria as quatro VMs e configura arq antes dos clientes.
require "open3"
require "json"
require "fileutils"
require "shellwords"
require "socket"
require "ipaddr"

# Confere o ambiente e prepara os arquivos locais do Ansible.
module Projeto
  ROOT = File.expand_path(__dir__)
  STATE = File.join(ROOT, ".vagrant", "asa")
  DOMAIN = "pedro.henryque.devops"

  def self.run(*args)
    out, status = Open3.capture2e(*args)
    raise "Comando falhou: #{args.first}: #{out}" unless status.success?
    out
  end

  def self.info(vbox, uuid)
    run(vbox, "showvminfo", uuid, "--machinereadable").lines.each_with_object({}) do |line, result|
      key, value = line.strip.split("=", 2)
      result[key.delete('"')] = value.delete_prefix('"').delete_suffix('"') if value
    end
  end

  def self.guard(vbox, adapter, specs)
    raise "Use Ubuntu nativo como controlador Ansible" unless RUBY_PLATFORM.include?("linux") && !File.read("/proc/sys/kernel/osrelease").downcase.include?("microsoft")
    raise "Execute como usuario normal" if Process.uid.zero?
    raise "Adaptador invalido" unless adapter.match?(/\Avboxnet\d+\z/)
    raise "Metadados nao podem ser links" if File.symlink?(File.join(ROOT, ".vagrant")) || File.symlink?(STATE)
    owned = {}
    specs.each do |name, spec|
      path = File.join(ROOT, ".vagrant", "machines", name, "virtualbox", "id")
      next unless File.file?(path)
      uuid = File.read(path).strip
      raise "UUID local invalido" unless uuid.match?(/\A[\da-f-]{36}\z/i)
      vm = info(vbox, uuid)
      unless vm["name"] == "ASA-Proj1-#{name}" && vm["macaddress2"]&.downcase == spec[:mac].downcase && vm["nic1"] == "nat" && vm["nic2"] == "hostonly" && vm["hostonlyadapter2"] == adapter
        raise "Identidade/rede divergente em #{name}; nao sera alterada"
      end
      raise "Estado nao suportado: #{name}" unless %w[running poweroff].include?(vm["VMState"])
      owned[uuid] = vm
    end
    run(vbox, "list", "vms").lines.each do |line|
      match = line.match(/^"(.+)"\s+\{([^}]+)\}/) or raise "Registro de VM desconhecido"
      name, uuid = match.captures
      next if owned.key?(uuid)
      vm = info(vbox, uuid)
      raise "Nome reservado sem vinculo com este clone: #{name}" if specs.keys.any? { |n| name == "ASA-Proj1-#{n}" }
      # Preserva redes usadas por outras VMs.
      raise "Rede #{adapter} pertence tambem a #{name}; escolha uma rede isolada" if vm.any? { |k, v| k.start_with?("hostonlyadapter") && v == adapter }
      raise "MAC reservado ja usado por #{name}" if vm.any? { |k, v| k.start_with?("macaddress") && specs.values.any? { |s| s[:mac].downcase == v.downcase } }
    end
    specs.each_value do |spec|
      next if owned.values.any? { |vm| vm["VMState"] == "running" && vm.values.any? { |v| v.include?(",127.0.0.1,#{spec[:port]},,22") } }
      TCPServer.open("127.0.0.1", spec[:port]).close
    end
    subnet = IPAddr.new("192.168.56.0/24")
    JSON.parse(run("ip", "-j", "route", "show")).each do |route|
      next if route["dev"] == adapter || route["dst"] == "default"
      net = IPAddr.new(route.fetch("dst"))
      raise "Rota de terceiros sobreposta a rede privada" if subnet.include?(net) || net.include?(subnet)
    end
    raise "Outro DHCP no hospedeiro" if run("ss", "-H", "-lun").lines.any? { |l| l.split[3]&.match?(/\A(?:0\.0\.0\.0|\*|\[::\]|192\.168\.56\.1):67\z/) }
    needed = specs.sum { |name, spec| owned.values.any? { |vm| vm["name"] == "ASA-Proj1-#{name}" && vm["VMState"] == "running" } ? 0 : spec[:ram] } + 1024
    available = File.read("/proc/meminfo")[/^MemAvailable:\s+(\d+)/, 1].to_i / 1024
    raise "RAM insuficiente: precisa de #{needed} MiB livres" if available < needed
    folders = [ROOT, Dir.home]
    default_folder = run(vbox, "list", "systemproperties")[/^Default machine folder:\s*(.+)$/, 1]
    if default_folder
      folder = File.expand_path(default_folder.strip)
      folder = File.dirname(folder) until File.directory?(folder)
      folders << folder
    end
    folders.uniq.each do |folder|
      raise "Menos de 20 GiB livres em #{folder}" if run("df", "-Pm", folder).lines.last.split[3].to_i < 20480
    end
    raise "Ansible ausente; veja os pre-requisitos no README" unless system("ansible-playbook", "--version", out: File::NULL)
  end

  def self.network(vbox, adapter)
    blocks = run(vbox, "list", "hostonlyifs").split(/\r?\n\s*\r?\n/)
    selected = blocks.find { |b| b.match?(/^Name:\s+#{Regexp.escape(adapter)}\s*$/) }
    raise "Outro adaptador usa 192.168.56.1" if blocks.any? { |b| b != selected && b.match?(/^IPAddress:\s+192\.168\.56\./) }
    unless selected
      run(vbox, "hostonlyif", "create")
      listing = run(vbox, "list", "hostonlyifs")
      raise "Adaptador criado com outro nome; confira antes de continuar" unless listing.match?(/^Name:\s+#{Regexp.escape(adapter)}\s*$/)
      run(vbox, "hostonlyif", "ipconfig", adapter, "--ip", "192.168.56.1", "--netmask", "255.255.255.0")
    end
    selected = run(vbox, "list", "hostonlyifs").split(/\r?\n\s*\r?\n/).find { |b| b.match?(/^Name:\s+#{Regexp.escape(adapter)}\s*$/) }
    raise "Adaptador existente divergente" unless selected && selected.match?(/^IPAddress:\s+192\.168\.56\.1\s*$/) && selected.match?(/^NetworkMask:\s+255\.255\.255\.0\s*$/)
    network = "HostInterfaceNetworking-#{adapter}"
    block = run(vbox, "list", "dhcpservers").split(/\r?\n\s*\r?\n/).find { |b| b.match?(/^NetworkName:\s+#{Regexp.escape(network)}\s*$/) }
    if block
      { "Dhcpd IP" => "192.168.56.100", "NetworkMask" => "255.255.255.0", "LowerIPAddress" => "192.168.56.101", "UpperIPAddress" => "192.168.56.254" }.each do |key, value|
        raise "DHCP existente divergente: #{key}" unless block.match?(/^#{Regexp.escape(key)}:\s+#{Regexp.escape(value)}\s*$/)
      end
    else
      run(vbox, "dhcpserver", "add", "--interface", adapter, "--server-ip", "192.168.56.100", "--netmask", "255.255.255.0", "--lower-ip", "192.168.56.101", "--upper-ip", "192.168.56.254", "--enable")
    end
  end

  def self.guest(machine, command)
    output = +""
    machine.communicate.execute(command, error_check: true) { |type, data| output << data if type == :stdout }
    output.strip
  end

  def self.register(machine, vbox)
    name = machine.name.to_s
    FileUtils.mkdir_p(File.join(STATE, "keys"), mode: 0700)
    %w[pedro henryque].each do |user|
      key = File.join(STATE, "keys", user)
      run("ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", key) unless File.exist?(key)
      raise "Par de chaves incompleto: #{user}" unless File.file?(key + ".pub")
    end
    ssh = machine.ssh_info
    hostkey = guest(machine, "cat /etc/ssh/ssh_host_ed25519_key.pub").split[0, 2].join(" ")
    raise "Chave de host invalida" unless hostkey.start_with?("ssh-ed25519 ")
    private_ip = guest(machine, "ip -4 -o address show | awk '$4 ~ /^192[.]168[.]56[.]/ {split($4,a,\"/\"); print a[1]}'")
    expected = {"arq" => "192.168.56.120", "db" => "192.168.56.121", "app" => "192.168.56.122"}
    raise "IP privado divergente: #{name}" unless expected.key?(name) ? private_ip == expected[name] : private_ip.match?(/\A192\.168\.56\.(?:[5-9]\d|100)\z/)
    record = {name: name, ip: private_ip, hostkey: hostkey, port: ssh[:port]}
    path = File.join(STATE, "#{name}.json")
    raise "Chave de host mudou: #{name}" if File.file?(path) && JSON.parse(File.read(path))["hostkey"] != hostkey
    File.write(path, JSON.pretty_generate(record), perm: 0600)
    records = %w[arq db app cli].map { |n| File.join(STATE, "#{n}.json") }.select { |p| File.file?(p) }.map { |p| JSON.parse(File.read(p)) }
    File.write(File.join(STATE, "known_hosts"), records.map { |r| "[127.0.0.1]:#{r['port']},#{r['ip']},#{r['name']}.#{DOMAIN} #{r['hostkey']}\n" }.join, perm: 0600)
    # Testa as chaves da box e guarda somente a que autentica.
    target = File.join(STATE, "keys", "vagrant-#{name}")
    candidate = target + ".candidate"
    accepted = Array(ssh[:private_key_path]).any? do |key|
      next false unless File.file?(key)
      FileUtils.cp(key, candidate)
      File.chmod(0600, candidate)
      output, status = Open3.capture2e("ssh", "-F", "none", "-i", candidate, "-p", ssh[:port].to_s,
        "-o", "BatchMode=yes", "-o", "IdentitiesOnly=yes", "-o", "StrictHostKeyChecking=yes",
        "-o", "UserKnownHostsFile=#{File.join(STATE, 'known_hosts')}", "-o", "ConnectTimeout=10",
        "vagrant@127.0.0.1", "hostname -f")
      status.success? && output.lines.map(&:strip).include?("#{name}.#{DOMAIN}")
    end
    unless accepted
      File.delete(candidate) if File.exist?(candidate)
      raise "Nenhuma chave Vagrant autenticou; nao alterar as restricoes SSH"
    end
    File.rename(candidate, target)
    inventory = records.map { |r| "#{r['name']} ansible_host=127.0.0.1 ansible_port=#{r['port']} ansible_user=vagrant ansible_ssh_private_key_file=#{File.join(STATE, 'keys', 'vagrant-'+r['name']).to_json}\n" }.join
    inventory += "\n[fileservers]\narq\n[clients]\n" + records.reject { |r| r["name"] == "arq" }.map { |r| r["name"] }.join("\n") + "\n[lab:children]\nfileservers\nclients\n"
    inventory += "\n[lab:vars]\nansible_ssh_common_args=-o UserKnownHostsFile=#{File.join(STATE, 'known_hosts').to_json} -o StrictHostKeyChecking=yes\n"
    File.write(File.join(STATE, "inventory.ini"), inventory, perm: 0600)
    return unless name == "arq"
    vm = info(vbox, machine.id)
    disks = vm.select { |k, _| k.match?(/\ASATA Controller-ImageUUID-[123]-0\z/) }.values.filter_map do |uuid|
      details = run(vbox, "showmediuminfo", "disk", uuid)
      next unless details.include?("ASA-Proj1-arq-dados-")
      raise "Disco adicional com tamanho inesperado" unless details.match?(/^Capacity:\s+10240 MBytes/)
      run(vbox, "list", "vms").scan(/\{([^}]+)\}/).flatten.each do |other|
        next if other == machine.id
        raise "Disco adicional compartilhado" if info(vbox, other).values.include?(uuid)
      end
      raise "Disco adicional nao pode ser diferencial" unless details.match?(/^Parent UUID:\s+base/)
      tail = uuid.delete("-")[-8, 8]
      {serial: "VB#{uuid[0, 8]}-#{tail.scan(/../).reverse.join}", media_uuid: uuid}
    end
    raise "Esperados tres discos adicionais distintos" unless disks.size == 3 && disks.uniq.size == 3
    manifest = File.join(STATE, "storage.json")
    data = {"storage_disks" => disks}
    raise "Manifesto de discos divergente" if File.file?(manifest) && JSON.parse(File.read(manifest)) != JSON.parse(data.to_json)
    File.write(manifest, JSON.pretty_generate(data), perm: 0600)
  end
end

Vagrant.configure("2") do |config|
  hostonly = ENV.fetch("ASA_PROJ1_HOSTONLY_NAME", "vboxnet0")
  vbox = ENV.fetch("VBOXMANAGE", %w[VBoxManage vboxmanage].find { |n| ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |p| File.executable?(File.join(p, n)) } } || "VBoxManage")
  machines = {
    "arq" => { ram: 512, port: 2220, mac: "022026000020" },
    "db"  => { ram: 512, port: 2221, mac: "022026000021" },
    "app" => { ram: 512, port: 2223, mac: "022026000022" },
    "cli" => { ram: 2048, cpus: 2, port: 2224, mac: "022026000023" }
  }
  config.vm.box = "debian/bookworm64"
  config.vm.box_version = "12.20250126.1"
  config.vm.box_check_update = false
  config.ssh.insert_key = false
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vbguest.auto_update = false if Vagrant.has_plugin?("vagrant-vbguest")

  config.trigger.before [:up, :reload, :resume, :provision] do |t|
    t.ruby do |_env, machine|
      Projeto.guard(vbox, hostonly, machines)
      if machine.name.to_s != "arq"
        arq = machine.env.machine(:arq, :virtualbox)
        raise "Inicie e provisione arq primeiro" unless arq.id && arq.communicate.ready?
        Projeto.guest(arq, "sudo sh -c 'set -e; for s in named isc-dhcp-server nfs-server; do systemctl is-active --quiet $s; done; mountpoint -q /dados'")
      end
      Projeto.network(vbox, hostonly)
    end
  end

  # Para o DHCP do VirtualBox para evitar conflito.
  config.trigger.before :"Vagrant::Action::Builtin::WaitForCommunicator", type: :action do |t|
    t.warn = "Interrompe o servidor DHCP do VirtualBox"
    t.run = { inline: "#{Shellwords.escape(vbox)} dhcpserver stop --interface #{Shellwords.escape(hostonly)}" }
  end

  machines.each do |name, spec|
    config.vm.define name do |vm|
      vm.vm.hostname = "#{name}.#{Projeto::DOMAIN}"
      vm.vm.network "forwarded_port", guest: 22, host: spec[:port], host_ip: "127.0.0.1", id: "ssh", auto_correct: false
      if name == "arq"
        vm.vm.network "private_network", name: hostonly, ip: "192.168.56.120", netmask: "255.255.255.0", mac: spec[:mac]
        3.times { |i| vm.vm.disk :disk, size: "10GB", name: "ASA-Proj1-arq-dados-#{i + 1}" }
        vm.vm.provision "shell", inline: "test \"$(hostname -f)\" = arq.pedro.henryque.devops && ip -4 address show | grep -q '192.168.56.120/24'"
      else
        vm.vm.network "private_network", name: hostonly, type: "dhcp", mac: spec[:mac], auto_config: false, dhcp_ip: "192.168.56.100", dhcp_lower: "192.168.56.101", dhcp_upper: "192.168.56.254", netmask: "255.255.255.0"
        vm.vm.provision "shell", path: "scripts/bootstrap-client.sh", args: [spec[:mac].scan(/../).join(":"), "#{name}.#{Projeto::DOMAIN}"]
      end
      vm.vm.provider "virtualbox" do |vb|
        vb.name = "ASA-Proj1-#{name}"
        vb.memory = spec[:ram]
        vb.cpus = spec.fetch(:cpus, 1)
        vb.linked_clone = true
        vb.check_guest_additions = false
      end
      # Registra as chaves e os endereços antes de executar o Ansible.
      vm.trigger.after :provisioner_run, type: :hook do |t|
        t.ruby { |_env, machine| Projeto.register(machine, vbox) }
      end
      vm.vm.provision "ansible" do |ansible|
        ansible.playbook = "ansible/site.yml"
        ansible.inventory_path = File.join(Projeto::STATE, "inventory.ini")
        ansible.limit = name
        ansible.config_file = "ansible.cfg"
        ansible.host_key_checking = true
        ansible.compatibility_mode = "2.0"
        ansible.galaxy_role_file = "ansible/requirements.yml"
        ansible.galaxy_command = "ansible-galaxy collection install -r %{role_file}"
      end
    end
  end
end
