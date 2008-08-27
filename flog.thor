# module: flog
class Flog < Thor
  desc "dir DIRS", "flog the specified directories"
  
  def dir(*dirs)
    dirs = ['.'] if dirs.empty?
    system "find #{dirs.join(' ')} -name \\*.rb | xargs flog"
  end
end
