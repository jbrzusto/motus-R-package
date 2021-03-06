% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/dbHumanizeTimestamps.R
\name{dbHumanizeTimestamps}
\alias{dbHumanizeTimestamps}
\title{create a view of a table where timestamps are displayed in human-readable
form.}
\usage{
dbHumanizeTimestamps(dbcon, table, newtable = paste0("_", table),
  tsRegex = "^ts.*", temporary = FALSE)
}
\arguments{
\item{dbcon}{connection to a MySQL/MariaDB server or sqlite database}

\item{table}{name of existing table}

\item{newtable}{name of new view; default: \code{paste0('_', table)}}

\item{tsRegex}{regular expression that matches names of columns holding
numeric timestamps.  Default:  '^ts.*'}

\item{temporary}{should view be temporary?  default:FALSE}
}
\value{
TRUE on success; FALSE otherwise.
}
\description{
create a view of a table where timestamps are displayed in human-readable
form.
}
\details{
Creates a view of a table where any numeric `timestamp`
    field is replaced by a human readble version.  The view will
    have the given new name, `timestamp` is judged by having
    a name matching the timestamp regex.  If the view
    already exists, this function does nothing.
}
\author{
John Brzustowski \email{jbrzusto@REMOVE_THIS_PART_fastmail.fm}
}
