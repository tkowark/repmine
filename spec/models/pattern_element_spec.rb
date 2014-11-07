require 'rails_helper'

RSpec.describe PatternElement, :type => :model do
  
  it "should overwrite simple rdf_types" do 
    @pe = FactoryGirl.create(:pattern_element)
    assert_equal "http://example.org/generic_element", @pe.rdf_type
    @pe.rdf_type = "http://example.org/MyType2"
    assert_equal "http://example.org/MyType2", @pe.rdf_type
  end
  
  it "should also overwrite complex ones" do
    @pe = FactoryGirl.create(:pattern_element)
    @pe.type_expression.update_attributes(:operator => OwlClass::SET_OPS[:not])
    assert_equal "#{OwlClass::SET_OPS[:not]}http://example.org/generic_element", @pe.rdf_type
    assert_equal false, @pe.type_expression.is_simple?
    @pe.rdf_type = "http://example.org/MyType2"
    assert_equal "http://example.org/MyType2", @pe.rdf_type  
  end
  
  it "should create a proper element for a given rdf type" do
    @pe = PatternElement.for_rdf_type("http://example.org/fancy_type")
    assert_equal "http://example.org/fancy_type", @pe.rdf_type
  end
  
  it "should create just what you want it to be" do
    assert Node.for_rdf_type("http://example.org/fancy_type").is_a?(Node)
    assert AttributeConstraint.for_rdf_type("http://example.org/fancy_type").is_a?(AttributeConstraint)
    assert RelationConstraint.for_rdf_type("http://example.org/fancy_type").is_a?(RelationConstraint)        
  end
  
end