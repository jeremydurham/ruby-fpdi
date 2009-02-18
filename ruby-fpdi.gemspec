# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{ruby-fpdi}
  s.version = '0.0.1'

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Jeremy Durham"]
  s.date = %q{2009-02-17}
  s.description = %q{PDF Importer for Ruby}
  s.email = %q{jeremydurham@gmail.com}
  s.extra_rdoc_files = ["README", "LICENSE"]
  s.files = ["lib/fpdi.rb", "lib/fpdi/fpdf.rb", "lib/fpdi/fpdf_tpl.rb", "lib/fpdi/fpdi_pdf_parser.rb", 
             "lib/fpdi/pdf_context.rb", "lib/fpdi/pdf_parser.rb", "spec/fpdf_tpl_spec.rb", 
             "spec/fpdi_pdf_parser_spec.rb", "spec/fpdi_spec.rb", "spec/pdf_context_spec.rb", 
             "spec/pdf_parser_spec.rb", "spec/spec_helper.rb", "spec/pdf/encrypted.pdf", "spec/pdf/simple.pdf"]
  s.has_rdoc = true
  s.homepage = %q{}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{PDF Importer for Ruby}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<facets>, [">= 0"])
    else
      s.add_dependency(%q<facets>, [">= 0"])
    end
  else
    s.add_dependency(%q<facets>, [">= 0"])
  end
end
