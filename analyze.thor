class Analyze < Thor
  desc "queries", "Analyze the SQL queries run during this Rails app's test."
  method_options :units_only => :boolean, :v => :boolean
  def queries(opts)
    File.unlink('log/test.log') if File.exists?('log/test.log')
    
    test_cmd = opts['units_only'] ? "rake test:units" : "rake test"
    test_cmd += " 2>&1 > /dev/null" unless opts['v']
    
    if system(test_cmd)
      %w(SELECT INSERT UPDATE DELETE).each do |sql|
        puts "#{sql} statements: " + %x[grep #{sql} log/test.log | wc -l]
      end
    end
  end  
end
