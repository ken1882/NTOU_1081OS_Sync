require 'mechanize'
require_relative 'action'

# Presentation Helpr
module AgentHelper
  StartWorkingMsg = "Getting %s"
  RespondError    = "\nReceived response code %d, retrying...(depth=%d)"
  TerminationMsg  = "#{SPLIT_LINE}Terminate singal received!"
  ErrorMsg        = "An error occurred!"

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
      eval_action(sprintf(StartWorkingMsg, target)) do
        _doc = self.get(target)
      end
    rescue Mechanize::ResponseCodeError => err
      warning(sprintf(RespondError, err.response_code, kwargs[:depth]))
      sleep(0.3)
      fetch(target, **kwargs, &block)
    rescue SystemExit, Interrupt => err
      puts TerminationMsg
      raise err
    rescue Exception => err
      puts ErrorMsg
      raise err
    end
    @current_doc = _doc if kwargs[:set]
    return _doc
  end
end
# Main producer
class Producer < Agent
  def self.start(targets)
    worker = self.new
    targets.each do |target|
      item = Marshal.dump(worker.fetch(target))
      $mutex.synchronize{$buffer << item}
    end
  end
end
