#!/usr/bin/env ruby

class Server
  
  require 'yaml'
  require File.dirname(__FILE__)+'/setup_helper'
  include SetupHelper  
  
  def initialize
    
    read_settings
            
    @application_root = "#{@settings['server']['webserver_root']}/#{@settings['application']['name']}"
    check_force
  end
  
  def setup

    prepare_application       if @settings['tasks']['application']
    setup_apache_config       if @settings['tasks']['apache']
    setup_database            if @settings['tasks']['database']
    create_publickey          if @settings['tasks']['publickey']
    
    puts "===== Finished setting up server."

    if @settings['tasks']['apache']
      puts "You can now deploy your application and then restart apache with" 
      puts "sudo a2ensite #{@settings['application']['name']}"
      puts "sudo /etc/init.d/apache2 reload"
    end

  end
  
  # Setup the applications directory and a corresponding user
  def prepare_application
    
    puts "===== Preparing directory and user for application"
    
    # Setting up project directory    
    if !File.exist?(@application_root) || force? || confirmation("overwrite #{@application_root}")
      run "sudo rm -rf #{@application_root}"
    end
    
    if "`cat /etc/group | grep #{@settings['application']['user']}`".match(/#{@settings['application']['user']}:.*/) && (force? || confirmation("recreate #{@settings['application']['user']}"))
      run "sudo userdel #{@settings['application']['user']}"
    end

    # Setup a user for the application
    run "sudo mkdir #{@application_root}"
    run "sudo useradd #{@settings['application']['user']} --home #{@application_root} --shell /bin/bash -p '#{@settings['application']['password'].crypt(Time.now.to_s)}'"
    run "sudo chown #{@settings['application']['user']}:#{@settings['application']['user']} #{@application_root}"
    run "sudo chmod 755 #{@application_root}"
    run "sudo su #{@settings['application']['user']} -c \"echo 'export RAILS_ENV=production' > #{@application_root}/.profile\""
  end
  
  # Setup an apache virtual host (passenger) from template
  def setup_apache_config
  
    puts "===== Writing apache config"
    apache_config_file = "/etc/apache2/sites-available/#{@settings['application']['name']}"

    run "sudo a2enmod rewrite"

    if !File.exist?(apache_config_file) || force? || confirmation("overwrite #{apache_config_file}")
      run "sudo touch #{apache_config_file}"
      run "sudo chmod 777 #{apache_config_file}"

      File.open(File.expand_path(File.dirname(__FILE__)+'/apache_template'), "r") do |input|
        File.open(apache_config_file, "w") do |output|
          input.each_line do |line|
            line.gsub!("APPLICATION_DOMAIN", @settings['application']['domain'])
            line.gsub!("APPLICATION_HOST", @settings['server']['host'])            
            line.gsub!("APPLICATION_ROOT", "#{@settings['server']['webserver_root']}/#{@settings['application']['name']}")
            output.print(line)
            puts line
          end
        end
      end
    
      run "sudo chmod 644 #{apache_config_file}"
    end
  end  
  
  # Create a database and set permissions
  def setup_database
    
    puts "===== Setting up the database"
    user_and_password = "-u root -p#{@settings['server']['database']['password']}"
    database_exists = run("mysql #{user_and_password} -e \"show databases\"").match(/^#{@settings['application']['database']['name']}$/)
    
    if (database_exists && force?) || (database_exists && confirmation("drop database #{@settings['application']['database']['name']}"))
      run "echo 'y' | mysqladmin drop #{@settings['application']['database']['name']} #{user_and_password}"
    end
    
    run "mysqladmin create #{@settings['application']['database']['name']} #{user_and_password}"
    run "mysql #{user_and_password} -e \"GRANT ALL PRIVILEGES ON #{@settings['application']['database']['name']}.* TO '#{@settings['application']['database']['user']}'@'localhost' IDENTIFIED BY '#{@settings['application']['database']['password']}' WITH GRANT OPTION;\""
  end
  
  # Create a public key for the application user
  def create_publickey
    puts "===== Setting up SSH key"
    publickey_file = "#{@application_root}/.ssh/id_rsa.pub"
    
    if !File.exist?(publickey_file) || force? || confirmation("overwrite #{publickey_file}")
      run "sudo su #{@settings['application']['user']} -c \"ssh-keygen -t rsa\""
    
      puts "+++++ Use this public key eg. for your github authentication"
      run "sudo cat #{publickey_file}"
    end
  end
  
end

myapp = Server.new
myapp.setup