require 'rails_helper'

RSpec.describe Correspondence, :type => :model do

  before(:each) do
    Correspondence.any_instance.stub(:add_to_alignment)
    @o1 = FactoryGirl.create(:ontology)
    @o2 = FactoryGirl.create(:ontology)
  end

  it "not create duplicate simple correspondences when providing them through different elements" do
    sn1 = FactoryGirl.create(:node, ontology: @o1)
    sn2 = FactoryGirl.create(:node, ontology: @o1)
    tn1 = FactoryGirl.create(:node, ontology: @o2)
    tn2 = FactoryGirl.create(:node, ontology: @o2)
    c1 = Correspondence.from_elements([sn1],[tn1])
    c2 = Correspondence.from_elements([sn2],[tn2])
    assert c1.is_a?(SimpleCorrespondence)
    assert_equal c1,c2
    assert_equal 1, Correspondence.count
  end

  it "should not create duplicate complex correspondences when providing them through different elements" do
    sn1 = FactoryGirl.create(:node, ontology: @o1)
    ac1 = FactoryGirl.create(:attribute_constraint, ontology: @o1, node: sn1)

    sn2 = FactoryGirl.create(:node, ontology: @o1)
    ac2 = FactoryGirl.create(:attribute_constraint, ontology: @o1, node: sn2)

    tn1 = FactoryGirl.create(:node, ontology: @o2)
    tn2 = FactoryGirl.create(:node, ontology: @o2)

    c1 = Correspondence.from_elements([sn1, ac1],[tn1])
    c2 = Correspondence.from_elements([sn2, ac2],[tn2])
    assert c1.is_a?(ComplexCorrespondence)
    assert_equal c1,c2
    assert_equal 1, Correspondence.count
  end

  it "should find candidates with exact matches" do
    sc = FactoryGirl.create(:simple_correspondence, onto1: @o1, onto2: @o2)
    cc = FactoryGirl.create(:complex_correspondence, onto1: @o1, onto2: @o2)
    hc = FactoryGirl.create(:hardway_complex, onto1: @o1, onto2: @o2)
    node = FactoryGirl.create(:node, rdf_type: sc.entity1)
    candidates = Correspondence.candidates_for(@o1,@o2,[node])
    expect(candidates[[node]]).to include(sc)
    expect(candidates[[node]]).to include(cc)
    expect(candidates[[node]]).to_not include(hc)
    expect(candidates.size).to eq(1)

    candidates = Correspondence.candidates_for(@o1,@o2,hc.entity1)
    expect(candidates[hc.entity1]).to_not include(sc)
    expect(candidates[hc.entity1]).to_not include(cc)
    expect(candidates[hc.entity1]).to include(hc)
    expect(candidates.size).to eq(1)
  end

  it "should ignore superset matches" do
    sc = FactoryGirl.create(:simple_correspondence, onto1: @o1, onto2: @o2)
    cc = FactoryGirl.create(:complex_correspondence, onto1: @o1, onto2: @o2)
    hc = FactoryGirl.create(:hardway_complex, onto1: @o1, onto2: @o2)
    node = FactoryGirl.create(:node, rdf_type: sc.entity1)

    candidates = Correspondence.candidates_for(@o1,@o2,[node])
    expect(candidates[[node]]).to include(sc)
    expect(candidates[[node]]).to include(cc)
    expect(candidates[[node]]).to_not include(hc)
    expect(candidates.size).to eq(1)
  end

  it "should include subset matches" do
    sc = FactoryGirl.create(:simple_correspondence, onto1: @o1, onto2: @o2)
    cc = FactoryGirl.create(:complex_correspondence, onto1: @o1, onto2: @o2)
    hc = FactoryGirl.create(:hardway_complex, onto1: @o1, onto2: @o2)
    node = FactoryGirl.create(:node, rdf_type: sc.entity1)

    # subset matches
    candidates = Correspondence.candidates_for(@o1,@o2,hc.entity1 + [node])
    expect(candidates.values.flatten).to include(sc)
    expect(candidates.values.flatten).to include(cc)
    expect(candidates.values.flatten).to include(hc)
    expect(candidates.size).to eq(2)

    candidates = Correspondence.candidates_for(@o1,@o2,hc.entity1.select{|el| el.is_a?(RelationConstraint)})
    expect(candidates).to be_empty
  end

  it "should not be fooled by two identical subsets" do
    sc = FactoryGirl.create(:simple_correspondence, onto1: @o1, onto2: @o2)
    node1 = FactoryGirl.create(:node, rdf_type: sc.entity1)
    node2 = FactoryGirl.create(:node, rdf_type: sc.entity1)
    candidates = Correspondence.candidates_for(@o1,@o2,[node1, node2])
    expect(candidates[[node1, node2]]).to be_nil
    expect(candidates.size).to eq(2)
  end

  it "should create proper strings for different input elements" do
    nrnp = FactoryGirl.create(:n_r_n_pattern)
    nrnp.nodes.last.rdf_type += "2"
    string = Correspondence.key_for_entity(nrnp.pattern_elements)
    expect(string).to eq("#{nrnp.nodes.first.rdf_type}-#{nrnp.relation_constraints.first.rdf_type}->#{nrnp.nodes.last.rdf_type}")
    string2 = Correspondence.key_for_entity(nrnp.nodes)
    expect(string2).to eq("#{nrnp.nodes.first.rdf_type}||#{nrnp.nodes.last.rdf_type}")
    string3 = Correspondence.key_for_entity([nrnp.nodes.first, nrnp.relation_constraints.first])
    expect(string3).to eq("#{nrnp.nodes.first.rdf_type}-#{nrnp.relation_constraints.first.rdf_type}")
  end

  it "should provide the same candidates for multiple subnodes" do
    pattern = FactoryGirl.create(:n_r_n_pattern)
    pattern.nodes.last.rdf_type += "2"
    hc = FactoryGirl.create(:hardway_complex, onto1: @o1, onto2: @o2, entity1: pattern.pattern_elements)
    sc = FactoryGirl.create(:simple_correspondence, onto1: @o1, onto2: @o2, entity1: pattern.nodes.first.rdf_type)
    candidates = Correspondence.candidates_for(@o1,@o2,pattern.pattern_elements)
    expect(candidates[[pattern.nodes.first]]).to include(sc)
    expect(candidates[pattern.pattern_elements]).to include(hc)
    expect(candidates.size).to eq(2)
  end

  it "should remove a correspondence from the alignment if we destroy it in our database" do
    corr1 = FactoryGirl.create(:simple_correspondence, onto1: @o1, onto2: @o2)
    corr2 = FactoryGirl.create(:simple_correspondence, onto1: @o1, onto2: @o2)
    expect(corr1.ontology_matcher).to receive(:remove_correspondence!)
    corr1.destroy
    expect(corr2.ontology_matcher).to receive(:remove_correspondence!)
    corr2.destroy
  end
end
