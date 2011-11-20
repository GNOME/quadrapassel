pixmapdir = $(pkgdatadir)/quadrapassel/pixmaps
pixmap_DATA = 
	quadrapassel.svg \
	7blocks-tig.png \
	7blocks-gw.png

gamesdir = $(datadir)/applications
games_in_files = quadrapassel.desktop.in.in
games_DATA = $(games_in_files:.desktop.in.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

schema_in_files = quadrapassel.schemas.in
if HAVE_GNOME
schemadir = $(GCONF_SCHEMA_FILE_DIR)
schema_DATA = $(schema_in_files:.schemas.in=.schemas)
endif
@INTLTOOL_SCHEMAS_RULE@

man_MANS = quadrapassel.6

EXTRA_DIST = \
	$(pixmap_DATA) \
	$(schema_in_files) \
	$(man_MANS)

install-data-local:
if GCONF_SCHEMAS_INSTALL
	GCONF_CONFIG_SOURCE=$(GCONF_SCHEMA_CONFIG_SOURCE) $(GCONFTOOL) --makefile-install-rule $(top_builddir)/quadrapassel/data/$(schema_DATA)
endif

DISTCLEANFILES = $(games_DATA) $(schema_DATA)

-include $(top_srcdir)/git.mk
