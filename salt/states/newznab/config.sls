/var/www/nnplus/www/lib/smarty/templates_c:
  file.directory:
    - mode: 777

/var/www/nnplus/www/covers/movies:
  file.directory:
    - mode: 777

/var/www/nnplus/www/covers/anime:
  file.directory:
    - mode: 777

/var/www/nnplus/www/covers/tv:
  file.directory:
    - mode: 777

/var/www/nnplus/www/covers/music:
  file.directory:
    - mode: 777

/var/www/nnplus/www/install:
  file.directory:
    - mode: 777

/var/www/nnplus/nzbfiles:
  file.directory:
    - mode: 777

finalize_newznab_config:
  file.managed:
    - name: /var/www/nnplus/www/config.php
    - source: salt://newznab/files/newznab.config.php
    - template: jinja
    - mode: 777

copy_custom_update_config:
  file.managed:
    - name: /var/www/nnplus/misc/update_scripts/nix_scripts/newznab_screen_local.sh
    - source: salt://newznab/files/newznab_screen.sh
    - mode: 755
