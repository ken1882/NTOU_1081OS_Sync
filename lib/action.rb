def warn(*args)
  puts "[Warn]: #{args.join(' ')}" unless $silent
end

# Action UI message decorator
def eval_action(name)
  print "#{name}..." unless $silent
  yield
  puts "done" unless $silent
end