require 'rails_helper'

RSpec.describe Ontology, :type => :model do
  it "should not be able to save an ontology if it cannot be downloaded to the repository" do
    Ontology.any_instance.unstub(:download!)
    Ontology.any_instance.unstub(:load_to_dedicated_repository!)
    ont = Ontology.new(url: "http://example.org")
    ont.stub(:repository_name => "__XX__TEST__")
    ont.stub(:download!).and_raise("something is wrong ...")
    assert !ont.save
    assert_not_empty ont.errors[:url]
  end
end