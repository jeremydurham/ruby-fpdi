require File.dirname(__FILE__) + '/fpdf'

class FPDF_TPL < FPDF
  FPDF_TPL_VERSION = '1.1.1'
  
  def initialize(orientation='P', unit='mm', format='A4')
    @tpls = {}
    @tpl = 0
    super(orientation, unit, format)
  end
  
  def beginTemplate(x=nil, y=nil, w=nil, h=nil)
    self.Error('You have to add a page to fpdf first!') if @page.to_i <= 0
    
    x ||= 0
    y ||= 0
    w ||= @w
    h ||= @h
    
    @tpl += 1
    tpl = @tpls[@tpl]
    tpl = {
      'o_x' => @x,
      'o_y' => @y,
      'o_AutoPageBreak' => @AutoPageBreak,
      'o_bMargin' => @bMargin,
      'o_tMargin' => @tMargin,
      'o_lMargin' => @lMargin,
      'o_rMargin' => @rMargin,
      'o_h' => @h,
      'o_w' => @w,
      'buffer' => '',
      'x' => x,
      'y' => y,
      'w' => w,
      'h' => h
    }
    
    self.SetAutoPageBreak(false)
    @h = h
    @w = w
    
    @_intpl = true
    self.SetXY(x + @lMargin, y + @tMargin)
    self.SetRightMargin(@w - w + @rMargin)
    
    @tpl
  end

  def endTemplate
    return false unless @_intpl
    
    tpl = @tpls[@tpl]
    self.SetXY(tpl['o_x'], tpl['o_y']);
    @tMargin = tpl['o_tMargin'];
    @lMargin = tpl['o_lMargin'];
    @rMargin = tpl['o_rMargin'];
    @h = tpl['o_h'];
    @w = tpl['o_w'];
    self.SetAutoPageBreak(tpl['o_AutoPageBreak'], tpl['o_bMargin']);
    
    @tpl
  end
  
  def useTemplate(tplidx, _x=nil, _y=nil, _w=0, _h=0)
    self.Error("You have to add a page to fpdf first!") if @page.to_i <= 0    
    self.Error("Template does not exist!") unless @tpls[tplidx]

    @_res['tpl'][@tpl]['tpls'][tplidx] = @tpls[tplidx] if @_intpl
    
    tpl = @tpls[tplidx]
    x = tpl['x']
    y = tpl['y']
    w = tpl['w']
    h = tpl['h']
    
    _x ||= x
    _y ||= y
    
    wh = self.getTemplateSize(tplidx, _w, _h)
    _w = wh['w']
    _h = wh['h']
    
    self._out(sprintf("q %.4f 0 0 %.4f %.2f %.2f cm", (_w/w), (_h/h), _x*@k, (@h-(_y+_h))*@k))
    self._out(@tplprefix + tplidx + " Do Q")

    { 'w' => _w, 'h' => _h }    
  end
  
  def getTemplateSize(tplidx, _w=0, _h=0)
    return false unless @tpls[tplidx]
    
    tpl = @tpls[tplidx]
    w = tpl['w']
    h = tpl['h']
    
    if (_w == 0 && _h == 0)
      _w = w
      _h = h
    end
    
    _w = _h * (w/h) if _w == 0
    _h = _w * (h/w) if _h == 0  
  
    { 'w' => _w, 'h' => _h }
  end
  
  def SetFont(family, style='', size=0)
    @FontFamily = '' if @_intpl
    
    super(family, style, size)
    fontkey = @FontFamily + @FontStyle
    
    if @_intpl
      @_res['tpl'][@tpl]['fonts'][fontkey] = @fonts[fontkey]
    else
      @_res['page'][@page]['fonts'][fontkey] = @fonts[fontkey]
    end
  end
  
  def Image(file, x, y, w=0, h=0, type='', link='')
    super(file, x, y, w, h, type, link)
    if @_intpl
      @_res['tpl'][@tpl]['images'][file] = @images[file]
    else
      @_res['page'][@page]['images'][file] = @images[file]
    end
  end
  
  def AddPage(orientation='')
    self.Error("Adding pages in templates isn't possible!") if @_intpl
    super(orientation)
  end

  def Link(x, y, w, h, link)
    self.Error("Adding links in templates isn't possible!") if @_intpl
    super(x, y, w, h, link)
  end

  def AddLink
    self.Error("Adding links in templates aren't possible!") if @_intpl
    super
  end

  def SetLink(link, y=0, page=-1)
    self.Error("Setting links in templates aren't possible!") if @_intpl
    super(link, y, page)
  end
  
  def _putformxobjects
    filter = @compress ? '/Filter /FlateDecode ' : ''
    # reset @tpls
    @tpls.each do |tplidx, tpl|
      p = @compress ? Zlib::Deflate.deflate(tpl['buffer']) : tpl['buffer']
      self._newobj
      @tpls[tplidx]['n'] = @n
      self._out('<<' + filter + '/Type /XObject')
      self._out('/Subtype /Form')
      self._out('/FormType 1')
      self._out(sprintf('/BBox [%.2f %.2f %.2f %.2f]',tpl['x'] * @k, (tpl['h'] - tpl['y']) * @k, tpl['w'] * @k, (tpl['h'] - tpl['y'] - tpl['h']) * @k))
      self._out('/Resources ')
      self._out('<</ProcSet [/PDF /Text /ImageB /ImageC /ImageI]')
    
      if @_res['tpl'][tplidx]['fonts'] && @_res['tpl'][tplidx]['fonts'].length > 0
        self._out('/Font <<')
        @_res['tpl'][tplidx]['fonts'].each { |font| self._out('/F' + font['i'] + ' ' + font['n'] + ' 0 R') }
        self.out('>>')
      end
      
      if (@_res['tpl'][tplidx]['images'] && @_res['tpl'][tplidx]['images'].length > 0) || (@_res['tpl'][tplidx]['tpls'] && @_res['tpl'][tplidx]['tpls'].length > 0)
        self._out('/XObject <<')
        
        if @_res['tpl'][tplidx]['images'] && @_res['tpl'][tplidx]['images'].length > 0
          @_res['tpl'][tplidx]['images'].each { |image| self._out('/I' + image[i] + ' ' + image['n'] + ' 0 R') }
        end
        
        if @_res['tpl'][tplidx]['tpls'] && @_res['tpl'][tplidx]['tpls'].length > 0
          @_res['tpl'][tplidx]['tpls'].each { |i| self._out('/TPL' + i + ' ' + tpl['n'] + ' 0 R') }
        end
        self._out('>>')
      end
      self._out('>>')
      self._out('/Length ' + p.length + ' >>')
      self._putstream(p)
      self._out('endobj')
    end
  end
          
  def _putresources
    self._putfonts
    self._putimages
    self._putformxobjects
    self.offsets[2] = @buffer.length
    self._out('2 0 obj')
    self._out('<<')
    self._putresourcedict
    self._out('>>')
    self._out('endobj')
  end
  
  def _putxobjectdict
    super
    
    if @tpls.length > 0
      @tpls.each do |tplidx, tpl|
        self._out('/TPL' + tplidx + ' ' + tpl['n'] + ' 0 R')
      end
    end
  end
  
  def _out(s)
    if @state == 2
      unless @_intpl
        @pages[@page] += s + "\n"
      else
        @tpls[@tpl]['buffer'] += s + "\n"
      end
    else
      @buffer += s + "\n"
    end
  end  
end