#!/usr/bin/env ruby

class Local
  
  require 'yaml'
  require File.dirname(__FILE__)+'/setup_helper'
  include SetupHelper
  
  def initialize
    read_settings
    check_force
  end
  
  # Perform all tasks defined in config.yml
  def setup 
     
    if File.directory?(@settings['local']['application_root'])
      create_capistrano_config  if @settings['tasks']['capistrano']
      create_gitignore          if @settings['tasks']['gitignore']
    else
      abort("Directory #{@settings['local']['application_root']} could not be found.")
    end

    puts "===== Finished setting up application."

    if @settings['tasks']['apache']
      puts "Commit the changes, setup your server and then deploy your application with" 
      puts "cap deploy:setup"
      puts "cap deploy:migrations"
    end
  end

  # Create capistrano configuration from template in config/deploy.rb
  def create_capistrano_config
    
    capistrano_config_file = @settings['local']['application_root']+"/config/deploy.rb"
    
    puts "===== Initializing capistrano"
    if !File.exist?(capistrano_config_file) || force? || confirmation("overwrite #{capistrano_config_file}")
      run "capify #{@settings['local']['application_root']}"

      File.open(File.expand_path(File.dirname(__FILE__)+'/capistrano_template'), "r") do |input|
        File.open(capistrano_config_file, "w") do |output|
          input.each_line do |line|
            line.gsub!("APPLICATION_HOST", @settings['server']['host'])
            line.gsub!("APPLICATION_USER", @settings['application']['user'])
            line.gsub!("APPLICATION_REPOSITORY", @settings['application']['repository'])
            line.gsub!("APPLICATION_NAME", @settings['application']['name'])                
            line.gsub!("APPLICATION_ROOT", @settings['server']['webserver_root'] + "/" + @settings['application']['name'])
            output.print(line)
            puts line
          end
        end
      end
    end
    
    create_maintenance_html
  end
    
  # Create a maintenance.html file in the public directory that will be used by capistrano
  def create_maintenance_html
    
    puts "===== Setting up maintenance.html"
    maintenance_file = @settings['local']['application_root']+"/public/maintenance.html"
    if !File.exist?(maintenance_file) || force? || confirmation("overwrite #{maintenance_file}")
      run "cp #{File.dirname(__FILE__)+'/maintenance_template'} #{maintenance_file}"
    end
    
  end
  
  # Create a .gitignore file in the application root containing the most common ignores
  def create_gitignore
    
    puts "===== Setting up .gitignore"
    gitignore_file = @settings['local']['application_root']+"/.gitignore"
    if !File.exist?(gitignore_file) || force? || confirmation("overwrite #{gitignore_file}")
      run "cp #{File.dirname(__FILE__)+'/gitignore_template'} #{gitignore_file}"
    end  
    
  end
  
end

myapp = Local.new
myapp.setup