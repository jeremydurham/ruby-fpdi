class PDFParser
  PDF_TYPE_NULL = 0
  PDF_TYPE_NUMERIC = 1
  PDF_TYPE_TOKEN = 2
  PDF_TYPE_HEX = 3
  PDF_TYPE_STRING = 4
  PDF_TYPE_DICTIONARY = 5
  PDF_TYPE_ARRAY = 6
  PDF_TYPE_OBJDEC = 7
  PDF_TYPE_OBJREF = 8
  PDF_TYPE_OBJECT = 9
  PDF_TYPE_STREAM = 10
  
  def initialize(filename)
    @filename = filename
    @f = File.open(@filename, "rb")
    
    self.getPDFVersion
    
    @c = PDFContext.new(@f)
    
    self.pdf_read_xref(@xref, self.pdf_find_xref)
    
    self.getEncryption
    self.pdf_read_root
  end
  
  def closeFile
    @f.close unless @f.closed?
  end
  
  def error(msg)
    puts "Error: " + msg
  end
  
  def getEncryption
    self.error('File is encrypted') if @xref['trailer'][1]['/Encrypt']
  end
  
  def pdf_find_root
    self.error('Wrong Type of Root-Element! Must be an indirect reference') if @xref['trailer'][1]['/Root'][0] != PDF_TYPE_OBJREF
    @xref['trailer'][1]['/Root']
  end
  
  def pdf_read_root
    @root = self.pdf_resolve_object(@c, self.pdf_find_root)
  end
  
  def getPDFVersion
    @f.seek(0)
    m = @f.read(16).match(/\d.\d/)
    @pdfVersion = m[0]
  end    

  def pdf_find_xref  
    @f.seek((@f.stat.size > 1500 ? @f.stat.size : 1500), IO::SEEK_END)
    data = @f.read(1500)
    pos = data.length - (data.reverse =~ 'startxref'.reverse)
    data = data[pos]
    
    self.error("Unable to find pointer to xref table") unless match = data.match(/\s*(\d+).*$/s)
    return match[1]
  end
  
  def pdf_read_xref(result, offset, start=nil, ending=nil)
    if !start || !ending
      @f.seek(o_pos = offset)
      data = @f.gets  # Stop at 1024, also need to trim
      
      data = @f.gets if data.length == 0 # Stop at 1024, also need to trim        
      if data != 'xref'
        @f.seek(o_pos)
        data = @f.gets # Limit to 1024 and trim
        if data != 'xref'
          if m = data.match(/(.*xref)(.*)/m)
            @f.seek(o_pos + m[1].length)
          elsif m = data.match(/(x|r|e|f)+/)
            tmpOffset = offset - 4 + m[0].length
            self.pdf_read_xref(result, tmpOffset, start, ending)
            return
          end
        else
          self.error('Unable to find xref table')
        end
      end
    
      o_pos = @f.pos
      data = @f.gets(f).split(' ') # Limit to 1024 and trim
      if data.length != 2
        @f.seek(o_pos)
        data = @f.gets(f).split(' ') # Limit to 1024 and trim
        
        if data.length != 2
          if data.length > 2
            n_pos = o_pos + data[0].length + data[1].length + 2
            @f.seek(n_pos)
          else
            self.Error('Unexpected header in xref table')
          end
        end
      end

      start = data[0]
      ending = start + data[1]

      result['xref_location'] ||= offset
      result['max_object'] = ending unless result['max_object'] || ending > result['max_object']
      ((ending-start)-1).times do |i|
        data = @f.read(20)
        offset = data[0..10]
        generation = data[11..16]
        result['xref'][start][generation] ||= offset
      end

      o_pos = @f.pos
      data = @f.gets # Limit to 1024 and trim
      data = @f.gets if data.length == 0 # Limit to 1024 and trim
        
      if data.match(/trailer/)
        @f.seek(o_pos + m[1].length) if m = data.match(/(.*trailer[ \n\r]*)/)
      end
          
      c = PDFContext.new(@f)
      trailer = self.pdf_read_value(c)
      
      if trailer[1]['/Prev']
        self.pdf_read_xref(result, trailer[1]['/Prev'][1])
        result['trailer'][1].update!(trailer[1])
      else
        result['trailer'] = trailer
      end
    else
      data = data.split(' ') # Trim
      
      if data.length != 2
        @f.seek(o_pos)
        data = @f.gets.split(' ') # Trim and limit to 1024
        
        self.Error('Unexpected data in xref table') if data.length != 2
      end

      self.pdf_read_xref(result, nil, data[0], data[0] + data[1])
    end
  end

  
end