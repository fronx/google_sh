#! /usr/local/bin/ruby
require 'rubygems'
require 'open-uri'
require 'uri'
require 'hpricot'
require 'htmlentities'

def url_escape(string)
  string.gsub(/([^ a-zA-Z0-9_.-]+)/n) do
  '%' + $1.unpack('H2' * $1.size).join('%').upcase
  end.tr(' ', '+')
end

class String
  def strip_tags
    self.gsub(/<[^<>]+>/,'')
  end
  
  def green
    "\033[0;32m" + self + "\033[1;37m"
  end
  
  def with_line_length(max_length)
    words = split(' ')
    result = []
    line = []
    words.each do |w|
      line << w
      if line.join(' ').length >= max_length
        result << line.join(' ')
        line = []
      end
    end
    result
  end
end

class Google
  def self.root_url
    'http://www.google.com/search?q='
  end
  
  def initialize
    @coder = HTMLEntities.new
  end

  def search(terms)
    page = Hpricot(open(search_url(terms)))
    (page/"li.g").map do |result|
      if href = (result/:h3/'a.l').first.attributes['href'] rescue nil
        SearchResult.new(
          :href => href,
          :title => @coder.decode( result.at(:h3).inner_html.strip_tags ),
          :description => @coder.decode( result.at('div.s').inner_html.strip_tags )
        )
      end
    end.compact
  end
  
  def search_url(terms)
    Google.root_url + to_query(terms)
  end
  
  private
  
  def to_query(terms)
    (terms || []).map { |t| url_escape(t) }.join('+')
  end
end

class SearchResult
  attr_reader :href, :title, :description
  
  def initialize(options = {})
    @href = options[:href]
    @title = options[:title]
    @description = options[:description]
  end
  
  def to_s(indent = 4)
    indent = "\n" + ' ' * indent
    [title, href.green, description.with_line_length(50).join(indent)].join(indent)
  end
end

g = Google.new
results = g.search($*)
count = results.size
results.reverse.each_with_index do |r, i|
  puts "(#{count - i}) " + r.to_s + "\n\n"
end
puts g.search_url($*)
