require 'fpdf_tpl'
require 'fpdi_pdf_parser'

class FPDI < FPDF_TPL
  FPDI_VERSION = '1.2.1'
  
  def initialize
    @_importedPages = []
  end
  
  def setSourceFile(filename)
    @current_filename = filename
    fn = @current_filename
    @parsers[fn] = FPDI_PDF_Parser.new(fn, self)
    @current_parser = @parsers[fn]    
    @parsers[fn].getPageCount
  end
  
  def importPage(pageno)
    fn = @current_filename
    @parsers[fn].setPageNo(pageno)
    @tpl += 1
    @tpls[@tpl] = []
    @tpls[@tpl]['parser'] = @parsers[fn]
    @tpls[@tpl]['resources'] = @parsers[fn].getPageResources
    @tpls[@tpl]['buffer'] = @parsers[fn].getContent
    mediabox = @parsers[fn].getPageMediaBox(pageno)
    @tpls[@tpl] = @tpls[@tpl].update(mediabox)
    
    @tpl
  end
  
  def _putOobjects
    if (@parsers.is_a?(Array) && @parsers.length > 0)
      @parsers.each do |filename, p|
        @current_parser = @parsers[filename]
        if (@obj_stack[filename].is_a?(Array))
          @obj_stack[filename].each do |n|
            nObj = @current_parser.pdf_resolve_object(@current_parser.c, @obj_stack[filename][n][1])
            _newobj(@obj_stack[filename][n][1])
            if nObj[0] == 10
              pdf_write_value(nObj)
            else
              pdf_write_value(nObj[1])
            end
            
            _out('endobj')
            @obj_stack[filename][n] = nil
          end
        end
      end
    end
  end
  
  def _begindoc
    @state = 1
  end
  
  def setVersion
    if @importVersion > @PDFVersion
      @PDFVersion = @importVersion
      
      if self.respond_to?(:_putheader)
        @buffer = '%PDF-' + @PDFVersion + "\n" + @buffer
      end
    end
  end

  def _enddoc
    setVersion
    super
  end
  
  def _putresources
    _putfonts
    _putimages
    _puttemplates
    _putOobjects
    
    @offsets[2] = @buffer.length
    _out('2 0 obj')
    _out('<</ProcSet [/PDF /Text /ImageB /ImageC /ImageI]')
    _out('/Font <<')
    @fonts.each do |font|
      _out(@fontprefix + font['i'] + ' ' + font['n'] + ' 0 R')
    end
    _out('>>')
    if @images.count || @tpls.count
      _out('/XObject <<')
      if @images.count
        @images.each do |image|
          _out('/I' + image['i'] + ' ' + image['n'] + ' 0 R')
    		end
    	end
    	if @tpls.count
    	  @tpls.each do |tplidx, tpl|
    	    _out(@tplprefix + tplidx + ' ' + tpl['n'] + ' 0 R')
    		end
    	end
    	_out('>>')
    end
    _out('>>')
    _out('endobj')
  end
      
end