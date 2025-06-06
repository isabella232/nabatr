#############################################################################
#     _   _____    ____        __  ____
#    / | / /   |  / __ )____ _/ /_/ __ \
#   /  |/ / /| | / __  / __ `/ __/ /_/ /
#  / /|  / ___ |/ /_/ / /_/ / /_/ _, _/
# /_/ |_/_/  |_/_____/\__,_/\__/_/ |_|
#
# R Tools for accessing and manipulating North American Bat Monitoring data
#
# Written by: Kyle Enns
#
# FILE DESCRIPTION:  This file contains functions that query the NABat
# GQL API for summary information on the different data types
#
# USGS DISCLAIMER:  This software is in the public domain because it contains
# materials that originally came from the U.S. Geological Survey, an agency
# of the United States Department of Interior. For more information, see the
# [official USGS copyright policy]
# (https://www.usgs.gov/visual-id/credit_usgs.html#copyright/
# "official USGS # copyright policy")
#
# Although this software program has been used by the U.S. Geological Survey
# (USGS), no warranty, expressed or implied, is made by the USGS or the U.S.
# Government as to the accuracy and functioning of the program and related
# program material nor shall the fact of distribution constitute any such
# warranty, and no responsibility is assumed by the USGS in connection
# therewith.
#
# This software is provided "AS IS."
#############################################################################


#' @title Get All project's data types available
#'
#' @import jsonlite
#'
#' @description Returns a dataframe with all of a project's data types
#' (stationary/mobile/colonycount)
#'
#' @param token List token created from get_nabat_gql_token() or
#' get_refresh_token()
#' @param branch (optional) String that defaults to 'prod' but can also be
#' 'dev'|'beta'|'local'
#' @param url (optional) String url to use for GQL
#' @param aws_gql (optional) String url to use in aws
#' @param aws_alb (optional) String url to use in aws
#' @param docker (optional) Boolean if being run in docker container or not
#'
#' @export
#'
get_all_project_types = function(
  token,
  branch ='prod',
  url = NULL,
  aws_gql = NULL,
  aws_alb = NULL,
  docker = FALSE){

  # Get headers for token
  tkn_hdr = get_token_headers(token, branch, url, aws_gql, aws_alb, docker)
  headers = tkn_hdr$headers
  token   = tkn_hdr$token
  url     = tkn_hdr$url

  # GQL Query
  query = paste0('query {
    allSurveys{
      nodes{
        projectId
        surveyEventsBySurveyId{
          nodes{
            surveyTypeId
          }
        }
  		}
    }
  }')

  # Create body to send to GQL
  pbody = list(query = query)
  # Query GQL API
  res      = httr::POST(url, headers, body = pbody, encode='json')
  content   = httr::content(res, as = 'text')
  json = fromJSON(content, flatten = TRUE)
  # Convert to dataframe from json
  df   = as.data.frame(json$data$allSurveys$nodes, stringsAsFactors = FALSE) %>%
    tidyr::unnest('surveyEventsBySurveyId.nodes') %>%
    dplyr::distinct()
  # Rename fields
  names(df) = tolower(gsub("(?<=[a-z0-9])(?=[A-Z])", "_", names(df), perl = TRUE))

  # Return dataframe of projects
  return (df)
  }



#' @title Get a Project's Stationary Acoustic Summary Data
#'
#' @import jsonlite
#'
#' @description Returns a dataframe with all of a project's acoustic
#' stationary data down to the event
#'
#' @param token List token created from get_nabat_gql_token() or
#' get_refresh_token()
#' @param project_df Dataframe output from get_projects()
#' @param project_id Numeric or String a project id
#' @param branch (optional) String that defaults to 'prod' but can also be
#' 'dev'|'beta'|'local'
#' @param url (optional) String url to use for GQL
#' @param aws_gql (optional) String url to use in aws
#' @param aws_alb (optional) String url to use in aws
#' @param docker (optional) Boolean if being run in docker container or not
#' @param return_t (optional) Boolean Changes the Returned value to a list
#' and adds a token as one of the returned values (if set to TRUE)
#'
#' @export
#'
get_sa_project_summary = function(
  token,
  project_df,
  project_id,
  branch ='prod',
  url = NULL,
  aws_gql = NULL,
  aws_alb = NULL,
  docker = FALSE,
  return_t = FALSE){

  # Get headers for token
  tkn_hdr = get_token_headers(token, branch, url, aws_gql, aws_alb, docker)
  headers = tkn_hdr$headers
  token   = tkn_hdr$token
  url     = tkn_hdr$url

  # GQL Query
  query = paste0('query RRsaSummaries {
    allVwAcousticSummaries(
      filter: {projectId: {equalTo: ', project_id ,'}, surveyTypeId: {equalTo: 7}}
    ) {
      nodes {
      projectId
      grtsCellId
      surveyId
      surveyEventId
      surveyTypeId
      event
      date
      verified
      missing
      }
    }
  }')
  pbody = list(query = query, operationName = 'RRsaSummaries')

  # Post to nabat GQL
  res = httr::POST(url, headers, body = pbody, encode='json')
  content = httr::content(res, as = 'text')
  cont_json = jsonlite::fromJSON(content, flatten = TRUE)
  # Rename field names to snake case instead of camel case
  cont_df   = as.data.frame(cont_json$data$allVwAcousticSummaries$nodes,
    stringsAsFactors = FALSE)
  names(cont_df) = tolower(gsub("(?<=[a-z0-9])(?=[A-Z])", "_", names(cont_df), perl = TRUE))
  # Add a year field that is a string split from the date field
  if (dim(cont_df)[1] > 0){
    cont_df$year = as.integer(gsub("^.* ", "", cont_df$date))
    row.names(cont_df) = NULL
  }

  # Define global grts_fname()
  grts_fname = get_grts_frame_name(project_df, project_id)
  assign('grts_fname', grts_fname, pkg.env)

  # Define package environmental variables
  if (is.null(pkg.env$bats_df)){
    # print ('Setting species_df environmental variable')
    species_df = get_species(token = token, url = url, aws_gql = aws_gql,
      aws_alb = aws_alb, docker = docker)
    assign('bats_df', species_df, pkg.env)
  }

  # If return_t is TRUE, return token as well
  if (return_t){
    return (list(df = cont_df, token = token))
  }else{
    # Return dataframe of projects
    return (cont_df)
  }
}



