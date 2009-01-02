class FPDI < FPDF_TPL
  FPDF_VERSION = '1.2'

  def initialize(orientation='P', unit='mm', format='A4')
    super(orientation, unit, format)
  end
  
  def setSourceFile(filename)
    @current_filename = filename
    fn = @current_filename
    
    @parsers[fn] = FPDI_PDF_Parser.new(fn, self) unless @parsers[fn]
    
    @parsers[fn].getPageCount
  end
  
  def importPage(pageno, boxName='/CropBox')
    self.Error("Please import the desired pages before creating a new template.") if @_intpl
    
    fn = @current_filename
    parser = @parsers[fn]
    parser.setPageno(pageno)
    
    @tpl += 1
    @tpls[@tpl] = []
    tpl = @tpls[@tpl]
    tpl['parser'] = parser
    tpl['resources'] = parser.getPageResources
    tpl['buffer'] = parser.getContent
    
    return self.Error(sprintf("Unknown box: %s", boxName)) unless parser.availableBoxes.include?(boxName)
    pageboxes = parser.getPageBoxes(pageno)
    
    boxName = '/CropBox' if !pageboxes[boxName] && (boxName == '/BleedBox' || boxName == '/TrimBox' || boxName == '/ArtBox')
    boxName = '/MediaBox' if !pageboxes[boxName] && boxName == '/CropBox'
    return false unless pageboxes[boxName]
    @lastUsedPageBox = boxName
    box = pageboxes[boxName]
    tpl['box'] = box
    @tpls[@tpl] = @tpls[@tpl].update(box)
    tpl['x'] = 0
    tpl['y'] = 0
    page = parser.pages[parser.pageno]
    rotation = parser.getPageRotation(pageno)
    if rotation[1] && ((angle = rotation[1] % 360) != 0)
      steps = angle / 90
      
      _w = tpl['w']
      _h = tpl['h']
      tpl['w'] = steps % 2 == 0 ? _w : _h
      tpl['h'] = steps % 2 == 0 ? _h : _w
      
      if (steps % 2 != 0)
        x = y = (steps == 1 || steps == -3) ? tpl['h'] : tpl['w']
      else
        x = tpl['w']
        y = tpl['h']
      end
        
      cx = (x / 2 + tpl['box']['x']) * @k
      cy = (y / 2 + tpl['box']['y']) * @k
      
      angle *= -1
      
      angle *= 3.1415926535898/180
      c = Math.cos(angle)
      s = Math.sin(angle)
      
      tpl['buffer'] = sprintf('q %.5f %.5f %.5f %.5f %.2f %.2f cm 1 0 0 1 %.2f %.2f cm %s Q',c,s,-s,c,cx,cy,-cx,-cy, tpl['buffer']);
    end
    
    @tpl
  end
  
  def getLastUsedPageBox
    @lastUsedPageBox
  end
  
  def useTemplate(tplidx, _x=nil, _y=nil, _w=0, _h=0)
    self._out('q 0 J 1 w 0 j 0 G')
    s = super(tplidx, _x, _y, _w, _h)
    self._out('Q')
    s
  end
  
  def _putimportedobjects
    if @parsers.length > 0
      @parsers.each do |filename, p|
        @current_parser = @parsers[filename]
        if @_obj_stack[filename]
          @_obj_stack[filename].each_key do |n|
            nObj = @current_parser.pdf_resolve_object(@current_parser.c, @_obj_stack[filename][n][1])
            _newobj(@_obj_stack[filename][n][0])
            
            if nObj[0] == PDF_TYPE_STREAM
              self.pdf_write_value(nObj)
            else
              self.pdf_write_value(nObj[1])
            end
            
            self._out('endobj')
          end
        end
      end
    end
  end

  def setVersion
    @PDFVersion = @importVersion > @PDFVersion ? @importVersion : @PDFVersion
  end
  
  def _putresources
    self._putfonts
    self._putimages
    self._putformxobjects
    self._putimportedobjects
    @offsets[2] = @buffer.length
    self._out('2 0 obj')
    self._out('<<')
    self._putresourcedict
    self._out('>>')
    self._out('endobj')
  end
  
  def _putformxobjects
    filter = @compress ? '/Filter /FlateDecode ' : ''
    @tpls.each do |tplidx, tpl|
      p = @compress ? Zlib::Deflate.deflate(tpl['buffer']) : tpl['buffer']
      self._newobj
      @tpls[tplidx]['n'] = @n
      self._out('<<' + filter + '/Type /XObject')
      self._out('/Subtype /Form')
      self._out('/FormType 1')
      self._out(sprintf('/BBox [%.2f %.2f %.2f %.2f]',
          (tpl['x'] + (tpl['box']['x'] || 0))*@k,
          (tpl['h'] + (tpl['box']['y'] || 0) - $tpl['y'])*@k,
          (tpl['w'] + (tpl['box']['x'] || 0))*@k,
          (tpl['h'] + (tpl['box']['y'] || 0) - $tpl['y']-$tpl['h'])*@k))
      self._out(sprintf('/Matrix [1 0 0 1 %.5f %.5f]',-tpl['box']['x']*@k, -tpl['box']['y']*@k)) if tpl['box']
      self._out('/Resources ')
      if tpl['resources']
        @current_parser = tpl['parser']
        self.pdf_write_value(tpl['resources'])
      else
        self._out('<</ProcSet [/PDF /Text /ImageB /ImageC /ImageI]')
        if @_res['tpl'][tplidx]['fonts'].length > 0
          self._out('/Font <<')
          @_res['tpl'][tplidx]['fonts'].each { |font| self._out('/F' + font['i'] + ' ' + font['n'] + ' 0 R') }
          self._out('>>')
        end
        if has_images = @_res['tpl'][tplidx]['images'].length > 0 || has_tpls = @_res['tpl'][tplidx]['tpls'].length > 0
          self._out('/XObject <<')
          if has_images
            @_res['tpl'][tplidx]['images'].each { |image| self._out('/I' + image['i'] + ' ' + image['n'] + ' 0 R') }
          end
          
          if has_tpls
            @_res['tpl'][tplidx]['tpls'].each { |i, tpl| self._out(@tplprefix + i + ' ' + tpl['n'] + ' 0 R') }
          end
          
          self._out('>>')
        end
        self._out('>>')
      end
      self._out('/Length ' + p.length + ' >>')
  		self._putstream(p)
  		self._out('endobj')
  	end
  end
          
  def _newobj(obj_id=false, onlynewobj=false)
    obj_id = @n += 1 unless obj_id
    
    unless onlynewobj
      @offsets[obj_id] = @buffer.length
      self._out(obj_id + ' 0 obj')
      @_current_obj_id = obj_id
    end
  end
  
  def pdf_write_value(value)
    case value[0]
    when (PDF_TYPE_NUMERIC || PDF_TYPE_TOKEN) then self._out(value[1] + " ", false)
    when PDF_TYPE_ARRAY then
      self._out('[', false)
      value[1].times do |i|
        self.pdf_write_value(value[1][i])
      end
      self._out(']')
    when PDF_TYPE_DICTIONARY then
      # May not be implemented correctly
      self._out("<<",false)
      value[1].each do |k, v|
        self._out(k + ' ', false)
        self.pdf_write_value(v)
      end
      self._out('>>')    
    when PDF_TYPE_OBJREF then
      cpfn = @current_parser.filename
      if @_don_obj_stack[cpfn][value[1]]
        self._newobj(false, true)
        @_obj_stack[cpfn][value[1]] = [@n, value]
        @_don_obj_stack[cpfn][value[1]] = [@n, value]
      end
      objid = @_don_obj_stack[cpfn][value[1]][0]
      self._out("##{objid} 0 R")
    when PDF_TYPE_STRING then
      self._out('(' + value[1] + ')')
    when PDF_TYPE_STREAM then
      self.pdf_write_value(value[1])
      self._out('stream')
      self._out(value[2][1])
      self._out('endstream')
    when PDF_TYPE_HEX then
      self._out("<" + value[1] + ">")
    when PDF_TYPE_NULL then
      self._out("null");      
    end
  end
  
  def _out(s, ln=true)
    if @state == 2
      if !@_intpl
        @pages[@page] += s + (ln == true ? "\n" : '')
      else
        @tpls[@tpl]['buffer'] += s + (ln == true ? "\n" : '')
      end
    else
      @buffer += s + (ln == true ? "\n" : '')
    end
  end
  
  def _enddoc
    super
    self._closeParsers
  end
  
  def _closeParsers
    if @state > 2 && @parsers.length > 0
      @parsers.each do |k, v|
        @parsers[k].closeFile
        @parsers[k] = nil
      end
      true
    else
      false
    end
  end
end