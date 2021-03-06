% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/dataServer.R
\name{hits_for_receiver}
\alias{hits_for_receiver}
\title{get all hits from a batch for a receiver}
\usage{
hits_for_receiver(env)
}
\arguments{
\item{batchID}{integer batchID}

\item{hitID}{double ID of largest hit already obtained}
}
\value{
a data frame with the same schema as the hits table, but JSON-encoded as a list of columns
}
\description{
get all hits from a batch for a receiver
}
