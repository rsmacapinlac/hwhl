jenkins:
  lookup:
    port: 80
    home: /var/lib/jenkins
    user: jenkins
    group: www-data
    server_name: salt.dev.nucleoid.com
    master_url: http://salt.dev.nucleoid.com:8080
    plugins:
      installed:
        - greenballs
    pkgs:
      - jenkins
