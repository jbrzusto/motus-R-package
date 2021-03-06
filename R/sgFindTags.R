#' find tags in an SG stream
#'
#' A stream is the ordered sequence of raw data files from a receiver
#' corresponding to a single boot session (period between restarts).
#' This function searches for patterns of pulses corresponding to
#' coded ID tags and adds them to the hits, runs, batches etc. tables
#' in the receiver database.  Each boot session is run as a separate
#' batch.
#'
#' @param src dplyr src_sqlite to receiver database
#'
#' @param tagDB path to sqlite tag registration database
#'
#' @param resume if TRUE, tag detection resumes where it last left off
#'     for each given item in \code{mbn}.  Typically, a new batch of
#'     data files arrives and is added to the receiver database using
#'     \code{sgMergeFiles()}, and then \code{sgFindTags} is called
#'     again to continue processing these new data.  When running
#'     archived data retroactively, it is better to set
#'     \code{resume=FALSE}, otherwise if bootnums are not monotonic,
#'     then tag event histories will be scrambled leading to searching
#'     for the wrong tags at the wrong times.  This has often been the
#'     case for Beaglebone White receivers, since they had no internal
#'     memory for storing the bootcount, and relied on writing it to
#'     the SD card; updating to a new SD card would typically reset
#'     the boot count.
#'
#' @param par list of non-default parameters to the findtags code; defaults to NULL
#'
#' @param mbn integer monotonic boot number(s); this is the monoBN field
#'     from the \code{files} table in the receiver's sqlite database.
#'
#' @return a list with these items
#' \itemize{
#'   \item batchID the batch number
#'   \item numHits the number of unfiltered tag detections in the stream.
#' }
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

sgFindTags = function(src, tagDB, resume=TRUE, par = NULL, mbn) {

    cmd = "LD_LIBRARY_PATH=/usr/local/lib/boost_1.60 /sgm/bin/find_tags_motus"
    if (is.list(par))
        pars = paste0("--", names(par), '=', as.character(par), collapse=" ")
    else
        pars = paste(par, collapse=" ")

    sql = function(...) dbGetQuery(src$con, sprintf(...))

    for (bn in sort(mbn)) {

        ## if not resuming, discard resume information.
        if (! resume)
            sql("delete from batchState where progName='find_tags_motus' and monoBN=%d", bn)

        ## start the child;
        bcmd = paste(cmd, pars, if (resume) "--resume", paste0("--bootnum=", bn), "--src_sqlite", tagDB, attr(src$con, "dbname"), " 2>&1 ")

        cat("  => ", bcmd, "\n")

        safeSys(bcmd, quote=FALSE)
    }

    ## get ID and stats for new batch of tag detections
    rv = sql("select batchID, numHits from batches order by batchID desc limit 1")

    return (c(rv))
}
