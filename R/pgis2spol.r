#' Load a polygon geometry stored in a PostgreSQL database into R.
#'
#' @param conn A connection object created in RPostgreSQL package.
#' @param table character, Name of the schema-qualified table in Postgresql holding the geometry.
#' @param geom character, Name of the column in 'table' holding the geometry object (Default = 'geom')
#' @param gid character, Name of the column in 'table' holding the ID for each polygon geometry. Should be unique if additional columns of unique data are being appended. (Default = 'gid')
#' @param proj numeric, Can be set to TRUE to automatically take the SRID for the table in the database. Alternatively, the number of EPSG-specified projection of the geometry (Default is NULL, resulting in no projection.)
#' @param other.cols character, names of additional columns from table (comma-seperated) to append to dataset (Default is all columns, other.cols=NULL returns a SpatialPolygons object)
#' @param query character, additional SQL to append to modify select query from table
#' @return SpatialPolygonsDataFrame or SpatialPolygons
#' @examples
#' #library(RPostgreSQL)
#' #drv<-dbDriver("PostgreSQL")
#' #conn<-dbConnect(drv,dbname='dbname',host='host',port='5432',user='user',password='password')
#'
#' #pgis2spol(conn,'schema.tablename')
#' #pgis2spol(conn,'schema.states',geom='statesgeom',gid='state_ID',proj=4326,other.cols='area,population', query = "AND area > 1000000 ORDER BY population LIMIT 10")

pgis2spol <- function(conn,table,geom='geom',gid='gid',proj=NULL,other.cols='*',query=NULL) {

  require(sp)
  require(rgdal)
  require(rgeos)
  require(RPostgreSQL)

  if (is.null(other.cols))
  {dfTemp<-suppressWarnings(dbGetQuery(conn,paste0("select ",gid," as tgid,st_astext(",geom,") as wkt from ",table," where ",geom," is not null ",query,";")))
  row.names(dfTemp) = dfTemp$tgid}
  else {dfTemp<-suppressWarnings(dbGetQuery(conn,paste0("select ",gid," as tgid,st_astext(",geom,") as wkt,",other.cols," from ",table," where ",geom," is not null ",query,";")))
  row.names(dfTemp) = dfTemp$tgid}

  if (is.null(proj)){
    tt<-mapply(function(x,y) readWKT(x,y), x=dfTemp[,2], y=dfTemp[,1])}
  else {
    if (isTRUE(proj)){
      t2<-strsplit(table,".",fixed=TRUE)[[1]]
      proj<-dbGetQuery(conn,paste0("select srid from public.geometry_columns where f_table_schema = '",t2[1],"' AND f_table_name = '",t2[2],"';"))$srid
    }
    p4s<-as.character(CRS(paste0("+init=epsg:",proj)))
    tt<-mapply(function(x,y,z) readWKT(x,y,z), x=dfTemp[,2], y=dfTemp[,1], z=p4s)
  }

  Spol <- SpatialPolygons(lapply(1:length(tt), function(i) {
    lin <- slot(tt[[i]], "polygons")[[1]]
    slot(lin, "ID") <- slot(slot(tt[[i]], "polygons")[[1]],"ID")  ##assign original ID to polygon
    lin
  }))

  Spol@proj4string<-slot(tt[[1]], "proj4string")

  if (is.null(other.cols)){ return(Spol) }
  else {try(dfTemp[geom]<-NULL)
    try(dfTemp['wkt']<-NULL)
    spdf<-SpatialPolygonsDataFrame(Spol, dfTemp)
    spdf@data['tgid']<-NULL
    return(spdf)}
}
