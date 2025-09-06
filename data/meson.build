# Install scalable icon
install_data(
        join_paths('icons', 'hicolor', 'scalable', '@0@.svg'.format(app_id)),
    install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', 'scalable', 'apps')
)
# Install symbolic icon
install_data(
        join_paths('icons', 'hicolor', 'symbolic', '@0@-symbolic.svg'.format(base_id)),
    install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', 'symbolic', 'apps'),
    rename: '@0@-symbolic.svg'.format(app_id)
)

# GSchema file
gschema_conf = configuration_data()
gschema_conf.set('app-id', app_id)
gschema_conf.set('base-id-slashed', '/' + base_id.replace('.', '/'))
gschema_conf.set('gettext-package', meson.project_name())

configure_file(
  input: '@0@.gschema.xml'.format(base_id),
  output: '@0@.gschema.xml'.format(app_id),
  install: true,
  install_dir: datadir / 'glib-2.0' / 'schemas',
  configuration: gschema_conf
)

# D-Bus service file
service_conf = configuration_data()
service_conf.set('app-id', app_id)
service_conf.set('bindir', bindir)
service_conf.set('exec-name', meson.project_name())

configure_file(
    input: '@0@.service.in'.format(base_id),
    output: '@0@.service'.format(app_id),
    install: true,
    install_dir: join_paths(get_option('datadir'), 'dbus-1', 'services'),
    configuration: service_conf
)

# Desktop file
desktop_conf = configuration_data()
desktop_conf.set('app-id', app_id)
desktop_conf.set('exec-name', meson.project_name())

desktop_file = i18n.merge_file(
    input: configure_file(
      input: '@0@.desktop.in.in'.format(base_id),
      output: '@0@.desktop.in'.format(base_id),
      configuration: desktop_conf
    ),
    output: '@0@.desktop'.format(app_id),
    po_dir: '../po',
    type: 'desktop',
    install: true,
    install_dir: join_paths(get_option('datadir'), 'applications')
)

# Validate desktop file
desktop_file_validate = find_program('desktop-file-validate', required: false)
if desktop_file_validate.found()
  test(
    'validate-desktop',
    desktop_file_validate,
    args: [
      desktop_file.full_path()
    ]
  )
endif

# Metainfo file
metainfo_conf = configuration_data()
metainfo_conf.set('app-id', app_id)

metainfo_file = i18n.merge_file(
    input: configure_file(
        input: '@0@.metainfo.xml.in.in'.format(base_id),
        output: '@0@.metainfo.xml.in'.format(base_id),
        configuration: metainfo_conf
    ),
    output: '@0@.metainfo.xml'.format(app_id),
    po_dir: '../po',
    install: true,
    install_dir: join_paths(get_option('datadir'), 'metainfo')
)

# Install man page
install_man('@0@.6'.format(meson.project_name()))

# Install sounds
install_data(
    [
        'gameover.ogg',
        'land.ogg',
        'lines1.ogg',
        'lines2.ogg',
        'lines3.ogg',
        'quadrapassel.ogg',
        'slide.ogg',
        'turn.ogg'
    ],
    install_dir: soundsdir
)
