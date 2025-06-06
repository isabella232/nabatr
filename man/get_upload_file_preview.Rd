% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/nabat_gql_queries.R
\name{get_upload_file_preview}
\alias{get_upload_file_preview}
\title{Get Upload file preview}
\usage{
get_upload_file_preview(
  file_path,
  token,
  survey_type = "bulk_sae",
  branch = "prod",
  url = NULL,
  aws_gql = NULL,
  aws_alb = NULL,
  docker = FALSE
)
}
\arguments{
\item{file_path}{String full path to CSV file for preview}

\item{token}{List token created from get_nabat_gql_token() or
get_refresh_token()}

\item{survey_type}{(optional) String 'bulk_sae' | 'bulk_mae' | 'bulk_hib' | 'bulk_mat'}

\item{branch}{(optional) String that defaults to 'prod' but can also be
'dev'|'beta'|'local'}

\item{url}{(optional) String url to use for GQL}

\item{aws_gql}{(optional) String url to use in aws}

\item{aws_alb}{(optional) String url to use in aws}

\item{docker}{(optional) Boolean if being run in docker container or not}
}
\description{
Returns a template to be uploaded with the processing function
}
