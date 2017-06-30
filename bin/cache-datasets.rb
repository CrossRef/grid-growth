require 'rubygems'
require 'bundler'
Bundler.require :default

FileUtils.mkdir_p("data")

datasets = JSON.parse( File.read(ARGV[0]) )

datasets.each.each do |dataset, versions|

  FileUtils.mkdir_p "data/#{dataset}"

  versions.each do |version|
    FileUtils.mkdir_p "data/#{dataset}/#{version["version"]}"

    agent = Mechanize.new
    agent.pluggable_parser.default = Mechanize::Download

    if version["format"] == "json"
      file = File.join( "data/#{dataset}/#{version["version"]}", "#{dataset}.json" )
    else
      file = File.join( "data/#{dataset}/#{version["version"]}", "#{dataset}.zip" )
    end

    $stderr.puts "Downloading #{dataset} #{version["version"]} to #{file}"

    agent.get(version["download"]).save!( file )

  end


end