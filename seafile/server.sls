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
{%- if server.get('upgrade') %}
      - cmd: seafile-upgrade
{%- endif %}

seafile-graceful-down:
  service.dead:
    - name: seafile
    - prereq:
      - file: seafile-install
      - cmd: seafile-setup
{%- if server.get('upgrade') %}
      - cmd: seafile-upgrade
{%- endif %}

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
    - target: {{ server.current_install }}
    - require:
      - archive: seafile-install

autoexpect:
  pkg.installed:
    - name: expect

seafile-setup:
  file.managed:
    - name: /tmp/seafile-setup.sh
    - mode: 755
    - contents: |
        #!/usr/bin/expect
        spawn ./setup-seafile.sh
        expect "Press \\\[ENTER\\\]"
        send "\n"
        expect "\\\[server name\\\]:"
        send "{{ server.config.name }}\n"
        expect "\\\[This server's ip or domain\\\]:"
        send "{{ server.config.domain }}\n"
        expect "\\\[default: {{ server.dir }}/seafile-data \\\]"
        send "\n"
        expect "\\\[default: 8082 \\\]"
        send "\n"
        expect "press \\\[ENTER\\\]"
        send "\n"
        expect "Press \\\[ENTER\\\]"
        send "\n"
        expect "completed successfully."
        
        spawn ./seafile.sh start
        expect eof
        
        spawn ./seahub.sh start
        expect "\\\[ admin email \\\]"
        send "{{ server.config.admin }}\n"
        expect "\\\[ admin password \\\]"
        send "{{ server.config.password }}\n"
        expect "\\\[ admin password again \\\]"
        send "{{ server.config.password }}\n"
        expect "Done."
        
        spawn ./seahub.sh stop
        expect eof
        spawn ./seafile.sh stop
        expect eof

  cmd.wait:
    - cwd: {{ server.current_install }}
    - name: /tmp/seafile-setup.sh
    - user: {{ server.user }}
    - unless: test -d {{ server.dir }}/ccnet
    - require:
      - pkg: autoexpect
      - file: seafile-setup
    - watch:
      - archive: seafile-install
    - require_in:
      - file: seafile-install

{% if server.get('upgrade') %}
seafile-upgrade:
  file.managed:
    - name: /tmp/seafile-upgrade.sh
    - mode: 755
    - contents: |
        #!/usr/bin/expect
        spawn ./upgrade/{{ server.upgrade }}
        expect "Press \\\[ENTER\\\]"
        send "\n"
        expect eof

  cmd.wait:
    - cwd: {{ server.current_install }}
    - name: /tmp/seafile-upgrade.sh
    - user: {{ server.user }}
    - require:
      - pkg: autoexpect
      - file: seafile-upgrade
      - cmd: seafile-setup
    - watch:
      - archive: seafile-install
    - require_in:
      - file: seafile-install
    - watch_in:
      - service: seafile
      - service: seahub
{% endif %}
