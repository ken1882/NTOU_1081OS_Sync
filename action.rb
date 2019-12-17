def warn(*args)
  puts "[Warn]: #{args.join(' ')}"
end

def eval_action(name)
  print "#{name}..."
  yield
  puts "done"
end