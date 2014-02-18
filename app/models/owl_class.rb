class OwlClass
  attr_accessor :subclasses, :name, :relations, :attributes, :schema
  
  include RdfSerialization
  
  def initialize(schema, name)
    @subclasses = Set.new
    @schema = schema
    @name = name
    @relations = Set.new
    @attributes = Set.new
    schema.add_class(self)
  end
  
  def add_attribute(name, type)
    attributes << Attribute.new(name, type, self)
  end
  
  def add_relation(name, target_class)
    relations << Relation.new(name, target_class, self)
  end
  
  def uri
    return schema.uri + "/" + name
  end
  
  def statements
    stmts = [
      [resource, RDF.type, RDF::OWL.Class],
      [resource, RDF::RDFS.isDefinedBy, RDF::Resource.new(schema.uri)],
      [resource, RDF::RDFS.label, RDF::Literal.new(name)],
      [resource, RDF::RDFS.comment, RDF::Literal.new("Class generated by schema extractor.")]
    ]
    relations.each{|rel| stmts.concat(rel.statements)}
    attributes.each{|att| stmts.concat(att.statements)}    
    return stmts
  end
  
end