#' @title Get a Project's Mobile Acoustic Summary Data
#'
#' @description Returns a dataframe with all of a project's acoustic
#' mobile data down to the event
#'
#' @param token List token created from get_nabat_gql_token() or
#' get_refresh_token()
#' @param project_df Dataframe output from get_projects()
#' @param project_id Numeric or String a project id
#' @param branch (optional) String that defaults to 'prod' but can also be
#' 'dev'|'beta'|'local'
#' @param url (optional) String url to use for GQL
#' @param aws_gql (optional) String url to use in aws
#' @param aws_alb (optional) String url to use in aws
#' @param docker (optional) Boolean if being run in docker container or not
#' @param return_t (optional) Boolean Changes the Returned value to a list
#' and adds a token as one of the returned values (if set to TRUE)
#'
#' @export
#'
get_ma_project_summary = function(
  token,
  project_df,
  project_id,
  branch ='prod',
  url = NULL,
  aws_gql = NULL,
  aws_alb = NULL,
  docker = FALSE,
  return_t = FALSE){

  # Get headers for token
  tkn_hdr = get_token_headers(token, branch, url, aws_gql, aws_alb, docker)
  headers = tkn_hdr$headers
  token   = tkn_hdr$token
  url     = tkn_hdr$url

  # GQL Query
  query = paste0('query RRmaSummaries {
      allVwAcousticSummaries(
      filter: {projectId: {equalTo: ', project_id ,'}, surveyTypeId: {equalTo: 8}}
    ) {
      nodes {
      projectId
      grtsCellId
      surveyId
      surveyEventId
      surveyTypeId
      event
      verified
      missing
      }
    }
  }')
  pbody = list(query = query, operationName = 'RRmaSummaries')

  # Post to nabat GQL
  res = httr::POST(url, headers, body = pbody, encode='json')
  content = httr::content(res, as = 'text')
  cont_json = jsonlite::fromJSON(content, flatten = TRUE)
  # Rename field names to snake case instead of camel case
  cont_df   = as.data.frame(cont_json$data$allVwAcousticSummaries$nodes,
    stringsAsFactors = FALSE)
  names(cont_df) = tolower(gsub("(?<=[a-z0-9])(?=[A-Z])", "_", names(cont_df),
    perl = TRUE))
  # Add a year field that is a string split from the event field
  if (dim(cont_df)[1] > 0){
    cont_df$year = as.integer(gsub("^.* ", "", cont_df$event))
    row.names(cont_df) = NULL
  }

  # Define global grts_fname()
  grts_fname = get_grts_frame_name(project_df, project_id)
  assign('grts_fname', grts_fname, pkg.env)

  # Define package environmental variables
  if (is.null(pkg.env$bats_df)){
    # print ('Setting species_df environmental variable')
    species_df = get_species(token = token, url = url, aws_gql = aws_gql,
      aws_alb = aws_alb, docker = docker)
    assign('bats_df', species_df, pkg.env)
  }

  # If return_t is TRUE, return token as well
  if (return_t){
    return (list(df = cont_df, token = token))
  }else{
    # Return dataframe of projects
    return (cont_df)
  }
}



