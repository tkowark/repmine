class CypherQueryCreator < QueryCreator
  
  def build_query!
    "MATCH #{match} #{parameters}#{with} RETURN #{return_values}".strip.gsub(/\s\s+/, ' ')
  end
  
  def match
    pattern.nodes.collect{|pn| paths_for_node(pn)}.flatten.compact.join(", ")
  end
  
  def paths_for_node(node)
    # only "isolated" nodes need to be added as-is, the rest will be added through incoming relations, eventually
    if node.source_relation_constraints.empty? && node.target_relation_constraints.empty?
      return [node_reference(node)]
    else
      return node.source_relation_constraints.collect do |rc|
        "#{node_reference(node)}-#{relation_reference(rc)}->#{node_reference(rc.target)}"
      end
    end
  end
  
  def node_reference(node)
    "(#{pe_variable(node)}:`#{node.label_for_type}`)"
  end
  
  def relation_reference(rel)
    "[#{pe_variable(rel)}:`#{rel.label_for_type}`]"
  end
  
  def attribute_reference(ac)
    "#{pe_variable(ac.node)}.#{ac.label_for_type}"
  end
  
  def return_values
    pattern.returnable_elements(aggregations).collect{|pe| aggregated_variable(pe)}.join(", ")
  end
  
  def parameters
    str = pattern.attribute_constraints.collect do |ac|
      unless ac.operator == AttributeConstraint::OPERATORS[:var]
        if ac.operator == AttributeConstraint::OPERATORS[:not] && ac.value.blank?
          "has(#{attribute_reference(ac)})"
        else
          "#{attribute_reference(ac)} #{cypher_operator(ac.operator)} #{escaped_value(ac)}"
        end
      end
    end.compact.join(" AND ")
    return str.empty? ? "" : "WHERE #{str}"
  end

  
  def aggregated_variable(pe)
    str = pe_variable(pe)
    aggregation = aggregation_for_element(pe)
    
    if !aggregation.nil? && !aggregation.is_grouping?
      str = aggregation.operation.to_s + "(#{str}) AS #{aggregation.underscored_speaking_name}"
    elsif aggregation.nil? && pe.is_variable? && pe.is_a?(AttributeConstraint)
      str = "#{attribute_reference(pe)} AS #{pe.variable_name}"
    elsif pe.is_a?(Node)
      str = "id(#{str})"
    end
    
    return str
  end
  
  # we mainly use the sames ones as cypher...
  def cypher_operator(our_operator)
    return our_operator
  end
  
  def escaped_value(ac)
    if ac.refers_to_variable?
      aac = pattern.attribute_constraints.find{|aac| aac.value == ac.value}
      return aac.nil? ? ac.value : attribute_reference(aac)
    elsif ac.value_type == RDF::XSD.string
      return "'#{clean_value(ac)}'"
    else
      return ac.value
    end
  end
  
  def clean_value(ac)
    if ac.operator == AttributeConstraint::OPERATORS[:regex]
      return "#{ac.value.scan(/^\/(.*)\//).flatten.first || ac.value}"
    else
      return ac.value
    end
  end
  
  # needed in case of subqueries and aliased variables
  def with
    if pattern.pattern_elements.any?{|pe| pe.is_variable? && !aggregation_for_element(pe).nil?}
      str = " WITH #{(plain_vars + aliased_vars).join(", ")}"
    else
      return ""
    end
  end
  
  def aliased_vars
    pattern.pattern_elements.select{|pe| pe.is_variable?}.collect{|pe| "#{attribute_reference(pe)} AS #{pe_variable(pe)}"}.compact
  end
  
  def plain_vars
    pattern.pattern_elements.select{|pe| !pe.is_variable?}.collect{|pe| pe_variable(pe) unless pe.is_a?(AttributeConstraint)}.compact
  end
  
end