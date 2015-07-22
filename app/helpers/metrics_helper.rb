module MetricsHelper
  def icon_for_operator(op)
    #add subtract multiply divide
    case op
    when :add then return "+"
    when :subtract then return "-"
    when :multiply then return "*"
    when :divide then return "/"     
    end
  end
  
  def metric_node_position(node)
    if node.y == 0 && node.x == 0
      return "top: 150px; left: 20px;"
    else
      return "top: #{node.y}px; left: #{node.x}px;"
    end
  end
end