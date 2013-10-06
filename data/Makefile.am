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

appdatadir = $(datadir)/appdata
appdata_in_files = quadrapassel.appdata.xml.in
appdata_DATA = $(appdata_in_files:.xml.in=.xml)
@INTLTOOL_XML_RULE@

man_MANS = quadrapassel.6

EXTRA_DIST = \
	$(appdata_in_files) \
	$(gsettings_SCHEMAS) \
	$(sounds_DATA) \
	$(desktop_in_files) \
	$(man_MANS)

CLEANFILES = \
	$(appdata_DATA) \
	$(desktop_DATA)

check-local: $(appdata_DATA) $(desktop_DATA)
	$(APPDATA_VALIDATE) $(appdata_DATA)
	$(DESKTOP_FILE_VALIDATE) $(desktop_DATA)

-include $(top_srcdir)/git.mk
