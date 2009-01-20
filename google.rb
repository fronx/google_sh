#! /usr/bin/env ruby
require 'rubygems'
require 'open-uri'
require 'hpricot'
require 'htmlentities'
require 'iconv'

class String
  def strip_tags
    self.gsub(/<[^<>]+>/,'')
  end
  
  def replace_tag(tag, &block)
    self.gsub(/<#{tag}>([^<>]+)<\/#{tag}>/) { |match| yield $1 }
  end
  
  def url_escape
    self.gsub(/([^ a-zA-Z0-9_.-]+)/n) do
    '%' + $1.unpack('H2' * $1.size).join('%').upcase
    end.tr(' ', '+')
  end
  
  def green
    "\033[0;32m" + self + "\033[0m"
  end

  def red
    "\033[0;31m" + self + "\033[0m"
  end

  def yellow
    "\033[0;33m" + self + "\033[0m"
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
  attr_reader :results, :quick_result
  
  def self.root_url
    'http://www.google.com/search?q='
  end
  
  def initialize
    @coder = HTMLEntities.new
  end

  def search(terms, options = {})
    open(search_url(terms)) do |f|
      @page = Hpricot(Iconv.iconv('utf-8', f.charset, f.read).to_s)
    end
    @quick_result = (@page/:table/'h2.r').inner_html.strip_tags rescue nil
    @quick_result = nil if @quick_result.length == 0
    @results = (@page/'li.g').map do |result|
      if href = (result/:h3/'a.l').first.attributes['href'] rescue nil
        SearchResult.new(
          :href => href,
          :title => prepare(result.at(:h3)),
          :description => prepare(result.at('div'))
        )
      end
    end.compact
    if options[:open_first] == true
      `open #{@results.first.href}`
    else
      @result
    end
  end
  
  def search_url(terms)
    Google.root_url + to_query(terms)
  end
  
  private
  
  def prepare(str)
    return '' unless str
    @coder.decode(str.inner_html.replace_tag(:em) { |keyword| keyword.red }.strip_tags )
  end
  
  def to_query(terms)
    (terms || []).map { |t| to_param(t) }.join('+')
  end
  
  def to_param(term)
    (term.count(' ') > 0 ? %Q{"#{term}"} : term).url_escape 
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

search_terms = $*
options = {}
if search_terms.first == '1'
  options[:open_first] = true
  search_terms.shift
end

g = Google.new
g.search(search_terms, options)
if g.quick_result
  puts g.quick_result.yellow
else
  count = g.results.size
  g.results.reverse.each_with_index do |r, i|
    puts "(#{count - i}) " + r.to_s + "\n\n"
  end
end
puts g.search_url($*)