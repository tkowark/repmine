jsPlumb.ready(function() {
  
  jsPlumb.importDefaults({
    Container: "drawing_canvas"
	});
	
	jsPlumb.bind("connection", function(info, originalEvent) {
	  if(info.connection.scope == "relations") {
		  createConnection(info.connection);
	  }
	});
});

$("#new_pattern_node").on("ajax:success", function(e, data, status, xhr){
  $("#drawing_canvas").append(xhr.responseText);
  var node_id = $(xhr.responseText).attr("id");
  // make the node draggable
  jsPlumb.draggable(node_id);
  // endpoint for relations
  jsPlumb.addEndpoint(node_id, { anchor:[ "Perimeter", { shape:"Circle"}] }, connectionEndpoint());
  // endpoint for attributes
  // TODO
  // callback for newly selected node classes
});

// this has to go!
/*var connectionNode = function() {
  var con_id = relations.length;
  var con_html_id = "relations[" + con_id + "]";
  var rel_constraint_id = "relations["+ con_id +"]"
  var conn = "<div><select id='" + (con_html_id + "[relation_name]").replace(/\[|\]/g, '_') + "' name='" + con_html_id + "[relation_name]'></select><br />";
  var tc = con_html_id.replace(/\[|\]/g, '_') + "toggle_cards";
  var ce = con_html_id.replace(/\[|\]/g, '_') + "cardinalities";
  conn += "<div id='" + tc + "'><a href='#' onclick=\"$('#" + tc + "').hide(); $('#"+ ce + "').show();\">+ cardinalities</a></div>";
  conn += "<div id='" + ce + "' style='display:none;' class='relConstraints'>(<input type='text' class='veryNarrow' name='" + con_html_id + "[min_cardinality]'></input>-";
  conn += "<input type='text' class='veryNarrow' name='" + con_html_id + "[max_cardinality]'></input>)<br /></div>";  
  var tl = con_html_id.replace(/\[|\]/g, '_') + "toggle_length";
  var le = con_html_id.replace(/\[|\]/g, '_') + "path_length";
  conn += "<div id='" + tl + "'><a href='#' onclick=\"$('#" + tl + "').hide(); $('#"+ le + "').show();\">+ path length</a></div>";  
  conn += "<div id='" + le + "' style='display:none;' class='relConstraints'>[<input type='text' class='veryNarrow' name='" + con_html_id + "[min_path_length]'></input>..";  
  conn += "<input type='text' class='veryNarrow' name='" + con_html_id + "[max_path_length]'></input>]</div><br />";    
  conn += "<input type='hidden' id='relations_" + con_id + "__source' name='" + con_html_id + "[source]" + "'></input>";
  conn += "<input type='hidden' id='relations_" + con_id + "__target' name='" + con_html_id + "[target]" + "'></input></div>";  
  conn += "</div>"

  var connection = $(conn);
  return connection;
};*/

var createConnection = function(connection) {
  var source_id = $(connection.source).attr("data-node-id");
  var target_id = $(connection.target).attr("data-node-id");
  
  // reinstall the endpoints
  jsPlumb.addEndpoint(connection.source, { anchor:[ "Perimeter", { shape:"Circle"}] }, connectionEndpoint());  
  jsPlumb.addEndpoint(connection.target, { anchor:[ "Perimeter", { shape:"Circle"}] }, connectionEndpoint());
  
  // get the available relations from the server. this highly simplifies the JS...
  $.ajax({
    url: new_relation_constraint_path,
    type: "POST",
    data: {source_id: source_id, target_id: target_id},
    success: function(data) {
      $(select).html(data);
    }
  });
};

var optionGroupForRelation = function(label, rels) {
  
  if(rels.length > 0) {
    var options = "<optgroup label='" + label +"'>";
    $.each(rels, function(key, value){
      options += "<option value='" + value + "'>" + value.split("/").pop() + "</option>";
    });
    options += "</optgroup>";
    return options;    
  } else {
    return "";
  }
};

var createNode = function() {
  // create the basic div node and append a type selector to it
  var node_id = nodes.length;
  var node_html_id = "nodes_" + node_id;
  style = "";
  
  if(nodes.length == 0){
    style = " style='top: 300px;left: 300px;'";
  }
  
  nodes.push(node_html_id);
  $("#drawing_canvas").append("<div id='" + node_html_id +"' class='node'" + style +"></div>");
  $("#" + node_html_id).append(nodeTypeSelector(node_id));
  
  // an onchange handler that will update all conncetions going in and out of this node
  $("#nodes_" + node_id + "__rdf_type_").change(function(ev) {
    $.each(jsPlumb.getConnections({source: node_html_id, scope: 'relations'}), function(index, connection) {
      updateConnectionSelector(connection);  
    });
    $.each(jsPlumb.getConnections({target: node_html_id, scope: 'relations'}), function(index, connection) {
      updateConnectionSelector(connection);  
    });
    if($("#nodes_" + node_id + "__attributes_").length != 0) {
      insertAttributeSelectorContent(node_id);
    }
  });
  
  // make it draggable 
  jsPlumb.draggable(node_html_id);
  // and add an endpoint to allow for fancy user interaction
  jsPlumb.addEndpoint(node_html_id, { anchor:[ "Perimeter", { shape:"Circle"}] }, connectionEndpoint());
  var ae = jsPlumb.addEndpoint(node_html_id, attributeEndpoint());  
  
  // bind the doubleclick to the attribute filter opening button
  ae.bind("dblclick", function(endpoint) {
    if(endpoint.connections.length == 0) {
      createNodeAttributeFilter(endpoint, node_id);
    }
  });
};

