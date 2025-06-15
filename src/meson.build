quadrapassel_sources = [
    'vapi/config.vapi',
    'vapi/input-event-codes.vapi',
    'game-view.vala',
    'game.vala',
    'history.vala',
    'preview.vala',
    'quadrapassel.vala',
    'score-dialog.vala'
]

quadrapassel_sources += gnome.compile_resources('quadrapassel-resources',
    'quadrapassel.gresource.xml',
    source_dir: 'gresource',
    c_name: 'quadrapassel'
)

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
        gsound_dependency,
        gtk_dependency,
        libadwaita_dependency,
        manette_dependency,
        pango_dependency,
        pango_cairo_dependency,
        posix_dependency,
        rsvg_dependency,
        libm_dependency
    ]
)
