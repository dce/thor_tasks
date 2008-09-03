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

class Provision < Thor
  def initialize(*args)
    raise "You must have provision_base installed." unless BASE_LOADED
    super(*args)
  end
  
  desc "ubuntu SERVER", "Remotely provision an Ubuntu server for " +
    "running Rails and Rack apps with Phusion Passenger. You must be in " +
    "the sudoers file on the remote server."
  method_options :user => :optional, :god => :boolean    
  def ubuntu(server, opts)
    get_user_and_password(opts)        
    get_ubuntu_cap(server, opts).provision
  end
  
  private
  
  def get_ubuntu_cap(server, opts)
    cap = Capistrano::Configuration.new
    cap.logger.level = Capistrano::Logger::TRACE
    cap.set :user, opts['user']
    cap.set :password, opts['password']
    
    cap.role :app, server
    
    cap.task :provision do
      install_ubuntu_env
      install_ruby
      install_rubygems
      install_apache
      install_mysql
      install_rails
      install_passenger
      install_god if opts['god']
    end
    
    cap.task :install_ubuntu_env do
      pkgs = %w(build-essential libssl-dev libreadline5-dev zlib1g-dev 
        curl git-core git-svn)
      sudo 'aptitude update'
      sudo 'aptitude -y -q full-upgrade'
      sudo "aptitude -y -q install #{pkgs.join(' ')}"
    end
    
    cap.task :install_ruby do
      pkgs = %w(ruby ruby1.8-dev irb ri libopenssl-ruby librmagick-ruby)
      sudo "aptitude -y -q install #{pkgs.join(' ')}"
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
    
    cap.task :install_rubygems do
      run 'wget -nv ' +
        'http://rubyforge.org/frs/download.php/38646/rubygems-1.2.0.tgz'
      run 'tar zxvf rubygems-*.tgz'
      run 'rm rubygems-*.tgz'
      run "cd rubygems-* && (sudo ruby setup.rb) && cd .."
      sudo 'rm -f /usr/bin/gem'
      sudo 'ln -s /usr/bin/gem1.8 /usr/bin/gem'
      put 'gem: --no-ri --no-rdoc', '.gemrc'
    end
    
    cap.task :install_rails do
      sudo "gem install rails"
    end
    
    cap.task :install_passenger do
      sudo "gem install passenger"
      sudo("/usr/bin/passenger-install-apache2-module", 
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
    
    cap.task :install_god do
      sudo 'gem install god'
      put GOD_INIT_SCRIPT, '/tmp/god.init'
      sudo "mv /tmp/god.init /etc/init.d/god"
      sudo "chmod +x /etc/init.d/god"
      put '/etc/god.conf', '/tmp/default-god'
      sudo 'mv /tmp/default-god /etc/default/god'
      sudo 'touch /etc/god.conf'
      sudo 'update-rc.d god defaults'
    end
    
    cap
  end

  
  PASSENGER_LOAD = <<EOF
LoadModule passenger_module ROOT/ext/apache2/mod_passenger.so
EOF

  PASSENGER_CONF = <<EOF
PassengerRoot ROOT
PassengerRuby /usr/bin/ruby1.8
PassengerDefaultUser www-data
EOF

  GOD_INIT_SCRIPT = <<EOF
#!/bin/sh

### BEGIN INIT INFO
# Provides:             god
# Required-Start:       $all
# Required-Stop:        $all
# Default-Start:        2 3 4 5
# Default-Stop:         0 1 6
# Short-Description:    God
### END INIT INFO

NAME=god
DESC=god

set -e

# Make sure the binary and the config file are present before proceeding
test -x /usr/bin/god || exit 0

# Create this file and put in a variable called GOD_CONFIG, pointing to
# your God configuration file
test -f /etc/default/god && . /etc/default/god
[ $GOD_CONFIG ] || exit 0

. /lib/lsb/init-functions

RETVAL=0

case "$1" in
  start)
    echo -n "Starting $DESC: "
    /usr/bin/god -c $GOD_CONFIG -P /var/run/god.pid -l /var/log/god.log
    RETVAL=$?
    echo "$NAME."
    ;;
  stop)
    echo -n "Stopping $DESC: "
    kill `cat /var/run/god.pid`
    RETVAL=$?
    echo "$NAME."
    ;;
  restart)
    echo -n "Restarting $DESC: "
    kill `cat /var/run/god.pid`
    /usr/bin/god -c $GOD_CONFIG -P /var/run/god.pid -l /var/log/god.log
    RETVAL=$?
    echo "$NAME."
    ;;
  status)
    /usr/bin/god status
    RETVAL=$?
    ;;
  *)
    echo "Usage: god {start|stop|restart|status}"
    exit 1
    ;;
esac

exit $RETVAL
EOF
end


