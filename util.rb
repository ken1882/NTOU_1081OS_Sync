# fix windows getrlimit not implement bug
if Gem.win_platform?
  module Process
    RLIMIT_NOFILE = 7
    def self.getrlimit(*args); [1024]; end
  end
end

class Array
  def equally_divide(n)
    raise ArgumentError, "`n` cannot <= 0" if n <= 0
    len = self.size
    n   = len if n > len
    n   = Integer(n)
    partation = len / n
    delta = (len / n.to_f) - partation
    err   = 0
    st,ed = 0, partation
    n.times.collect do |i|
      ed = len if ed > len
      part = self[st...ed]
      err += delta
      if self[ed] && err >= 1.0
        part << self[ed]; err -= 1;
        ed += 1;
      end
      st = ed; ed += partation;
      part
    end
  end
end