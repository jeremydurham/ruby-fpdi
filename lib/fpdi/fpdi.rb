require File.dirname(__FILE__) + '/fpdf_tpl'
require File.dirname(__FILE__) + '/fpdi_pdf_parser'

class FPDI < FPDF_TPL
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
  VERSION = '1.2'
  
  attr_accessor :importVersion, :k

  def initialize(orientation='P', unit='mm', format='A4')
    @parsers = {}
    @_don_obj_stack = {}
    @_obj_stack = {}
    super(orientation, unit, format)
  end
  
  def setSourceFile(filename)
    @current_filename = filename
    fn = @current_filename
        
    @parsers[fn] = FPDIPDFParser.new(fn, self) unless @parsers[fn]
    
    @parsers[fn].getPageCount
  end
  
  def importPage(pageno, boxName='/CropBox')
    self.Error("Please import the desired pages before creating a new template.") if @_intpl
    
    fn = @current_filename
    parser = @parsers[fn]
    parser.setPageno(pageno)

    @tpl += 1
    @tpls[@tpl] = {}
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
    if rotation[1] && ((angle = rotation[1].to_i % 360) != 0)
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
    self.out('q 0 J 1 w 0 j 0 G')
    s = super(tplidx, _x, _y, _w, _h)
    self.out('Q')
    s
  end
  
  def putimportedobjects
    if @parsers.length > 0
      @parsers.each do |filename, p|
        @current_parser = @parsers[filename]
        if @_obj_stack[filename]
          @_obj_stack[filename].each_key do |n|
            nObj = @current_parser.pdf_resolve_object(@current_parser.c, @_obj_stack[filename][n][1])
            self.newobj(@_obj_stack[filename][n][0])
            
            if nObj['0'] == PDF_TYPE_STREAM
              self.pdf_write_value(nObj)
            else
              self.pdf_write_value(nObj['1'])
            end
            
            self.out('endobj')
          end
        end
      end
    end
  end

  def setVersion
    @PDFVersion = @importVersion > @PDFVersion ? @importVersion : @PDFVersion
  end
  
  def putresources
    self.putfonts
    self.putimages
    self.putformxobjects
    self.putimportedobjects
    @offsets[2] = @buffer.length
    self.out('2 0 obj')
    self.out('<<')
    self.putresourcedict
    self.out('>>')
    self.out('endobj')
  end
  
  def putformxobjects
    filter = @compress ? '/Filter /FlateDecode ' : ''
    @tpls.each do |tplidx, tpl|
      p = @compress ? Zlib::Deflate.deflate(tpl['buffer']) : tpl['buffer']
      self.newobj
      @tpls[tplidx]['n'] = @n
      self.out('<<' + filter + '/Type /XObject')
      self.out('/Subtype /Form')
      self.out('/FormType 1')
      self.out(sprintf('/BBox [%.2f %.2f %.2f %.2f]',
          (tpl['x'] + (tpl['box']['x'] || 0))*@k,
          (tpl['h'] + (tpl['box']['y'] || 0) - tpl['y'])*@k,
          (tpl['w'] + (tpl['box']['x'] || 0))*@k,
          (tpl['h'] + (tpl['box']['y'] || 0) - tpl['y']-tpl['h'])*@k))
      self.out(sprintf('/Matrix [1 0 0 1 %.5f %.5f]',-tpl['box']['x']*@k, -tpl['box']['y']*@k)) if tpl['box']
      self.out('/Resources ')
      
      if tpl['resources']
        @current_parser = tpl['parser']
        self.pdf_write_value(tpl['resources'])
      else
        self.out('<</ProcSet [/PDF /Text /ImageB /ImageC /ImageI]')
        if @_res['tpl'][tplidx]['fonts'].length > 0
          self.out('/Font <<')
          @_res['tpl'][tplidx]['fonts'].each { |font| self.out('/F' + font['i'] + ' ' + font['n'] + ' 0 R') }
          self.out('>>')
        end
        if has_images = @_res['tpl'][tplidx]['images'].length > 0 || has_tpls = @_res['tpl'][tplidx]['tpls'].length > 0
          self.out('/XObject <<')
          if has_images
            @_res['tpl'][tplidx]['images'].each { |image| self.out('/I' + image['i'] + ' ' + image['n'] + ' 0 R') }
          end
          
          if has_tpls
            @_res['tpl'][tplidx]['tpls'].each { |i, tpl| self.out(@tplprefix + i + ' ' + tpl['n'] + ' 0 R') }
          end
          
          self.out('>>')
        end
        self.out('>>')
      end
      self.out("/Length #{p.length} >>")
  		self.putstream(p)
  		self.out('endobj')
  	end
  end
          
  def newobj(obj_id=false, onlynewobj=false)
    obj_id = @n += 1 unless obj_id
    
    unless onlynewobj
      @offsets[obj_id] = @buffer.length
      self.out("#{obj_id} 0 obj")
      @_current_obj_id = obj_id
    end
  end
  
  def pdf_write_value(value)
    case value[0]
    when (PDF_TYPE_NUMERIC || PDF_TYPE_TOKEN) then self.out(value[1] + " ", false)
    when PDF_TYPE_ARRAY then
      self.out('[', false)
      value[1].length.times do |i|
        self.pdf_write_value(value[1][i])
      end
      self.out(']')
    when PDF_TYPE_DICTIONARY then
      # May not be implemented correctly
      self.out("<<",false)
      value[1].each do |k, v|
        self.out(k + ' ', false)
        self.pdf_write_value(v)
      end
      self.out('>>')    
    when PDF_TYPE_OBJREF then
      cpfn = @current_parser.filename
      if !@_don_obj_stack[cpfn] || !@_don_obj_stack[cpfn][value[1]]
        self.newobj(false, true)
        @_obj_stack[cpfn] ||= {}
        @_don_obj_stack[cpfn] ||= {}
        @_obj_stack[cpfn][value[1]] = [@n, value]
        @_don_obj_stack[cpfn][value[1]] = [@n, value]
      end
      objid = @_don_obj_stack[cpfn][value[1]][0]
      self.out("##{objid} 0 R")
    when PDF_TYPE_STRING then
      self.out('(' + value[1] + ')')
    when PDF_TYPE_STREAM then
      self.pdf_write_value(value[1])
      self.out('stream')
      self.out(value[2][1])
      self.out('endstream')
    when PDF_TYPE_HEX then
      self.out("<" + value[1] + ">")
    when PDF_TYPE_NULL then
      self.out("null");      
    end
  end
  
  def out(s, ln=true)
    if @state == 2
      if !@_intpl
        @pages[@page] += s + (ln == true ? "\n" : '')
      else
        @tpls[@tpl]['buffer'] += s + (ln == true ? "\n" : '')
      end
    else
      @buffer += s.to_s + (ln == true ? "\n" : '')
    end
  end
  
  def enddoc
    super
    self.closeParsers
  end
  
  def closeParsers
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