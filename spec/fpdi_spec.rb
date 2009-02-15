require 'rubygems'
require 'ruby-debug'
require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/../lib/fpdi/fpdi'

describe FPDI do    
  before do
    @pdf = FPDI.new
    @pdf.setSourceFile(File.dirname(__FILE__) + '/pdf/simple.pdf')
    tplidx = @pdf.importPage(1, '/MediaBox')
    @pdf.AddPage
    @pdf.useTemplate(tplidx, 10, 10, 90)        
  end
  
  it "should successfully parse a simple PDF" do
    @pdf.Output('test.pdf').should_not be_nil
  end
    
end
