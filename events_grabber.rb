require 'json'
require 'httparty'
require 'nokogiri'
require 'date'

####################
# Models

class Event
    attr_reader :year, :description, :description_html
    attr_accessor :entities

    def initialize(year, description, description_html = nil)
        @year = year
        @description = description
        @description_html = description_html
        @entities = []
    end

    def to_json(*_args)
        to_h.to_json
    end

    def to_h
        { year: year, description: description, html: description_html, entities: entities.map(&:to_h) }
    end
end

class Entity
    attr_reader :name, :url
    attr_accessor :length

    def initialize(name, url)
        @name = name
        @url = url
    end

    def to_json(*_args)
        to_h.to_json
    end

    def to_h
        { name: name, url: url, length: length }
    end
end

####################
# Functions

def extract_events(html)
    doc  = Nokogiri::HTML(html)
    events_nodes = doc.css('li')
    events = []
    events_nodes.each do |event_node|
        event_text = event_node.inner_text
        event_components = event_text.split(' – ')
        if event_components.count > 1
            next if event_components[0][0] == "^"
            entities = []
            entities = event_node.css('a').map do |link|
                Entity.new(link['title'], link['href'])
            end
            entities = entities.select { |entity| entity.name != nil }
            entities = entities.select { |entity| entity.url != "/wiki/Wikipedia:Citation_needed"}
            entities = entities.select { |entity| entity.name && entity.name !~ /^\d+$/ }
            the_event = Event.new(event_components[0].strip, event_components[1].strip.gsub(/\[\d+\]/,''), description_html = event_node.to_html)
            the_event.entities = entities
            events << the_event
        end
    end
    events
end

def load_entity_lengths(events)
    base_url = "https://en.wikipedia.org/w/api.php?action=query&prop=info&format=json&inprop=url&titles="
    events.each do |event|
        titles = event.entities.map { |entity| entity.url.split('/').last }
        url = base_url + titles.join('|')
        begin
            response = HTTParty.get(url)
        rescue URI::InvalidURIError => e
            puts "Invalid URI: #{e.message}"
            next
        end
        results = JSON.parse(response.body)
        next unless results['query'] && results['query']['pages']
        results['query']['pages'].each do |page_id, page|
            entity = event.entities.find { |entity| entity.name == page['title'] }
            next unless entity
            entity.length = page['length']
        end
    end
end

def write_json(html, filename)
    events = extract_events(html)
    load_entity_lengths(events)
    File.open(filename, 'w') do |file|
        file.write(JSON.pretty_generate(events.map(&:to_h)))
    end
end

def generate_events(forDay = Date.today)
    json_filename = "events/#{forDay.strftime('%m%d')}_events.json"
    if File.exist?(json_filename) && File.size(json_filename) > 0
        puts "JSON file for #{forDay.strftime('%B')} #{forDay.strftime('%e')} already exists and is non-zero length."
        return
    end

    url = "https://en.wikipedia.org/w/api.php?action=parse&page=#{forDay.strftime('%B')}_#{forDay.strftime('%e')}&prop=text&formatversion=2&format=json"

    response = HTTParty.get(url)
    wiki = JSON.parse(response.body)

    events_html = wiki['parse']['text'].split('Events</h2>')[1].split('Births</h2>')[0]
    births_html = wiki['parse']['text'].split('Births</h2>')[1].split('Deaths</h2>')[0]
    deaths_html = wiki['parse']['text'].split('Deaths</h2>')[1].split('Holidays_and_observances</h2>')[0]

    puts "Extracting events from #{forDay.strftime('%B')} #{forDay.strftime('%e')}"

    events = extract_events(events_html)
    load_entity_lengths(events)
    puts "Loaded #{events.count} events"

    births = extract_events(births_html)
    load_entity_lengths(births)
    puts "Loaded #{births.count} births"

    deaths = extract_events(deaths_html)
    load_entity_lengths(deaths)
    puts "Loaded #{deaths.count} deaths"

    all_events = { events: events, births: births, deaths: deaths }
    File.open("events/#{forDay.strftime('%m%d')}_events.json", 'w') do |file|
        file.write(JSON.pretty_generate(all_events))
    end
end


####################
# Main

if ARGV.include?('--all')
    puts "Generating events for the entire year"
    (Date.new(Date.today.year, 1, 1)..Date.new(Date.today.year, 12, 31)).each do |theDay|
        generate_events(theDay)
    end
else
    puts "Generating events for today"
    generate_events(Date.today)
end
