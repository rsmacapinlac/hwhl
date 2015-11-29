allow_remote_users:
  mysql_query.run:
    - query: GRANT ALL PRIVILEGES ON *.* TO 'newznab'@'%' IDENTIFIED BY 'newznab' WITH GRANT OPTION;
