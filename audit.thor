class Audit < Thor
  desc "queries", "Audit the SQL queries run during this Rails app's test."
  method_options :units => :boolean, :v => :boolean
  def queries(opts)
    File.unlink('log/test.log') if File.exist?('log/test.log')
    
    test_cmd = opts['units'] ? "rake test:units" : "rake test"
    test_cmd += " 1> /dev/null 2>&1" unless opts['v']
    
    if system(test_cmd)
      %w(SELECT INSERT UPDATE DELETE).each do |sql|
        puts "#{sql} statements: " + %x[grep #{sql} log/test.log | wc -l]
      end
    else
      puts "Error. Probably not in a Rails app. Try -v for details."
    end
  end  
end
