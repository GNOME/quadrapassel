SUBDIRS = icons

gsettings_in_file = org.gnome.quadrapassel.gschema.xml.in
gsettings_SCHEMAS = $(gsettings_in_file:.xml.in=.xml)
@INTLTOOL_XML_NOMERGE_RULE@
@GSETTINGS_RULES@

pixmapdir = $(datadir)/quadrapassel/pixmaps
pixmap_DATA = \
	quadrapassel.svg \
	7blocks-tig.png \
	7blocks-gw.png

desktopdir = $(datadir)/applications
desktop_in_files = quadrapassel.desktop.in.in
desktop_DATA = $(desktop_in_files:.desktop.in.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

man_MANS = quadrapassel.6

EXTRA_DIST = \
	$(gsettings_in_file) \
	$(pixmap_DATA) \
	$(desktop_in_files) \
	$(man_MANS)

CLEANFILES = $(desktop_DATA) $(gsettings_SCHEMAS)
DISTCLEANFILES = $(desktop_DATA) $(gsettings_SCHEMAS)

-include $(top_srcdir)/git.mk
