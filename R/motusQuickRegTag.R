#' Quickly register a tag with motus
#'
#' This lets you register a tag with minimal fuss, provided you know
#' the project name or ID, manufacturer's tag ID, and approximate
#' burst interval (to 0.1 s precision).  You should also know the
#' dateBin, i.e. the year and quarter the tag was deployed in.
#'
#' This function uses the official Lotek database to look up tag
#' parameters.  It also estimates a precise burst interval as the mean
#' of those burst intervals from previously-registered tags which are
#' within 0.05 s of the one you specify here.
#'
#' You will be shown the full set of registration parameters and given
#' a chance to cancel the process if they look wrong.
#'
#' @param projectID: integer scalar; motus internal project ID;
#'     Alternatively, a character scalar which is matched against
#'     project names, and if a match is found, that is used, with
#'     prompting.
#'
#' @param mfgID: character scalar; typically a small integer; return
#'     only records for tags with this manufacturer ID (usually
#'     printed on the tag).  If a duplicate within a given project and
#'     season, it should have decimal digits indicating the number of
#'     physical marks added to the tag.
#'
#' @param period: numeric scalar; approximate repeat interval of tag
#'     transmission, in seconds, to nearest 0.1 s; the precise value
#'     is guessed from the tag database
#'
#' @param dateBin: character scalar; quick and dirty approach to
#'     keeping track of tags likely to be active at a given time; this
#'     records "YYYY-Q" where Q is 1, 2, 3, or 4.  Represents the
#'     approximate quarter during which the tag is expected to be
#'     active.  Used in lieu of deployment information when that is
#'     not (yet) available.
#'
#' @param codeSet: 3 or 4, or their character equivalents.  Default is
#'     4.
#'
#' @param model: one of the Lotek model codes.  Default is NULL,
#'     meaning unknown.
#'
#' @param tsStart: start of deployment, if known.
#'
#' @param species: 4-letter code of species, or integer species ID if known
#'
#' @param ...: additional parameters to motusDeployTag()
#'
#' @return a 3-element numeric vector; the first element is the motus
#'     tag ID, and the second element, if not NA, is the motus
#'     deployment ID.  The third element is the estimated true burst
#'     interval, in seconds.
#'
#' @note: if both \code{tsStart} and \code{species} are NULL, then a
#'     tag deployment record is \emph{not} generated for the
#'     newly-registered tag.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusQuickRegTag = function(projectID,
                            mfgID,
                            period,
                            dateBin,
                            codeSet=4,
                            model=NULL,
                            tsStart=NULL,
                            species=NULL,
                            nomFreq=166.38,
                            ...
                            ) {
    if (is.character(projectID)) {
        projs = motusListProjects()
        i = grep(projectID, projs$name, ignore.case=TRUE)
        if (length(i) == 0)
            stop("Couldn't find a project matching '", projectID, "'")
        if (length(i) > 1)
            stop("More than one project matches; try again with one of these IDs:\n", paste(projs$id[i], "=", projs$name[i], collapse="\n"),"\n")
        projectID = projs$id[i]
        cat("Using project ", projs$name[i])
    }

    if (! grepl("20[0-9][0-9]-[1-4]", dateBin))
        stop("dateBin must be specified as YYYY-Q, where Q is 1, 2, 3 or 4")

    mfgID = as.character(mfgID)

    manufacturer = "Lotek"

    type = "ID"

    codeSet = paste0("Lotek", codeSet)

    offsetFreq = 0 ## assume nominal frequency

    if (! exists("allMotusTags")) {
        allMotusTags <<- MetaDB("select * from tags")
        allMotusTags <<- subset(allMotusTags, ! is.na(period))
    }

    ## try get BI for registered tags of same model, similar period
    pip = allMotusTags$period[which(abs(allMotusTags$period - period) <= 0.05 & (is.null(model) | is.na(model) | (gsub("[-A-Z]", "", allMotusTags$model, perl=TRUE) == gsub("[-A-Z]", "", model, perl=TRUE))))]

    ## if not enough, get BI for any tags of similar period
    if (length(pip) == 0)
        pip = allMotusTags$period[abs(allMotusTags$period - period) <= 0.05]

    if (length(pip) > 1) {
        periodSD = sd(pip)
        if (periodSD > 0.003)
            stop("Estimate for period from database has sd > 3 ms")
        period = mean(pip)
    } else {
        periodSD = 0
    }
    pulseLen = 2.5

    db = subset(ltGetCodeset(codeSet), id==floor(as.numeric(mfgID)))

    param1 = db$g1
    param2 = db$g2
    param3 = db$g3
    param4 = param5 = param6 = 0
    paramType = 1

    ts = as.numeric(Sys.time())

    pars = list(
        projectID    = projectID,
        mfgID        = mfgID,
        manufacturer = manufacturer,
        model        = model,
        type         = type,
        codeSet      = codeSet,
        offsetFreq   = offsetFreq,
        period       = period,
        periodSD     = periodSD,
        pulseLen     = pulseLen,
        param1       = param1,
        param2       = param2,
        param3       = param3,
        param4       = param4,
        param5       = param5,
        param6       = param6,
        paramType    = paramType,
        ts           = ts,
        nomFreq      = nomFreq,
        dateBin      = dateBin
    )
    res = motusQuery(MOTUS_API_REGISTER_TAG, requestType="post",
               pars)

    if (is.null(res$tagID))
        stop("tag registration failed ", capture.output(res))

    ## convert NA or "" to null for the API
    for (n in c("tsStart", "species")) {
        v = get(n)
        if (isTRUE(! is.null(v) && (is.na(v) || (is.character(v) && nchar(v) == 0))))
            assign(n, NULL)
    }

    ## convert non-NULL to numeric
    for (n in c("tsStart")) {
        v = get(n)
        if (isTRUE(! is.null(v)))
            assign(n, as.numeric(v))
    }

    deployID = NA
    if (! is.null(tsStart) || !is.null(species) || length(list(...)) != 0) {

        speciesID = NULL
        if (is.character(species)) {
            sp = motusListSpecies(species, qlang="CD")
            if (length(sp) == 0) {
                warning("Unknown species code: ", species, ". Tag registered, but no species will be included in the deployment record")
            } else {
                speciesID = sp$id
            }
        } else if (is.numeric(species)) {
            speciesID = species
        }

        ## test again for non-null deployment info
        if (! is.null(tsStart) || !is.null(species) || length(list(...)) != 0) {
            resD = motusDeployTag(res$tagID, projectID, "pending", tsStart=tsStart, speciesID=speciesID, ...)
            deployID = resD$deployID
        }
    }
    MetaDB("BEGIN EXCLUSIVE TRANSACTION")
    newTags = motusSearchTags(projectID=projectID) %>% subset(tagID == res$tagID)
    updateMetadataForTags(newTags)
    commitMetadataHistory(MetaDB)
    MetaDB("COMMIT")
    return (c(res$tagID, deployID, period))
}
