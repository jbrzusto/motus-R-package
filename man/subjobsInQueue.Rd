% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/subjobsInQueue.R
\name{subjobsInQueue}
\alias{subjobsInQueue}
\title{return a vector of subjobs of the given topjob which are in the queue}
\usage{
subjobsInQueue(tj)
}
\arguments{
\item{tj}{a Twig object representing the topjob.  It must have \code{parent(tj) = NULL}}
}
\value{
NULL, if no subjobs of \code{tj} are in the queue, otherwise a vector
with class "Twig" of job IDs.
}
\description{
return a vector of subjobs of the given topjob which are in the queue
}
\author{
John Brzustowski \email{jbrzusto@REMOVE_THIS_PART_fastmail.fm}
}
