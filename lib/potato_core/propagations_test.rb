require 'potato_core/jira_adapter'
require 'potato_helper'
require 'pry'

if __FILE__ == $0
  user = 'user'
  jira = JiraAdapter.new
  data = jira.get_tasks_by_propagation user
  binding.pry
  data2 = PotatoHelper.format_tasks_by_propagation(user, nil, jira)[:propagations_table_data]
  binding.pry
end
