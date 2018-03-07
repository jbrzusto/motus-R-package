<?php
/***

   This script generates the main download page at https://sgdata.motus.org/download
   It requires authentication via apache's mod_auth_tkt.  The authentication cookie
   is generated by the script login.php

   We show users the projects they have motus authorization for, along with project '0',
   which is where summary plots and datasets go if we can't figure out what project
   they belong to.

   Project names and descriptions are taken from the database defined by $MOTUS_META_DB

 ***/

// database with project info
$MOTUS_META_DB = '/sgm_local/motus_meta_db.sqlite';

// where downloadable files are in the filesystem
$DOWNLOAD_PATH = '/sgm/www';

?>
<html>
    <head>
        <title>Motus Project Files</title>
    </head>
    <body>
        Files for projects on <a href="https://motus.org">motus.org</a>:
        <ul>
            <li>hourly plots and summary tag detections for each project receiver</li>
            <li>database of registered tags for installing on a sensorgnome, so you can see live detections in the field</li>
        </ul>
        Your motus.org credentials give you access to these projects.
        <ol>
            <?php
            // extract ids of projects user is authorized for from the already-validated ticket
            $auth_projs = explode("!", $_COOKIE['auth_tkt'])[1];

            $db = new SQLite3($MOTUS_META_DB);
            $projs = $db->query(sprintf('SELECT id, label, name FROM projs where id > 0 and id in (%s) order by id',
                                        $auth_projs));

            $p = ['id' => 0, 'label' => 'UNASSIGNED', 'name' => 'Files whose project has not been assigned'];
            while ($p) {
                if (file_exists($DOWNLOAD_PATH . '/' . $p['id'])) {
                    printf ('<li value="%d"><a href="/download/%d">%s - %s</a></li>', $p['id'],$p['id'], $p['label'], $p['name']);
                } else {
                    printf ('<li value="%d">%s - %s <em>(no files yet)</em>)</li>', $p['id'], $p['label'], $p['name']);
                }
                $p = $projs->fetchArray(SQLITE3_ASSOC);
            }
            $db->close();
            ?>
        </ul>
    </body>
</html>
