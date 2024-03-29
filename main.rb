require 'json'
require_relative 'lib/util'
require_relative 'lib/producer'
require_relative 'lib/consumer'

WorkerCnt   = 3
ConsumerCnt = 3             
SIGKILL     = 9
FlagTerminated = 0x80000000   # -2147483648
BufferReadSize = 1024         # How many bytes read from IO

FPS  = 60
TickDuration = (1.0 / FPS)

# Root base location of data located
BaseLocation   = "https://www.etax.nat.gov.tw/etw-main/web/ETW183W1/"

$producers   = []          # producer threads
$consumers   = []          # consumer sub-processes
$buffer      = []          # item buffer
$mutex       = Mutex.new   # mutual exclusion lock
$flag_stop   = false       # program stop flag
$silent      = false       # output slience flag

def start_producer
  # Get root page that contains data to fetch
  base_doc = Agent.new.fetch(BaseLocation)

  # Get target links
  targets = base_doc.links.collect{|l| l.uri.to_s if l.to_s.include?("冊")}.compact

  # Relative to absolute path
  targets.collect!{|uri| base_doc.uri.merge(uri).to_s}

  # Equally divide targets to worker to fetch data
  targets.equally_divide(WorkerCnt).collect do |group|
    Thread.new{
      begin
        Producer.start(group)
      rescue SystemExit, Interrupt
        exit
      end
    }
  end
end

# Start sub-process with communication IO pipe
def start_consumer
  ConsumerCnt.times.collect do
    IO.popen("ruby lib/consumer.rb #{__id__}", 'wb+')
  end
end

# Define singletion methods for easier operation
def define_consumer_singletons
  $consumers.each do |_proc|
    class << _proc
      attr_accessor :idle, :dead
      def idle?;   @idle; end
      def busy?;  !@idle && !@dead; end
      def dead?;   @dead; end
      def alive?; !@dead; end
    end
    _proc.dead = false
    _proc.idle = false
  end
end

# Send data to sub-process pipe
def send_data(pipe, data)
  pipe.write(data, "\n#{MSG_ENDI}\n")
end

# Dispatch newly generate item to sub-process (consumer)
def dispatch_work
  $consumers.each do |pipe|
    next unless pipe.idle? || pipe.dead?
    item = nil
    $mutex.synchronize{item = $buffer.pop}
    return unless item
    pipe.idle = false
    Thread.new{send_data(pipe, item)} 
  end
end

# Read sub-process message
def read_pipe(pipe)
  begin
    return pipe.read_nonblock(BufferReadSize)
  rescue IO::WaitReadable
    # do nothing
  rescue EOFError
    ret = :EOF
    return ret
  end
end

# Update pipe status
def update_pipes
  $consumers.each do |pipe|
    line = read_pipe(pipe) || ''
    line.chomp! rescue line
    case line
    when     :EOF; pipe.dead = true;
    when MSG_IDLE; pipe.idle = true;
    end
  end
  return if $buffer.empty?
  dispatch_work
end

# Wheather works are all done
def all_done?
  return false if $producers.any?{|_thr|  _thr.alive?}
  return false if $consumers.any?{|_proc| _proc.busy?}
  return true
end

# Sub-process status watcher
def start_proc_monitor
  Thread.new{
    loop do
      break if $flag_stop
      sleep(1)
      puts ''
      puts $consumers.each_with_index.collect{|_proc, i|
        stat = 'I' if _proc.idle?
        stat = 'W' if _proc.busy?
        stat = 'D' if _proc.dead?
        "Subprocess##{i} (#{_proc.pid})=#{stat}"
      }
    end
  }
end

# Program main loop
def main_loop
  update_pipes
  $flag_stop = all_done?
  sleep(TickDuration)
end

def start 
  $producers = start_producer
  $consumers = start_consumer
  define_consumer_singletons
  start_proc_monitor unless $silent
  main_loop until $flag_stop
end

# Finialize data and send exit message to sub-processes
def post_terminte
  $consumers.each{|pipe| pipe.puts MSG_EXIT}
  File.open(DataFileName, 'rb') do |rfile|
    File.open(ResultFileName, 'w') do |wfile|
      wfile.puts JSON.pretty_generate(Marshal.load(rfile))
    end
  end
end

# Kill all remaining stuff
def terminate
  $consumers.each{|_proc| Process.kill(SIGKILL, _proc.pid) rescue nil}
  $producers.each{|_thr| Thread.kill(_thr) rescue nil}
  File.delete(LockFileName) rescue nil
end

begin
  start
ensure
  post_terminte
  sleep(1) # gently wait for process terminate themselves
  terminate
end
