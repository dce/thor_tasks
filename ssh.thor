# module: ssh

class Ssh < Thor
  require 'net/sftp'
  require 'highline/import'
  
  desc "install_key HOSTNAME", "installs your public key on the remote host."
  method_options :username => :optional, :password => :optional, :key => :optional
  def install_key(host, opts)
    username = opts['username'] or ask("Enter your username: ") { |q| q.default = ENV['USER'] }
    password = opts['password'] or ask("Enter your password: ") { |q| q.echo = false }
    key = opts['key'] or ask("Enter your key file location: ") { |q| q.default = '~/.ssh/id_rsa.pub' }
    key = File.expand_path(key)
    
    Net::SFTP.start(host, username, :password => password) do |sftp|
      sftp.mkdir!('.ssh', :permissions => 0700) rescue true
      current_keys = sftp.download!(".ssh/authorized_keys") rescue ''
      new_key = File.read(key) rescue ''
      
      unless current_keys.index(new_key)      
        sftp.file.open(".ssh/authorized_keys", "w", 0600) do |f|
          f.puts current_keys unless current_keys.empty?
          f.puts new_key unless new_key.empty?
        end
      end
    end
  end
end