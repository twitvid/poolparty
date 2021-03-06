module PoolParty
  class ChefAttribute < Base
    
    def initialize(opts={}, &block)
      @init_block = block
      @init_opts = opts
      instance_eval &block if block
      @base_name = self.name
    end
    
    def merge!(h={})
      init_opts.merge!(h)
    end
    
    def to_dna(recipes, filepath)
      opts = init_opts
      (opts[:recipes] ||= []) << recipes unless opts[:recipes]
      
      opts[:recipes].flatten!
      opts.delete(:name) if opts[:name] && opts[:name].empty?
      File.open(filepath, "w") do |f|
        f << JSON.pretty_generate(init_opts)
      end
    end
    
    def method_missing(m,*a,&block)
      if @init_opts.has_key?(m)
        @init_opts[m]
      else
        @init_opts.merge!(m => a)
      end
    end
    
  end
end