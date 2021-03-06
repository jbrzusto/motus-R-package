#' Export the results of an sqlite query directly into an .rds file
#'
#' @details Typically, exporting the contents of an sqlite database
#'     table as an R .rds file has meant reading the entire table into
#'     R as a data.frame, then using \code{saveRDS()}.  This requires
#'     memory proportional to the size of the data.frame, but with a sufficiently
#'     large swap partition, this will still work.  However, our experience on
#'     an Intel core-i7 server with 4 cores @ 3.4 GHz, 32 G RAM, and a 256 SSD swap
#'     shows that our largest sites still slow the server down to a grind when
#'     processing one site at a time.  To permit this all to work on a lower
#'     spec server with multiple sites potentially being processed at once, we
#'     need to do this with a much smaller memory footprint, even at the expense
#'     of considerably longer running time.
#'
#' This function serializes the results of an SQLite query as a
#' data.frame into an .rds file, but with bounded memory.  Because
#' sqlite stores data row-by-row, while .rds files store them column
#' by column, the main challenge is to transpose the data without having
#' it all in memory.  We do this with a single run of the query, distributing
#' columns to their own files, then concatenating and compressing these into
#' the final .rds file via a shell command.
#'
#' @note End users should really be working with an on-disk .sqlite
#'     version of their data, but we want to maintain backward
#'     compatibility with users' existing code.  Also, the details of
#'     this algorithm depend on the encodeing inherent in the files
#'     serialize.c and Rinternals.h from the R source tree.
#'
#' The algorithm, ignoring headers and footers, is:
#'
#' \itemize{
#'
#' \item for each column in the query result, open a temporary output
#' file
#'
#' \item while there are results remaining
#' \itemize{
#'
#' \item fetch a block of query results
#'
#' \item distribute data in the block among the column files
#'
#' }
#'
#' \item when all blocks have been distributed, close the temporary
#' files and concatenate them on disk into the target .rds file
#'
#' }
#'
#' The result is an .rds file in non-XDR little-endian format, which should
#' read more quickly into memory.
#'
#' Data types are converted as so:
#' \itemize{
#'  \item sqlite real: written as 8-byte doubles
#'  \item sqlite int: written as 4-byte signed integers or logical (see below)
#'  \item sqlite text: written as a factor
#' }
#'
#' Additionally, class() attributes can be specified for any of the columns.
#' If "logical" or "integer" is specified for a column, it is
#' written as a native vector of that type.
#'
#' @param con connection to sqlite database
#'
#' @param query character scalar; query on con; the entire results of
#'     the query will be written to the .rds file, but the query can
#'     include 'limit' and 'offset' phrases.
#'
#' @param bind.data values for query parameters, if any; see
#' \link{\code{dbSendQuery}}.  Defaults to \code{data.frame(x=0L)},
#' i.e. a trivial data.frame meant only to pass the sanity checks
#' imposed by \code{dbSendQuery()}
#'
#' @param out character scalar; name of file to which the query
#'     results will be saved.  Should end in ".rds".
#'
#' @param classes named list of character vectors; classes for a
#'     subset of the columns in parameter \code{query}
#'
#' @param rowsPerBlock maximum number of rows fetched from the DB at a
#'     time; this limits the maximum memory consumed by this function.
#' Default: 10000
#'
#' @param stringsAsFactors should string columns be exported as factors?
#' With the default value of TRUE, size on disk and size in memory of
#' the data.frame upon subsequent read will both be smaller, but at the
#' cost of having to run a separate query on each string column to determine
#' the levels.  These separate queries will be fairly cheap if the
#' columns are the results of a join on a table without many rows, which
#' is typical.  You can specify FALSE here and still request that specific text columns
#' be exported as factors by including \code{'factor'} in the appropriate
#' slot of the \code{'classes'} parameter.
#'
#' @return integer scalar; the number of result rows written to file \code{out}.
#'
#' @note If there are no result rows from the query, then the R value
#'     \code{NULL} is saved to file \code{out}.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}


