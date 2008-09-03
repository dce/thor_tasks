# module: provision_apache

class Provision < Thor
  def initialize(*args)
    raise "You must have provision_base installed." unless BASE_LOADED
    super(*args)
  end
  
  desc "apache SERVER DOMAIN", "Adds a virtual host config for DOMAIN " +
    "on the remote server SERVER."
  method_options(:user => :optional, :ip => :optional, :ssl => :boolean)
  def apache(server, domain, opts)
    ip_regex = /\b(?:\d{1,3}\.){3}\d{1,3}$/ # not perfect, but works
    get_user_and_password(opts)
    
    opts['ip'] = opts['ip'] || \
      ask("Enter the IP address for the virtual host: ") { 
        |q| q.default = `host -t A #{server}`.scan(ip_regex)[0] || server
      }
    
    opts['docroot'] = opts['docroot'] || \
      ask("Enter the docroot for the virtual host: ") {
        |q| q.default = "/var/www/#{domain}"
      }
    
    get_apache_cap(server, domain, opts).provision
  end
  
  private
  
  def get_apache_cap(server, domain, opts)
    cap = Capistrano::Configuration.new
    cap.logger.level = Capistrano::Logger::TRACE
    cap.set :user, opts['user']
    cap.set :password, opts['password']
    
    cap.role :app, server
    
    cap.task :provision do
      conf_text = APACHE_VHOST_CONF
      conf_text += "\n\n#{APACHE_SSL_VHOST_CONF}" if opts[:ssl]
      conf_text.gsub!('_IP_', opts['ip'])
      conf_text.gsub!('_DOCROOT_', opts['docroot'])
      
      apache_conf_dir = capture('apxs2 -q SYSCONFDIR')
      put conf_text, "/tmp/#{domain}"
      sudo "mv /tmp/#{domain} #{apache_conf_dir}/sites-available/"
      sudo "a2dissite #{domain}"
      sudo "a2ensite #{domain}"
      sudo "apache2ctl graceful"
    end
    
    cap
  end
  
APACHE_VHOST_CONF = <<EOF
NameVirtualHost _IP_:80

<VirtualHost _IP_:80>
  ServerName _VHOST_
  DocumentRoot _DOCROOT_/current/public
  CustomLog _DOCROOT_/shared/log/access.log combined
  ErrorLog _DOCROOT_/shared/log/error.log
  
  RewriteEngine On
  RewriteCond %{DOCUMENT_ROOT}/system/maintenance.html -f
  RewriteCond %{SCRIPT_FILENAME} !maintenance.html
  RewriteRule ^.*$ /system/maintenance.html [L]
</VirtualHost>
EOF

APACHE_SSL_VHOST_CONF = <<EOF
NameVirtualHost _IP_:80

<VirtualHost _IP_:443>
  ServerName _VHOST_
  DocumentRoot _DOCROOT_/current/public
  CustomLog _DOCROOT_/shared/log/access.log combined
  ErrorLog _DOCROOT_/shared/log/error.log
  
  RewriteEngine On
  RewriteCond %{DOCUMENT_ROOT}/system/maintenance.html -f
  RewriteCond %{SCRIPT_FILENAME} !maintenance.html
  RewriteRule ^.*$ /system/maintenance.html [L]
  
  SSLEngine on
  SSLCertificateFile    /etc/apache2/certs/_VHOST_.crt
  SSLCertificateKeyFile /etc/apache2/certs/_VHOST_.key
</VirtualHost>
EOF
  
end