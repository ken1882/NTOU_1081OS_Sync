require_relative 'action'
require_relative 'util'
#================================================================
# * Consumer
#----------------------------------------------------------------
#   This module handles data sent from parent via IO pipes
#================================================================
module Consumer
  #--------------------------------------------------------------
  # * Module variable
  #--------------------------------------------------------------
  @buffer = []      # IO buffer

  module_function
  #--------------------------------------------------------------
  # * Initialize setup before recieve data from pipes
  #--------------------------------------------------------------
  def setup
    @buffer = []
    puts MSG_IDLE
  end
  #--------------------------------------------------------------
  # * Main loop
  #--------------------------------------------------------------
  def start
    loop do
      line = STDIN.gets      # Retrieve input from parent
      next unless line       # Ignore empty data
      break if line == MSG_EXIT
      if line.chomp == MSG_ENDI
        data   = @buffer.join.chomp       # Assemble recieve data chunks
        process_data Marshal.load(data)   # Read serialized data
        setup # cleanups
      else
        @buffer << line
      end
    end
  end
  #--------------------------------------------------------------
  # * Data processing
  #--------------------------------------------------------------
  def process_data(page)
    table_10m = page.search("#fbonly")      # 10m rewarder table
    table_2m  = page.search("#fbonly_200")  #  2m rewarder table

    # Address location
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
  #--------------------------------------------------------------
  # * Get address from raw HTML
  #--------------------------------------------------------------
  def extract_address(node)
    node.search("td[headers=\"companyAddress2\"]").collect{|ele| ele.to_s.match(/>(.*)<\/td>/); $1}
  end
  #--------------------------------------------------------------
  # * Dump processed data to shared file
  #--------------------------------------------------------------
  def dump_data
    File.open(LockFileName, File::CREAT) do |file|
      file.flock(File::LOCK_EX)
      @new_data.merge!(load_data){|_, a, b| a + b}
      File.open(DataFileName, 'wb') do |file|
        Marshal.dump(@new_data, file)
      end
    end
  end
  #--------------------------------------------------------------
  # * Load processed data from shared file
  #--------------------------------------------------------------
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