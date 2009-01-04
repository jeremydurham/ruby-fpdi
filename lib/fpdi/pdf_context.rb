class PDFContext
  attr_accessor :stack, :offset, :length, :buffer
  
  def initialize(f)
    @file = f
    self.reset
  end
  
  def reset(pos = nil, l = 100)
    @file.seek(pos) if pos
    @buffer = l > 0 ? @file.read(l) : ''
    @offset = 0
    @length = @buffer.length
    @stack = []
  end
  
  def ensure_content
    @offset >= (@length - 1) ? self.increase_length : true
  end
  
  def increase_length(l=100)
    if @file.eof?
      false
    else
      @buffer += @file.read(l)
      @length = @buffer.length
      true
    end
  end
              
end