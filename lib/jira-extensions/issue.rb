require 'jira'
require 'jira-extensions/sprint'

class JIRA::Resource::Issue
  TARGET_BRANCH_KEY = 'customfield_12905'
  TARGET_VERSION_KEY = 'customfield_12803'

  def target_branch
    begin
      self.send TARGET_BRANCH_KEY
    rescue
      nil
    end
  end
  
  def target_branch_name
    return nil if self.target_branch.nil?
    self.target_branch['name']
  end

  def target_version
    begin
      self.send TARGET_VERSION_KEY
    rescue
      nil
    end
  end
  
  def target_version_name
    return nil if self.target_version.nil?
    self.target_version['name']
  end

  def has_parent?
    begin
      self.parent
      true
    rescue NoMethodError
      return false
    end
  end

  def is_parent?
    begin
      if self.subtasks && self.subtasks.length > 0
        true
      else
        false
      end
    rescue NoMethodError
      false
    end
  end
  
  def pull_requests
    rgx = %r{https?://github\.com/.+/pull/([0-9]+)}i
    results = []

    scrape_prs = lambda do |s, time|
      return [] if s.nil?
      s.to_enum(:scan, rgx).
        map{Regexp.last_match}.
        map{|m|
          {
            :key => m[1],
            :uri => m[0],
            :time => Time.parse(time)
          }
        }
    end

    results.push *scrape_prs.call(self.description, self.updated)

    self.comments.each do |comment|
      results.push *scrape_prs.call(comment.body, comment.updated)
    end

    results = results.sort_by{|pr| pr[:time]}.reverse
    
    results
  end

  def sprints
    result = customfield_10800.map{|s| Sprint.new s}
    result
  end
  
  def current_sprint
    temp = sprints
    temp.delete_if{|s| !s.active?}
    return nil if temp.empty?
    temp.sort_by!{|s| s.startDate}.last
  end
end

