# module: provision_ubuntu

# This script is meant to be used to provision new Ubuntu servers for Rails 
# and Rack apps using Phusion Passenger. 
#
# Things this does:
# - installs Ruby and Rubygems
# - installs Apache 2
# - installs MySQL
# - installs Passenger
# - adds a Passenger Apache conf and enables the module
# - installs logrotate, git, and git-svn
# - installs RMagick
# - installs Rails
# Optional:
# - installs god, and creates an init file for it

require 'open-uri'
require 'hpricot'

class Provision < Thor
  def initialize(*args)
    raise "You must have provision_base installed." unless defined?(BASE_LOADED)
    super(*args)
  end
  
  desc "ubuntu SERVER", "Remotely provision an Ubuntu server for " +
    "running Rails and Rack apps with Phusion Passenger. You must be in " +
    "the sudoers file on the remote server."
  method_options :user => :optional, :god => :boolean    
  def ubuntu(server)
    get_user_and_password(options)        
    get_ubuntu_cap(server).provision
  end
  
  private
  
  def get_ubuntu_cap(server)
    cap = Capistrano::Configuration.new
    cap.logger.level = Capistrano::Logger::TRACE
    cap.set :user, @user
    cap.set :password, @password
    
    cap.role :app, server
    
    cap.task :provision do
      install_ubuntu_env
      install_ruby
      install_apache
      install_mysql
      install_passenger
    end
    
    cap.task :install_ubuntu_env do
      pkgs = %w(build-essential libssl-dev libreadline5-dev zlib1g-dev 
        curl git-core git-svn)
      sudo 'aptitude update'
      sudo 'aptitude -y -q full-upgrade'
      sudo "aptitude -y -q install #{pkgs.join(' ')}"
    end
    
    cap.task :install_ruby do
      # get latest Ruby Enterprise Edition
      doc = open('http://rubyforge.org/frs/?group_id=5833') { |f| Hpricot(f) }
      link = (doc/'a').detect { |link| link['href'] =~ /\.tar\.gz$/ }['href']

      run "wget -nv http://rubyforge.org#{link}"
      run "tar xfz ruby-enterprise-*.tar.gz"

      sudo("./ruby-enterprise-*/installer", :pty => true) do |ch,stream,out|
        next if out.chomp == ''
        print out
        ch.send_data(input = "\n") if out =~ /enter/i
      end

      sudo "ln -s /opt/ruby-enterprise-* /opt/ruby-enterprise"
      sudo "ln -s /opt/ruby-enterprise/bin/* /usr/local/bin/"
    end
    
    cap.task :install_apache do
      pkgs = %w(apache2-mpm-prefork apache2-prefork-dev)
      sudo "aptitude -y -q install #{pkgs.join(' ')}"
      sudo "a2enmod rewrite"
    end
    
    cap.task :install_mysql do
      pkgs = %w(libmysql++-dev mysql-server)
      sudo "aptitude -y -q install #{pkgs.join(' ')}"
    end
        
    cap.task :install_passenger do
      sudo("/opt/ruby-enterprise/bin/passenger-install-apache2-module", 
        :pty => true) do |ch,stream,out|
        next if out.chomp == ''
        print out
        ch.send_data(input = "\n") if out =~ /enter/i
      end
      passenger_root = capture('passenger-config --root').chomp
      sudo "rm -f /tmp/passenger.*"
      put PASSENGER_LOAD.gsub(/ROOT/, passenger_root), '/tmp/passenger.load'
      put PASSENGER_CONF.gsub(/ROOT/, passenger_root), '/tmp/passenger.conf'
      sudo "mv /tmp/passenger.* /etc/apache2/mods-available"
      sudo "a2enmod passenger"
      sudo "/etc/init.d/apache2 force-reload"
    end
        
    cap
  end
  
  PASSENGER_LOAD = <<EOF
LoadModule passenger_module ROOT/ext/apache2/mod_passenger.so
EOF

  PASSENGER_CONF = <<EOF
PassengerRoot ROOT
PassengerRuby /opt/ruby-enterprise/bin/ruby
PassengerDefaultUser www-data
EOF
end


