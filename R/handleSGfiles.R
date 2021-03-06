#' handle a folder of files from one or more sensorgnomes
#'
#' Called by \code{\link{processServer}} for files from a sensorgnome
#'
#' @details For each unique SG serial number found among the names of
#'     the incoming files, queue a subjob for each boot session having
#'     data files.
#'
#' @param j the job with these item(s):
#' \itemize{
#'    \item filePath; path to files to be merged; if NULL, defaults to \code{jobPath(j)}
#' }
#'
#' @return TRUE
#'
#' @note if \code{topJob(j)$mergeOnly)} is TRUE, then only merge files
#' into receiver databases; don't run the tag finder.
#'
#' @seealso \link{\code{processServer}}
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

handleSGfiles = function(j) {
    path = j$filePath
    if (is.null(path))
        path = jobPath(j)

    r = sgMergeFiles(path, topJob(j))

    if (isTRUE(topJob(j)$mergeOnly > 0))
        return(TRUE)

    info = r$info

    ## TODO: (perhaps) if there were any files for which we were able to
    ## determine serial number but not boot session, fix those if possible

    ## log any uncorrected 8.3 names
    bad = which(is.na(info$serno))

    if (length(bad)) {
        jobLog(j, paste0("Ignoring files for which I can't determine the receiver:\n",
                         paste("   ", basename(info$name[bad]), "\n", collapse="")))
        info = info[- bad, ]
    }

    bad = which(info$monoBN == 0)

    if (length(bad)) {
        jobLog(j, paste0("Ignoring files for which I can't determine the boot session:\n",
                         paste("   ", basename(info$name[bad]), "\n", collapse="")))
        info = info[- bad, ]
    }

    ## function to queue a run of a receiver boot session, and export of its data

    nsj = 0

    queueFindtags = function(f) {

        newSubJob(j, "SGfindtags",
                  serno = f$serno[1],
                  monoBN = f$monoBN[1],
                  canResume = isTRUE(r$resumable[paste(f$serno[1], f$monoBN[1])][[1]])
                  )
        nsj <<- nsj + 1
    }

    ## queue runs of all receiver boot sessions with new data

    info %>%
        filter(use > 0) %>%
        arrange(serno, monoBN, ts) %>%
        group_by(serno, monoBN) %>%
        do (ignore=queueFindtags(.))

    jobLog(j, paste0("Will run tag finder on ", nsj, " receiver boot sessions"), summary=TRUE)

    ## function to queue an export of new data

    queueExport = function(f) {
        newSubJob(j, "exportData", serno = f$serno[1])
        newSubJob(j, "plotData", serno = f$serno[1],
                  monoBN = range(f$monoBN))
    }

    ## queue export of data from receivers where some are new
    ## N.B. we do this only once per receiver, since handleExportData()
    ## looks for and exports all new batches from that receiver.

    info %>%
        filter(use > 0) %>%
        group_by(serno) %>%
        do (ignore=queueExport(.))

    if (! any(info$use > 0))
        jobLog(j, "There were no new files in the dataset, so I didn't do anything.", summary=TRUE)

    return(TRUE)
}
