library(data.table)
library(RSQLite)
library(DBI)
library(dplyr)
library(dbplyr)
library(mixdist)
library(extraDistr)
library(jsonlite)
library(geojsonio)
library(sp)


setwd('~/working/bigmap_api')

covid_db <- dbConnect(RSQLite::SQLite(), 'data/covid_db.sqlite')

dates <- tbl(covid_db, 'counties') %>%
  select(date) %>%
  collect()

dates <- as.Date(unique(dates$date))
existing <- as.Date(substr(list.files('geojsons/'), start = 1, stop = 8), '%Y%m%d')

#dates <- dates[which(!dates %in% existing)]


data <- tbl(covid_db, 'counties') %>%
  collect()
data <- as.data.table(data)

county_shapes <- readRDS('data/all_counties.RDS')

rn <- row.names(county_shapes@data)

county_shapes$STATE <- as.character(county_shapes$STATE)
county_shapes$COUNTY <- as.character(county_shapes$COUNTY)
county_shapes$FIPS <- paste0(county_shapes$STATE, county_shapes$COUNTY)


pb <- txtProgressBar(max = length(dates), style = 3)
for(l in 1:length(dates)){
  
  dat <- data[date == dates[l], c('countyFIPS', 'date', 'case_count', 'per_delta', 'infect_prob', 'r_t', 'deaths', 'doubling', 'r_t_seven', 'r_t_three')]
  
  # dat <- jsonlite::fromJSON(paste0('http://160.1.89.242/alldata?min_date=20200301&max_date=', gsub('-', '', Sys.Date() - 1)))
  # dat <- data.table(dat)
  
  dat[, r_t := round(r_t, 2)]
  dat[, r_t_three := round(r_t_three, 2)]
  dat[, r_t_seven := round(r_t_seven, 2)]
  dat[, per_delta := round(per_delta* 100, 2) ]
  dat[, infect_prob := round(infect_prob, 2) ]
  
  
  
  
  # #---make wide timeseries data - every variable/date combo gets a column
  # u_id <- unique(dat$countyFIPS)
  # out <- list()
  # for(i in 1:length(u_id)){
  #   sub <- dat[countyFIPS == u_id[i]]
  #   sub <- unique(sub, by=c("countyFIPS", "date"))
  # 
  #   out_tmp <- list()
  #   for(j in 1:nrow(sub)){
  #     cols <- paste0(colnames(sub)[3:ncol(sub)],'_', gsub('-', '', sub$date[j]))
  #     tmp <- data.frame(sub[j, 3:ncol(sub)])
  #     colnames(tmp) <- cols
  #     out_tmp[[j]] <- tmp
  #   }
  #   z <- cbind(sub[1, 1], do.call('cbind', out_tmp))
  #   out[[i]] <- z
  # }
  # 
  # final <- rbindlist(out)
  
  
  #merge into county shapes
  county_shapes_out <- sp::merge(county_shapes, dat, by.x = 'FIPS', by.y = 'countyFIPS')
  row.names(county_shapes_out) <- rn
  county_shapes_out@data$CENSUSAREA <- NULL
  county_shapes_out@data$LSAD <- NULL
  county_shapes_out@data$COUNTY <- NULL
  county_shapes_out@data$STATE <- NULL
  county_shapes_out@data$GEO_ID <- NULL
  
  filename <- paste0('~/working/bigmap_api/geojsons/', gsub('-', '', dates[l]), '.geojson')
  geojsonio::geojson_write(county_shapes_out, file = filename)
  
  setTxtProgressBar(pb, l)
}



#cache data for charts by area
area <- unique(data$countyFIPS)
dat <- data[date >= '2020-03-01']
for(i in 1:length(area)){
  sub <- dat[countyFIPS == area[i]]
  jsonlite::write_json(sub, path = paste0('chart_data/', area[i], '.json'))
}




