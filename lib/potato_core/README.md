# jira\_connection.rb

Abstracts the connection to the JIRA server and accesses its REST API. Passes JQL queries to the server.

## Hacking
The `JiraConnection` class stores information necessary to connect to and access JIRA. It also has some methods to process issues, which could not easily be monkey-patched into `JIRA::Resource::Issue` (see below).

### Monkey patches
There is one monkey-patched class: `JIRA::Resource::Issue`. This gives some aliases to custom ffields, but the aliases are imperfect. Where the custom fields are used, the original JIRA module uses `method\_missing` to do some fancy tricks to return queryable objects. My aliases, however, only return hashes, which cannot be queried in the same way.

### Classes
Only one new class is defined, in `lib/jira-extensions/sprint.rb`. My company uses `JIRA::Resource::Issue.customfield\_10800` to store a collection of strings describing which sprints the Issue belongs to. Unfortunately, the JIRA module does not parse them out to hashes for me, so I wrote the `Sprint` class which does. Its constructor takes one of these strings as an argument and returns a `Sprint` object whose fields can be accessed via dot notation.

### Utilities
JIRA issue objects tend to have lots of fields set to nil, which makes it difficult to find what you need. The `clean\_recurse` function removes such fields recursively, resulting in a smaller hash for display. It lives in `lib/utilities/object\_cleaner.rb`.


# version\_scraper.rb

Loads a secure HTML page with a release schedule on it, then scrapes the data from the tables.

Uses the same JIRA login info as `jira_connection.rb`:

```yml
jira:
    username: '<username>'
    password: '<password>'
    host: 'https://jira.example.com'
```

