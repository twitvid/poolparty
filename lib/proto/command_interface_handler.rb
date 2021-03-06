class CommandInterfaceHandler
  def run_command(cld, command, args)
        
    cr = CloudThrift::CloudResponse.new
    cr.name = cld.name
    cr.command = command
    
    cr.response = format_response(get_response(cld, command, args))

    return cr
  end
  
  def cast_command(cld, command, args)
        
    cr = CloudThrift::CloudResponse.new
    cr.name = cld.name
    cr.command = command
    cr.response = format_response("Running command: #{command}(#{args})")
    
    fork do
      get_response(cld, command, args)
    end

    return cr
  end
  
  
  private
  
  def get_response(cld, command, args)
    begin
      the_cloud = clouds[cld.name]
      if the_cloud
        if command.include?(".")
          command.split(".").inject(the_cloud) do |curr_cloud, cmd|
            if cmd.match(/\((.*)\)/)
              args = $1
              new_cmd = cmd.gsub(args, '').gsub(/\(\)/, '')
              curr_cloud = curr_cloud.send(new_cmd.to_sym, *args)
            else
              curr_cloud = curr_cloud.send(cmd)
            end
          end
        else
          the_cloud.send(command.to_sym, *args)
        end
      else
        "Cloud not found: #{cld.name}"
      end
    rescue Exception => e
      cr.response = "Error: #{e.inspect}"
    end    
  end
  
  def format_response(resp)
    case resp
    when Array
      resp.join(",")
    when Hash
      resp.map {|k,v| "#{k}:#{format_response(v.empty? ? "null" : v)}" }
    else
      [resp]
    end.map {|ele| ele.to_s }
  end
  
end