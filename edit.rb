#!/usr/bin/env ruby
$:.unshift File.join(__FILE__, '..', 'lib')
  
require 'potato_core/jira_adapter'
require 'cgi'
require 'pry'

# project in (CD, JZ) AND component in (CSN, Supplier, suppliers, SIM, "Supplier Information Portal (SIP)", "Supplier Information Portal") AND (labels not in (team_tortuga, svitla, team_ninja, web_services_team, automated_sanity) OR labels is EMPTY) ORDER BY Rank ASC, priority ASC

conditions = [
  'project in (CD, JZ)',
  'component in (CSN, Supplier, suppliers, SIM, "Supplier Information Portal")',
  '(labels not in (team_tortuga, svitla, team_ninja, web_services_team, automated_sanity, metal_bunnies) OR labels is EMPTY)'
]
order = 'Rank ASC, priority ASC'

jql = "#{conditions.join ' AND '} ORDER BY #{order}"
puts jql
path = "/rest/api/2/search"
joined_path = "#{path}?jql=#{CGI.escape jql}"
puts joined_path

j = JiraAdapter.new
start_at = 0
max_results = 1000
fields = ['key', 'labels']

all_results = []
loop do
  puts "Fetching #{max_results} starting at #{start_at}..."
  r = j.get_issues conditions, order, {start_at: start_at, max_results: max_results, fields: fields}
  break if r.length == 0
  all_results.push *r
  start_at += max_results
end

failed = []
all_results.each_with_index{|i, index|
  labels = i.labels + ['metal_bunnies']
  failed << i unless i.save({fields: {labels: labels}})
  puts "#{index+1}/#{all_results.length}: #{i.key} #{i.labels}"
}

unless failed.empty?
  puts "#{failed.length} issues could not be edited"
end
