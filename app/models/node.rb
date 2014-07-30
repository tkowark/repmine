#!/bin/env ruby
# encoding: utf-8

class Node < ActiveRecord::Base
  attr_accessible :rdf_type, :x, :y

  belongs_to :pattern
  has_many :source_relation_constraints, :class_name => "RelationConstraint", :foreign_key => "source_id", :dependent => :destroy
  has_many :target_relation_constraints, :class_name => "RelationConstraint", :foreign_key => "target_id", :dependent => :destroy  
  has_many :attribute_constraints, :dependent => :destroy
  
  def query_variable()
    return rdf_type.split("/").last.downcase + self.id.to_s
  end
  
  def rdf_statements
    return []
  end
  
  def reset!
    # remove the newly created ones
    source_relation_constraints.find(:all, :conditions => ["created_at > ?", self.pattern.updated_at]).each{|rc| rc.destroy}
    attribute_constraints.find(:all, :conditions => ["created_at > ?", self.pattern.updated_at]).each{|ac| ac.destroy}
    # and get rid of all the changed attributes n stuff
    source_relation_constraints.reload    
    attribute_constraints.reload
    source_relation_constraints.each{|rc| rc.reload}
    attribute_constraints.each{|rc| rc.reload}    
  end
end
