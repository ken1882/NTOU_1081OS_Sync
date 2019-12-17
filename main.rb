require_relative 'util'
require_relative 'producer'
require_relative 'consumer'

WorkerCnt   = 3
ProcTimeout = 10
SIGKILL     = 9
FlagTerminated = 0x80000000   # -2147483648
BufferReadSize = 1024         # How many bytes read from IO

FPS  = 60
Tick = (1.0 / FPS)

$children       = []          # child processes
$result_buffers = []          # result buffers for consumers
$io_buffers     = []          # IO buffers for unfinished IO reading
$consumers      = []          # consumer threads
$mutex          = Mutex.new   # mutual exclusion lock
$flag_stop      = false

def start_worker
  base_doc = Producer.new.fetch
  targets = base_doc.links.collect{|l| l.uri.to_s if l.to_s.include?("冊")}.compact
  targets.collect!{|uri| base_doc.uri.merge(uri).to_s}
  targets.equally_divide(WorkerCnt).collect do |group|
    IO.popen("ruby producer.rb #{__id__} #{group}", 'r+')
  end
end

def start_consumer
  idx = -1
  $children.collect do |pipe|
    idx += 1
    Thread.new{}
  end
end

# Read finished output from pipes
def read_pipes
  $children.each_with_index do |pipe, i|
    next if $io_buffers[i] == FlagTerminated
    begin
      line = $children[i].read_nonblock(BufferReadSize)
      $mutex{$result_buffers << line} if line.end_with? "\r\n"
    rescue IO::WaitReadable
      retry
    rescue EOFError
      $io_buffers[i] = FlagTerminated
    end
  end
end

def terminate(i)
  $timeouts[i] = FlagTerminated
  Thread.kill $consumers[i]
  Process.kill SIGKILL, $producer[i].pid
  puts "Chain #{i} killed due to timeout"
end

def main_loop
  read_pipes
  sleep(Tick)
end

def start 
  $children  = start_worker
  $consumers = start_consumer
  $last_timestamp = Time.now.to_f
  main_loop until $flag_stop
end
# doc = prod.fetch("https://www.etax.nat.gov.tw/etw-main/web/ETW183W3_10111", set: 1)
# puts doc.search("td[headers=\"companyAddress2\"]").collect{|ele| ele.to_s.match(/>(.*)<\/td>/); $1}
