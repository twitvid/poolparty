require "#{::File.dirname(__FILE__)}/ec2"

module CloudProviders

  class Ec2Instance < CloudProviderInstance
    
    default_options(
      Ec2.default_options.merge({
        :launching_time   => nil,
        :private_dns_name => nil,
        :kernel_id        => nil,
        :ramdisk_id       => nil,
        :launch_time      => nil,
        :instance_id      => nil,
        :launch_index     => nil,
        :public_ip        => nil,
        :internal_ip      => nil,
        }
      )
    )
    
    # A new instance will be created from a hash.
    # The parent clouds describe_instances list will be searched for the first one matching any of this instance's provided unique identifiers.
    # If an instance is found, this instance's properties will be set to the properties provided
    # If the found instance has properties of the same key as the provided options, the found instance's values will override the passed in options
    def initialize(opts={}, &block)
      opts.delete(:id)  # metavirt (in case your using it) passes an id that we do not want to set
      set_vars_from_options(opts)
      super
    end
    
    # Printing. This is how we extract the instances into the listing on the 
    # local side into the local listing file
    def to_s
      "#{name}\t#{dns_name}\t#{instance_id}"
    end
    
    # #TODO: test or remove
    # def hosts_file_listing_for(cl)
    #   string = (cl.name == cloud.name) ? "#{name}.#{my_cloud.name}\t#{name}" : "#{name}.#{my_cloud.name}"
    #   "#{internal_ip}\t#{string}"
    # end
    
    def cloud_provider(o={}, &block)
      @cloud_provider ||= if cloud
        cloud.cloud_provider
      else
        options_for_cloud_provider = o.choose{|k,v| Ec2.default_options.has_key?(k)}
        Ec2.new( options_for_cloud_provider, &block)
      end
    end
    
    # Access the right_aws instance directly
    def right_aws
      cloud_provider.ec2.describe_instances instance_id
    end
    
    # add ec2 specific configuration steps
    def configure!(opts={})
      cloud opts[:cloud] if opts[:cloud]
      raise StandardError.new("cloud is not defined.  It must be defined to run configure on the instance") unless cloud
      vputs "configuring ec2 instance #{instance_id}."
      ec2_dir = "/etc/poolparty/ec2"
      FileUtils.mkdir_p(cloud.tmp_path/ec2_dir) unless File.directory?(cloud.tmp_path/ec2_dir)
      run ["mkdir -p #{ec2_dir}"]
      # Save a yaml file of aws varibles and send to the instance
      File.open(cloud.tmp_path/"etc"/"poolparty"/'env.yml', 'w') do |f|
        f<<YAML::dump(cloud_provider.aws_hash(ec2_dir))  #TODO: don't save sensitive info in /tmp
      end
      # We scp these files directly to the instance so to reduce the risk of accidentally leaving them in an insecure location
      scp(:source=>cert,        :destination=>ec2_dir/File.basename(cert)) if cert
      scp(:source=>private_key, :destination=>ec2_dir/File.basename(private_key)) if private_key
      scp(:source=>cloud_cert,  :destination=>ec2_dir/File.basename(cloud_cert)) if cloud_cert
      # TODO: install_ec2_tools
      super opts
      vputs "completed configuring instance  #{instance_id}."
    end
    
    def rsync_excludes(array_of_abs_paths_to_exclude=nil)
      array_of_abs_paths_to_exclude ||= %w( /sys
                             /proc
                             /dev/pts
                             /dev
                             /media
                             /mnt
                             /proc
                             /sys
                             /etc/ssh/ssh_host_*
                             /etc/ssh/moduli
                             /etc/udev/rules.d/70-persistent-net.rules
                             /etc/udev/rules.d/z25_persistent-net.rules
                            )
      array_of_abs_paths_to_exclude.inject(''){|str, path| str<<"--exclude=#{path}"; str}
    end
    
    # create an image file and copy this instance to the image file.
    def make_image(opts={})
      opts = {:volume       => '/',
              :size         => 6000,
              :destination  => '/mnt/bundle',
              :prefix       => image_id,
              :cert         => cert,
              :exclude      => nil,
              :kernel       => kernel_id,
              :ramdisk      => ramdisk_id,
              :ec2cert      => cloud_cert
              }.merge(opts)
      image_file = File.join(opts[:destination], opts[:prefix] )
      cmds = ["mkdir -p #{opts[:destination]}"]
      cmds << "dd if=/dev/zero of=#{image_file} bs=1M count=#{opts[:size]}"
      cmds << "mkfs.ext3 -F -j  #{image_file}"
      cmds << "mkdir -p #{opts[:destination]}/loop"
      cmds << "mount -o loop #{image_file} #{opts[:destination]}/loop"
      cmds << "rsync -ax #{rsync_excludes(opts[:exclude])} #{opts[:volume]}/ #{opts[:destination]}/loop/"
      cmds << "if [[ -f /etc/init.d/ec2-ssh-host-key-gen ]]; then  chmod u+x /etc/init.d/ec2-ssh-host-key-gen ;fi"
      cmds << "umount #{opts[:destination]}/loop"
      self.run cmds
      image_file
    end
    
    #TODO
    # def bundle_and_register(opts={})
    #   arch = 'uname'
    #   image = make_image(opts)
    #   'ec2-bundle-image' image
    #   'ec2-upload-bundle'
    #   'ec2-register-bundle'
    #   return ami
    # end
    
  end

end