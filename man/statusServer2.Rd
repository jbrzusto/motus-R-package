% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/statusServer2.R
\name{statusServer2}
\alias{statusServer2}
\title{reply to http requests for information on the processing queue; API version}
\usage{
statusServer2(port = 22439, tracing = FALSE, maxRows = 20L)
}
\arguments{
\item{port}{integer; local port on which to listen for requests;
default: 0x57A7}

\item{tracing}{logical; if TRUE, run interactively, allowing local user
to enter commands.}

\item{maxRows}{integer; maximum number of rows to return per request.
Default: 20}
}
\value{
does not return; meant to be run as a server.
}
\description{
reply to http requests for information on the processing queue; API version
}
\author{
John Brzustowski \email{jbrzusto@REMOVE_THIS_PART_fastmail.fm}
}
