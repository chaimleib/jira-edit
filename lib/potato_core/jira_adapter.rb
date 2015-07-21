require 'potato_core/jira_connection'
require 'potato_core/version_scraper'

class JiraAdapter
  attr_reader :connection, :jira
  
  def initialize
    @connection = JiraConnection.new
    @jira = @connection.client
  end
  
  ### CALLED BY PotatoHelper ###
  
  def get_task_tallies_by_version(user)
    issues = get_task_list_by_version user

    n = Time.now
    data = {}
    
    # tally the tasks
    issues.each do |ver, tasks|
      data[ver] = { :tasks => tasks.length }
    end
    
    # assign due dates
    data.each do |ver, row|
      data[ver][:version] = ver
      data[ver][:due] = DueDate.for_version ver
    end
    data
  end
  
  def get_tasks_by_propagation(user=@connection.username)
    conditions = [
      "sprint in openSprints()",
      "type='code propagation'",
      "status not in (closed,resolved)"
    ]

    parent_conditions = [
      "status in (reopened,'code review','ready to merge',resolved,'code propagation')",
      "type in (story,bug)"
    ]

    query_result = get_issues_by_user user, conditions
    parent_keys = []   # parents I need to check later
    issue_filter = []  # results of filtering on this issue's data
    query_result.each do |issue|
      next if !issue.has_parent?
      parent_keys.push issue.parent['key']  # look up more stuff later

      line = {}
      line[:user] = issue.assignee.name
      line[:key] = issue.key
      line[:status] = issue.status.name
      line[:target] = target = issue.target_branch_name || issue.target_version_name
      line[:prs] = issue.pull_requests
      line[:due] = DueDate.for_version target
      line[:parent] = issue.parent['key']

      issue_filter.push line
    end

    filtered_parents = get_issues_by_keys(parent_keys, parent_conditions)

    parent_filter = []  # results of filtering issues on parents' data
    issue_filter.each do |line|
      parent_key = line[:parent]
      next unless filtered_parents.has_key? parent_key
      
      parent = filtered_parents[parent_key]
      line[:parent_status] = parent.status.name
      line[:parent_target] = parent.target_branch_name || parent.target_version_name

      parent_filter.push line
    end

    parent_filter
  end
  
  
  ### INTERNAL ###
  
  def get_task_list_by_version(user)
    issues = get_open_issues user
    issues.delete_if &:has_parent?
      
    sorted = sort_issues_by_version_category issues
    sorted.each{ |ver, issues|
      sorted[ver] = issues.map &:key
    }
    sorted
  end
  
  def sort_issues_by_version_category(issues)
    result = {}
    _add_to_version = proc do |issue, version|
      result[version] = [] if !result.has_key? version
      result[version].push issue
    end
    issues.each do |issue|
      version = issue_version_category issue
      _add_to_version.call issue, version
    end
    result
  end
  
  def issue_affected_versions(issue)
    versions = issue.versions.map &:name
  end
  
  def issue_version_category(issue)
    issue.target_branch_name || 
      issue.target_version_name || 
      "Unversioned"
  end
  
  def get_issue(key)
    issue = @jira.Issue.find key
  end
  
  def get_issues(conditions=[], order="updated desc", options={})
    verbose = options.delete :verbose
    query = conditions.join " AND "
    query += " order by #{order}" if order.present?
    if verbose
      puts(options.present? ? 
        "#{query}# options: #{options}" : 
        query)
    end
    issues = @jira.Issue.jql query, **options
  end

  def get_issues_by_user(username=@connection.username, conditions=[], order="updated desc")
    return nil unless username.present?
    usernames = (username.class == Array) ? username : [username]
    user_conditions = usernames.map{|name|
      sanitized_name = ActiveRecord::Base::sanitize name
      if sanitized_name.include? ' '
        user_condition = "assignee=#{sanitized_name}"
      else
        user_condition = "(assignee=#{sanitized_name} OR labels=#{sanitized_name})"
      end
      user_condition
    }.
      join ' OR '
    conditions.unshift user_conditions
    get_issues conditions, order
  end
  
  def get_issues_by_keys(keys, conditions=[], order="key asc")
    return {} if keys.empty?
    sanitized_keys = keys.map{|k| ActiveRecord::Base::sanitize k}.join ','
    conditions.unshift "key in (#{sanitized_keys})"
    issues = get_issues conditions, order
    result = {}
    issues.each do |issue|
      key = issue.key
      result[key] = issue
    end
    result
  end

  def get_open_issues(username=@connection.username)
    conditions = [
      'sprint in openSprints()',
      'status not in (Closed,Resolved)',
    ]
    issues = get_issues_by_user username, conditions
  end
  
  def get_user(username=@connection.username)
    begin
      user = @jira.User.find username
    rescue JIRA::HTTPError
      nil
    end
  end

  def get_projects
    projects = @jira.Project.all
    projects.each do |project|
      puts "#{project.key}: #{project.name}"
    end
  end

  ### DEBUG ONLY ###
  def print_issue_array(issues)
    issues.each do |issue|
      # parent = issue.fields.parent.key
      status = issue.status.name
      description = issue.description
      if description
        description.gsub! "\n", ' '
        description.gsub! "\r", ''
      else
        description = '<No description>'
      end
      versions = issue.versions.map &:name
      versions = versions.join ', '
      if versions.empty?
        versions = 'No versions assigned'
      else
        versions = "Versions: #{versions}"
      end
      puts "# #{issue.key} #{issue.updated} (#{status}): #{versions}"
      puts description
      puts ''
    end
  end
end

