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

  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: seafile
{% else %}
  file.managed:
    - name: /etc/init.d/seafile
    - source: salt://seafile/files/seafile-initd
    - mode: 755
    - template: jinja
    - defaults:
        config: {{ server }}

  cmd.run:
    - name: update-rc.d seafile defaults
    - onchanges:
      - file: seafile
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
      - file: seahub-settings
{% if server.use_systemd %}
  file.managed:
    - name: /etc/systemd/system/seahub.service
    - source: salt://seafile/files/seahub.service
    - template: jinja
    - defaults:
        config: {{ server }}

  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: seahub
{% else %}
  file.managed:
    - name: /etc/init.d/seahub
    - source: salt://seafile/files/seahub-initd
    - mode: 755
    - template: jinja
    - defaults:
        config: {{ server }}

  cmd.run:
    - name: update-rc.d seahub defaults
    - onchanges:
      - file: seahub
{% endif %}

seahub-graceful-down:
  service.dead:
    - name: seahub
    - prereq:
      - archive: seafile-install

seafile-graceful-down:
  service.dead:
    - name: seafile
    - prereq:
      - archive: seafile-install

seafile-download:
  cmd.run:
    - name: "curl -L --silent '{{ server.url }}' > '{{ server.source }}'"
    - unless: "test -f '{{ server.source }}'"
    - prereq:
      - archive: seafile-install
    - require_in:
      - service: seafile-graceful-down
      - service: seahub-graceful-down

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
    - user: {{ server.user }}
    - group: {{ server.group }}
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

seafile-seahub-data:
  file.directory:
    - name: {{ server.dir }}/seahub-data/custom
    - user: {{ server.user }}
    - group: {{ server.group }}
    - makedirs: True

seafile-seahub-data-symlink:
  file.symlink:
    - name: {{ server.current_install }}/seahub/media/custom
    - target: ../../../seahub-data/custom
    - require:
      - file: seafile-seahub-data

{% if server.get('css') %}
seafile-css:
  file.managed:
    - name: {{ server.dir }}/seahub-data/{{ server.seahub_settings.BRANDING_CSS }}
    - user: {{ server.user }}
    - group: {{ server.group }}
    - mode: 644
    - makedirs: True
    - contents: |
        {{ server.css|indent(8) }}
    - require:
      - file: seafile-seahub-data
{% endif %}

{% if server.get('logo_source') %}
seafile-logo:
  file.managed:
    - name: {{ server.dir }}/seahub-data/{{ server.seahub_settings.LOGO_PATH }}
    - source: {{ server.logo_source }}
{%- if server.get('logo_hash') %}
    - source_hash: {{ server.logo_hash}}
{%- endif %}
    - user: {{ server.user }}
    - group: {{ server.group }}
    - mode: 644
    - makedirs: True
    - require:
      - file: seafile-seahub-data
{% endif %}

seahub-settings:
  file.managed:
    - name: {{ server.dir }}/conf/seahub_settings.py
    - user: {{ server.user }}
    - group: {{ server.group }}
    - mode: 600
    - makedirs: True
    - contents: |
{%- for key, value in server.get('seahub_settings', {}).items() %}
        {{ key }} = {{ value|python }}
{%- endfor %}

seafile-ccnet:
  ini.options_present:
    - name: {{ server.dir }}/conf/ccnet.conf
    - sections: {{ server.get('ccnet', {})|yaml }}
    - watch_in:
      - service: seafile

seafile-seafile-conf:
  ini.options_present:
    - name: {{ server.dir }}/conf/seafile.conf
    - sections: {{ server.get('seafile', {})|yaml }}
    - watch_in:
      - service: seafile

seafile-seafdav:
  ini.options_present:
    - name: {{ server.dir }}/conf/seafdav.conf
    - sections: {{ server.get('seafdav', {})|yaml }}
    - watch_in:
      - service: seafile

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
{% endif %}
