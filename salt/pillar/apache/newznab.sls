apache:
  sites:
    000-default:
      enabled: False
    nnplus:
      enabled: True
      DocumentRoot: /var/www/nnplus/www
      Directory:
        default:
          Options: +FollowSymLinks
          AllowOverride: All
          Order: allow,deny    # For Apache < 2.4
          Allow: from all      # For apache < 2.4

  modules:
    enabled:
      - rewrite
