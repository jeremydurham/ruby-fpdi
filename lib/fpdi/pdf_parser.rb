require 'pdf_context'

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
    @xref = {}
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
    @f.seek(-(@f.stat.size < 1500 ? @f.stat.size : 1500), IO::SEEK_END)
    data = @f.read(1500)
    pos = data.length - (data.reverse =~ /ferxtrats/)
    data = data[pos..-1]    
    
    self.error("Unable to find pointer to xref table") unless match = data.match(/\s*(\d+).*$/s)
    return match[1].to_i
  end
  
  def pdf_read_xref(result, offset, start=nil, ending=nil)
    if !start || !ending
      @f.seek(o_pos = offset.to_i)      
      data = @f.gets("\r").chomp
      
      data = @f.gets("\r").chomp if data.length == 0
      
      if data != 'xref'
        @f.seek(o_pos)
        data = @f.gets("\r").chomp
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
      data = @f.gets("\r").chomp.split(' ')

      if data.length != 2
        @f.seek(o_pos)
        data = @f.gets("\r").chomp.split(' ')
        
        if data.length != 2
          if data.length > 2
            n_pos = o_pos + data[0].length + data[1].length + 2
            @f.seek(n_pos)
          else
            self.Error('Unexpected header in xref table')
          end
        end
      end

      start = data[0].to_i
      ending = start + data[1].to_i

      result.update('xref_location' => offset)
      result.update('max_object' => ending) if !result['max_object'] || ending.to_i > result['max_object'].to_i

      while (start < ending) do
        data = @f.read(20).lstrip.chomp
        offset = data[0..10]
        generation = data[11..16]
        result.update('xref' => {}) unless result['xref']
        result['xref'].update({ start => { generation.to_i => offset.to_i } })
        start += 1
      end

      o_pos = @f.pos
      data = @f.gets("\r")
      data = @f.gets("\r") if data.chomp.length == 0
      
      if data.match(/trailer/)
        @f.seek(o_pos + m[1].length) if m = data.match(/(.*trailer[ \n\r]*)/)
      end
      
      c = PDFContext.new(@f)

      trailer = self.pdf_read_value(c)      

      if trailer[1]['/Prev']
        self.pdf_read_xref(result, trailer[1]['/Prev'][1])
        result['trailer'][1].update(trailer[1])
      else
        result['trailer'] = trailer
      end
    else
      data = data.chomp.split(' ')
      
      if data.length != 2
        @f.seek(o_pos)
        data = @f.gets("\r").chomp.split(' ')
        
        self.Error('Unexpected data in xref table') if data.length != 2
      end

      self.pdf_read_xref(result, nil, data[0], data[0] + data[1])
    end
  end

  def pdf_read_value(c, token=nil)
    token ||= self.pdf_read_token(c)
    return false unless token
    
    case token
    when '<' then
      pos = c.offset
      
      while(true) do
        match = c.buffer[pos..-1] =~ />/ # Need to respect pos
        match += pos if match

        unless match
          if !c.increase_length
            return false
          else
            next # continue?
          end
        end
        
        result = c.buffer[c.offset..(match - c.offset)]
        c.offset = match + 1
        return [PDF_TYPE_HEX, result]
      end
    when '<<' then
      result = {}
      while ((key = self.pdf_read_token(c)) != '>>') do
        return false unless key
        return false unless value = self.pdf_read_value(c)
        result[key] = value
      end
      return [PDF_TYPE_DICTIONARY, result]
    when '[' then
      result = []
      while((token = self.pdf_read_token(c)) != ']') do
        return false unless token
        return false unless value = self.pdf_read_value(c, token)
        result << value.first
      end
      return [PDF_TYPE_ARRAY, result]      
    when '(' then
      pos = c.offset

      while(true) do
        match = c.buffer.match(')') # Need to respect pos
        unless match
          unless c.increase_length
            return false
          else
            next #continue
          end
        end
        tmpresult = c.buffer[c.offset..(match - c.offset)]
        m = tmpresult.match(/([\\\\]+)$/)
        
        if !m || (m[1].length % 2 == 0)
          result = tmpresult
          c.offset = match + 1
          return [PDF_TYPE_STRING, result]
        else
          pos = match + 1
          
          if pos > (c.offset + c.length)
            c.increase_length
          end
        end
      end
    when 'stream' then
      o_pos = c.file.pos - c.buffer.length
      o_offset = c.offset
      c.reset(startpos = o_pos + o_offset)
      e = 0
      e += 1 if c.buffer[0] == 10 || c.buffer[0] == 13
      e += 1 if c.buffer[1] == 10 || c.buffer[0] != 10
      
      if @actual_obj[1][1]['/Length'][0] == PDF_TYPE_OBJREF
        tmp_c = PDFContext.new(@f)
        tmp_length = self.pdf_resolve_object(tmp_c, @actual_obj[1][1]['/Length'])
        length = tmp_length[1][1]
      else
        length = @actual_obj[1][1]['/Length'][1]
      end

      if length > 0
        c.reset(startpos + e, length)
        v = c.buffer
      else
        v = ''
      end
      c.reset(startpos + e + length + "endstream".length)
      
      return [PDF_TYPE_STREAM, v]        
    else
      if token.to_i > 0
        if (tok2 = self.pdf_read_token(c)) != false
          if tok2 =~ /[0-9]{1,}/
            if (tok3 = self.pdf_read_token(c)) != false
              case tok3
              when 'obj' then return [PDF_TYPE_OBJDEC, token.to_i, tok2.to_i]
              when 'R' then return [PDF_TYPE_OBJREF, token.to_i, tok2.to_i]
              end
              c.stack.push(tok3)
            end
          end
          c.stack.push(tok2)
        end
        
        [PDF_TYPE_NUMERIC, token]
      else
        [PDF_TYPE_TOKEN, token]
      end
    end
  end
  
  def pdf_resolve_object(c, obj_spec, encapsulate = true)
    return false unless obj_spec # Array check
    if obj_spec[0] == PDF_TYPE_OBJREF
      if @xref['xref'][obj_spec[1]][obj_spec[2]]
        old_pos = @c.file.pos
        
        c.reset(@xref['xref'][obj_spec[1]][obj_spec[2]])
        header = self.pdf_read_value(c, nil)
        if header[0] != PDF_TYPE_OBJDEC || header[1] != obj_spec[1] || header[2] != obj_spec[2]
          self.error("Unable to find object (#{obj_spec[1]}, #{obj_spec[2]}) at expected location")
        end
        
        @actual_obj = nil
        if encapsulate
          result = [
            #PDF_TYPE_OBJECT,
            'obj' => obj_spec[1],
            'gen' => obj_spec[2]
          ]
        else
          result = []
        end
      
        while(true) do
          value = self.pdf_read_value(c)
          break if !value || result.length > 4
          break if value[0] == PDF_TYPE_TOKEN && value[1] === 'endobj'
          result << value
        end
        c.reset(old_pos)
        result[0] = PDF_TYPE_STREAM if result[2][0] == PDF_TYPE_STREAM
        return result
      end
    else
      return obj_spec
    end
  end

  def pdf_read_token(c)
    return c.stack.shift if c.stack.length > 0

    begin
      return false if !c.ensure_content
      # $c->offset += _strspn($c->buffer, " \n\r\t", $c->offset);
      c.offset += (c.buffer[c.offset..-1] =~ /[^ |\n|\r|\t]/) || c.offset.length
    end while (c.offset >= (c.length - 1))
    
    char = c.buffer[c.offset].chr
    c.offset += 1

    case char
    when '[', ']', '(', ')' then return char
    when '<', '>' then 
      if c.buffer[c.offset].chr == char
        return false if !c.ensure_content
        c.offset += 1
        return char + char
      else
        return char
      end
    else
      return false if !c.ensure_content
      while(true) do
        pos = (c.buffer[c.offset..-1] =~ /[ |\[|\]|\<|\>|\(|\)|\r|\n|\t]/) || 0
        # $pos = _strcspn($c->buffer, " []<>()\r\n\t/", $c->offset);
        if c.offset + pos <= c.length - 1
          break
        else
          c.increase_length
        end
      end
      result = c.buffer[(c.offset - 1)..(c.offset - 1 + pos)]
      c.offset += pos
      return result
    end
  end
end