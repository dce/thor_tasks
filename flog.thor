# module: flog
class Flog < Thor
  desc "dir DIR", "flog the specified directory"
  
  method_options :rails => :boolean
  def dir(dir, opts)
    dir = 'app' if opt['rails']
    dir = '.' if dirs.empty?
    system "find #{dir} -name \\*.rb | xargs flog"
  end
end
