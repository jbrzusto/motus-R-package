% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/getMap.R
\name{getMap}
\alias{getMap}
\title{Access (maybe after creating) a persistent named list in a database.}
\usage{
getMap(src, name = "meta")
}
\arguments{
\item{src}{dplyr src_sqlite to a database or an SQLiteConnection}

\item{name}{name of table in database; default: "meta"}
}
\value{
an object of class "motusMap".
}
\description{
This function creates an object of S3 class "motusMap", which behaves
like a named list, allowing access via the \code{$} and \code{[[
]]} operators.  Elements assigned to the list are immediately
stored in table \code{name} in the database pointed to by
\code{src}.  An element can be removed from the list by assigning
NULL to it.
}
\examples{

x = getMap(safeSrcSQLite("SG-1234BBBK5678.motus"), "meta")
x$recvSerno
x$MACAddr <- "01235a3be098"
x$recvSerno <- NULL
x[["MACAddr"]]
}
