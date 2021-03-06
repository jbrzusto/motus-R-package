% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/dataServer.R
\name{size_of_update_for_tag_project}
\alias{size_of_update_for_tag_project}
\title{get count of update items for a tag project}
\usage{
size_of_update_for_tag_project(env)
}
\arguments{
\item{projectID}{integer project ID}

\item{batchID}{integer batchID; only batches with larger batchID are considered}
}
\value{
a list with these items:
\itemize{
\item numBatches
\item numRuns
\item numHits
\item numGPS
\item numBytes
}
}
\description{
get count of update items for a tag project
}
\details{
the value of numHits and so numBytes is an overestimate, because
it counts the full length of each run, rather than just of those hits
added by new batches to existing runs.
}
