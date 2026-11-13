# -*- mode: ruby -*-
# Infraestrutura definitiva preparada. Operar via scripts/projeto.cmd.
# A configuracao anterior do teste foi preservada localmente em Vagrantfile.teste-debian.
# Servicos configurados por Ansible.
require "open3"

Vagrant.configure("2") do |config|
  domain = "pedro.henryque.devops"
  hostonly = ENV.fetch("ASA_PROJ1_HOSTONLY_NAME", "VirtualBox Host-Only Ethernet Adapter")
  network = "HostInterfaceNetworking-#{hostonly}"
  vboxmanage = ENV.fetch("VBOXMANAGE", "VBoxManage")


  # NAT fica no adaptador 1. Os MACs abaixo identificam a interface privada.
  machines = {
    "arq" => { ram: 512,  port: 2220, mac: "022026000020", ip: "192.168.56.120" },
    "db"  => { ram: 512,  port: 2221, mac: "022026000021" },
    "app" => { ram: 512,  port: 2223, mac: "022026000022" },
    "cli" => { ram: 1024, cpus: 2, port: 2224, mac: "022026000023" }
  }

  # Os subprocessos só são chamados pelos gatilhos, nunca ao carregar/validar.
  query = lambda do |*args|
    output, status = Open3.capture2e(vboxmanage, *args)
    raise "VBoxManage falhou (#{args.first}): #{output}" unless status.success?
    output
  end

  dhcp_block = lambda do
    blocks = query.call("list", "dhcpservers").split(/\r?\n\s*\r?\n/)
    block = blocks.find { |entry| entry.match?(/^NetworkName:\s+#{Regexp.escape(network)}\s*$/) }
    raise "DHCP esperado ausente; interrompido para evitar criacao automatica pelo Vagrant." unless block
    {
      "Dhcpd IP" => "192.168.56.2", "LowerIPAddress" => "192.168.56.3",
      "UpperIPAddress" => "192.168.56.254", "NetworkMask" => "255.255.255.0"
    }.each do |field, value|
      unless block.match?(/^#{Regexp.escape(field)}:\s+#{Regexp.escape(value)}\s*$/)
        raise "DHCP divergiu do diagnostico (#{field}); nenhuma alteracao automatica permitida."
      end
    end
    block
  end

  config.vm.box = "debian/bookworm64"
  # Versao efetivamente instalada; pode ser parametrizada para uma revisao aprovada.
  config.vm.box_version = ENV.fetch("ASA_PROJ1_BOX_VERSION", "12.20250126.1")
  config.vm.box_check_update = false
  config.ssh.insert_key = false
  config.vm.synced_folder ".", "/vagrant", disabled: true
  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = false
  end

  machines.each do |name, spec|
    # Um 'up' sem nome seleciona apenas arq. Os dependentes exigem nome explicito.
    config.vm.define name, autostart: name == "arq" do |vm|
      vm.vm.hostname = "#{name}.#{domain}"
      vm.vm.network "forwarded_port", guest: 22, host: spec[:port],
                    host_ip: "127.0.0.1", id: "ssh", auto_correct: false

      if name == "arq"
        vm.vm.network "private_network", name: hostonly, ip: spec[:ip],
                      netmask: "255.255.255.0", mac: spec[:mac]
        3.times do |index|
          vm.vm.disk :disk, size: "10GB", name: "ASA-Proj1-arq-dados-#{index + 1}"
        end
      else
        # O convidado sera configurado por Ansible, via NAT, para usar DHCP.
        # Nao ha IP estatico de cli. A configuracao antecipada pelo Vagrant
        # criaria uma dependencia de DHCP antes do bootstrap administrativo.
        vm.vm.network "private_network", name: hostonly, type: "dhcp",
                      mac: spec[:mac], auto_config: false,
                      dhcp_ip: "192.168.56.2", dhcp_lower: "192.168.56.3",
                      dhcp_upper: "192.168.56.254", netmask: "255.255.255.0"
        vm.vm.provision "shell", path: "scripts/bootstrap-client.sh",
                        args: [spec[:mac].scan(/../).join(":"), "#{name}.#{domain}"]
      end

      vm.vm.provider "virtualbox" do |vb|
        vb.name = "ASA-Proj1-#{name}"
        vb.memory = spec[:ram]
        vb.cpus = spec.fetch(:cpus, 1)
        vb.linked_clone = true
        vb.check_guest_additions = false
      end

      # Gatilho de acao por VM, antes do fluxo do provider (tipo padrao do Vagrant).
      vm.trigger.before [:up, :reload, :resume], type: :action do |trigger|
        trigger.name = "Aprovacao e DHCP exclusivo do Projeto 01"
        trigger.on_error = :halt
        trigger.ruby do |_env, _machine|
          unless ENV["ASA_PROJ1_EXECUTION_APPROVED"] == "1" &&
                 ENV["ASA_PROJ1_DHCP_CHANGE_APPROVED"] == "1"
            raise "Execucao bloqueada: requer aprovacao humana de VMs e do DHCP compartilhado."
          end
          if name != "arq" && ENV["ASA_PROJ1_CLIENT_BOOTSTRAP_READY"] != "1"
            raise "Dependentes bloqueados: validar arq e preparar o bootstrap Ansible via NAT."
          end
          interfaces = query.call("list", "hostonlyifs").split(/\r?\n\s*\r?\n/)
          selected = interfaces.find { |entry| entry.match?(/^Name:\s+#{Regexp.escape(hostonly)}\s*$/) }
          unless selected && selected.match?(/^IPAddress:\s+192\.168\.56\.1\s*$/) &&
                 selected.match?(/^NetworkMask:\s+255\.255\.255\.0\s*$/)
            raise "Adaptador host-only ausente ou divergente; revisar a arquitetura."
          end
          before = dhcp_block.call
          unless before.match?(/^Enabled:\s+No\s*$/)
            query.call("dhcpserver", "modify", "--network=#{network}", "--disable")
          end
          raise "DHCP do VirtualBox continua habilitado." unless dhcp_block.call.match?(/^Enabled:\s+No\s*$/)
        end
      end

      vm.trigger.after [:up, :reload, :resume], type: :action do |trigger|
        trigger.name = "Conferir ausencia de DHCP concorrente"
        trigger.on_error = :halt
        trigger.ruby do |_env, _machine|
          raise "DHCP concorrente detectado; interromper e investigar." unless dhcp_block.call.match?(/^Enabled:\s+No\s*$/)
        end
      end
    end
  end
end
