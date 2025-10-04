blueprints = custom_target('blueprints',
  input: files(
    'shortcuts-dialog.blp',
  ),
  output: '.',
  command: [find_program('blueprint-compiler'), 'batch-compile', '@OUTPUT@', '@CURRENT_SOURCE_DIR@', '@INPUT@'],
)

quadrapassel_sources = [
    'vapi/config.vapi',
    'vapi/input-event-codes.vapi',
    'game-view.vala',
    'game.vala',
    'preview.vala',
    'quadrapassel.vala'
]

resources_conf = configuration_data()
resources_conf.set('app-id', app_id)
resources_conf.set('base-id-slashed', '/' + base_id.replace('.', '/'))
resources = gnome.compile_resources(
    'resources',
    configure_file(
        input: '@0@.gresource.xml'.format(base_id),
        output: '@BASENAME@',
        configuration: resources_conf,
    ),
    source_dir: 'gresource',
    c_name: 'quadrapassel',
    dependencies: blueprints
)
quadrapassel_sources += resources
executable(meson.project_name(),
    quadrapassel_sources,
    install: true,
    c_args: [
        '-include', 'config.h'
    ],
    vala_args: [
        '--target-glib', '2.44',
        '--vapidir', join_paths(meson.current_source_dir(), 'vapi')
    ],
    dependencies: [
    	gee_dependency,
        gsound_dependency,
        gtk_dependency,
        libadwaita_dependency,
        libgnome_games_support_dependency,
        manette_dependency,
        pango_dependency,
        pango_cairo_dependency,
        posix_dependency,
        rsvg_dependency,
        libm_dependency
    ]
)