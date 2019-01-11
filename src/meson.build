executable(meson.project_name(),
    [
        'vapi/config.vapi',        
        'vapi/input-event-codes.vapi',
        'game-view.vala',
        'game.vala',
        'history.vala',
        'preview.vala',
        'quadrapassel.vala',
        'score-dialog.vala'
    ],
    install: true,
    c_args: [
        '-include', 'config.h'
    ],
    vala_args: [
        '--target-glib', '2.44',
        '--vapidir', join_paths(meson.current_source_dir(), 'vapi')
    ],
    dependencies: [
        canberra_dependency,
        canberra_gtk3_dependency,
        cogl_dependency,
        clutter_dependency,
        clutter_gtk_dependency,
        gtk_dependency,
        manette_dependency,
        pango_depepdency,
        pango_cairo_dependency,
        posix_dependency,
        rsvg_dependency
    ]
)
