require File.dirname(__FILE__) + '/pdf_parser'

class FPDIPDFParser < PDFParser
  attr_accessor :fpdi, :availableBoxes
  
  def initialize(filename, fpdi)
    @availableBoxes = ['/MediaBox','/CropBox','/BleedBox','/TrimBox','/ArtBox']
    @fpdi = fpdi
    @filename = filename
    @pages = []
    super(filename)
    pages = self.pdf_resolve_object(@c, @root[1][1]['/Pages'])
    self.read_pages(@c, pages, @pages)
    @page_count = @pages.length
  end
  
  def Error(msg)
    self.fpdi.Error(msg)
  end
  
  def getPageCount
    @page_count
  end
  
  def setPageno(pageno)
    pageno = pageno - 1
    if pageno < 0 || pageno >= self.getPageCount
      self.fpdi.Error("Pagenumber is wrong!")
    end
    
    @pageno = pageno
  end
  
  def getPageResources
    self._getPageResources(@pages[@pageno])
  end
  
  def _getPageResources(obj)
    obj = self.pdf_resolve_object(@c, obj)
    if obj[1][1]['/Resources']
      res = self.pdf_resolve_object(@c, obj[1][1]['/Resources'])
      return res[1] if res[0] == PDF_TYPE_OBJECT
      return res
    else
      unless obj[1][1]['/Parent']
        return false
      else
        res = self._getPageResources(obj[1][1]['/Parent'])
        return res[1] if res[0] == PDF_TYPE_OBJECT        
        return res
      end
    end
  end
  
  def getContent
    buffer = ''
    
    if @pages[@pageno][1][1]['/Contents']
      contents = self._getPageContent(@pages[@pageno][1][1]['/Contents'])
      contents.each { |tmp_content| buffer += self._rebuildContentStream(tmp_content) + ' ' }
    end
    
    buffer
  end
  
  def _getPageContent(content_ref)
    contents = []
        
    if content_ref[0] == PDF_TYPE_OBJREF
      content = self.pdf_resolve_object(@c, content_ref)
      if content[1][0] == PDF_TYPE_ARRAY
        contents = self._getPageContent(content[1])
      else
        contents.push(content)
      end
    elsif content_ref[0] == PDF_TYPE_ARRAY
      content_ref.each { |tmp_content_ref| contents.update(self._getPageContent(tmp_content_ref)) }
    end
    
    contents
  end

  def _rebuildContentStream(obj)
    filters = []
    
    if obj[1][1]['/Filter']
      _filter = obj[1][1]['/Filter']
      
      if _filter[0] == PDF_TYPE_TOKEN
        filters.push(_filter)
      elsif _filter[0] == PDF_TYPE_ARRAY
        filters = _filter[1]
      end
    end

    stream = obj[2][1]
    
    filters.each do |filter|
      case _filter[1]
      when '/FlateDecode' then stream = Zlib::Deflate.deflate(stream)
      when nil then stream = stream
      else
        if filterName = _filter[1].match(/^\/[a-z85]*$/i)
          filterName = _filter[1][1..-1]
          # Load filter class
          # decoder = filterName.new(fpdi)          
          stream = decoder.decode(stream)
        else
          self.fpdi.Error(sprintf("Unsupported Filter: %s",_filter[1]))
        end
      end
    end
    
    stream
  end
  
  def getPageBox(page, box_index)
    page = self.pdf_resolve_object(@c, page)
    box = nil
    box = page[1][1][box_index] if page[1][1][box_index]
    
    if box && box[0] == PDF_TYPE_OBJREF
      tmp_box = self.pdf_resolve_object(@c, box)
      box = tmp_box[1]
    end
    
    if box && box[0] == PDF_TYPE_ARRAY
      b = box[1]
      return {
              "x" => b[0][1].to_i / self.fpdi.k.to_i,
              "y" => b[1][1].to_i / self.fpdi.k.to_i,
              "w" => ((b[0][1].to_i - b[2][1].to_i)/self.fpdi.k.to_i).abs,
              "h" => ((b[1][1].to_i - b[3][1].to_i)/self.fpdi.k.to_i).abs
              }
    elsif !page[1][1]['/Parent']
      return false
    else
      self.getPageBox(self.pdf_resolve_object(@c, page[1][1]['/Parent']), box_index)
    end
  end
  
  def getPageBoxes(pageno)
    self._getPageBoxes(@pages[@pageno - 1])
  end
  
  def _getPageBoxes(page)
    boxes = []
    
    @availableBoxes.each do |box|
      if _box = self.getPageBox(page, box)
        boxes[box] = _box
      end
    end
    
    boxes
  end
      
  def getPageRotation(pageno)
    self._getPageRotation(@pages[pageno - 1])
  end
  
  def _getPageRotation(obj)
    obj = self.pdf_resolve_object(@c, obj)
    if obj[1][1]['/Rotate']
      res = self.pdf_resolve_object(@c, obj[1][1]['/Rotate'])
      return res[1] if res[0] == PDF_TYPE_OBJECT
      return res
    else
      if obj[1][1]['/Parent']
        return false
      else
        res = self._getPageRotation(obj[1][1]['/Parent'])
        return res[1] if res[0] == PDF_TYPE_OBJECT
        return res
      end
    end
  end
  
  def read_pages(c, pages, result)
    kids = self.pdf_resolve_object(c, pages[1][1]['/Kids'])
    
    if !kids.is_a?(Array)
      self.fpdi.Error('Cannot find /Kids in current /Page-Dictionary')
    else
      kids[1].each do |v|
        pg = self.pdf_resolve_object(c, v)
        if pg[1][1]['/Type'][1] == '/Pages'          
          self.read_pages(c, pg, result)
        else
          result.push(pg)
        end
    	end
    end
  end

  def getPDFVersion
    super
    
    if self.fpdi.importVersion && self.pdfVersion > self.fpdi.importVersion
      self.fpdi.importVersion = self.pdfVersion
    end
  end
end