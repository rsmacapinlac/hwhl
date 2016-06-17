<?php

//=========================
// Config you must change - updated by installer.
//=========================
define('DB_TYPE', 'mysql');
define('DB_HOST', 'shino.db.macapinlac.com');
define('DB_PORT', 3306);
define('DB_USER', 'newznab');
define('DB_PASSWORD', 'newznab');
define('DB_NAME', 'newznab');
define('DB_INNODB', false);
define('DB_PCONNECT', true);
define('DB_ERRORMODE', PDO::ERRMODE_SILENT);

define('NNTP_USERNAME', '{{ salt['pillar.get']('newznab:newsgroup:username') }}');
define('NNTP_PASSWORD', '{{ salt['pillar.get']('newznab:newsgroup:password') }}');
define('NNTP_SERVER', '{{ salt['pillar.get']('newznab:newsgroup:server') }}');
define('NNTP_PORT', '{{ salt['pillar.get']('newznab:newsgroup:port') }}');
define('NNTP_SSLENABLED', true);

define('CACHEOPT_METHOD', 'file');
define('CACHEOPT_TTLFAST', '120');
define('CACHEOPT_TTLMEDIUM', '600');
define('CACHEOPT_TTLSLOW', '1800');
define('CACHEOPT_MEMCACHE_SERVER', '127.0.0.1');
define('CACHEOPT_MEMCACHE_PORT', '11211');

// define('EXTERNAL_PROXY_IP', ''); //Internal address of public facing server
// define('EXTERNAL_HOST_NAME', ''); //The external hostname that should be used

require("automated.config.php");
