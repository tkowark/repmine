class AttributeConstraint < PatternElement
  attr_accessible :value, :operator, :node, :x, :y, :monitoring_task_id
  belongs_to :node, :class_name => "PatternElement"
  validates :node, :presence => true
  belongs_to :monitoring_task
  before_save :assign_to_pattern!, :assign_ontology!

  OPERATORS = {
    :var => "?",
    :regex => "=~",
    :equals => "=",
    :less_than => "<",
    :greater_than => ">",
    :not => "!="
  }

  def rdf_mappings
    super.merge({
      Vocabularies::GraphPattern.attributeValue => {:property => :value, :literal => true},
      Vocabularies::GraphPattern.attributeOperator => {:property => :operator, :literal => true},
      Vocabularies::GraphPattern.node => {:property => :node},
    })
  end

  def rdf_statements
    stmts = super
    stmts << [resource, Vocabularies::GraphPattern.node, node.resource]
    stmts << [resource, Vocabularies::GraphPattern.attributeValue, value]
    stmts << [resource, Vocabularies::GraphPattern.attributeOperator, operator]
    return stmts
  end

  def value_type
    ontology.attribute_range(rdf_type)
  end

  def assign_to_pattern!
    self.pattern = node.pattern unless node.nil?
  end

  def assign_ontology!
    self.ontology = node.ontology if ontology.nil?
  end

  def possible_attributes()
    check_rdf_type(node.possible_attribute_constraints)
  end

  def refers_to_variable?
    return contains_variable?(self.value) && !is_variable?
  end

  def is_variable?
    operator == OPERATORS[:var]
  end

  def referenced_element
    pattern.attribute_constraints.find{|ac| ac.is_variable? && ("?#{ac.value}" == self.value)}
  end

  def rdf_types
    [Vocabularies::GraphPattern.PatternElement, Vocabularies::GraphPattern.AttributeConstraint]
  end

  def pretty_string
    "#{short_rdf_type} #{operator} #{value}"
  end

  def graph_strings(elements = [])
    str = elements.include?(node) ? "#{node.rdf_type}->" : ""
    str += rdf_type
  end
end
