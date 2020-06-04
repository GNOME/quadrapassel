# Install scalable icon
install_data(
        join_paths('icons', 'hicolor', 'scalable', '@0@.svg'.format(project_id)),
    install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', 'scalable', 'apps')
)
# Install symbolic icon
install_data(
        join_paths('icons', 'hicolor', 'symbolic', '@0@-symbolic.svg'.format(project_id)),
    install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', 'symbolic', 'apps')
)

# Install gschema
install_data(
  '@0@.gschema.xml'.format(project_id),
  install_dir : join_paths(get_option('datadir'), 'glib-2.0', 'schemas')
)


# Desktop file
desktop_file = i18n.merge_file(
    input: '@0@.desktop.in'.format(project_id),
    output: '@0@.desktop'.format(project_id),
    po_dir: join_paths(meson.source_root(), 'po'),
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

# AppData file
appdata_file = i18n.merge_file(
    input: '@0@.appdata.xml.in'.format(project_id),
    output: '@0@.appdata.xml'.format(project_id),
    po_dir: join_paths(meson.source_root(), 'po'),
    install: true,
    install_dir: join_paths(get_option('datadir'), 'metainfo')
)

# Validate AppData file
appstream_util = find_program('appstream-util', required: false)
if appstream_util.found()
  test(
    'validate-appdata', appstream_util,
    args: [
      'validate-relax', '--nonet', appdata_file.full_path()
    ]
  )
endif

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
    install_dir: join_paths(get_option('datadir'), meson.project_name(), 'sounds')
)
