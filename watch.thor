# module: watch

# Based on rstakeout, originally by Mike Clark, from
# http://www.pragmaticautomation.com/cgi-bin/pragauto.cgi/Monitor/StakingOutFileChanges.rdoc

class Watch < Thor
  
  desc "run COMMAND FILES", "Watch the given files and execute the command every time they change."
  def run(command, *files)
    exit if files.empty?
    files = Hash[files.map { |file| [file, File.mtime(file)] }]
    puts "Watching #{files.keys.join(', ')}\n\nFiles: #{files.keys.length}"

    trap('INT') do
      puts "\nQuitting..."
      exit
    end
    
    loop do
      sleep 1

      changed_file, last_changed = files.find { |file, last_changed|
        File.mtime(file) > last_changed
      }

      if changed_file
        files[changed_file] = File.mtime(changed_file)
        puts "=> #{changed_file} changed, running #{command}"
        puts `#{command}`
        puts "=> done"
      end
    end
  end
end


