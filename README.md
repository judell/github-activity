# Using SQL to query GitHub activity

The [GitHub plugin](https://hub.steampipe.io/plugins/turbot/github) provides tables, including [github.github_search_issue](https://hub.steampipe.io/plugins/turbot/github/tables/github.github_search_issue) and [github.github_search_pull_request](https://hub.steampipe.io/plugins/turbot/github/tables/github.github_search_pull_request), that leverage GitHub's powerful search syntax. Here are some ways to use it to explore a user's activity.

## Issues created by a user in a set of repos

Here I'm looking for issues that I created in any of 100+ repos whose names match `turbot`.

```sql
select
  *
from
  github.github_search_issue
where
  query = 'is:issue author:judell'
  and html_url ~ 'turbot'
```

The native GitHub query can almost do this, but https://github.com/issues?q=is:issue+author:judell doesn't filter by repo, and you can't say https://github.com/issues?q=is:issue+author:judell+repo:*turbot*.

## Issues/pulls where a user is author/assignee/mentioned or a commenter, in a set of repos

This query combines eight CTEs that encapsulate variations of the GitHub query syntax for both issues and pull requests

```sql
with my_created_issues as (
  select
    html_url,
    title,
    updated_at,
    created_at,
    closed_at,
    comments
  from
    github.github_search_issue
  where
    query = 'is:issue author:judell'
    and html_url ~ 'turbot'
  ),

  my_assigned_issues as (
    select
      html_url,
      title,
      updated_at,
      created_at,
      closed_at,
      comments
    from
      github.github_search_issue
    where
      query = 'is:issue assignee:judell'
      and html_url ~ 'turbot'
  ),

  my_mentioned_issues as (
    select
      html_url,
      title,
      updated_at,
      created_at,
      closed_at,
      comments
    from
      github.github_search_issue
    where
      query = 'is:issue mentions:judell'
      and html_url ~ 'turbot'
  ),

  my_commenter_issues as (
    select
      html_url,
      title,
      updated_at,
      created_at,
      closed_at,
      comments
    from
      github.github_search_issue
    where
      query = 'is:issue commenter:judell'
      and html_url ~ 'turbot'
  ),

  my_created_pulls as (
    select
      html_url,
      title,
      updated_at,
      created_at,
      closed_at,
      comments
    from
      github.github_search_pull_request
    where
      query = 'is:pr author:judell'
      and html_url ~ 'turbot'
  ),

  my_assigned_pulls as (
    select
      html_url,
      title,
      updated_at,
      created_at,
      closed_at,
      comments
    from
      github.github_search_pull_request
    where
      query = 'is:pr assignee:judell'
      and html_url ~ 'turbot'
  ),

  my_mentioned_pulls as (
    select
      html_url,
      title,
      updated_at,
      created_at,
      closed_at,
      comments
    from
      github.github_search_pull_request
    where
      query = 'is:pr mentions:judell'
      and html_url ~ 'turbot'
  ),

  my_commenter_pulls as (
    select
      html_url,
      title,
      updated_at,
      created_at,
      closed_at,
      comments
    from
      github.github_search_issue
    where
      query = 'is:pr commenter:judell'
      and html_url ~ 'turbot'
  ),

  combined as (
    select * from my_created_issues
    union
    select * from my_assigned_issues
    union
    select * from my_mentioned_issues
    union
    select * from my_commenter_issues
    union
    select * from my_created_pulls
    union
    select * from my_assigned_pulls
    union
    select * from my_mentioned_pulls
    union
    select * from my_commenter_pulls
  )

  select distinct
    *
  from
    combined
  order by
    updated_at desc
```

## Caching results in a materialized view

For the above parameters -- user `judell` and repo match `turbot` -- Steampipe runs the initial query in 13.5 seconds. Followup queries that filter the initial results are instantaneous within the default 5-minute cache duration. One way to persist the cache is to wrap the query in a materialized view.

```sql
create materialized view my_github_activity as (
  -- include above sql
) with data;
```

If I create that view today, it's immediately available throughout the day. Tomorrow I can say `refresh materialized view my_github_activity` to spend another 13.5 seconds recaching the view for the rest of that day.

## Parameterizing the query

Here are three ways to refine the query:

- Find issues/pulls for a different user

- Find issues/pulls in repos whose names match a different pattern

- Find issues/pulls whose bodies match a search string 

This function parameterizes the query in those ways.

```sql
create or replace function github_activity(match_user text, match_repo text, match_body text) 
  returns table (
    html_url text,
    title text,
    updated_at timestamptz,
    created_at timestamptz,
    closed_at timestamptz,
    comments bigint,
    body text
  ) as $$
  begin 
    return query
      with my_created_issues as (
        select
          i.html_url,
          i.title,
          i.updated_at,
          i.created_at,
          i.closed_at,
          i.comments,
          i.body
        from
          github.github_search_issue i
        where
          i.query = 'is:issue author:' || match_user
          and i.html_url ~ match_repo
        ),

        my_assigned_issues as (
          select
            i.html_url,
            i.title,
            i.updated_at,
            i.created_at,
            i.closed_at,
            i.comments,
            i.body
          from
            github.github_search_issue i
          where
            i.query = 'is:issue assignee:' || match_user
            and i.html_url ~ match_repo
        ),

        my_mentioned_issues as (
          select
            i.html_url,
            i.title,
            i.updated_at,
            i.created_at,
            i.closed_at,
            i.comments,
            i.body
          from
            github.github_search_issue i
          where
            i.query = 'is:issue mentions:' || match_user
            and i.html_url ~ match_repo
        ),

        my_commenter_issues as (
          select
            i.html_url,
            i.title,
            i.updated_at,
            i.created_at,
            i.closed_at,
            i.comments,
            i.body
          from
            github.github_search_issue i
          where
            i.query = 'is:issue commenter:' || match_user
            and i.html_url ~ match_repo
        ),

        my_created_pulls as (
          select
            p.html_url,
            p.title,
            p.updated_at,
            p.created_at,
            p.closed_at,
            p.comments,
            p.body
          from
            github.github_search_pull_request p
          where
            p.query = 'is:pr author:' || match_user
            and p.html_url ~ match_repo
        ),

        my_assigned_pulls as (
          select
            p.html_url,
            p.title,
            p.updated_at,
            p.created_at,
            p.closed_at,
            p.comments,
            p.body
          from
            github.github_search_pull_request p
          where
            p.query = 'is:pr assignee:' || match_user
            and p.html_url ~ match_repo
        ),

        my_mentioned_pulls as (
          select
            p.html_url,
            p.title,
            p.updated_at,
            p.created_at,
            p.closed_at,
            p.comments,
            p.body
          from
            github.github_search_pull_request p
          where
            p.query = 'is:pr mentions:' || match_user
            and p.html_url ~ match_repo
        ),

        my_commenter_pulls as (
          select
            p.html_url,
            p.title,
            p.updated_at,
            p.created_at,
            p.closed_at,
            p.comments,
            p.body
          from
            github.github_search_pull_request p
          where
            p.query = 'is:pr commenter:' || match_user
            and p.html_url ~ match_repo
        ),

        combined as (
          select * from my_created_issues
          union
          select * from my_assigned_issues
          union
          select * from my_mentioned_issues
          union
          select * from my_commenter_issues
          union
          select * from my_created_pulls
          union
          select * from my_assigned_pulls
          union
          select * from my_mentioned_pulls
          union
          select * from my_commenter_pulls
        ),

        filtered as (
          select distinct
            *
          from
            combined c
          where 
            ( c.body is not null and c.body ~* match_body )
            or
            ( c.body is null and match_body = '')
        )

      select 
        *
      from
        filtered f
      order by
        f.updated_at desc;
    end;
$$ language plpgsql;
```

The SQL wrapped in this function uses Postgres [POSIX regular expression match operators](https://www.postgresql.org/docs/current/functions-matching.html#FUNCTIONS-POSIX-REGEXP): `~` and its case-insensitive counterpart `~*`. 

When you use one of these operators to match a string and the empty string, the result is always true.

```
select 'abc123' ~ '' as match
 match
-------
 t
(1 row)
```

But when you match null and the empty string, it isn't.

```
select null ~ '' as match;
 match
-------

(1 row)
```

(I'm not sure why Postgres doesn't report `f` here.)

Anyway, since issue/pr bodies can be null, the `filtered` CTE has to handle both cases. 

To create the function, paste that code into the Steampipe CLI (`steampipe query`) or `psql`.

Now these queries are possible.

### Issues/pulls for user 'judell', in repos matching 'turbot'

This does exactly what the above query does.

```sql
select * from github_activity('judell','turbot','')
```

It can be cached like so.

```sql
create materialized view my_github_activity as (
  select * from github_activity('judell','turbot','')
) with data;
```

### Issues/pulls for user 'judell' in any repo

```sql
select * from github_activity('judell','','')
```

### Issues/pulls for user 'rajlearner17' in any steampipe-mod repo

```sql
select * from github_activity('rajlearner17','steampipe-mod','')
```

### Issues/pulls matching 'nil pointer' for user 'kaidaguerre' in any turbot repo

```sql
select * from github_activity('kaidaguerre','turbot','nil pointer')
```
### See the examples

![](./github-activity.gif)

### Make the function's parameters interactive

If you connect a visualizer to Steampipe, and if the visualizer supports UX for substitutable parameters, then you can make the function's parameters interactive. Here's an example in Tableau. 

![](./in-tableau.gif)


