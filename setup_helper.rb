module SetupHelper  

  def read_settings
    @settings = YAML::load_file(File.dirname(__FILE__)+'/config.yml')
    abort("config.yml is not valid") unless @settings
  end
  
  def abort(message='Something went wrong')
    print "\n\n#{message}\n"
    exit $?.to_i
  end

  def run(cmd, fail_on_error = true)
    puts "Running command: #{cmd}"

    output = `#{cmd}`

    puts output
    if !$?.success? and fail_on_error
      abort("Command failed: #{cmd}")
      exit $?.to_i
    end
    output
  end

  def confirmation(message)
    puts "Do you really want to: #{message} (yes/no)"
    gets.strip == 'yes'
  end
  
  def check_force
    # Force all operations (this will overwrite and delete existing files)
    @force = ARGV[0] == '--force'
    ARGV.pop
    if @force
      proceed = confirmation("force all operations (This will overwrite and delete existing files)")
      abort('Setup aborted by user') unless proceed
    end
    proceed
  end
  
  def force?
    @force
  end
  
end