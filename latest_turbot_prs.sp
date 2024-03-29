dashboard "Latest_Turbot_Pull_Requests" {

  tags = {
    service = "GitHub Activity"
  }

  container {
    text {
      value = replace(
        replace(
          "${local.menu}",
          "__HOST__",
          "${local.host}"
        ),
        "[Latest_Turbot_Pull_Requests](${local.host}/github_activity.dashboard.Latest_Turbot_Pull_Requests)",
        "Latest_Turbot_Pull_Requests"
      )
    }
  }  


  container {

    table {
      title = "Latest PR activity by repo"
      sql = <<EOQ
        with rankedprs as (
          select
            repository_full_name,
            number,
            created_at,
            updated_at,
            closed_at,
            author_login,
            title,
            html_url,
            row_number() over (
              partition by repository_full_name 
              order by created_at desc
            ) as rank
          from
            github_pull_activity_all
        )
        select
          repository_full_name,
          number,
          created_at,
          updated_at,
          closed_at,
          author_login,
          title,
          html_url
        from
          rankedprs
        where
          rank = 1;
      EOQ
    }

  }

}