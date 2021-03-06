=begin rdoc
  CloudProvider is the base class for cloud computing services such as Ec2, Eucalyptus - where your servers run.
=end
module CloudProviders

  # List of all defined cloud_providers
  def self.all
    @all ||= []
  end

end

%w(connections cloud_provider cloud_provider_instance 
  load_balancer auto_scaler).each do |lib|
  require File.dirname(__FILE__)+"/cloud_providers/#{lib}"
end

%w(ec2 vmware ssh).each do |lib|
  require "cloud_providers/#{lib}/#{lib}"
end