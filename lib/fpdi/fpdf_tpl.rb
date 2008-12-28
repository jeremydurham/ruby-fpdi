require 'fpdf'

class FPDF_TPL < FPDF
  def initialize
    @tpls = []
    @tpl = 0
    @_intpl = false
    @tplprefix = '/TPL'
    @_res = []
  end

  def beginTemplate(x=nil,y=nil,w=nil,h=nil)
    self.Error('You have to add a page to fpdf first!') if @page <= 0
    x ||= 0
    y ||= 0
    w ||= @w
    h ||= @h
    @tpl += 1
    tpl = @tpls[@tpl]
    tpl = ['o_x' => @x,
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
           'h' => h]
           
    SetAutoPageBreak(false)
    
    @h = h
    @w = w
    
    @_intpl = true
    SetXY(x + @lMargin, y + @tMargin)
    SetRightMargin(@w - w + @rMargin)
    
    @tpl    
  end
  
  def endTemplate
    if @_intpl
      @_intpl = false
      tpl = @tpls[@tpl]
      SetXY(tpl['o_x'], tpl['o_y'])
      @tMargin = tpl['o_tMargin']
      @lMargin = tpl['o_lMargin']
      @rMargin = tpl['o_rMargin']
      @h = tpl['o_h']
      @w = tpl['o_w']
      SetAutoPageBreak(tpl['o_AutoPageBreak'], tpl['o_bMargin'])
      @tpl
    else
      false
    end
  end
  
  def useTemplate(tplidx, _x=nil, _y=nil, _w=0, _h=0)
    self.Error("You have to add a page to fpdf first!") if @page <= 0
    self.Error("Template does not exist!") unless @tpls[tplidx]
    @_res['tpl'][@tpl]['tpls'][tplidx] = @tpls[tplidx] if @_intpl
    tpl = @tpls[tplidx]
    x = tpl['x']
    y = tpl['y']
    w = tpl['w']
    h = tpl['h']
    _x ||= x
    _y ||= y
    wh = getTemplateSize(tplidx, _w, _h)
    _w = wh['w']
    _h = wh['h']
      
    out(sprintf("q %.4f 0 0 %.4f %.2f %.2f cm", (_w/w), (_h/h), _x*@k, (@h - (_y + _h)) * @k))
    out(@tplprefix + tplidx + " Do Q")
    
    ['w' => _w, 'h' => _h]
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
    
    _w = (_h * w/h) if _w == 0
    _h = (_w * h/w) if _h == 0

    ['w' => _w, 'h' => _h]
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
  
  def Image(file, x, y, w=0, h=0, type='', link='', align='', resize=false, dpi=300)
    super(file, x, y, w, h, type, link, align, resize, dpi)
    if @_intpl
      @_res['tpl'][@tpl]['images'][file] = @images[file]
    else
      @_res['page'][@page]['images'][file] = @images[file]
    end
  end
  
  def AddPage(orientation='', format='')
    self.Error("Adding pages in templates isn't possible!") if @_intpl
    super(orientation, format)
  end

  def Link(x, y, w, h, link)
    self.Error("Using links in templates isn't possible!") if @_intpl
    super(x, y, w, h, link)
  end
  
  def AddLink
    self.Error("Adding links in templates isn't possible!") if @_intpl
    super
  end

  def setLink(link, y=0, page=-1)
    self.Error("Setting links in templates isn't possible!") if @_intpl
    super(link, y, page)
  end

  def putformxobjects
    filter = @compress ? '/Filter /FlateDecode ' : ''
    @tpls.each do |tplidx,tpl|
      p = @compress ? Zlib::Deflate.deflate(tpl['buffer']) : tpl['buffer']
      newobj
      @tpls[tplidx]['n'] = @n
      out('<<' + filter + '/Type /XObject')
      out('/FormType 1')
      out(sprintf('/BBox [%.2f %.2f %.2f %.2f]',tpl['x'] * @k, (tpl['h'] - tpl['y']) * @k, tpl['w'] * @k, (tpl['h'] - tpl['y'] - tpl['h']) * @k))
      out('/Resources ')
      out('<</ProcSet [/PDF /Text /ImageB /ImageC /ImageI]');
      if @_res['tpl'][tplidx]['fonts'] && @_res['tpl'][tplidx]['fonts'].size > 0
        out('/Font <<')
        @_res['tpl'][tplidx]['fonts'].each do |font|
          out('/F' + font['i'] + ' ' + font['n'] + ' 0 R')
        end
        out('>>')
      end
      if @_res['tpl'][tplidx]['images'] && @_res['tpl'][tplidx]['images'].size > 0 && @_res['tpl'][tplidx]['tpls'] && @_res['tpl'][tplidx]['tpls'].size > 0
         out('/XObject <<')
         if @_res['tpl'][tplidx]['images'] && @_res['tpl'][tplidx]['images'].size > 0
           @_res['tpl'][tplidx]['images'].each do |image|
             out('/I' + image['i'] + ' ' + image['n'] + ' 0 R')
          end
        end
        if @_res['tpl'][tplidx]['tpls'] && @_res['tpl'][tplidx]['tpls'].size > 0
          @_res['tpl'][tplidx]['tpls'].each do |i, tpl|
            out(@tplprefix + i + ' ' + tpl['n'] + ' 0 R')
          end
        end
        out('>>')        
      end
      out('>>')
      out('/Length ' + p.length.to_s + ' >>')
      putstream(p)      
      out('endobj')
    end
  end

  def putresources
    putextgstates
    putocg
    putfonts
    putimages
    putshaders
    putformxobjects
    @offsets[2] = @buffer.length
    out('2 0 obj')
    out('<<')
    putresourcedict
    out('>>')
    out('endobj')
    putjavascript
    putbookmarks
    if @encrypted
      newobj
      @enc_obj_id = @n
      obj('<<')
      putencryption
      out('>>')
      out('endobj')
    end
  end
  
  def putxobjectdict
    super
    
    if @tpls.length > 0
      @tpls.each do |tplidx, tpl|
        out(@tplprefix + tplidx + ' ' + tpl['n'] + ' 0 R')
      end
    end
  end

  def out(s)
    if (@state == 2 && @_intpl)
      @tpls[@tpl]['buffer'] << s + "\n"
    else
      super(s)
    end
  end
 
end