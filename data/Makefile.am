SUBDIRS = icons

gsettings_in_file = org.gnome.quadrapassel.gschema.xml.in
gsettings_SCHEMAS = $(gsettings_in_file:.xml.in=.xml)
@INTLTOOL_XML_NOMERGE_RULE@
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
desktop_in_files = quadrapassel.desktop.in.in
desktop_DATA = $(desktop_in_files:.desktop.in.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

man_MANS = quadrapassel.6

EXTRA_DIST = \
	$(gsettings_in_file) \
	$(sounds_DATA) \
	$(desktop_in_files) \
	$(man_MANS)

CLEANFILES = $(desktop_DATA) $(gsettings_SCHEMAS)
DISTCLEANFILES = $(desktop_DATA) $(gsettings_SCHEMAS)

-include $(top_srcdir)/git.mk