#' @title Get a Project's Colony Count Summary Data
#'
#' @import jsonlite
#'
#' @description Returns a dataframe with all of a project's colony
#' count data down to the event
#'
#' @param token List token created from get_nabat_gql_token() or
#' get_refresh_token()
#' @param project_df Dataframe output from get_projects()
#' @param project_id Numeric or String a project id
#' @param branch (optional) String that defaults to 'prod' but can also be 'dev'|'beta'|'local'
#' @param url (optional) String url to use for GQL
#' @param aws_gql (optional) String url to use in aws
#' @param aws_alb (optional) String url to use in aws
#' @param docker (optional) Boolean if being run in docker container or not
#' @param return_t (optional) Boolean Changes the Returned value to a list
#' and adds a token as one of the returned values (if set to TRUE)
#'
#' @export
#'
get_cc_project_summary = function(
  token,
  project_df,
  project_id,
  branch ='prod',
  url = NULL,
  aws_gql = NULL,
  aws_alb = NULL,
  docker = FALSE,
  return_t = FALSE){

  # Get headers for token
  tkn_hdr = get_token_headers(token, branch, url, aws_gql, aws_alb, docker)
  headers = tkn_hdr$headers
  token   = tkn_hdr$token
  url     = tkn_hdr$url

  # GQL Query
  query = paste0('query RRccSummaries{
    allVwColonyCountSummaries (filter :{projectId:{equalTo:',
    project_id,'}}){
    nodes{
      projectId,
      surveyId,
      grtsCellId,
      eventId,
      surveyTypeId,
      date,
      siteIdentifier,
      siteName,
      countDead,
      countAlive
  }
  }
  }')
  pbody = list(query = query)

  # Post to nabat GQL
  res = httr::POST(url, headers, body = pbody, encode='json')
  content = httr::content(res, as = 'text')
  cont_json = jsonlite::fromJSON(content, flatten = TRUE)
  # Rename field names to snake case instead of camel case
  cont_df   = as.data.frame(cont_json$data$allVwColonyCountSummaries$nodes,
    stringsAsFactors = FALSE)
  names(cont_df) = tolower(gsub("(?<=[a-z0-9])(?=[A-Z])", "_", names(cont_df), perl = TRUE))
  # Add a year field that is a string split from the event field
  if (dim(cont_df)[1] > 0){
    cont_df$year = as.integer(gsub("^.* ", "", cont_df$date))
    row.names(cont_df) = NULL
  }

  # Define global grts_fname()
  grts_fname = get_grts_frame_name(project_df, project_id)
  assign('grts_fname', grts_fname, pkg.env)

  # Define package environmental variables
  if (is.null(pkg.env$bats_df)){
    # print ('Setting species_df environmental variable')
    species_df = get_species(token = token, url = url, aws_gql = aws_gql,
      aws_alb = aws_alb, docker = docker)
    assign('bats_df', species_df, pkg.env)
  }

  # If return_t is TRUE, return token as well
  if (return_t){
    return (list(df = cont_df, token = token))
  }else{
    # Return dataframe of projects
    return (cont_df)
  }
}


#' @title Get a Project's Emergence Count Summary Data
#'
#' @description Returns a dataframe with all of a project's colony
#' count data down to the event
#'
#' @param token List token created from get_nabat_gql_token() or
#' get_refresh_token()
#' @param project_id Numeric or String a project id
#' @param branch (optional) String that defaults to 'prod' but can also be 'dev'|'beta'|'local'
#' @param url (optional) String url to use for GQL
#' @param aws_gql (optional) String url to use in aws
#' @param aws_alb (optional) String url to use in aws
#' @param docker (optional) Boolean if being run in docker container or not
#' @param return_t (optional) Boolean Changes the Returned value to a list
#' and adds a token as one of the returned values (if set to TRUE)
#'
#' @export
#'
get_ee_project_summary = function(
  token,
  project_id,
  branch ='prod',
  url = NULL,
  aws_gql = NULL,
  aws_alb = NULL,
  docker = FALSE,
  return_t = FALSE){

  # Get headers for token
  tkn_hdr = get_token_headers(token, branch, url, aws_gql, aws_alb, docker)
  headers = tkn_hdr$headers
  token   = tkn_hdr$token
  url     = tkn_hdr$url

  # GQL Query
  query = paste0('
    query RReeSummaries {
      allVwEmergenceCountSummaries(filter: {projectId: {in: [', project_id ,']}}) {
        nodes {
          date
          eventId
          grtsCellId
          grtsId
          projectId
          siteName
          surveyId
          surveyTypeId
          year
        }
      }
    }')
  pbody = list(query = query, operationName = 'RReeSummaries')
  # Query GQL API
  res       = httr::POST(url, headers, body = pbody, encode='json')
  content   = httr::content(res, as = 'text')
  json = fromJSON(content, flatten = TRUE)
  df = as_tibble(json$data$allVwEmergenceCountSummaries$nodes) %>% as.data.frame(stringsAsFactors = FALSE)
  names(df) = tolower(gsub("(?<=[a-z0-9])(?=[A-Z])", "_", names(df), perl = TRUE))

  # If return_t is TRUE, return token as well
  if (return_t){
    return (list(df = df, token = token))
  }else{
    # Return dataframe of projects
    return (df)
  }
}

