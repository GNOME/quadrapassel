SUBDIRS = icons

gsettings_SCHEMAS = org.gnome.quadrapassel.gschema.xml
@GSETTINGS_RULES@

soundsdir = $(datadir)/quadrapassel/sounds
sounds_DATA = \
	gameover.ogg \
	land.ogg \
	lines1.ogg \
	lines2.ogg \
	lines3.ogg \
	slide.ogg \
	turn.ogg \
	quadrapassel.ogg

desktopdir = $(datadir)/applications
desktop_in_files = quadrapassel.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

appstream_in_files = quadrapassel.appdata.xml.in
appstream_XML = $(appstream_in_files:.xml.in=.xml)
@APPSTREAM_XML_RULES@
@INTLTOOL_XML_RULE@

man_MANS = quadrapassel.6

EXTRA_DIST = \
	$(appstream_in_files) \
	$(gsettings_SCHEMAS) \
	$(sounds_DATA) \
	$(desktop_in_files) \
	$(man_MANS)

CLEANFILES = \
	$(appstream_XML) \
	$(desktop_DATA)

check-local: $(desktop_DATA)
	$(DESKTOP_FILE_VALIDATE) $(desktop_DATA)

DISTCHECK_CONFIGURE_FLAGS = --enable-appdata-check

-include $(top_srcdir)/git.mk
