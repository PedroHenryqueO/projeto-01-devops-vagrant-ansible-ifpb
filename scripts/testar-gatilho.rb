# Testa os callbacks reais com um substituto de Open3: nunca chama VirtualBox.
require "open3"
require "ostruct"

class ConfigFake
  attr_reader :before, :after, :machines
  def initialize
    @before, @after, @machines = [], [], {}
  end
  def vm; self; end
  def ssh; self; end
  def trigger; TriggerFake.new(self); end
  def define(name, **options)
    child = ConfigFake.new
    @machines[name] = child
    yield child
  end
  def provider(*)
    yield self
  end
  def method_missing(*); end
  def respond_to_missing?(*); true; end
end
class TriggerFake
  def initialize(config); @config = config; end
  def before(*); add(@config.before) { |t| yield t }; end
  def after(*); add(@config.after) { |t| yield t }; end
  def add(list)
    t = OpenStruct.new
    t.define_singleton_method(:ruby) { |&block| self.callback = block }
    yield t
    list << t
  end
end
module Vagrant
  def self.has_plugin?(*); false; end
  def self.configure(*)
    @config = ConfigFake.new
    yield @config
  end
  def self.config; @config; end
end
ENV["VAGRANT_DOTFILE_PATH"] = File.expand_path("../.vagrant-proj1", __dir__)
load File.expand_path("../Vagrantfile", __dir__)
module Open3
  def self.capture2e(*args)
    $calls << args
    command = args.drop(1)
    text = case command
    when ["list", "vms"] then ""
    when ["list", "hostonlyifs"]
      "Name: VirtualBox Host-Only Ethernet Adapter\nIPAddress: 192.168.56.1\nNetworkMask: 255.255.255.0\n"
    when ["list", "dhcpservers"]
      "NetworkName: HostInterfaceNetworking-VirtualBox Host-Only Ethernet Adapter\nDhcpd IP: 192.168.56.2\nLowerIPAddress: #{$pool}\nUpperIPAddress: 192.168.56.254\nNetworkMask: 255.255.255.0\nEnabled: #{$enabled}\n"
    when ["dhcpserver", "modify", "--network=HostInterfaceNetworking-VirtualBox Host-Only Ethernet Adapter", "--disable"]
      $enabled = "No"
      ""
    else raise "Comando inesperado na simulacao: #{command.inspect}"
    end
    [text, OpenStruct.new(success?: true)]
  end
end
def reset
  $calls, $pool, $enabled = [], "192.168.56.3", "Yes"
  ENV.delete("ASA_PROJ1_EXECUTION_APPROVED")
  ENV.delete("ASA_PROJ1_DHCP_CHANGE_APPROVED")
end
def blocked(callback, message)
  begin
    callback.call(nil, nil)
  rescue RuntimeError => e
    raise unless e.message.include?(message)
    return
  end
  raise "Controle nao bloqueou a operacao"
end
callback = Vagrant.config.machines.fetch("arq").before.first.callback
reset
blocked(callback, "aprovacao humana")
raise unless $calls.empty?
reset
ENV["ASA_PROJ1_EXECUTION_APPROVED"] = ENV["ASA_PROJ1_DHCP_CHANGE_APPROVED"] = "1"
$pool = "192.168.56.99"
blocked(callback, "DHCP divergiu")
raise if $calls.any? { |c| c.include?("modify") }
reset
ENV["ASA_PROJ1_EXECUTION_APPROVED"] = ENV["ASA_PROJ1_DHCP_CHANGE_APPROVED"] = "1"
callback.call(nil, nil)
raise unless $enabled == "No" && $calls.count { |c| c.include?("modify") } == 1
Vagrant.config.machines.fetch("arq").after.first.callback.call(nil, nil)
$calls.clear
callback.call(nil, nil)
raise if $calls.any? { |c| c.include?("modify") }
blocked(Vagrant.config.machines.fetch("cli").before.first.callback, "Dependentes bloqueados")
puts "OK: aprovacao, divergencia de pool, alvo exclusivo, idempotencia e bloqueio de clientes (simulados)."
