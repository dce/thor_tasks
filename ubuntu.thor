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
      puts "Installing essential development packages..."
      ssh.exec!(sudo 'aptitude -y -q install build-essential libssl-dev libreadline5-dev zlib1g-dev curl')
      
      puts "Installing ruby..."
      ssh.exec!(sudo 'aptitude -y -q install ruby libruby irb ri')
      
      puts "Downloading rubygems..."
      ssh.exec!('wget -nv http://rubyforge.org/frs/download.php/38646/rubygems-1.2.0.tgz')
      
      puts "Installing rubygems..."
      ssh.exec!('tar zxvf rubygems-*.tgz')
      ssh.exec!('rm rubygems-*.tgz')
      ssh.exec!("cd rubygems-* && (#{sudo 'ruby setup.rb'}) && cd ..")
      ssh.exec!('ln -s /usr/bin/gem1.8 /usr/bin/gem')
      
      puts "Installing thor..."
      ssh.exec!(sudo 'gem install thor')
      ssh.exec!('wget -O ubuntu.thor http://github.com/crnixon/thor_tasks/tree/master/ssh.thor?raw=true')
      puts "Log into the server and run 'thor ubuntu:provision' to continue."
    end
  end

  desc "provision", "Provision an Ubuntu server for running Ruby on Rails applications with Apache and Passenger or Mongrel. Assumes Ruby and thor are installed."
  def provision
    system "sudo aptitude -y -q install mysql-server libmysql++-dev"
    system "sudo aptitude -y -q install imagemagick libmagick++-dev"
    system "sudo aptitude -y -q install apache2 apache2-dev"
    system "sudo gem install rmagick"
    system "sudo gem install rails"
    system "sudo gem install passenger"
  end
  
  private
  
  def sudo(command)
    "echo #{@password} | sudo -S #{command}"
  end
end