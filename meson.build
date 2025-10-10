project('quadrapassel', 'vala', 'c',
        version: '49.1',
        meson_version: '>= 1.1')

# App ID
if get_option('profile') == 'development'
  profile = '.Devel'
else
  profile = ''
endif

base_id = 'org.gnome.Quadrapassel'
app_id = 'org.gnome.Quadrapassel@0@'.format(profile)

# used to install help
gnome = import('gnome')
# used for internationalization
i18n = import('i18n')

cc = meson.get_compiler('c')

gee_dependency = dependency ('gee-0.8')
gsound_dependency = dependency('gsound', version: '>= 1.0.2')
gtk_dependency = dependency('gtk4', version: '>= 4.4')
libadwaita_dependency = dependency('libadwaita-1', version: '>= 1.8')
libgnome_games_support = subproject ('libgnome-games-support',
	    		             default_options: 'superproject_name=quadrapassel')
libgnome_games_support_dependency = libgnome_games_support.get_variable ('lggs_dependency')
manette_dependency = dependency('manette-0.2', version: '>= 0.2.10')
pango_dependency = dependency('pango')
pango_cairo_dependency = dependency('pangocairo')
posix_dependency = meson.get_compiler('vala').find_library('posix')
rsvg_dependency = dependency('librsvg-2.0', version: '>= 2.32.0')
libm_dependency = cc.find_library('m', required : true)

localedir = join_paths(get_option('prefix'), get_option('localedir'))
datadir = join_paths(get_option('prefix'), get_option('datadir'))
soundsdir = join_paths(datadir, 'sounds', meson.project_name())
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
