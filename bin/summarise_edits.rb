require 'rubygems'
require 'bundler'
require 'csv'
require 'set'
Bundler.require :default

datasets = JSON.parse( File.read(ARGV[0]) )

STATS = {
    #version => size
    counts: {},
    #property => {} :edits, max/min distance, ...
    edits: {}
}

PREVIOUS_IDS=Set.new

INSTITUTES=Hash.new

#
#Version, Added, Deleted, Changed

#Version, Property, Edit Counts, Min/Max Hamming Distance,

#An edit is a change to a field
#For string fields we can calculate hamming distance to indicate degree of change
#For array we can, after sorting the array, compare them on size and contents. Edits is number of additions/removals

#External_ids may need special case?

def process(date, institutes)
  ids = Set.new
  latest_institutes = {}
  changed = 0
  statuses = {}
  institutes.each do |institute|
    id = institute.delete("id")
    ids.add( id )
    latest_institutes[ id ] = institute

    if INSTITUTES.key?(id )
      changed +=1 if INSTITUTES[id] != institute
      #we've encountered this before, look for edits
      calculate_edits(date, INSTITUTES[id], institute)
    end

    statuses[institute["status"]] ||= 0
    statuses[institute["status"]]  += 1
  end

  STATS[:counts][ date ] = {
      total: institutes.size,
      new: (ids - PREVIOUS_IDS).size,
      deleted: (PREVIOUS_IDS - ids).size,
      changed: changed,
      statuses: statuses
  }
  PREVIOUS_IDS.clear.merge(ids)
  INSTITUTES.clear.merge!( latest_institutes )
end

def calculate_edits(date, previous, latest)
  latest.keys.each do |key|
    STATS[:edits][key] ||= {}
    STATS[:edits][key][date] ||= {}
    STATS[:edits][key][date][:count] ||= 0

    #calculate change for each key
    #Note: relying on Ruby != heavily here
    if latest[key] != previous[key]
      STATS[:edits][key][date][:count] += 1
      if latest[key].class == String
        STATS[:edits][key][date][:distances] ||= []
        STATS[:edits][key][date][:distances] << Hotwater.damerau_levenshtein_distance(previous[key], latest[key])
      elsif latest[key].class == Array
        #For arrays we count number of new and deleted items
        STATS[:edits][key][date][:distances] ||= []
        o = previous[key] || []
        l = latest[key] || []
        distance = (o - l).size + (l - o).size
        STATS[:edits][key][date][:distances] << distance
      else
        #currently ignoring weight (number), established (date), external_ids (object)
      end
    end
  end
end

datasets.each.each do |dataset, versions|
  versions.each do |version|

    date = version["version"]
    file = File.join("data", dataset, date, "#{dataset}.json")
    puts "Processing #{file}"
    data = JSON.parse( File.read(file) )

    process(date, data["institutes"])

  end
end

CSV.open("data/growth.csv", "w") do |csv|
  csv << ["Version", "Total", "New", "Deleted", "Changed", "Active", "Redirected", "Obsolete"]
  STATS[:counts].each do |version, counts|
    csv << [version, counts[:total], counts[:new], counts[:deleted], counts[:changed],
      counts[:statuses]["active"], counts[:statuses]["redirected"], counts[:statuses]["obsolete"]]
  end
end

CSV.open("data/edits.csv", "w") do |csv|
  csv << ["Version", "Property", "Edits", "Min Distance", "Max Distance", "Average Distance"]
  STATS[:edits].each do |property, version_stats|
    total = 0
    total_min_distance = 0
    total_max_distance = 0
    distances = []
    version_stats.each do |version, stats|
      if stats[:distances].nil?
        csv << [property, version, stats[:count], nil, nil, nil]
      else
        average = stats[:distances].reduce(:+) / stats[:distances].size.to_f
        csv << [property, version, stats[:count],
                stats[:distances].min, stats[:distances].max, average]

        #for totals
        distances += stats[:distances]
        total_min_distance = stats[:distances].min if stats[:distances].min < total_min_distance
        total_max_distance = stats[:distances].max if stats[:distances].max > total_max_distance

      end
      total += stats[:count]
    end
    average = distances.empty? ? 0 : distances.reduce(:+) / distances.size.to_f
    csv << [property, "All", total, total_min_distance, total_max_distance, average]
  end
end