var createNodeAttributeFilter = function(endpoint, node_id) {
  // build the div
  var node_html_id = "nodes_" + node_id + "__attributes_";
  var attributeFilter = "<div id='" + node_html_id  + "' class='attributeFilter' style='left: ";
  attributeFilter += (endpoint.canvas.offsetLeft + 3) + "px; top: " + (endpoint.canvas.offsetTop - 120) + "px;'></div>";
  // along with the selectors
  
  // make the div draggable and connect it to the node
  $("#drawing_canvas").append(attributeFilter);  
  insertAttributeSelectorContent(node_id);
    
  jsPlumb.draggable(node_html_id);
  var ae = jsPlumb.addEndpoint(node_html_id, { anchor:[ "BottomLeft"] }, attributeEndpoint());
  jsPlumb.connect({ source: endpoint, target: ae});  
};

var insertAttributeSelectorContent = function(node_id) {
  getPossibleAttributes(node_id, function(data){
    var selector = attributeFilterSelect(node_id, 0, data);
    var link = "<a id='more_filters_link_" + node_id + "' href='#' data-node-id='" + node_id + "'>+ add filter</a>";
    $("#nodes_" + node_id + "__attributes_").html(selector + link);    

    $("#more_filters_link_" + node_id).bind("click", function(e) {
      var orderNumber = $("#nodes_" + node_id + "__attributes_").children().length - 1;
      getPossibleAttributes(node_id, function(data){
        $(attributeFilterSelect(node_id, orderNumber, data)).insertBefore("#more_filters_link_" + node_id);
      });
    });
  });  
};

var getPossibleAttributes = function(node_id, callback) {
  jQuery.get(
    attribute_info_url,
    {node_class: $("#nodes_" + node_id + "__rdf_type_").val()},
    function(data) {callback(data);}
  );
};

var attributeFilterSelect = function(node_id, order_number, data){
  var sId = "nodes[" + node_id + "][attributes][" + order_number + "][attribute_name]";
  var selector = "<div><select id='" + sId.replace(/\[|\]/g, '_') + "' name='" + sId + "' class='justRight'>";
  
  data.forEach(function(attributeInfo){
    selector += "<option value='" + attributeInfo["uri"] + "'>" + attributeInfo["uri"].split("/").pop() + "</option>";    
  });
  
  selector += "</select>";

  var ncId = "nodes[" + node_id + "[attributes][" + order_number + "][operator]";
  selector += "<select id='" + ncId.replace(/\[|\]/g, '_') + "' name='" + ncId + "' class='veryNarrow'>";
  
  $.each(["=", ">", "<", "~="], function(i, value) {
    selector += "<option value='" + value + "'>" + value + "</option>";    
  });
  selector += "</select>";

  var navId = "nodes[" + node_id + "[attributes][" + order_number + "][value]";
  selector += "<input type='text' id='" + navId.replace(/\[|\]/g, '_') + "' name='" + navId + "' class='narrow'></input></div>";
  
  return selector;
};

/*
  This method creates the option list for the node class. It is called recursively in case a class
  has (a) subclass(es). 
*/
var addSubclassesToNodeSelector = function(startingPoint, level) {
  var selector = "";
  for(var i = startingPoint["subclasses"].length - 1; i >= 0; i -= 1) {
    selector += "<option value='" + startingPoint["subclasses"][i]["uri"] + "'>";
    for(var ii = 0; ii < level; ii += 1){selector += "&nbsp;&nbsp"};
    selector += startingPoint["subclasses"][i]["name"] + "</option>";
    if(startingPoint["subclasses"][i]["subclasses"].length > 0){
      selector += addSubclassesToNodeSelector(startingPoint["subclasses"][i], level + 1);
    }
  };
  return selector;
};

var connectionEndpoint = function() {
  return {
		endpoint:["Dot", {radius:4} ],
		paintStyle:{ fillStyle:"#ffa500", opacity:0.5 },
		isSource:true,
		scope: "relations",
		connectorStyle:{ strokeStyle:"#ffa500", lineWidth:3 },
		connectorOverlays:[["Arrow",{ width:10, location:1, length:20, id:"arrow" }]],
		connector : "Straight",
		isTarget:true,
		dropOptions : {
  		tolerance:"touch",
  		hoverClass:"dropHover",
  		activeClass:"dragActive"
  	},
		beforeDetach:function(conn) { 
			return confirm("Detach connection?"); 
		}
	};
};

var attributeEndpoint = function() {
  return {
		endpoint:["Rectangle", {width:6, height:6} ],
		anchor: ["Top"],
		paintStyle:{ fillStyle:"#0087CF", opacity:0.5 },
		scope: "attributes",
		connectorStyle:{ strokeStyle:"#0087CF", lineWidth:3 },		
		connector : "Straight",
		beforeDetach:function(conn) { 
			return confirm("Detach connection?"); 
		}
	};
};