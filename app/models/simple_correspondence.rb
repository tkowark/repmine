class SimpleCorrespondence < Struct.new(:measure, :relation, :entity1, :entity2, :onto1, :onto2)
  include RdfSerialization
  
  attr_accessor :node

  def rdf_types
    [Vocabularies::Alignment.Cell]
  end
  
  def url
    nil
  end
  
  def equal_to?(other)
    return entity1 == other.entity1 && entity2 == other.entity2 && relation == other.relation
  end
  
  def output_element
    return onto2.element_class_for_rdf_type(entity2)
  end
  
  def resource
    @resource ||= RDF::Node.new
  end
  
  def rdf_statements
    [
      [resource, Vocabularies::Alignment.entity1, RDF::Resource.new(entity1)],
      [resource, Vocabularies::Alignment.entity2, RDF::Resource.new(entity2)],
      [resource, Vocabularies::Alignment.measure, RDF::Literal.new(measure)],
      [resource, Vocabularies::Alignment.relation, RDF::Literal.new(relation)]
    ]
  end
end
