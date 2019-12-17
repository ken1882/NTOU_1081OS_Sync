require_relative 'action'
require_relative 'util'

module Consumer

  @buffer = []
  @mutex  = Mutex.new

  module_function
  def setup
    @buffer = []
    puts MSG_IDLE
  end

  def start
    # Retrieve input from parent
    loop do
      line = STDIN.gets
      next unless line
      break if line == MSG_EXIT
      if line.chomp == MSG_ENDI
        data   = @buffer.join.chomp
        process_data Marshal.load(data)
        setup 
      else
        @buffer << line
      end
    end
  end

  def process_data(page)
    table_10m = page.search("#fbonly")
    table_2m = page.search("#fbonly_200")
    ten_millions = extract_address(table_10m.children[5])
    two_millions = extract_address(table_2m.children[5])
    dat = {}
    ten_millions.each do |addr|
      loc = addr[0...3]
      dat[loc] = (dat[loc] || 0) + 10
    end
    two_millions.each do |addr|
      loc = addr[0...3]
      dat[loc] = (dat[loc] || 0) + 2
    end
    @new_data = dat
    dump_data
  end

  def extract_address(node)
    node.search("td[headers=\"companyAddress2\"]").collect{|ele| ele.to_s.match(/>(.*)<\/td>/); $1}
  end

  def dump_data
    File.open(LockFileName, File::CREAT) do |file|
      file.flock(File::LOCK_EX)
      @new_data.merge!(load_data){|_, a, b| a + b}
      File.open(DataFileName, 'wb') do |file|
        Marshal.dump(@new_data, file)
      end
    end
  end

  def load_data
    return {} unless File.exist?(DataFileName)
    File.open(DataFileName, 'rb') do |file|
      file.flock(File::LOCK_SH)
      @old_data = Marshal.load(file)
    end
  end

end

# Launched as a subprocess
if (Integer(ARGV[0]) rescue nil)
  STDOUT.sync = true  # no IO buffering
  $parent_pid = ARGV[0].to_i
  Consumer.setup
  Consumer.start
  exit 0
end