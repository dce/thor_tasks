# module: ramaze

class Ramaze < Thor
  desc "setup PROJECT_NAME", "Setup a new Ramaze project."
  def setup(project_name)
    require 'yaml'
    require 'erb'
    
    snake_case = project_name.gsub(/\B[A-Z]/, '_\&').downcase
    camel_case = project_name.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
    
    FileUtils.mkdir_p snake_case
    
    Dir.chdir(snake_case) do
      %w(system public templates test test).each do |dir|
        FileUtils.mkdir_p dir
      end
    
      @files = YAML::load(
        ERB.new(File.read(__FILE__).split('__END__').last).result(binding)
      )
    
      @files.each do |name, contents|
        File.open(name, "w") do |f|
          f.puts contents
        end
      end
    end
  end
end
__END__
config.ru: |
  $:.push(File.dirname(__FILE__) + '/system')
  require <%= snake_case.inspect %>

  Ramaze.trait[:essentials].delete Ramaze::Adapter
  Ramaze.start!
  run Ramaze::Adapter::Base
start.rb: |
  #!/usr/bin/env ruby
  require File.dirname(__FILE__) + '/system/<%= snake_case %>'
  Ramaze.start :adapter => :webrick, :port => 7000
system/<%= snake_case %>.rb: |
  require 'rubygems'
  require 'ramaze'
  
  module <%= camel_case %>
    DIR = File.join(File.dirname(__FILE__), '..') unless defined?(DIR)
    
    class << self
      def dir(subdir = '')
        File.join(DIR, subdir)
      end
      
      def env
        ENV['RACK_ENV'] || 'development'
      end

      def setup
        Ramaze::Global.view_root = dir('templates')
        acquire dir('system/<%= snake_case %>/*')
      end
    end  
  end
  
  <%= camel_case %>.setup
