project('quadrapassel', 'vala', 'c',
        version: '40.2')

project_id = 'org.gnome.Quadrapassel'

# used to install help
gnome = import('gnome')
# used for internationalization
i18n = import('i18n')
# used to run post install script
python3 = import('python3')

cc = meson.get_compiler('c')

clutter_dependency = dependency('clutter-1.0', version: '>= 1.0.0')
clutter_gtk_dependency = dependency('clutter-gtk-1.0', version: '>= 0.91.6')
cogl_dependency = dependency('cogl-1.0')
gsound_dependency = dependency('gsound', version: '>= 1.0.2')
gtk_dependency = dependency('gtk+-3.0', version: '>= 3.12.0')
manette_dependency = dependency('manette-0.2', version: '>= 0.2.0')
pango_depepdency = dependency('pango')
pango_cairo_dependency = dependency('pangocairo')
posix_dependency = meson.get_compiler('vala').find_library('posix')
rsvg_dependency = dependency('librsvg-2.0', version: '>= 2.32.0')
libm_dependency = cc.find_library('m', required : true)
        
# Set gettext package name
add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language: 'c')

localedir = join_paths(get_option('prefix'), get_option('localedir'))
datadir = join_paths(get_option('prefix'), get_option('datadir'), meson.project_name())
soundsdir = join_paths(datadir, 'sounds')

conf = configuration_data ()
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

meson.add_install_script(python3.find_python().path(), join_paths(meson.source_root(), 
                                                                  'build-aux', 
                                                                  'meson_post_install.py'))
