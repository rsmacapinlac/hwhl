git-core:
  pkg.installed

python:
  pkg.installed

python-cheetah:
  pkg.installed

git://github.com/midgetspy/Sick-Beard.git:
  git.latest:
    - target: /home/media/.sickbeard

/home/media/.sickbeard:
  file.directory:
    - user: media
    - group: media
    - mode: 755
    - recurse:
      - user
      - group
   
