require 'rails_helper'

RSpec.describe TranslationPattern, :type => :model do

  before(:each) do
    @pattern = FactoryGirl.create(:pattern)
    @source_ontology = @pattern.ontologies.first
    @target_ontology = FactoryGirl.create(:ontology, :url => "http://example.org/ontology2")
    AgraphConnection.any_instance.stub(:element_class_for_rdf_type => Node)
  end

  it "should create an empty pattern if no correspondences exist" do
    om = ontology_matcher([])
    tp = TranslationPattern.for_pattern_and_ontologies(@pattern, [@target_ontology])
    tp.prepare!
    assert_empty tp.nodes
    assert_empty tp.pattern_elements
  end

  it "should create corresponding elements for simple correspondences" do
    # let's translate the first node
    correspondence = FactoryGirl.create(:simple_correspondence, :onto1 => @source_ontology, :onto2 => @target_ontology)
    om = ontology_matcher([correspondence])
    assert @pattern.pattern_elements.none?{|pe| pe.rdf_type == correspondence.entity1}
    @pattern.nodes.first.update_attributes(rdf_type: correspondence.entity1)
    tp = TranslationPattern.for_pattern_and_ontologies(@pattern, [@target_ontology])
    tp.prepare!

    assert_equal 1, tp.pattern_elements.size
    assert_equal correspondence.entity2, tp.pattern_elements.first.rdf_type
  end

  it "should create corresponding elements for complex correspondences" do
    correspondence = FactoryGirl.create(:complex_correspondence, :onto1 => @source_ontology, :onto2 => @target_ontology)
    om = ontology_matcher([correspondence])
    assert @pattern.pattern_elements.none?{|pe| pe.rdf_type == correspondence.entity1}
    @pattern.nodes.first.update_attributes(rdf_type: correspondence.entity1)
    @tp = TranslationPattern.for_pattern_and_ontologies(@pattern, [@target_ontology])
    @tp.prepare!
    assert @tp.pattern_elements.all?{|pe| correspondence.entity2.any?{|ce| ce.equal_to?(pe)}}
    # rspec seems to not properly reload has_many relations so we have to do that manually...
    @tp.pattern_elements.reload
    @tp.pattern_elements.none?{|pe| pe.pattern.nil?}
  end

  it "should raise an exception if one element could be mapped to two different target structures" do
    correspondence1 = FactoryGirl.create(:simple_correspondence, onto1: @source_ontology, onto2: @target_ontology, entity1: @pattern.nodes.first.rdf_type)
    correspondence2 = FactoryGirl.create(:hardway_complex, onto1: @source_ontology, onto2: @target_ontology)
    om = ontology_matcher([correspondence1, correspondence2])
    tp = TranslationPattern.for_pattern_and_ontologies(@pattern, [@target_ontology])
    expect{tp.prepare!}.to raise_error(TranslationPattern::AmbiguousTranslation)
  end

  it "should determine whether a requested translation already exists and return that instead of a new one" do
    p1 = FactoryGirl.create(:pattern)
    tp1 = TranslationPattern.new(:name => "translation", :description => "just that", :pattern_id => p1.id)
    tp1.ontologies << FactoryGirl.create(:ontology)
    tp1.save

    # simple case - equal ontologies, go for it
    assert_equal tp1, TranslationPattern.for_pattern_and_ontologies(p1, tp1.ontologies)
    # more tricky - the new target is a superset. In that case, the old pattern suffices but should get the new ontology in addition
    o1 = FactoryGirl.create(:ontology)
    tp2 = TranslationPattern.for_pattern_and_ontologies(p1, tp1.ontologies + [o1])
    assert_equal tp1, tp2
    assert_equal tp1.ontologies + [o1], tp2.ontologies
    # finally, we need a new pattern at some point...
    o3 = FactoryGirl.create(:ontology)
    tp3 = TranslationPattern.for_pattern_and_ontologies(p1, [o3])
    assert_not_equal tp3, tp1
  end

  it "should be able to mix it up... " do
    correspondence1 = FactoryGirl.create(:simple_correspondence, :onto1 => @source_ontology, :onto2 => @target_ontology)
    correspondence2 = FactoryGirl.create(:hardway_complex, :onto1 => @source_ontology, :onto2 => @target_ontology)
    om = ontology_matcher([correspondence1, correspondence2])
    new_node = @pattern.create_node!(@pattern.ontologies.first)
    new_node.update_attributes(rdf_type: correspondence1.entity1)
    tp = TranslationPattern.for_pattern_and_ontologies(@pattern, [@target_ontology])
    tp.prepare!
    # there should be one node comming from the simple correspondence and one from the hardway
    assert_equal 2, tp.pattern_elements.size
  end

  it "should properly attach elements to the translation pattern" do
    correspondence = FactoryGirl.create(:hardway_complex, :onto1 => @source_ontology, :onto2 => @target_ontology)
    om = ontology_matcher([correspondence])
    tp = TranslationPattern.for_pattern_and_ontologies(@pattern, [@target_ontology])
    tp.prepare!
    assert_equal tp, tp.pattern_elements.first.pattern
  end

  it "should properly set that elements have already been matched" do
    correspondence = FactoryGirl.create(:hardway_complex, :onto1 => @source_ontology, :onto2 => @target_ontology)
    om = ontology_matcher([correspondence])
    tp = TranslationPattern.for_pattern_and_ontologies(@pattern, [@target_ontology])
    tp.prepare!
    assert_equal 3, @pattern.matched_elements([@target_ontology]).size
  end

  it "should be able to extend if we suddenly know of a new correspondence" do
    correspondence1 = FactoryGirl.create(:hardway_complex, :onto1 => @source_ontology, :onto2 => @target_ontology)
    om = ontology_matcher([correspondence1])
    new_node = @pattern.create_node!(@source_ontology)
    new_node.update_attributes(rdf_type: "unmatchable")

    tp = TranslationPattern.for_pattern_and_ontologies(@pattern, [@target_ontology])
    tp.prepare!

    # the unmatchable should not be matched
    assert_equal 1, @pattern.unmatched_elements([@target_ontology]).size
    assert_equal new_node, @pattern.unmatched_elements([@target_ontology]).first
    assert_equal 1, tp.pattern_elements.size

    # adding a new correspondence
    corr2 = FactoryGirl.create(:simple_correspondence, :onto1 => @source_ontology, :onto2 => @target_ontology)
    # now we change the rdf type on one node
    @pattern.nodes.last.update_attributes(rdf_type: corr2.entity1)
    tp.prepare!

    assert_empty @pattern.unmatched_elements([@target_ontology])
    assert_equal 2, tp.pattern_elements.size
  end

  it "should throw away elements of translation patterns if the original one was changed" do
    correspondence1 = FactoryGirl.create(:hardway_complex, :onto1 => @source_ontology, :onto2 => @target_ontology)
    om = ontology_matcher([correspondence1])

    tp = TranslationPattern.for_pattern_and_ontologies(@pattern, [@target_ontology])
    tp.prepare!

    assert_equal 1, tp.pattern_elements.size
    expect(PatternElementMatch.count).to eq(3)
    @pattern.nodes.first.update_attributes(rdf_type: @pattern.nodes.first.rdf_type + "_new")
    expect(TranslationPattern.first.pattern_elements).to be_empty
  end

  it "should throw away a translation if an existing element was remvoved" do
    correspondence1 = FactoryGirl.create(:hardway_complex, :onto1 => @source_ontology, :onto2 => @target_ontology)

    om = ontology_matcher([correspondence1])
    tp = TranslationPattern.for_pattern_and_ontologies(@pattern, [@target_ontology])
    tp.prepare!

    assert_equal 1, tp.pattern_elements.size
    @pattern.nodes.first.destroy
    assert_empty TranslationPattern.first.pattern_elements
    assert_equal 0, PatternElementMatch.count
  end

  it "should extend the translation pattern if the original one was extended" do
    correspondence1 = FactoryGirl.create(:hardway_complex, :onto1 => @source_ontology, :onto2 => @target_ontology)
    om = ontology_matcher([correspondence1])

    tp = TranslationPattern.for_pattern_and_ontologies(@pattern, [@target_ontology])
    assert_equal 1, TranslationPattern.count
    corr2 = FactoryGirl.create(:simple_correspondence, :onto1 => @source_ontology, :onto2 => @target_ontology)
    om.add_correspondence!(corr2)
    new_node = @pattern.create_node!(@source_ontology, corr2.entity1)
    assert_equal 1, TranslationPattern.count
    tp.prepare!
    assert_empty @pattern.unmatched_elements(@target_ontology)
  end

  it "should build a graph if we have simple mappings for node and attribute constraint" do
    c1 = FactoryGirl.create(:simple_correspondence, :onto1 => @source_ontology, :onto2 => @target_ontology)
    c2 = FactoryGirl.create(:simple_attrib_correspondence, :onto1 => @source_ontology, :onto2 => @target_ontology)

    @pattern = FactoryGirl.create(:empty_pattern)
    om = ontology_matcher([c1, c2])

    node = FactoryGirl.create(:node, :ontology => @source_ontology, :rdf_type => c1.entity1, :pattern => @pattern)
    ac = FactoryGirl.create(:attribute_constraint, :node => node, :rdf_type => c2.entity1, :ontology => @source_ontology)

    AgraphConnection.any_instance.stub(:element_class_for_rdf_type).with(c1.entity2){Node}
    AgraphConnection.any_instance.stub(:element_class_for_rdf_type).with(c2.entity2){AttributeConstraint}

    tp = TranslationPattern.for_pattern_and_ontologies(@pattern, [@target_ontology])
    tp.prepare!

    assert_equal 2, tp.pattern_elements.size
    assert_equal 1, tp.nodes.size
    assert_equal 1, tp.attribute_constraints.size
    assert_equal tp.attribute_constraints.first.node, tp.nodes.first
  end

  it "should build a graph for simple mappings for node and relation constraints" do
    @pattern = FactoryGirl.create(:n_r_n_pattern, ontologies: [@source_ontology])

    c1 = FactoryGirl.create(:simple_correspondence, entity1: @pattern.nodes.first.rdf_type, :onto1 => @source_ontology, :onto2 => @target_ontology)
    c2 = FactoryGirl.create(:simple_correspondence, entity1: @pattern.nodes.last.rdf_type, :onto1 => @source_ontology, :onto2 => @target_ontology)
    c3 = FactoryGirl.create(:simple_relation_correspondence, entity1: @pattern.relation_constraints.first.rdf_type, :onto1 => @source_ontology, :onto2 => @target_ontology)
    om = ontology_matcher([c1, c2, c3])

    AgraphConnection.any_instance.stub(:element_class_for_rdf_type).with(c1.entity2){Node}
    AgraphConnection.any_instance.stub(:element_class_for_rdf_type).with(c2.entity2){Node}
    AgraphConnection.any_instance.stub(:element_class_for_rdf_type).with(c3.entity2){RelationConstraint}

    tp = TranslationPattern.for_pattern_and_ontologies(@pattern, [@target_ontology])
    tp.prepare!

    assert_equal 3, tp.pattern_elements.size
    assert_equal 2, tp.nodes.size
    assert_equal 1, tp.relation_constraints.size
    assert tp.pattern_elements.all?{|pe| pe.valid?}
    assert_not_equal tp.relation_constraints.first.source, tp.relation_constraints.first.target
  end

  it "should not create additional nodes if we have unmatched ones within the TP" do
    corr = FactoryGirl.create(:simple_correspondence, :onto1 => @source_ontology, :onto2 => @target_ontology)
    om = ontology_matcher([corr])
    p = FactoryGirl.create(:node_only_pattern, :ontologies => [@source_ontology])
    n1 = p.create_node!(@source_ontology, corr.entity1)
    n2 = p.create_node!(@source_ontology, corr.entity1)

    # create one node that refers to one of the input nodes
    tp = FactoryGirl.create(:translation_pattern, :pattern_id => p.id, :ontologies => [@target_ontology])
    tn1 = tp.create_node!(@target_ontology, corr.entity2)
    corr.pattern_element_matches.create(:matched_element => n1, :matching_element => tn1)

    # create a second node that does not refer to anything (i.e., user created one but didn't mark the match)
    tn2 = tp.create_node!(@target_ontology, corr.entity2)
    assert_equal 2, tp.nodes.size

    # now prepare the pattern
    tp.prepare!

    # and there should not be an additional node but only a new match ...
    assert_equal 2, tp.pattern_elements.size
    assert_equal 2, PatternElementMatch.count
  end

  it "should find ambigous mappings based on the found keys" do
    ok = {[1] => [[2]]}
    too_many = {[1] => [2,3]}
    ambiguous = {[1] => [2], [1,3] => [4]}
    ambiguous_2 = {[1,2] => [2], [4,5,1,6,2] => [4]}
    intersecting = {[1,3] => [1], [3,4] => [1], [4,1] => [1]}
    assert_empty TranslationPattern.new.check_for_ambiguous_mappings(ok)
    tm = TranslationPattern.new.check_for_ambiguous_mappings(too_many)
    assert_equal [2,3], tm[[1]]
    tm = TranslationPattern.new.check_for_ambiguous_mappings(ambiguous)
    assert_equal [2], tm[[1]]
    assert_equal [4], tm[[1,3]]
    tm = TranslationPattern.new.check_for_ambiguous_mappings(ambiguous_2)
    assert_equal [2], tm[[1,2]]
    assert_equal [4], tm[[4,5,1,6,2]]
    tm = TranslationPattern.new.check_for_ambiguous_mappings(intersecting)
    assert_equal [1], tm[[1,3]]
    assert_equal [1], tm[[3,4]]
    assert_equal [1], tm[[4,1]]
  end

  it "should properly select the chosen correspondences" do
    o1 = FactoryGirl.create(:ontology)
    o2 = FactoryGirl.create(:ontology)
    o3 = FactoryGirl.create(:ontology)

    c1 = FactoryGirl.create(:simple_correspondence, entity1: "http://example1", onto2: o2, onto1: o1)
    c2 = FactoryGirl.create(:simple_correspondence, entity1: "http://example2", onto2: o2, onto1: o1)
    c3 = FactoryGirl.create(:simple_correspondence, entity1: "http://example3", onto2: o2, onto1: o1)

    mapping = {[o1] => [c1, c3], [o1,o2] => [c2], [o2,o3] => [c2]}
    choice1 = {[o1.id] => c1.id}
    TranslationPattern.new.resolve_ambiguities(mapping, choice1)
    assert_equal [c1], mapping[[o1]]
    assert_nil mapping[[o1,o2]]
    assert_equal [c2], mapping[[o2,o3]]

    mapping = {[o1] => [c1], [o1,o2] => [c2], [o2,o3] => [c3]}
    choice2 = {[o1.id,o2.id] => c2.id}
    TranslationPattern.new.resolve_ambiguities(mapping, choice2)
    assert_nil mapping[[o1]]
    assert_equal [c2], mapping[[o1,o2]]
    assert_nil mapping[[o2,o3]]

    mapping = {[o1] => [c1], [o1,o2] => [c2], [o2,o3] => [c3]}
    choice2 = {[o1.id] => c2.id}
    TranslationPattern.new.resolve_ambiguities(mapping, choice2)
    assert_nil mapping[[o2]]
    assert_equal [c2], mapping[[o1,o2]]
    assert_nil mapping[[o2,o3]]
  end

  it "should ignore stuff we want to do manually" do
    o1 = FactoryGirl.create(:ontology)
    o2 = FactoryGirl.create(:ontology)
    c1 = FactoryGirl.create(:simple_correspondence, entity1: "http://example1", onto2: o2, onto1: o1)
    c2 = FactoryGirl.create(:simple_correspondence, entity1: "http://example2", onto2: o2, onto1: o1)
    c3 = FactoryGirl.create(:simple_correspondence, entity1: "http://example3", onto2: o2, onto1: o1)

    mapping = {[o1] => [c1], [o2] => [c3], [o1,o2] => [c2]}
    choice1 = {[o1.id] => c1.id, [o2.id] => 0}
    TranslationPattern.new.resolve_ambiguities(mapping, choice1)
    assert_equal [c1], mapping[[o1]]
    assert_nil mapping[[o1,o2]]
    assert_nil mapping[[o2]]
  end

  it "should throw away pattern element matches if an element changes" do
    c1 = FactoryGirl.create(:hardway_complex, :onto1 => @source_ontology, :onto2 => @target_ontology)
    om = ontology_matcher([c1])
    tp = TranslationPattern.for_pattern_and_ontologies(@pattern, [@target_ontology])
    tp.prepare!

    assert_equal 3, PatternElementMatch.count
    tp.nodes.first.update_attributes(rdf_type: tp.nodes.first.rdf_type + "_new")
    assert_equal 0, PatternElementMatch.count
    assert_equal 3, Pattern.first.pattern_elements.size
  end

  it "should allow tracing the implementation of a correspondence" do
    o1 = FactoryGirl.create(:ontology)
    o2 = FactoryGirl.create(:ontology)
    pattern = FactoryGirl.create(:n_r_n_pattern, ontologies: [o1])
    pattern2 = FactoryGirl.create(:n_r_n_pattern, ontologies: [o1])
    pattern2.pattern_elements.each{|pe| pattern.pattern_elements << pe}

    mtn = FactoryGirl.create(:m_to_n_complex, onto1: o1, onto2: o2)
    tp = TranslationPattern.for_pattern_and_ontologies(pattern, [o2])

    tp.prepare!
    assert_equal 6, tp.pattern_elements.size
    expect(PatternElementMatch.count).to eq(18)
    matching_groups = tp.matching_groups
    expect(matching_groups.size).to eq(2)
    expect(matching_groups[pattern.pattern_elements[0..2]][:matching_elements]).to eq(tp.pattern_elements[0..2])
    expect(matching_groups[pattern.pattern_elements[3..-1]][:matching_elements]).to eq(tp.pattern_elements[3..-1])
  end

  def ontology_matcher(correspondences)
    om = OntologyMatcher.new(@source_ontology, @target_ontology)
    om.alignment_repo.clear!
    om.insert_graph_pattern_ontology!
    correspondences.each{|c| om.add_correspondence!(c)}
    return om
  end
end
