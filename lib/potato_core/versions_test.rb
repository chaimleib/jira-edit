#!/usr/bin/env ruby
require 'potato_core/version_scraper'
require 'pp'

def write_page
  require 'potato_core/jira_connection'
  rel_uri = '/wiki/display/CP/CD+Maintenance+Releases'
  con = JiraConnection.new
  html = con.submit_get rel_uri
  File.new('test.html', 'wb').write(html)
end

if __FILE__ == $0
  write_page

  html = File.read('test.html')
  freezes = VersionScraper.scrape_freeze_dates html
  pp freezes
end
