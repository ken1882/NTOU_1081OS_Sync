def warn(*args)
  puts "[Warn]: #{args.join(' ')}" unless $silent
end

def eval_action(name)
  print "#{name}..." unless $silent
  yield
  puts "done" unless $silent
end