# module: ubuntu

class Ubuntu < Thor
  require 'net/ssh'
  require 'highline/import'

  desc "remote_provision SERVER", "Remotely provision an Ubuntu server for running Ruby and Thor. You must be in the sudoers file on the remote server."
  method_options :username => :optional, :password => :optional
  def remote_provision(server, opts)
    @username = opts['username'] || ask("Enter your username on the remote server: ") { |q| q.default = ENV['USER'] }
    @password = opts['password'] || ask("Enter your password on the remote server: ") { |q| q.echo = false }
    
    Net::SSH.start(server, @username, :password => @password) do |ssh|
      puts "Updating Ubuntu (this may take a while)..."
      ssh.exec!(sudo('aptitude update'))
      ssh.exec!(sudo('aptitude full-upgrade'))
      
      puts "Installing essential development packages..."
      ssh.exec!(apt(%w(build-essential libssl-dev libreadline5-dev zlib1g-dev curl)))
      
      puts "Installing ruby..."
      ssh.exec!(apt(%w(ruby ruby1.8-dev irb ri libopenssl-ruby)))
      
      puts "Downloading rubygems..."
      ssh.exec!('wget -nv http://rubyforge.org/frs/download.php/38646/rubygems-1.2.0.tgz')
      
      puts "Installing rubygems..."
      ssh.exec!('tar zxvf rubygems-*.tgz')
      ssh.exec!('rm rubygems-*.tgz')
      ssh.exec!("cd rubygems-* && (#{sudo 'ruby setup.rb'}) && cd ..")
      ssh.exec!(sudo('ln -s /usr/bin/gem1.8 /usr/bin/gem'))
      ssh.exec!("echo 'gem: --no-ri --no-rdoc' > .gemrc")
      
      puts "Installing thor and gems..."
      ssh.exec!(sudo('gem install thor net-ssh net-sftp highline'))
      ssh.exec!('wget -O ubuntu.thor http://github.com/crnixon/thor_tasks/tree/master/ubuntu.thor?raw=true')
      puts "Log into the server and run 'thor ubuntu:provision' to continue."
    end
  end

  desc "provision", "Provision an Ubuntu server for running Ruby on Rails applications with Apache and Passenger or Mongrel. Assumes Ruby and thor are installed."
  def provision
    # Put all the noisy ones at the beginning so you can leave it alone for 
    # as long as possible afterwards.
    puts "There will be several prompts coming up. Stick around until we let you know it's safe to leave."
    ask "Press ENTER to continue."
    
    system apt(%w(libmysql++-dev mysql-server apache2-mpm-prefork apache2-prefork-dev))
    system sudo('gem install passenger')
    system sudo('passenger-install-apache2-module')
    
    puts "You will not be asked to enter anything else. I can finish up on my own."
    ask "Press ENTER to continue."
    
    pkgs = %w(librmagick-ruby logrotate git-core git-svn)     
    system apt(pkgs)
    
    gems = %w(rails mongrel mongrel_cluster god)
    system sudo("gem install #{gems.join(' ')}")
    
    File.open('/tmp/god.init', 'w') do |file|
      file.write GOD_INIT_FILE
    end
    
    system sudo("mv /tmp/god.init /etc/init.d/god")
    system sudo("chmod +x /etc/init.d/god")
    system "echo '/etc/god.conf' > /tmp/god"
    system sudo("mv /tmp/god /etc/defaults/god")
    system sudo("touch /etc/god.conf")
  end
  
  private
  
  def sudo(cmd)
    if @password
      "echo #{@password} | sudo -S #{cmd}"
    else
      "sudo #{cmd}"
    end
  end
  
  def apt(*pkgs)
    sudo "aptitude -y -q install #{pkgs.flatten.join(' ')}"
  end
end

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