class Attribute
  attr_accessor :name, :type, :domain
  
  include RdfSerialization  
  
  def initialize(name, type, domain)
    @name = name
    @type = type.is_a?(RDF::Resource) ? type : RDF::Resource.new(type)
    @domain = domain
  end
  
  def uri
    return domain.ont_uri + "/" + name
  end
  
  def statements
    stmts = [
      [resource, RDF.type, RDF::OWL.DatatypeProperty],
      [resource, RDF.domain, domain.resource],
      [resource, RDF.range, type]
    ]
  end
end
