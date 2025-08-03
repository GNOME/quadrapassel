project('quadrapassel', 'vala', 'c',
        version: '49.beta')

base_id = 'org.gnome.Quadrapassel'
app_id = 'org.gnome.Quadrapassel.Devel'

# used to install help
gnome = import('gnome')
# used for internationalization
i18n = import('i18n')
# used to run post install script
python3 = import('python3')

cc = meson.get_compiler('c')

gee_dependency = dependency ('gee-0.8')
gsound_dependency = dependency('gsound', version: '>= 1.0.2')
gtk_dependency = dependency('gtk4', version: '>= 4.4')
libadwaita_dependency = dependency('libadwaita-1', version: '>= 1.1')
libgnome_games_support_dependency = dependency ('libgnome-games-support-2', version: '>= 2.0.0')
manette_dependency = dependency('manette-0.2', version: '>= 0.2.0')
pango_dependency = dependency('pango')
pango_cairo_dependency = dependency('pangocairo')
posix_dependency = meson.get_compiler('vala').find_library('posix')
rsvg_dependency = dependency('librsvg-2.0', version: '>= 2.32.0')
libm_dependency = cc.find_library('m', required : true)

# Set gettext package name
add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language: 'c')

localedir = join_paths(get_option('prefix'), get_option('localedir'))
datadir = join_paths(get_option('prefix'), get_option('datadir'))
soundsdir = join_paths(datadir, 'sounds')
bindir = join_paths (get_option ('prefix'), get_option ('bindir'))

conf = configuration_data ()
conf.set_quoted ('APP_ID', app_id)
conf.set_quoted ('VERSION', meson.project_version())
conf.set_quoted ('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted ('SOUND_DIRECTORY', soundsdir)
conf.set_quoted ('LOCALEDIR', localedir)

configure_file(output: 'config.h', configuration: conf)
config_h_dir = include_directories('.')

subdir('data')
subdir('po')
subdir('help')
subdir('src')

gnome.post_install(
  gtk_update_icon_cache: true,
  glib_compile_schemas: true,
  update_desktop_database: true,
)