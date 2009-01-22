# module: provision_base

class Provision < Thor
  require 'highline/import'
  require 'capistrano'
  require 'capistrano/cli'
  
  BASE_LOADED = true
  
  private
  
  def get_user_and_password(opts)
    @user = opts['user'] || \
      ask("Enter your user name on the remote server: ") { 
        |q| q.default = ENV['USER'] 
      }
      
    @password = opts['password'] || \
      ask("Enter your password on the remote server: ") { |q| q.echo = false }
  end
end
