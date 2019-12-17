require 'mechanize'
require_relative 'action'

# Presentation Helpr
module AgentHelper
  def on_fetch_fail(target, fallback)
    puts "Failed to get #{target}"
    return unless fallback
    fallback.call
  end
end

# Base crawler
class Agent < Mechanize
  include AgentHelper

  attr_reader :current_doc

  def fetch(*args, **kwargs, &block)
    target = args[0]
    _doc   = nil
    kwargs[:depth] ||= 0
    return on_fetch_fail(target, kwargs[:fallback]) if kwargs[:depth] >= 5
    kwargs[:depth] += 1
    begin
      eval_action("Getting #{target}") do
        _doc = self.get(target)
      end
    rescue Mechanize::ResponseCodeError => err
      warning("\nReceived response code #{err.response_code}, retrying...(depth=#{kwargs[:depth]})")
      sleep(0.3)
      fetch(target, **kwargs, &block)
    rescue SystemExit, Interrupt => err
      puts "#{SPLIT_LINE}Terminate singal received!"
      raise err
    rescue Exception => err
      puts "Error!"
      raise err
    end
    @current_doc = _doc if kwargs[:set]
    return _doc
  end
end

# Main producer
class Producer < Agent
  BaseLocation  = "https://www.etax.nat.gov.tw/etw-main/web/ETW183W1/"

  def self.start(targets)
    agent = self.new
    targets.each do |target|
    end
  end

  def fetch(target=BaseLocation, *args, **kwargs, &block)
    args.unshift(target)
    super(*args, **kwargs, &block)
  end

end

# Launched as a subprocess
if (Integer(ARGV[0]) rescue nil)
  STDOUT.sync = true  # no IO buffering
  $parent_pid = ARGV[0].to_i
  Producer.start(eval(ARGV[1]))
  exit 0
end