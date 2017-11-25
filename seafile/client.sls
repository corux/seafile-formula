{% from 'seafile/map.jinja' import client with context %}

{% if grains['os_family'] == 'RedHat' %} 
include:
  - epel
{% endif %}

{% if client.get('repo') %}
seafile-repo-key:
  cmd.run:
    - name: rpm --import {{ client.repo_key }}
    - unless: rpm -qi gpg-pubkey-{{ client.repo_keyid }}

seafile-repo:
  pkgrepo.managed:
    - humanname: Seafile Client repository
    - baseurl: {{ client.repo }}
    - gpgcheck: 1
    - gpgkey: {{ client.repo_key }}
    - require:
      - cmd: seafile-repo-key
{% endif %}

seafile-client:
  pkg.installed:
    - name: {{ client.get('package', 'seafile-client-qt') }}
{% if client.get('url') %}
    - sources:
      - seafile: {{ client.url }}
{% endif %}
