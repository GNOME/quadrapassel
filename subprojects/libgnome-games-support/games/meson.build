includesubdir = get_option('superproject_name') + '_gnome-games-support'

lggs_interface_deps = [
    adw_dependency,
    gio_dependency,
    glib_dependency,
    gtk_dependency,
]

sources = [
    'config.vapi',
    'appearance-group.vala',
    'gridframe.vala',
    'scores/category.vala',
    'scores/context.vala',
    'scores/dialog.vala',
    'scores/directory-importer.vala',
    'scores/history-file-importer.vala',
    'scores/importer.vala',
    'scores/score.vala',
]

vala_args = []

if get_option('sounds')
    sources += 'sounds.vala'

    vala_args += '--vapidir=' + meson.project_source_root () / 'games' / 'vapi'

    lggs_interface_deps += [
        sndfile_dependency,
        openal_dependency,
    ]
endif

conditional_args = {}

if get_option('introspection') == 'gir' or get_option('introspection') == 'typelib'
    conditional_args += { 'vala_gir': 'GnomeGamesSupport-3.0.gir' }
endif

lggs = static_library('gnome-games-support-3',
    sources,
    c_args: [
        '-w',
        '-DGETTEXT_PACKAGE="@0@"'.format (gettext_package),
        '-DLOCALEDIR="@0@"'.format (localedir),
    ],
    vala_header: 'libgnome-games-support.h',
    vala_args: vala_args,
    dependencies: lggs_interface_deps,
    kwargs: conditional_args,
)

if get_option('introspection') == 'typelib'
    g_ir_compiler = find_program('g-ir-compiler')
    typelib = custom_target('gnome-games-support-3-typelib',
        input: lggs.vala_gir(),
        output: get_option('superproject_name') + '_GnomeGamesSupport-3.0.typelib',
        command: [
            g_ir_compiler,
            '--output',
            '@OUTPUT@',
            '@INPUT@',
        ],
        install: true,
        install_dir: libdir / 'girepository-1.0',
    )
endif
