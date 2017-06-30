require 'rubygems'
require 'rake'
require 'rake/clean'

require 'bundler'
Bundler.require :default

CLEAN.include("data")

#Configure indexes for datasets

namespace :setup do
  desc "download datasets"
  task :download do
    sh %{ruby bin/cache-datasets.rb config/datasets.json}
  end

  desc "Unpack the downloaded files"
  task :unpack do
    datasets = JSON.parse( File.read("config/datasets.json") )
    datasets.each.each do |dataset, versions|
      versions.each do |version|
        if version["format"] != "json"
          #the -: modifier avoids a failure with 2016-11-02 which has a relative path: ../grid.ttl
          #-j to flatten folders
          sh %{cd data/#{dataset}/#{version["version"]}; unzip -j -: -un #{dataset}.zip}
        end
      end
    end
  end

  task :all => [:download, :unpack]
end

namespace :report do
  desc "extract JSON schema from grid.json"
  task :extract_schema do
    datasets = JSON.parse( File.read("config/datasets.json") )
    datasets.each.each do |dataset, versions|
      versions.each do |version|
        puts "Extracting schema for #{dataset} #{version["version"]}"
        sh %{cd data/#{dataset}/#{version["version"]}; generate-schema #{dataset}.json >#{dataset}-schema.json || true}
      end
    end
  end

  desc "Summarise the schema"
  task :schema => [:extract_schema] do
    sh %{ruby bin/summarise_schema.rb config/datasets.json}
  end

  desc "Summarise the data to extract statistics"
  task :edits do
    sh %{ruby bin/summarise_edits.rb config/datasets.json}
  end

  task :all => [:schema, :edits]

end


