{% from 'seafile/map.jinja' import server with context %}

seafile:
  pkg.installed:
    - pkgs: {{ server.dependencies }}

  group.present:
    - name: {{ server.group }}

  user.present:
    - name: {{ server.user }}
    - home: {{ server.dir }}
    - gid: {{ server.group }}
    - require:
      - group: seafile

  service.running:
    - name: seafile
    - enable: True
    - require:
      - file: seafile
      - user: seafile
    - watch:
      - file: seafile-install
{% if server.use_systemd %}
  file.managed:
    - name: /etc/systemd/system/seafile.service
    - source: salt://seafile/files/seafile.service
    - template: jinja
    - defaults:
        config: {{ server }}

  module.wait:
    - name: service.systemctl_reload
    - watch:
      - file: seafile
    - require_in:
      - service: seafile-graceful-down
{% else %}
  file.managed:
    - name: /etc/init.d/seafile
    - source: salt://seafile/files/seafile-initd
    - mode: 755
    - template: jinja
    - defaults:
        config: {{ server }}
    - require:
      - archive: seafile-install

  cmd.wait:
    - name: update-rc.d seafile defaults
    - watch:
      - file: seafile
    - require_in:
      - service: seafile-graceful-down
{% endif %}

seahub:
  service.running:
    - name: seahub
    - enable: True
    - require:
      - file: seahub
      - user: seafile
      - service: seafile
    - watch:
      - file: seafile-install
{% if server.use_systemd %}
  file.managed:
    - name: /etc/systemd/system/seahub.service
    - source: salt://seafile/files/seahub.service
    - template: jinja
    - defaults:
        config: {{ server }}

  module.wait:
    - name: service.systemctl_reload
    - watch:
      - file: seahub
    - require_in:
      - service: seahub-graceful-down
{% else %}
  file.managed:
    - name: /etc/init.d/seahub
    - source: salt://seafile/files/seahub-initd
    - mode: 755
    - template: jinja
    - defaults:
        config: {{ server }}
    - require:
      - archive: seafile-install

  cmd.wait:
    - name: update-rc.d seahub defaults
    - watch:
      - file: seahub
    - require_in:
      - service: seahub-graceful-down
{% endif %}

seahub-graceful-down:
  service.dead:
    - name: seahub
    - prereq:
      - file: seafile-install
      - cmd: seafile-setup

seafile-graceful-down:
  service.dead:
    - name: seafile
    - prereq:
      - file: seafile-install
      - cmd: seafile-setup

seafile-download:
  cmd.run:
    - name: "curl -L --silent '{{ server.url }}' > '{{ server.source }}'"
    - unless: "test -f '{{ server.source }}'"
    - prereq:
      - archive: seafile-install

seafile-install:
  archive.extracted:
    - name: {{ server.dir }}
    - source: {{ server.source }}
    - archive_format: tar
    - tar_options: z
    - if_missing: {{ server.current_install }}
    - user: {{ server.user }}
    - group: {{ server.group }}
    - require:
      - user: seafile

  file.symlink:
    - name: {{ server.latest }}
    - target: seafile-server-{{ server.version }}
    - require:
      - archive: seafile-install

autoexpect:
  pkg.installed:
    - name: expect

seafile-setup:
  file.managed:
    - name: /tmp/seafile-setup.sh
    - source: salt://seafile/files/seafile-setup.sh
    - mode: 755
    - template: jinja
    - defaults:
        server: {{ server }}

  cmd.run:
    - cwd: {{ server.current_install }}
    - name: /tmp/seafile-setup.sh
    - user: {{ server.user }}
    - unless: test -d {{ server.dir }}/ccnet
    - require:
      - pkg: autoexpect
      - file: seafile-setup
    - onchanges:
      - archive: seafile-install
    - require_in:
      - file: seafile-install

{% if server.get('upgrade') %}
seafile-upgrade:
  file.managed:
    - name: /tmp/seafile-upgrade.sh
    - source: salt://seafile/files/seafile-upgrade.sh
    - mode: 755
    - template: jinja
    - defaults:
        server: {{ server }}

  cmd.run:
    - cwd: {{ server.current_install }}
    - name: /tmp/seafile-upgrade.sh
    - user: {{ server.user }}
    - require:
      - pkg: autoexpect
      - file: seafile-upgrade
      - cmd: seafile-setup
    - onchanges:
      - archive: seafile-install
    - require_in:
      - file: seafile-install
    - watch_in:
      - service: seafile
      - service: seahub
    - prereq_in:
      - service: seafile-graceful-down
      - service: seahub-graceful-down
{% endif %}
