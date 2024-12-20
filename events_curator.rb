require 'json'
require 'date'

@debug = false

def curate_events(date)
    puts "Curating events for #{date}"
    today = date
    filename = "events/#{today.strftime('%m%d')}_events.json"
    all_events = JSON.parse(File.read(filename))

    events = all_events['events']
    births = all_events['births']
    deaths = all_events['deaths']

    # Let's explore this data first by ranking the events by the number of entities they are associated with.
    ranked_events = events.sort_by { |event| event['entities'].count }.reverse
    ranked_events = ranked_events.select { |event| event['description'] !~ /\d{3,4}/ }
    if @debug
        ranked_events.first(6).each_with_index do |event, index|
            puts "- - - - - "
            puts "#{index + 1}: #{event['entities'].count} entities"
            puts "#{event['year']}: #{event['description']}"
        end
    end
    selected_events = ranked_events.first(6)
    unique_entities = []
    selected_events = []
    years = []

    ranked_events.each do |event|
        event_entities = event['entities']
        if (unique_entities & event_entities).empty? && (years.none? { |y| (event['year'].to_i - y.to_i).abs <= 5 })
            selected_events << event
            years << event['year']
            unique_entities.concat(event_entities)
        end
        break if selected_events.size >= 6
    end

    ranked_births = births.sort_by { |birth| if birth['entities'].first then (birth['entities'].first['length'] || 0) else 0 end }.reverse
    ranked_births.each do |birth|
        birth['description'].gsub!(/\s*\(.*?\)\s*/, '')
        birth['description'].strip!
        birth['description'] << ", was born."
    end
    if @debug
        puts "\n\n"
        ranked_births.first(6).each_with_index do |birth, index|
            puts "- - - - - "
            puts "#{index + 1}: #{birth['entities'].first['length']} characters"
            puts "#{birth['year']}: #{birth['description']}"
        end
    end
    selected_births = ranked_births.first(3)

    ranked_deaths = deaths.sort_by { |death| if death['entities'].first then (death['entities'].first['length'] || 0) else 0 end }.reverse
    ranked_deaths.each do |death|
        death['description'].gsub!(/\s*\(.*?\)\s*/, '')
        death['description'].strip!
        death['description'] << ", died."
    end
    if @debug
        puts "\n\n"
        ranked_deaths.first(6).each_with_index do |death, index|
            puts "- - - - - "
            puts "#{index + 1}: #{death['entities'].first['length']} characters"
            puts "#{death['year']}: #{death['description']}"
        end
    end
    selected_deaths = ranked_deaths.first(3)

    selected_events << selected_births.sample
    selected_events << selected_deaths.sample
    File.open("selected_events/#{today.strftime('%m%d')}_selected_events.json", 'w') do |f|
        f.write(JSON.pretty_generate({ events: selected_events, births: selected_births, deaths: selected_deaths }))
    end
end

# Rules:
# - If an event description contains a year, it's not a candidate

####################
# Main

if ARGV.include?('--all')
    puts "Curating events for the entire year"
    (Date.new(Date.today.year, 1, 1)..Date.new(Date.today.year, 12, 31)).each do |theDay|
        curate_events(theDay)
    end
else
    puts "Curating events for today"
    curate_events(Date.today)
end