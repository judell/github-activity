node "people_org_members" {
  sql = <<EOQ
    with data as (
      select 
        member_login
      from
        github_org_members()
      where not 
        member_login in ( select excluded_member_login from github_org_excluded_members() )
    )
    select
      member_login as id,
      member_login as title,
      jsonb_build_object(
        'member_login', member_login
      ) as properties
    from
      data
  EOQ
}

node "people_not_org_members" {
  sql = <<EOQ
    with data as (
      select distinct
        author_login
      from
        public.github_pull_activity('org:turbot', $1)
    )
    select
      author_login as id,
      author_login as title,
      jsonb_build_object(
        'login', author_login
      ) as properties
    from
      data
    where
      not author_login in ( select member_login from github_org_members() )
      and author_login !~ 'dependabot'
      and not author_login in ( select excluded_member_login from github_org_excluded_members() )
  EOQ
}

node "org_repos" {
  sql = <<EOQ
    with data as (
      select distinct
        repository_full_name
      from
        public.github_pull_activity($1, $2)
    )
    select
      repository_full_name as id,
      replace(repository_full_name, 'turbot/steampipe-', '') as title,
      jsonb_build_object(
        'repository_full_name', repository_full_name
      ) as properties
    from
      data
  EOQ
}

node "open_internal_pull_requests" {
  sql = <<EOQ
    with data as (
      select distinct
        *
      from
        public.github_pull_activity($1, $2)
      where
        author_login in (select * from github_org_members() )
        and not author_login ~ 'dependabot'
        and closed_at is null
    )
    select
      pr as id,
      title,
      jsonb_build_object(
        'repository_full_name', repository_full_name,
        'author', author_login,
        'number', number,
        'created_at', created_at,
        'closed_at', closed_at,
        'html_url', html_url,
        'title', title
      ) as properties
    from
      data
  EOQ
}

node "closed_internal_pull_requests" {
  sql = <<EOQ
    with data as (
      select distinct
        *
      from
        public.github_pull_activity($1, $2)
      where
        author_login in (select * from github_org_members() )
        and not author_login ~ 'dependabot'
        and closed_at is not null
    )
    select
      pr as id,
      title,
      jsonb_build_object(
        'repository_full_name', repository_full_name,
        'author', author_login,
        'number', number,
        'created_at', created_at,
        'closed_at', closed_at,
        'html_url', html_url,
        'title', title
      ) as properties
    from
      data
  EOQ
}

node "open_external_pull_requests" {
  sql = <<EOQ
    with data as (
      select distinct
        *
      from
        public.github_pull_activity($1, $2)
      where
        not author_login in (select * from github_org_members() )
        and not author_login ~ 'dependabot'
        and closed_at is null
    )
    select
      pr as id,
      title,
      jsonb_build_object(
        'repository_full_name', repository_full_name,
        'author', author_login,
        'number', number,
        'created_at', created_at,
        'closed_at', closed_at,
        'html_url', html_url,
        'title', title
      ) as properties
    from
      data
  EOQ
}

node "closed_external_pull_requests" {
  sql = <<EOQ
    with data as (
      select distinct
        *
      from
        public.github_pull_activity($1, $2)
      where
        not author_login in (select * from github_org_members() )
        and not author_login ~ 'dependabot'
        and closed_at is not null
    )
    select
      pr as id,
      title,
      jsonb_build_object(
        'repository_full_name', repository_full_name,
        'author', author_login,
        'number', number,
        'created_at', created_at,
        'closed_at', closed_at,
        'html_url', html_url,
        'title', title
      ) as properties
    from
      data
  EOQ
}



