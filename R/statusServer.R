#' reply to http requests for information on the processing queue
#'
#' @param port integer; local port on which to listen for requests
#'
#' @param tracing logical; if TRUE, run interactively, allowing local user
#' to enter commands.
#'
#' @return does not return; meant to be run as a server.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

statusServer = function(port, tracing=FALSE) {
    ## open a connection to the server database
    DB <<- ensureServerDB()
    loadJobs()

    library(Rook)
    library(hwriter)

    ## save server in a global variable in case we are tracing

    SERVER <<- Rhttpd$new()

    ## add each function below as an app

    for (f in allApps)
        SERVER$add(RhttpdApp$new(app = get(f), name = f))

    SERVER$start(port = port)

    if (! tracing) {
        ## sleep while awaiting requests
        suspend_console()
    }
}

## a string giving the list of apps for this server

allApps = c("latestJobs", "queueStatus")

latestJobs = function(env) {

    ## return summary table of latest top jobs, with clickable expansion for details
    ## parameters:
    ##   - n:  number of jobs to show
    ##   - k:  max jobID to show (0 means unknown); if negative, - min jobID to show.
    ##   - user: if specified, all jobs belonging to user are shown

    req = Rook::Request$new(env)
    res = Rook::Response$new()

    res$header("Cache-control", "no-cache")
    res$header("Content-Type", "text/html; charset=utf-8")


    ## Note: the web page displaying this content needs to inlude the following <script> tag and
    ## contents, if the javascript written by this function is filtered out:

    res$write('<script type="text/javascript">
var numJobs = $(".jobDetails").length;

function toggleJobExpand(n) {
   var jdn = ".jobDetails" + n;
   var jsn = ".jobSummary" + n;
   var vis = $(jdn).is(":visible");
   if (vis) {
         $(jdn).hide();
         $(jsn).css({"color": "black"});
         $(".jobSummary").show();
         $("#jobSummaryEllipsis").hide();
   } else {
         $(".jobDetails").hide();
         $(".jobSummary").css({"color": "black"});
         $(".jobSummary").hide();
         for (var j=1; j <= Math.min(numJobs, n+3); ++j) {
             $(".jobSummary" + j).show();
         }
         if (n+3 < numJobs) {
             $("#jobSummaryEllipsis").show();
         } else {
             $("#jobSummaryEllipsis").hide();
         }
         $(jdn).show();
         $(jsn).css({"color": "green"});
   }
};

function makeJobToggle(n) {
    return(function() {toggleJobExpand(n)});
};

for (var j=1; j <= numJobs; ++j) {
    $(".jobSummary" + j).click(makeJobToggle(j));
}
</script>');
    user = as.character(req$GET()[['user']])[1]
    if (! is.na(user) && user != "admin" && user != "stuart" && user != "zoe") {
        jj = DB("select id from jobs where user=:user and pid is null order by id desc", user=user)[[1]]
    } else {
        n = as.integer(req$GET()[['n']])[1]
        if (! isTRUE(n > 0 && n <= 500))
            n = 20
        k = as.integer(req$GET()[['k']])[1]
        if (! isTRUE(k >= 0))
            k = 0
        if (k == 0)
            k = DB("select max (id) from jobs where pid is null")[[1]]
        if (k > 0) {
            jj = DB("select id from jobs where pid is null and id <= :k order by id desc limit :n", k=k, n=n)[[1]]
        } else {
            jj = DB("select id from jobs where pid is null and id >= :k order by id desc limit :n", k=-k, n=n)[[1]]
        }
    }
    if (length(jj) == 0) {
        jj = DB(sprintf("select id from jobs where pid is null order by id %s limit :n", if (k > 0) "desc" else ""), n=n) [[1]]
    }

    info = DB("select id, coalesce(json_extract(data, '$.replyTo[0]'), json_extract(data, '$.replyTo')), ctime, mtime, type, done from jobs where id in (:jj) order by id desc", jj=jj)
    class(info$ctime) = class(info$mtime) = c("POSIXt", "POSIXct")
    info$done = c("Error", "Active", "Done")[2 + info$done]

    ## any expression from here on can't use the original names for the columns of info
    names(info) = c("ID", "Sender", "Created", "Last Activity", "Job Type", "Status")
    res$write(hwrite(info, border=0, row.style=list('font-weight:bold'), row.bgcolor=rep(c("#ffffff", "#f0f0f0"), length=nrow(info)),
                     row.class=paste0("jobSummary jobSummary", 1:nrow(info))))
    res$write('<div id="jobSummaryEllipsis" style="display:none"><b>&nbsp;&nbsp;&nbsp;&nbsp;. . .</b></div>\n')
    for (i in seq(along=jj)) {
        dumpJobDetails(res, jj[i], i)
    }
    res$finish()
}

#' dump details of job j to res, as ith job listing
#' @param res Rook::response object
#' @param j job
#' @param i integer; index in list of jobs to be displayed

dumpJobDetails = function(res, j, i) {
    j = Jobs[[j]]
    res$write(paste0('<div class="jobDetails jobDetails', i, '" style="display:none">'))
    replyTo = paste(j$replyTo, collapse=", ")
    if (is.null(replyTo))
        replyTo = "none"

    res$write(sprintf("<h3>Status for job %d</h3><pre><b>Created Date:</b> %s\n<b>Last Activity:</b> %s\n<b>Sender:</b> %s\n<b>Queue: </b>%s</pre><h4>Log:</h4><pre>%s\n</pre>",
                      j,
                      format(TS(ctime(j))),
                      format(TS(mtime(j))),
                      replyTo,
                      if (is.na(j$queue)) "None" else paste(j$queue),
                      paste0("   ", gsub("\n", "\n   ", j$log, fixed=TRUE))
                      )
              )
    res$write("</div>")
}

queueStatus = function(env) {
    ## return summary of master queue and processing queues
    ## parameters:
    ## - none so far

    req = Rook::Request$new(env)
    res = Rook::Response$new()

    res$header("Cache-control", "no-cache")
    res$header("Content-Type", "text/html; charset=utf-8")

    ## number of embargoed emails awaiting processing
    emb = length(dir("/sgm/inbox_embargoed"))

    ## number of emails in inbox, awaiting processing
    inb = length(dir("/sgm/inbox"))

    ## is emailServer running?
    es = file.exists("/sgm/emailServer.pid")

    ## num jobs in email queue
    qm = DB("select count(*) from jobs where pid is null and queue is null and done=0 and type='email'")[[1]]

    ## num jobs waiting to be assigned to a processor
    q0 = DB("select count(*) from jobs where pid is null and queue=0 and done=0")[[1]]

    ## which processServers, if any, are running
    pids = dir("/sgm", pattern="^processServer[0-9]+.pid$", full.names=TRUE)
    if (length(pids) > 0)
        qr = as.integer(unlist(regexPieces("processServer(?<qn>[0-9]+).pid", pids)))
    else
        qr = integer(0)

    ul = "---------------------------------------------\n"
    res$write(paste0(
        "<small>As of ", format(Sys.time(), "%d %b %Y %H:%M:%S (GMT)</small>"),
        "<pre>",
        "<b>Embargoed INBOX</b>\n",
        emb, " emails awaiting manual intervention\n",
        ul,
        "<b>INBOX</b>\n",
        inb, " emails awaiting Email Server\n",
        ul,
        "<b>Email Server</b>\n",
        " - ", if (! es) "<b>not</b> ", "running\n",
        " - has ", qm, " emails partially processed\n",
        ul,
        "<b>Master Queue</b>\n",
        q0, " jobs waiting for a Tagfinder Processor\n"
        ))

    ## for each tagfinder process, show its status and queue length

    for (p in 1:8) {
        running = p %in% qr
        jj = DB("select distinct t1.id from jobs as t1 join jobs as t2 on t1.id = t2.stump where t1.pid is null and t1.queue=:p and t2.done=0", p=p)[[1]]
        res$write(paste0(ul,
          "<b>Tagfinder Processor #", p, "</b>\n",
          " - ", if (! running) "<b>not</b> ", "running\n",
          " - has ", length(jj), " jobs partially processed\n"))
        if (length(jj) > 0) {
            info = DB("select t1.id, json_extract(t1.data, '$.auth.email'), t1.ctime, t1.mtime, group_concat(t2.type) as sj from jobs as t1 join jobs as t2 on t1.id=t2.stump where t1.id in (:jj) and t2.done == 0 group by t1.id order by t1.id desc", jj=jj)
            class(info$ctime) = class(info$mtime) = c("POSIXt", "POSIXct")
            info$sj = sapply(info$sj, function(x) { j = strsplit(x, ",")[[1]]; t = table(j); paste(sprintf("%s(%d)", names(t), t), collapse=", ")})
            names(info) = c("ID", "Sender", "Created", "Last Activity", "Incomplete SubJobs")
            res$write(hwrite(info, border=0, row.style=list('font-weight:bold'), row.bgcolor=rep(c("#ffffff", "#f0f0f0"), length=nrow(info))))
        }
    }
    res$finish()
}