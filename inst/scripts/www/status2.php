<?php
/***

   This script generates the status download page at
   https://sgdata.motus.org/status2 It requires authentication via
   apache's mod_auth_tkt.  The authentication cookie is generated by
   the script login.php

   This script shows two ways to access the status API:

   - on the (proxy) server, using PHP; this is how the main summary
   job list is generated.  That server will be apache, typically.

   - on the client, using javascript; specifically, using jquery's
   $.query() function; this is how the detailed view of a single
   job is generated

   There was no specific reason to do it this way, except to
   demonstrate both approaches.

   Javascript will usually be more flexible, and puts the burden of
   formatting responses on the client side, rather than on the server.

   Replies from the back-end are bz2-compressed JSON-encoded objects,
   except that they are gzip-compressed if the request includes an
   `Accept-Encoding` header containing the word 'gzip'.  This is a
   special case to allow AJAX queries, for which bzip2 compression is
   not supported on some clients (e.g Firefox)

   API documentation is here:

   https://github.com/jbrzusto/motusServer/blob/new_server/inst/doc/status_api.md

   Note that the PHP code below still runs the query from the
 ***/

// because PHP runs on the proxy server, we can send API requests
// directly to the Rook server listening on port 22439
$STATUS_SERVER_URL = 'http://localhost:22439/custom';

$API_STATUS_INFO     = $STATUS_SERVER_URL . '/status_api_info';
$API_LIST_JOBS       = $STATUS_SERVER_URL . '/list_jobs';
$API_SUBJOBS_FOR_JOB = $STATUS_SERVER_URL . '/subjobs_for_job';

// parameters
$n = isset($_GET['n']) ? $_GET['n'] : 20;
$k = isset($_GET['k']) ? $_GET['k'] : 0;

// the status API allows us to use the auth_tkt cookie for authentication.
$authToken = $_COOKIE['auth_tkt'];


// function to post to a uri and return the json-decoded bzuncompressed reply
// $url: URL of request
// $par: array of items to be included in 'json' request object
// $auth: authentication object, to be added as 'authToken' to request object
//
// Note that this function runs on the server side, so the API call happens
// from there and requires use of the X-Forwarded-For header to pass the
// client's IP address.

function post ($url, $par) {
    global $authToken;
    $ch = curl_init($url);
    $par['authToken'] = $authToken;
    $json = 'json=' . urlencode(json_encode($par));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HEADER, false);
    curl_setopt($ch, CURLOPT_HTTPHEADER, array('Content-Type: application/x-www-form-urlencoded', 'X-Forwarded-For: ' . $_SERVER['REMOTE_ADDR']));
    curl_setopt($ch, CURLOPT_POSTFIELDS,  $json);
    $res = curl_exec($ch);
    curl_close($ch);
    return(json_decode(bzdecompress($res), true));
}


?>
<html>
    <head>
        <title>Status of Motus Processing Version 2 (using API back-end)</title>
        <script language="javascript" type="text/javascript"
                src="/javascript/jquery/jquery.min.js"></script>
        <script language="javascript" type="text/javascript"
                src="/download/status2.js"></script>
        <script language="javascript" type="text/javascript"
                src="/download/jquery.mustache.min.js"></script>
        <script language="javascript" type="text/javascript"
                src="/download/mustache.min.js"></script>
        <script language="javascript"  type="text/javascript"
                src="/download/jquery-ui-1.12.1.custom/jquery-ui.min.js">script</script>
        <link rel="stylesheet" href="/download/jquery-ui-1.12.1.custom/jquery-ui.min.css">
        <script language="javascript" type="text/javascript">
         // handle user click on job row by calling `show_job_details` for the appropriate job
         $(function() {
             $(document).on('click', '.job_list_row', function() {show_job_details(this.id.replace(/^job/, ""))});
             $.Mustache.add("job_details",
`
<b>Log:</b>
<pre>
{{log}}
</pre>
<b>Sub Jobs:</b>
<table>
<tr><th>id</th><th>ctime</th><th>type</th><th>done</th></tr>
{{@details}}
<tr><td>{{id}}</td><td>{{ctime}}</td><td>{{type}}</td><td>{{done}}</td></tr>
{{/details}}
</table>
`);

         })
        </script>
    </head>
    <body>
        <h3> Status of your motus data-processing jobs </h3>
        <div id="job_status">
            <pre>
                <?php
                $tbl = post($API_LIST_JOBS,
                            array(
                                'options' => array(
                                    'includeUnknownProjects' => true,
                                ),
                                'order' => array(
                                    'sortBy' => 'mtime desc'
                                )
                            )
                );
                ?>
                <div id="job_details">
                </div>
                <table id="job_list">
                    <tr>
                        <th>ID</th><th>MotusUserID</th><th>Type</th><th>Created</th><th>Last Activity</th><th>Status</th>
                    </tr>
                    <?php
                    $n = count($tbl['id']);
                    for ($i=0; $i < $n; $i++) {
                        $ctime = strftime("%Y-%m-%d.%H:%M:%S", $tbl['ctime'][$i]);
                        $mtime = strftime("%Y-%m-%d.%H:%M:%S", $tbl['mtime'][$i]);
                        echo <<<JOB_LIST_ROW
<tr class="job_list_row" id="job{$tbl['id'][$i]}">
   <td class="job_list_id">          {$tbl['id'][$i]}          </td>
   <td class="job_list_motusUserID"> {$tbl['motusUserID'][$i]} </td>
   <td class="job_list_type">        {$tbl['type'][$i]}        </td>
   <td class="job_list_ctime">       $ctime                    </td>
   <td class="job_list_mtime">       $mtime                    </td>
   <td class="job_list_done">        {$tbl['done'][$i]}        </td>
</tr>
JOB_LIST_ROW;
                    }
                    ?>
                </table>
            </pre>
        </div>
    </body>
</html>
