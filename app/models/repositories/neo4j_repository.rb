require 'objspace'

class Neo4jRepository < Repository

  attr_accessor :neo

  def self.model_name
    return Repository.model_name
  end
  
  def self.rdf_format
    "rdf"
  end

  def self.default_port
    7474
  end
  
  class OntExtractionJob < ProgressJob::Base

    def perform
      @repository = Repository.find(@repository_id)
      @repository.analyze_neo4j_repository!(self)
    end

  end
  
  def analyze_neo4j_repository!(job = nil)
    properties = {}
    log_msg("Getting properties per label", job)
    labels_and_counts.each_pair{|label, count| 
      properties[label] = get_properties(label, count, job)
      log_status("Finished '#{label}'", 1, job)
    }
    log_msg("Getting relationships per label", job)
    populate_ontology!(properties, get_relationships())
    log_status("Finished analyzing the ontology!", 1, job)
    ontology.update_attributes({:does_exist => true})
    ontology.load_to_dedicated_repository!
  end
  
  def log_status(msg, step, job)
    job.nil? ? puts(msg) : job.update_stage_progress(msg, :step => step)
  end
  
  def log_msg(msg, job)
    job.nil? ? puts(msg) : job.update_stage(msg)
  end

  # queries the graph in order to create an ontology that describes it...
  # 1. Get all nodes with certain labels and determine their properties + value types
  # 2. get all relations between different node types
  def create_ontology!
    if ontology_creation_job.nil?
      lc = labels_and_counts      
      j = OntExtractionJob.new(progress_max: lc.size + 1)
      j.instance_variable_set("@repository_id", self.id)
      Delayed::Job.enqueue(j, :queue => ont_creation_queue)
    end
    return nil
  end
  
  # yeah, sue me ... this is slow as f**k, but it does the job ^^
  def get_properties(label, count, job = nil)
    offset = sensible_offset(label)
    rounds = (count / offset).to_i
    rounds += 1 if offset.modulo(count) != 0 || count < offset
    log_msg("Getting samples for '#{label}' in #{rounds} rounds.", job)
    node_properties = {}
    rounds.times do |i|
      log_msg("Collecting samples for '#{label}'. Round #{i+1} of #{rounds}" ,job)
      nodes = query_result("MATCH (n:`#{label}`) RETURN n SKIP #{offset * i} LIMIT #{offset}")
      nodes.collect{|node| node.first["data"]}.each{|bh| node_properties.merge!(bh.reject{|k,v| v.nil?})}
    end
    return node_properties
  end

  # we use a sample object to determine how many we should get at once
  def sensible_offset(label)
    (1000000 / ObjectSpace.memsize_of(query_result("MATCH (n:`#{label}`) RETURN n LIMIT 1").first.first)).to_i
  end
  
  # Constructs an OWL ontology...
  def populate_ontology!(properties, relationships)
    properties.each_pair do |label, property_hash|
      owl_class = OwlClass.find_or_create(ontology, label, nil)
      property_hash.each_pair do |property_key, property_sample_value|
        owl_class.add_attribute(property_key, property_sample_value)
      end
    end
    
    # comes in arrays: 0: source, 1: name, 2: target, 3: count
    relationships.each do |relationship|
      domain = OwlClass.find_or_create(ontology, relationship[0], nil)
      range = OwlClass.find_or_create(ontology, relationship[2], nil)
      domain.add_relation(relationship[1], range)
    end
  end
  
  def get_relationships()
    return query_result("MATCH (a)-[r]->(b) RETURN labels(a)[0] AS This, type(r) as To, labels(b)[0] AS That, count(*) AS Count")
  end
  
  def labels_and_counts
    stats = Hash.new(0)
    res = query_result("START n=node(*) RETURN distinct labels(n), count(*)")
    res.each do |labels, count|
      if labels.is_a?(Array)
        labels.each{|label| stats[label] += count}
      else
        stats[labels] += count
      end
    end
    return stats    
  end

  def type_statistics
    return labels_and_counts.to_a
  end
  
  def query_result(query)
    return neo.execute_query(query)["data"]
  end
  
  def neo
    @neo ||= Neography::Rest.new("http://#{host}:#{port}")
  end
end