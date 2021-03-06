module PoolParty
  module Installers
    class Vmware < Installer
      
      def steps
        [
          :get_vmrun_file, :get_vm_ip, :get_key,
          :add_vmware_fusion_to_path, :start_vmrun_instance,
          :wait_for_connection, :scp_key, :test_login, :fix_eth0,
          :shutdown_vmrun_instance
        ]
      end
      
      def self.name
        "Vmware"
      end
      
      def self.description
        "Vmware Fusion installer"
      end
      
      private
      
      def get_vmrun_file
        if !default_vmrun_files.empty?
          show_menu_for_vmrun_files
        else
          ask_for_vmrun_path
        end
      end
      
      def show_menu_for_vmrun_files
        msg = "We found the following vmware files in the default vmware directory.\nChoose one of these to use as your vmrun file or select other\n<line>"
        
        providers = {}
        default_vmrun_files.each_with_index do |file,idx|
          providers.merge!(idx+1 => file)
        end
        
        base = choose(msg, providers)
        @vmrun_file = base == :other ? ask_for_vmrun_path : base
        
        puts "Chose: #{@vmrun_file}"
      end
      
      def ask_for_vmrun_path
        vmrun_file_help =<<-EOV
Vmware uses a vmwarevm file to keep information about the vmware instance. To find the vmwarevm file, 
navigate to vmware and find the vm you'd like to use. Find this in finder and paste that here.
        EOV

        vmrun_file = <<-EOE
Awesome. What's the path to your vmwarevm file?
        EOE
        ask_with_help :message => vmrun_file, :help => vmrun_file_help
      end
      
      def get_vm_ip
        ip_help =<<-EOV
Right now, vmrun, the remoter base needs an explicitly set ip. Log into your vm and type ifconfig. Copy and paste that here.
        EOV
        @ip = ask_with_help :message => "what's the ip of your vm?", :help => ip_help
        
        if @ip =~ /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/
          @ip
        else
          colored_say "<red>You must enter a valid ip</red>"
          get_vm_ip
        end
      end
      
      def get_key
        key_help =<<-EOV
Finally, we'll set somethings up here shortly, but first we'll need to know where your public key is. We'll assume it's 
at ~/.ssh/id_rsa.pub. If this is true, then just press enter. Otherwise, enter the path of your public key.        
        EOV
        
        ask_with_help :message => "What keypair would you like to use? (default: ~/.ssh/id_rsa.pub)", :help => key_help do |responded_key|
          responded_key = "~/.ssh/id_rsa.pub" if responded_key.empty?

          @key = File.expand_path(responded_key)
          if File.file?(@key)
            @key
          else
            colored_say "<red>You must enter a valid path to a keyfile</red>"
            get_key
          end
        end
      end
      
      def wait_for_connection
        ping_port_and(@ip, 22) do
          puts "Instance available for connection"
        end
      end
      
      def scp_key
        colored_say "Sending key to vmware instance..."
        o = %x{scp #{@key} root@#{@ip}:~/.ssh/authorized_keys}
        sleep 2
      end
      
      def test_login
        raise "Could not connect to #{@ip}. Check to make sure you set the ip properly" unless ping_port(@ip, 22, 3)
      end
      
      # TODO: Fix this
      def fix_eth0    
      end
      
      def add_vmware_fusion_to_path
        colored_say "Exporting path with the VMware Fusion. You will want to add this to your path by adding \n\texport PATH=/Library/Application Support/VMware Fusion:$PATH\n to your .profile or .bashrc file"
        o = %x{export PATH=/Library/Application\\\ Support/VMware\\\ Fusion:$PATH}
        sleep 2
      end
      
      def start_vmrun_instance
        vmrun_path = `which vmrun`.chomp!
        command = "#{vmrun_path.path_quote} start #{@vmrun_file.path_quote}"
        %x{#{command}}
      end
      
      def shutdown_vmrun_instance
        vmrun_path = `which vmrun`.chomp!
        command = "#{vmrun_path.path_quote} stop #{@vmrun_file.path_quote}"
        %x{#{command}}
      end
      
      def closing_message
        vmx_file = Dir["#{@vmrun_file}/*.vmx"].first
          clds =<<-EOC
pool :my_pool do
  cloud :my_app do
    using :vmrun do
      vmx_hash({
        "#{vmx_file}" => "#{@ip}"
      })
    end

    has_file "/etc/motd" do
      content "Welcome to your first PoolParty instance!"
    end
  end
end             
                EOC

        ::File.open("clouds.rb", "w") {|f| f << clds}
        super
      end
      
      def default_vmrun_files
        @default_vmrun_files ||= find_default_vmrun_files rescue nil
      end
      
      def find_default_vmrun_files
        Dir["#{::File.expand_path("~")}/Documents/Virtual\ Machines.localized/*.vmwarevm"]
      end
      
    end
  end
end