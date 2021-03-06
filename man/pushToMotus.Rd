% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/pushToMotus.R
\name{pushToMotus}
\alias{pushToMotus}
\title{Push any new tag detections to the motus master database.}
\usage{
pushToMotus(src, batchStatus = 1)
}
\arguments{
\item{src}{dplyr src_sqlite to receiver database}

\item{batchStatus}{integer to which the `status` field of each transferred
batch is set once complete. Default: 1, which means the batch will
be immediately servable by the \code{\link{dataServer()}}.}
}
\value{
no return value
}
\description{
For now, this pushes into the transfer tables in the MySQL "motus"
database on the local host, from where the Motus server pulls
data periodically.
}
\details{
Any batch whose ID is not in the receiver's motusTX table is sent
to the transfer tables.
}
\author{
John Brzustowski \email{jbrzusto@REMOVE_THIS_PART_fastmail.fm}
}
