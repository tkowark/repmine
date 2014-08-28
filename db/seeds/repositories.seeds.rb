MongoDbRepository.find_or_create_by_host("172.16.31.74", :port => 27017, :db_name => "msr14", :name => "GHTorrent", :description => "GHTorrent dataset for the 2014 working conference on mining software repositories")
RdbmsRepository.find_or_create_by_host_and_db_name("172.16.31.208", "sonar", :port => 5432, :name => "SonarQube", :description => "SonarQube import of the GHTorrent dataset.")
RdbmsRepository.find_or_create_by_host_and_db_name("172.16.31.208", "alitheia", :port => 5432, :name => "AlitheiaCore", :description => "SonarQube import of the GHTorrent dataset.")