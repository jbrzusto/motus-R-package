% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/handleSyncReceiver.R
\name{handleSyncReceiver}
\alias{handleSyncReceiver}
\title{sync from an attached receiver, processing any new data}
\usage{
handleSyncReceiver(j)
}
\arguments{
\item{j}{the job with these items:

\itemize{

\item serno character scalar; the receiver serial number
\item method; method for reaching the receiver.  So far, this
must be an integer, representing a tunnel port number (i.e.
number of a port on localhost that has been mapped back
to the ssh port (22) on the remote SG, typically via
the server at sensorgnome.org  Tunnel port numbers start
at 40000 and do not exceed 65535.
\item motusUserID integer scalar; the ID of the motus user
who registered the receiver for remote sync
[only used by \code{\link{handleSGfindtags}} and \code{\link{handleLtFindtags}}]
\item motusProjectID integer scalar; the ID of the motus
project specified when the receiver was registered for
remote sync [only used by \code{\link{handleSGfindtags}} and \code{\link{handleLtFindtags}}]

}}
}
\value{
TRUE
}
\description{
Called by \code{\link{syncServer}}
}
\details{
grabs any new data from the attached receiver, and
re-runs the tagfinder
}
\seealso{
\link{\code{syncServer}}
}
\author{
John Brzustowski \email{jbrzusto@REMOVE_THIS_PART_fastmail.fm}
}
