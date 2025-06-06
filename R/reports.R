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
# FILE DESCRIPTION:  This file contains functions build NABat reports for
# stationary, mobile, and colony count data
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


#' @title Build Stationary Acoustic Report document in .docx file
#'
#' @description Using the outputs from get_projects(), get_sa_project_summary(),
#' get_as_bulk_wavs(), and get_observed_nights() this function will create a
#' report .docx file to an out_dir.
#'
#' @import mapview
#' @import officer
#' @import magrittr
#' @import maps
#' @import maptools
#' @import sp
#' @import flextable
#' @import stringr
#'
#' @examples
#'
#' \dontrun{
#' See vignette: build_sa_report (Build Stationary Acoustic Report)
#' }
#'
#' @export

build_sa_doc =  function(
  out_dir,
  file_name = 'sa_doc.docx',
  project_df,
  project_id,
  sa_bulk_df,
  sa_survey_df,
  species_df,
  selected_year,
  nightly_observed_list = NULL,
  date = format(Sys.time(), "%B %d, %Y"),
  range_maps = TRUE){


  message ('Enter Stationary Report Function')
  # Clean the data
  sa_bulk_df = sa_bulk_df %>%
    clean_time_fields() %>%
    add_observed_nights() %>%
    add_start_end_nights()


  # Add selected year as 1st year
  message ('Setup for temp directories')
  if (is.null(selected_year)){
    selected_year = unique(format(as.Date(sa_bulk_df$recording_time),
      '%Y'))[1]
  }
  # Setup temps directory to store intermediate files
  if (dir.exists(paste0(out_dir, '/temps/'))==FALSE){
    dir.create(paste0(out_dir, '/temps/'))
  }
  if (dir.exists(paste0(out_dir, '/temps/range_maps/'))==FALSE){
    dir.create(paste0(out_dir, '/temps/range_maps/'))
  }

  # Set Save figures boolean
  save_figures = TRUE

  message ('Getting nightly data')
  # If nightly_observed_list isn't put in through variable
  if (is.null(nightly_observed_list)){
    nightly_observed_list =  get_observed_nights(sa_bulk_df)
  }
  # Getting Manipulated data for species counts at GRTS cells
  auto_nights_df = nightly_observed_list$auto_nightly_df
  manual_nights_df  = nightly_observed_list$manual_nightly_df
  all_species_totals_l_l = get_all_species_counts_long(auto_nights_df,
    manual_nights_df, fil = TRUE)
  manual_species_grts_df_w   = get_species_counts_wide(manual_nights_df)$species_grts_df
  auto_species_grts_df_w   = get_species_counts_wide(auto_nights_df)$species_grts_df
  manual_species_totals_l = get_species_counts_long(manual_nights_df, filter=TRUE)
  auto_species_totals_l   = get_species_counts_long(auto_nights_df, filter=TRUE)

  message ('Setting project specific variables')
  # Set Variables
  sa_logo_img_ = system.file("templates", "nabat_logo.png", package = "nabatr")
  sa_circle_logo_ = system.file('templates', 'NABat_Circle_color.jpg',
    package = 'nabatr')
  sa_proj_id = project_id
  sa_project_row_df = subset(project_df, project_df$project_id == sa_proj_id)
  sa_title        = sa_project_row_df$project_name
  sa_organization = sa_project_row_df$organization
  sa_this_project_description = sa_project_row_df$project_description

  message ('Getting example text')
  # Get the example text to put into the report
  sa_examples = get_sa_examples()

  message ('Build results text')
  # Build the results text for Stationary acoustic report
  sa_results = get_sa_results(sa_bulk_df, selected_year, species_df)

  message ('Build table 1')
  # sa_table_1
  sa_table_1 = build_sa_table_1(sa_bulk_df, project_id, project_df,
    species_df, selected_year)

  message ('Build table 2')
  # sa table 2
  sa_table_2 = build_sa_table_2(sa_bulk_df, selected_year, species_df)

  message ('Build figure 1')
  # Figure 1 (map)
  sa_figure_1 = build_sa_figure_1(sa_bulk_df, out_dir, project_df,
    project_id, sa_survey_df, selected_year, save_figures)

  message('Build figure 2')
  # Figure 2a/2b
  sa_figure_2 = build_sa_figure_2(sa_bulk_df, out_dir, species_df,
    selected_year, auto_species_grts_df_w, manual_species_grts_df_w,
    save_figures)

  message('Build figure 3')
  # Figure 3
  sa_figure_3 = build_sa_figure_3(sa_bulk_df, out_dir, species_df,
    selected_year, save_figures)

  if (range_maps){
    message ('Build range maps')
    # build range maps
    maps_data = get_sa_range_maps(sa_bulk_df, project_df, project_id,
      all_species_totals_l_l, species_df, out_dir, range_maps)
  }


  message('Build final.docx document')
  ##### BUILD DOCUMENT
  # Fonts
  bold_face_map = shortcuts$fp_bold(font.size = 12)
  bold_face = shortcuts$fp_bold(font.size = 16)
  date_font = fp_text(color = 'black', font.family =
      'Cambria', font.size = 12)
  par_style = fp_par(text.align = "center")
  example_font = fp_text(color = "#bfbfbf", font.size = 12,
    bold = FALSE, italic = FALSE, underlined = FALSE,
    font.family = "Cambria", vertical.align = "baseline",
    shading.color = "transparent")
  fig6_font = fp_text(color = "black", font.size = 10,
    font.family = "Cambria")

  message ('Begin .docx build')
  sa_doc = read_docx() %>%
    body_add_fpar(fpar(ftext('Stationary Acoustic Report',
      prop = bold_face), fp_p = par_style ), style = 'centered') %>%
    body_add_fpar(fpar(ftext(paste0(selected_year, ' Data'),
      prop = date_font), fp_p = par_style ), style = 'centered') %>%
    body_add_par(value = "", style = "centered") %>%
    body_add_fpar(fpar(ftext(sa_title, prop = bold_face),
      fp_p = par_style ), style = 'centered') %>%
    body_add_par(value = "", style = "centered") %>%
    body_add_par(value = sa_organization, style = "centered") %>%
    body_add_par(value = date, style = "centered") %>%

    body_add_par(value = "", style = "centered") %>%
    body_add_par(value = "", style = "centered") %>%
    body_add_par(value = "", style = "centered") %>%
    body_add_par(value = "", style = "centered") %>%

    body_add_img(src = sa_circle_logo_, width = 2.5, height = 2.5,
      style= 'centered') %>%


    # Add summary data for project and GRTS cells
    body_add_par(value = "", style = "centered") %>%

    body_add_break() %>%

    # Project Description
    body_add_par(value = "Project Description",
      style = "heading 1") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_par(value = sa_this_project_description,
      style = "Normal") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_fpar(fpar(ftext(sa_examples$sa_ex_description,
      prop = example_font)), style = 'Normal') %>%

    body_add_break() %>%

    # Methods
    body_add_par(value = "Methods", style = "heading 1") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_par(value = "Site Selection", style = "heading 2") %>%
    body_add_par(value = sa_examples$sa_methods_1, style = "Normal") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_par(value = "Data Collection", style = "heading 2") %>%
    body_add_par(value = sa_examples$sa_methods_2, style = "Normal") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_par(value = "Call Processing/Species Identification",
      style = "heading 2") %>%
    body_add_par(value = sa_examples$sa_methods_3, style = "Normal") %>%

    body_add_break() %>%

    # Results
    body_add_par(value = "Results", style = "heading 1") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_par(value = sa_results, style = "Normal") %>%

    body_add_break() %>%

    # Summary
    body_add_par(value = "Summary", style = "heading 1") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_fpar(fpar(ftext(sa_examples$sa_summary_1,
      prop = example_font)), style = 'Normal') %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_fpar(fpar(ftext(sa_examples$sa_summary_2,
      prop = example_font)), style = 'Normal') %>%

    body_add_break() %>%

    # Table 1
    body_add_par(value = sa_table_1$description, style = "Normal") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_flextable(sa_table_1$table, align='left') %>%

    body_add_break() %>%

    # Table 2
    body_add_par(value = sa_table_2$description, style = "Normal") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_flextable(sa_table_2$table, align='left') %>%

    body_add_break() %>%

    # Figure 1
    body_add_par(value = sa_figure_1$description, style = "Normal") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_img(src = sa_figure_1$file, width = 5.7,
      height = 4, style= 'centered') %>%

    body_add_break() %>%

    # Figure 2a
    body_add_par(value = sa_figure_2$description_a, style = "Normal") %>%
    slip_in_img(src = sa_figure_2$file_a, width = 6.5, height = 5) %>%

    body_add_break() %>%

    # Figure 2b
    body_add_par(value = sa_figure_2$description_b, style = "Normal") %>%
    slip_in_img(src = sa_figure_2$file_b, width = 6.5, height = 5) %>%

    body_add_break() %>%

    # Figure 3
    body_add_par(value = sa_figure_3$description, style = "Normal") %>%
    slip_in_img(src = sa_figure_3$file, width = 6.5, height = 5) %>%
    body_add_break()

  message('Adding species range maps to .docx')
  # Add species range maps
  if (range_maps){
    map_c = 0
    fig_count = 3
    for (range_m in maps_data$maps_range_files){
      map_c = map_c + 1
      fig_count = fig_count + 1
      grts_m = maps_data$maps_grts_files[map_c]
      spc_range_name = str_split(str_split(sub('\\.png$', '', range_m),
        'range_maps/')[[1]][2], '_range')[[1]][1]
      spc_grts_name = str_split(str_split(sub('\\.png$', '', grts_m),
        'range_maps/')[[1]][2], '_grts')[[1]][1]

      fig_a_name = paste0('Figure ', as.character(fig_count), 'a. ')
      fig_b_name = paste0('Figure ', as.character(fig_count), 'b. ')

      descr_fig5 = paste0(fig_a_name,"Species range map for ", spc_range_name, ".")
      descr_fig6 = paste0(fig_b_name,"Map of NABat GRTS cells surveyed in ",selected_year," with species range map overlayed (",
spc_range_name,"). Green cells indicate the presence of ",spc_range_name," was confirmed exclusively through
manual vetting, blue cells indicate the presence of ",spc_range_name," was confirmed exclusively through
automated identification software, and orange cells indicate the presence of ",spc_range_name," was confirmed
using both automated identification software and manual vetting. Transparent
cells indicated that ",spc_range_name," was not detected at those locations.")

      # Add the maps to the doc
      sa_doc = sa_doc %>%
        body_add_fpar(fpar(ftext(paste0('Species:  ',spc_range_name),
          prop = bold_face_map), fp_p = par_style ), style = 'Normal') %>%
        body_add_fpar(fpar(ftext(descr_fig5, prop = fig6_font)),
          style = 'Normal') %>%
        slip_in_img(src = range_m, width = 5.7, height = 4) %>%
        body_add_par(value = "", style = "Normal") %>%
        body_add_fpar(fpar(ftext(descr_fig6, prop = fig6_font)),
          style = 'Normal') %>%
        body_add_par(value = "", style = "Normal") %>%
        slip_in_img(src = grts_m, width = 5.7, height = 4) %>%
        body_add_break()
    }
  }

  # Literature Cited
  sa_doc = sa_doc %>%
    body_add_par(value = "Literature Cited", style = "heading 1") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_par(value = sa_examples$sa_lit_cited, style = "Normal")

  return (sa_doc)
}



#' @title Build Report document in .docx file for Colony Count Data
#'
#' @description Using the outputs from get_projects(),
#' get_project_surveys(), get_colony_bulk_counts(),
#' and () this function will create a report .docx file to an out_dir.
#'
#' @import mapview
#' @import officer
#' @import magrittr
#' @import maps
#' @import maptools
#' @import sp
#' @import flextable
#' @import lubridate
#' @import ggplot2
#'
#' @examples
#'
#' \dontrun{
#' See vignette: build_cc_report (Build Colony Count Report)
#' }
#'
#' @export

build_col_doc = function(
  out_dir,
  file_name = 'cc_doc.docx',
  project_df = NULL,
  project_id,
  cc_bulk_df = NULL,
  date = format(Sys.time(), "%B %d, %Y")){

  if (dir.exists(paste0(out_dir, '/temps/')) == FALSE){
    dir.create(paste0(out_dir, '/temps/'))
  }

  message('Get front page info')
  # Get front page info
  cc_logo_img_      = system.file("templates", "nabat_logo.png",
    package = "nabatr")
  cc_circle_logo_   = system.file('templates', 'NABat_Circle_color.jpg',
    package = 'nabatr')
  cc_proj_id        = project_id
  cc_project_row_df = subset(project_df, project_df$project_id == cc_proj_id)
  cc_title          = cc_project_row_df$project_name
  cc_organization   = cc_project_row_df$organization
  cc_description    = cc_project_row_df$project_description

  message ('Get Examples')
  # Get Colony Count Examples
  cc_examples = get_cc_examples()

  message ('Get Results')
  # Get Colony Count results
  cc_results = get_cc_results(cc_bulk_df)

  message ('Build table 1')
  # Build Colony Count table 1
  cc_table_1 = build_cc_table_1(cc_bulk_df, TRUE)

  message('Build table 2')
  # Build Colony Count table 2
  cc_table_2 = build_cc_table_2(cc_bulk_df)

  message ('Build figure 1')
  # Build Colony Count figure 1
  cc_figure_1 = build_cc_figure_1(cc_bulk_df, out_dir, TRUE)

  message ('Add Fonts')
  # Add fonts
  bold_face = shortcuts$fp_bold(font.size = 16)
  par_style = fp_par(text.align = "center")
  example_font = fp_text(color = "#bfbfbf", font.size = 12, bold = FALSE,
    italic = FALSE, underlined = FALSE, font.family = "Cambria",
    vertical.align = "baseline", shading.color = "transparent")

  message ('Begin Colony Count .docx build')
  # Build Colony Count document
  cc_doc = read_docx() %>%
    body_add_fpar(fpar(ftext('Colony Count Report', prop = bold_face),
      fp_p = par_style ), style = 'centered') %>%
    body_add_par(value = "", style = "centered") %>%
    body_add_fpar(fpar(ftext(cc_title, prop = bold_face), fp_p = par_style ),
      style = 'centered') %>%
    body_add_par(value = "", style = "centered") %>%
    body_add_par(value = cc_organization, style = "centered") %>%
    body_add_par(value = date, style = "centered") %>%
    body_add_par(value = "", style = "centered") %>%
    body_add_par(value = "", style = "centered") %>%
    body_add_par(value = "", style = "centered") %>%
    body_add_par(value = "", style = "centered") %>%

    body_add_img(src = cc_circle_logo_, width = 2.5, height = 2.5,
      style = 'centered') %>%

    body_add_break() %>%

    # Project Description
    body_add_par(value = "Project Description", style = "heading 1") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_par(value = cc_description, style = "Normal") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_fpar(fpar(ftext(cc_examples$description, prop = example_font)),
      style = 'Normal') %>%

    body_add_break() %>%

    # Methods
    body_add_par(value = "Methods", style = "heading 1") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_fpar(fpar(ftext(cc_examples$methods_1, prop = example_font)),
      style = 'Normal') %>%

    body_add_break() %>%

    # Results
    body_add_par(value = "Results", style = "heading 1") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_par(value = cc_results, style = "Normal") %>%

    body_add_break() %>%

    body_end_section_continuous() %>%

    # Table 1
    body_add_par(value = cc_table_1$description, style = "Normal") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_flextable(cc_table_1$table, align='left') %>%

    body_end_section_landscape() %>%

    # Table 2
    body_add_par(value = cc_table_2$description, style = "Normal") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_flextable(cc_table_2$table, align='left') %>%

    body_end_section_continuous()

  # Figure 1
  count = 0
  if (length(cc_figure_1$file) > 1){
    for(file in cc_figure_1$file){
      count = count + 1
      cc_doc = cc_doc %>%
        body_add_par(value = cc_figure_1$description[count], style = "Normal") %>%
        slip_in_img(src = file, width = 7.5, height = 5.5)
    }
  }else{
    cc_doc = cc_doc %>%
      body_add_par(value = cc_figure_1$description, style = "Normal") %>%
      slip_in_img(src = cc_figure_1$file, width = 7.5, height = 5.5)
  }

  cc_doc = cc_doc %>%
    body_end_section_landscape() %>%

    # Literature Cited
    body_add_par(value = "Literature Cited", style = "heading 1") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_par(value = cc_examples$lit_cited, style = "Normal")

  return (cc_doc)
}



#' @title Build Mobile Acoustic Report document in .docx file
#'
#' @description Using the outputs from get_projects(),
#' get_ma_project_summary(), get_ma_bulk_wavs(),
#' and get_observed_nights() this function will create
#' a report .docx file to an out_dir.
#'
#' @import mapview
#' @import officer
#' @import magrittr
#' @import maps
#' @import maptools
#' @import sp
#' @import flextable
#' @import leaflet
#' @import rmarkdown
#' @import htmlwidgets
#' @import htmltools
#'
#' @examples
#'
#' \dontrun{
#' See vignette: build_ma_report (Build Mobile Acoustic Report)
#' }
#'
#'
#' @export

build_ma_doc = function(
  out_dir,
  file_name = 'ma_doc.docx',
  project_df,
  project_id,
  ma_bulk_df,
  species_df,
  year,
  nightly_observed_list,
  date = format(Sys.time(), "%B %d, %Y")){

  message ('Enter Stationary Report Function')
  # Clean the data
  ma_bulk_df = ma_bulk_df %>%
    clean_time_fields() %>%
    add_observed_nights()

  # Setup temps directory to store intermediate files
  if (dir.exists(paste0(out_dir, '/temps/'))==FALSE){
    dir.create(paste0(out_dir, '/temps/'))
  }
  if (dir.exists(paste0(out_dir, '/temps/range_maps/'))==FALSE){
    dir.create(paste0(out_dir, '/temps/range_maps/'))
  }

  logo_img_ = system.file("templates", "nabat_logo.png",
    package = "nabatr")
  circle_logo_ = system.file('templates', 'NABat_Circle_color.jpg',
    package = 'nabatr')
  proj_id = project_id
  project_row_df = subset(project_df,
    project_df$project_id == proj_id)
  ma_title        = project_row_df$project_name
  ma_organization = project_row_df$organization
  ma_description = project_row_df$project_description

  message ('build results')
  # Build results text
  ma_results = get_ma_results(ma_bulk_df, species_df, year)

  message ('build examples')
  # get example text for mobile acoustic report
  ma_examples = get_ma_examples()

  message ('build table 1')
  # Build table 1
  ma_table_1 = build_ma_table_1(ma_bulk_df, project_id,
    project_df, species_df, year)

  message ('build table 2')
  # Build table 2
  ma_table_2 = build_ma_table_2(ma_bulk_df, species_df, year)

  message ('build table 3')
  # Build table 3
  ma_table_3 = build_ma_table_3(ma_bulk_df, nightly_observed_list,
    species_df, year)

  message ('build figure 1 (map)')
  # Build figure 1
  ma_figure_1 = build_ma_figure_1(ma_bulk_df, project_id,
    project_df, year)
  # Save out map to import into officer word doc builder later
  map_out_ = paste0(out_dir, '/temps/intermediate_map.png')
  message ('Saving map out')
  mapshot(ma_figure_1$map, file = map_out_)

  message ('build figure 2')
  # Build figure 2a/2b
  ma_figure_2 = build_ma_figure_2(ma_bulk_df, species_df, year)

  # Export to a file to be used to upload into the .docx
  fig2a_f = paste0(out_dir, "/temps/fig2a.png")
  plotly::export(ma_figure_2$figure_a, file = fig2a_f)
  # Export to a file to be used to upload into the .docx
  fig2b_f = paste0(out_dir, "/temps/fig2b.png")
  plotly::export(ma_figure_2$figure_b, file = fig2b_f)

  message ('build figure 3')
  # Build Figure 3
  ma_figure_3 = build_ma_figure_3(ma_bulk_df, species_df, year)

  # Export to a file to be used to upload into the .docx
  fig3_f = paste0(out_dir, "/temps/fig3.png")
  suppressWarnings(plotly::export(ma_figure_3$figure, file = fig3_f))


  bold_face = shortcuts$fp_bold(font.size = 16)
  date_font = fp_text(color = 'black', font.family = 'Cambria',
    font.size = 12)
  par_style = fp_par(text.align = "center")
  example_font = fp_text(color = "#bfbfbf", font.size = 12,
    bold = FALSE, italic = FALSE, underlined = FALSE,
    font.family = "Cambria", vertical.align = "baseline",
    shading.color = "transparent")

  message ('Build mobile acoustic .docx')
  ma_doc = read_docx() %>%
    body_add_fpar(fpar(ftext('Mobile Acoustic Report', prop = bold_face),
      fp_p = par_style ), style = 'centered') %>%
    body_add_fpar(fpar(ftext(paste0(year, ' Data'), prop = date_font),
      fp_p = par_style ), style = 'centered') %>%
    body_add_par(value = "", style = "centered") %>%
    body_add_fpar(fpar(ftext(ma_title, prop = bold_face), fp_p = par_style ),
      style = 'centered') %>%
    body_add_par(value = "", style = "centered") %>%
    body_add_par(value = ma_organization, style = "centered") %>%
    body_add_par(value = date, style = "centered") %>%

    body_add_par(value = "", style = "centered") %>%
    body_add_par(value = "", style = "centered") %>%
    body_add_par(value = "", style = "centered") %>%
    body_add_par(value = "", style = "centered") %>%

    body_add_img(src = circle_logo_, width = 2.5, height = 2.5,
      style= 'centered') %>%

    body_add_break() %>%

    # Project Description
    body_add_par(value = "Project Description", style = "heading 1") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_par(value = ma_description, style = "Normal") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_fpar(fpar(ftext(ma_examples$ma_ex_description,
      prop = example_font)), style = 'Normal') %>%

    body_add_break() %>%

    # Methods
    body_add_par(value = "Methods", style = "heading 1") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_par(value = "Site Selection", style = "heading 2") %>%
    body_add_par(value = ma_examples$ma_methods_1, style = "Normal") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_par(value = "Data Collection", style = "heading 2") %>%
    body_add_par(value = ma_examples$ma_methods_2, style = "Normal") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_par(value = "Call Processing/Species Identification",
      style = "heading 2") %>%
    body_add_par(value = ma_examples$ma_methods_3, style = "Normal") %>%

    body_add_break() %>%

    # Results
    body_add_par(value = "Results", style = "heading 1") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_par(value = ma_results, style = "Normal") %>%

    body_add_break() %>%

    # Summary
    body_add_par(value = "Summary", style = "heading 1") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_fpar(fpar(ftext(ma_examples$ma_summary_1, prop = example_font)),
      style = 'Normal') %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_fpar(fpar(ftext(ma_examples$ma_summary_2, prop = example_font)),
      style = 'Normal') %>%

    body_add_break() %>%

    # Table 1
    body_add_par(value = ma_table_1$description, style = "Normal") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_flextable(ma_table_1$table, align='left') %>%

    body_add_break() %>%

    # Table 2
    body_add_par(value = ma_table_2$description, style = "Normal") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_flextable(ma_table_2$table, align='left') %>%

    body_add_break() %>%
    body_end_section_continuous()



  # Add table 3a/b
  auto_ids = unique(ma_bulk_df$auto_id[!is.na(ma_bulk_df$auto_id)])
  if (length(auto_ids) > 0){
    ma_doc = ma_doc %>%
      # Table 3a
      body_add_par(value = ma_table_3$description_a, style = "Normal") %>%
      body_add_par(value = "", style = "Normal") %>%
      body_add_flextable(ma_table_3$table_a, align='left') %>%
      body_add_break()
  }
  man_ids = unique(ma_bulk_df$manual_id[!is.na(ma_bulk_df$manual_id)])
  if (length(man_ids) > 0){
    ma_doc = ma_doc %>%
      # Table 3b
      body_add_par(value = ma_table_3$description_b, style = "Normal") %>%
      body_add_par(value = "", style = "Normal") %>%
      body_add_flextable(ma_table_3$table_b, align='left') %>%
      body_add_break()
  }

  ma_doc = ma_doc %>%
    # Figure 1
    body_add_par(value = ma_figure_1$description, style = "Normal") %>%
    body_add_img(src = map_out_, width = 8, height = 6, style= 'centered') %>%

    # Figure 2a
    body_add_par(value = ma_figure_2$description_a, style = "Normal") %>%
    slip_in_img(src = fig2a_f, width = 7, height = 5) %>%

    body_add_break() %>%

    # Figure 2b
    body_add_par(value = ma_figure_2$description_b, style = "Normal") %>%
    slip_in_img(src = fig2b_f, width = 7, height = 5) %>%

    body_add_break() %>%

    # Figure 3
    body_add_par(value = ma_figure_3$description, style = "Normal") %>%
    slip_in_img(src = fig3_f, width = 7, height = 5) %>%
    body_end_section_landscape() %>%

    # Literature Cited
    body_add_par(value = "Literature Cited", style = "heading 1") %>%
    body_add_par(value = "", style = "Normal") %>%
    body_add_par(value = ma_examples$ma_lit_cited, style = "Normal")

  return (ma_doc)
}
