# frozen_string_literal: true
require "./lib/crawler.rb"

crawler = Crawler.new
puts "Start crawling..."
crawler.crawl
puts "Finished crawling"
