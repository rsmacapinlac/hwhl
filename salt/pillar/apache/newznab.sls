apache:
  sites:
    000-default:
      enabled: False
    nnplus:
      enabled: True
      DocumentRoot: /var/www/nnplus/www
      Directory:
        /var/www/nnplus/www:
          Options: +FollowSymLinks
          AllowOverride: All
          Order: allow,deny
          Allow: from all

  modules:
    enabled:
      - rewrite
