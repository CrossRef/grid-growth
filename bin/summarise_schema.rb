require 'rubygems'
require 'bundler'
require 'csv'
Bundler.require :default

datasets = JSON.parse( File.read(ARGV[0]) )

properties = {}

def add(properties, property, version, parent)
  key = parent.nil? ? property : "#{parent}.#{property}"
  if properties[key] == nil
    properties[key] = [ version ]
  else
    properties[key] << version
  end
end

def process_properties(properties, entry, version, parent=nil)
  if entry["type"] == "object"
    #If it's an object, list its properties, munging property name
    #TODO
    entry["properties"].keys.each do |property|
      add(properties, property, version, parent)
      process_properties(properties, entry["properties"][property], version, parent.nil? ? property : "#{parent}.#{property}")
    end
  elsif entry["type"] == "array"
    return unless entry["items"]["type"] != "string"
    return if entry["items"]["properties"].nil?
    #If it's an array, list its items, properties, munging property name
    entry["items"]["properties"].keys.each do |property|
      add(properties, property, version, parent)
      process_properties(properties, entry["items"]["properties"][property], version, parent.nil? ? property : "#{parent}.#{property}")
    end
  elsif entry["type"] == "null"
    #puts "Warning: null type for #{parent} #{entry} in #{version}"
  else
    #ignore, will be type string or null
  end
end

def process_schema(properties, version, schema)
  if schema["properties"]["institutes"] == nil || schema["properties"]["institutes"]["type"] != "array"
    $stderr.puts "Top-level schema has changed. Skipping"
    return
  end

  process_properties(properties, schema["properties"]["institutes"], version )

end

datasets.each.each do |dataset, versions|
  versions.each do |version|

    file = File.join("data", dataset, version["version"], "#{dataset}-schema.json")
    schema = JSON.parse( File.read(file) )
    process_schema( properties,version["version"], schema)
  end

  dates = []
  versions.each do |version|
    dates << version["version"]
  end

  CSV.open("data/properties.csv", "w") do |csv|
    csv << ["Name"] + dates.sort
    properties.each do |name, present_versions|
      row = Array.new( dates.length + 1, "" )
      row[0] = name
      dates.sort.each_with_index do |version, idx|
        row[idx + 1] = "Y" if present_versions.include? version
      end
      csv << row
    end
  end


end

