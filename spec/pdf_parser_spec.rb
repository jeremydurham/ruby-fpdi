require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/../lib/fpdi/pdf_parser'

describe PDFParser do
  describe PDFParser, "parsing PDFs" do
    it "should error when given an encrypted PDF" do      
      lambda { PDFParser.new(File.dirname(__FILE__) + '/pdf/encrypted.pdf') }.should raise_error(RuntimeError, 'FPDI error: File is encrypted')
    end
  end    
end