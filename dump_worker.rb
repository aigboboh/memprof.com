require 'db'
require 'ftools'
require 'rake'

def cleanup(basename, storage_name=nil)
  File.delete(storage_name) if storage_name
  File.delete("#{basename}.json.gz") if File.exists?("#{basename}.json.gz")
  File.delete("#{basename}.json") if File.exists?("#{basename}.json")
  File.delete("#{basename}_refs.json") if File.exists?("#{basename}_refs.json")
end

def process_dump(dump)
  dump_id = dump['_id'].to_s
  puts "processing dump: #{dump_id}"

  basename = File.expand_path("../dumps/#{dump_id}", __FILE__)
  storage_name = File.expand_path("../stored_dumps/#{dump_id}.json.gz", __FILE__)

  File.copy("#{basename}.json.gz", storage_name)

  sh "gunzip -f #{basename}.json.gz"
  if $?.exitstatus == 0
    sh "ruby import_json.rb #{basename}.json"
    if $?.exitstatus == 0
      DUMPS.update({:_id => dump['_id']}, :$set => {:status => 'imported'})
      cleanup(basename)
    else
      DUMPS.update({:_id => dump['_id']}, :$set => {:status => 'failed'})
      cleanup(basename)
    end
  else
    DUMPS.update({:_id => dump['_id']}, :$set => {:status => 'failed'})
    cleanup(basename, storage_name)
  end
end

puts 'starting loop'
loop do
  if dumps = DUMPS.find(:status => 'pending')
    dumps.each {|d| process_dump(d)}
  end

  sleep 10
end