sqliteToRDS = function(con, query, bind.data=data.frame(x=0L), out, classes = NULL, rowsPerBlock=10000, stringsAsFactors = TRUE) {
    ## get the result types by asking for the first row of the
    ## query

    res = dbSendQuery(con, query, params = bind.data)
    block = dbFetch(res, n=1)
    if (nrow(block) == 0) {
        saveRDS(NULL, out)
        dbClearResult(res)
        return(0L)
    }

    ## for RSQLite, at least, dbColumnInfo isn't valid until after
    ## dbFetch has been called
    col = dbColumnInfo(res)
    dbClearResult(res)

    ## make sure column names specified in parameter 'classes' exist in result:
    if (! all(names(classes) %in% col[[1]]))
        stop("You specified classes for these columns which are not in the result:\n", paste(setdiff(names(classes), col[[1]]), collapse=", "))

    n = nrow(col)

    ## classes for each column, indexed numerically; NULL
    ## for those where there's none
    useClass = lapply(col[[1]], function(n) classes[[n]])

    ## which columns are to be coded as factors?

    fact = which(col[[2]] == "character" & (stringsAsFactors | sapply(seq_len(n), function(x) 'factor' %in% useClass[[x]])))
    col[[2]][fact] = "factor"
    for (i in fact)
        useClass[[i]] = unique(c(useClass[[i]], "factor"))

    ## list of levels vectors for each of these columns, indexed by column number
    colLevels = list()

    ## get levels for each of these columns; we wrap the original query in a select distinct
    for (f in fact)
        colLevels[[f]] = dbGetQuery(con, paste0("select distinct ", col[[1]][f], " from (", query, ")"), params=bind.data)[[1]]

    ## which columns are to be exported as logical?
    logi = which(col[[2]] == "integer" &  sapply(seq_len(n), function(x) 'logical' %in% useClass[[x]]))
    col[[2]][logi] = "logical"

    ## open temporary files for each column, and file prefix and suffix
    colFiles = tempfile(tmpdir=MOTUS_PATH$TMP, fileext=rep(".bin", n+2))
    colCon = lapply(colFiles, file, "wb")

    ## write column headers: SEXPTYPE + FLAGS, LENGTH
    ## values for SEXPTYPE from R/include/Rinternals.h

    colTypeMap = c("logical"   = 0x0000000a,
                   "integer"   = 0x0000000d,
                   "factor"    = 0x0000000d,  ## factors coded as integers
                   "double"    = 0x0000000e,
                   "character" = 0x00000010)

    hasAttr = logical(n)

    for (i in seq_len(n)) {
        type = colTypeMap[col[[2]][i]]
        ## add Object and Attribute flags to columns which are factors,
        ## or which have class values other than "logical"
        if (i %in% fact || (!is.null(useClass[[i]]) & ! identical(useClass[[i]], "logical"))) {
            type = type + 0x0300  ## flags for "is object" and "has attributes"
            hasAttr[i] = TRUE     ## record this fact for later
        }
        writeBin(as.integer(c(type, 0L)), colCon[[i]], endian="little")
    }

    ## count the number of result rows; a query to determine this separately could
    ## be fairly expensive
    nr = 0L

    ## main loop for reading result blocks and distributing them
    ## We start with a block already available in "block".

    res = dbSendQuery(con, query, params=bind.data)
    while (TRUE) {
        block = dbFetch(res, n=rowsPerBlock)
        nr = nr + nrow(block)
        resRow = block[1,] ## save a row for later
        for (i in seq_len(n)) {
            switch(col[[2]][i],
                   factor = {
                       ## write a plain integer vector
                       writeBin(match(block[[i]], colLevels[[i]]), colCon[[i]], endian="little")
                   },
                   character = {
                       ## use serialize for this; we also need to drop the STRSXP and LENGTH bytes
                       writeBin(serializeNoHeader(block[[i]], dropTypeLen=TRUE), colCon[[i]])
                   },
                   ## write a plain vector of appropriate numeric type
                   writeBin(block[[i]], colCon[[i]], endian="little")
                   )
        }
        if (nrow(block) < rowsPerBlock || dbHasCompleted(res))
            break
    }

    ## write attributes for any columns that need them
    for (i in seq_len(n)) {
        if (! hasAttr[i])
            next
        ## attributes are user-specified classes, and levels, for factors
        attrs = list(class=useClass[[i]])
        if (i %in% fact)
            attrs$levels = colLevels[[i]]
        writeBin(serializeNoHeader(as.pairlist(attrs)), colCon[[i]])
    }

    ## we now know n, the number of rows, so write that to each column file
    ## at the appropriate location, namely 4 bytes from the start
    for (i in seq_len(n)) {
        seek(colCon[[i]], 4, rw="w")
        writeBin(as.integer(nr), colCon[[i]], endian="little")
    }

    ## write the RDS and data.frame header:
    writeBin(charToRaw('B\n'), colCon[[n+1]])
    v = unclass(getRversion())[[1]]
    writeBin(as.integer(c(
        0x2, ## serialization_version 2
        v[1] * 0x10000 + v[2] * 0x100 + v[3], ## R_writer_version
        0x00020300, ## min_R_version
        19L + 0x300, ## VECSXP + has_attr and is_object flags
        n  ## number of columns (i.e. length of VECSXP)
        )),
        colCon[[n+1]],
        endian="little")

    ## write the data.frame attributes (column names) We have to fix
    ## the row.names attribute, since it comes from a single row.
    ## Apparently, when there are no actual rownames, R stores this
    ## internally as the integer vector (NA, -nr), where nr is the
    ## number of rows in the data.frame

    att = attributes(resRow)
    att$row.names = as.integer(c(NA, -nr))
    writeBin(serializeNoHeader(as.pairlist(att)), colCon[[n+2]])

    ## close connections
    lapply(colCon, close)

    ## append each column file
    cmd = paste0("cat ", paste0(c(colFiles[n+1], colFiles[seq_len(n)], colFiles[n+2]), collapse=" "), " | bzip2 -9 -c > ", out)
    system(cmd)  ## NB: we don't use safeSys because that overrides redirects  (FIXME!)

    ## delete the intermediate files
    file.remove(colFiles)

    dbClearResult(res)

    return(nr)
}

#' serialize an object to a raw vector, without the "RDS" file header.
#'
#' @param x the R object
#'
#' @param dropTypeLen logical; if TRUE, also drop the initial TYPE and length fields (8 extra bytes)
#'
#' @return raw vector to which x has been serialized in binary little-endian (non-XDR) format,
#' but without the leading 'B\\n' and three 32-bit integers of header:
#'    RDS_serialization_version
#'    RDS_R_writer_version
#'    RDS_min_R_version
#' So we just drop the first 14 bytes.
#'
#' @note this is a convenience function used by sqliteToRds, and is intended for small objects,
#' since the serialization is done in-memory.
#'
#' @export

serializeNoHeader = function(x, dropTypeLen=FALSE) {
    r = rawConnection(raw(), "wb")
    serialize(x, r, ascii=FALSE, xdr=FALSE)
    rv = rawConnectionValue(r) [-seq_len(ifelse(dropTypeLen, 22, 14))]
    close(r)  ## don't wait for gc() to do this
    return(rv)
}
