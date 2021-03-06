class MetricOperatorNode < MetricNode

  attr_accessible :operator_cd

  as_enum :operator, %i{add subtract multiply divide}
  OPERATOR_MAPPING = {:add => "+", :subtract => "-", :multiply => "*", :divide => "/"}

  def self.model_name
    return MetricNode.model_name
  end

  def needs_aggregation?
    false
  end

  def qualified_name
    nil
  end

  def calculation_template()
    return "(#{children.sort{|c1,c2| c1.x <=> c2.x}.collect{|child| child.calculation_template()}.join(math_op)})"
  end

  def self.operator_symbols
    OPERATOR_MAPPING.collect{|k,v| [v, operators[k]]}
  end

  def math_op()
    return OPERATOR_MAPPING[operator]
  end
end