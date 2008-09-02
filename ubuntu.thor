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
        
    system apt(%w(librmagick-ruby))
    
    gems = %w(rails mongrel mongrel_cluster)
    system sudo("gem install #{gems.join(' ')}")
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