SUBDIRS = pix

if BUILD_HELP
SUBDIRS += help
endif

bin_PROGRAMS=gnometris

gnometris_SOURCES = \
	main.cpp \
	blocks.cpp \
	blocks.h \
	highscores.cpp \
	highscores.h \
	scoreframe.cpp \
	scoreframe.h \
	tetris.cpp \
	tetris.h \
	preview.cpp \
	preview.h \
	blockops.cpp \
	blockops.h \
	renderer.cpp \
	renderer.h \
	blocks-cache.cpp \
	blocks-cache.h

gnometris_CPPFLAGS = \
	-I$(top_srcdir) \
	$(AM_CPPFLAGS)

gnometris_CXXFLAGS = \
	$(GTK_CFLAGS) \
	$(CLUTTER_CFLAGS) \
	$(CLUTTER_GTK_CFLAGS) \
	$(AM_CXXFLAGS)

gnometris_LDADD = \
	$(top_builddir)/libgames-support/libgames-support.la \
	$(CLUTTER_LIBS) \
	$(CLUTTER_GTK_LIBS) \
	$(GTK_LIBS) \
	$(INTLLIBS)

if HAVE_GNOME
gnometris_CXXFLAGS += $(GNOME_CFLAGS)
gnometris_LDADD += $(GNOME_LIBS)
endif

if HAVE_RSVG
gnometris_CXXFLAGS += $(RSVG_CFLAGS) 
gnometris_LDADD += $(RSVG_LIBS)
endif

if WITH_GTHREAD
gnometris_CXXFLAGS += $(GHTREAD_CFLAGS)
gnometris_LDADD += $(GTHREAD_LIBS)
endif

pixmapdir = $(pkgdatadir)/gnometris/pixmaps
pixmap_DATA = gnometris.svg

Gamesdir = $(datadir)/applications
Games_in_files = gnometris.desktop.in.in
Games_DATA = $(Games_in_files:.desktop.in.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

schema_in_files = gnometris.schemas.in
if HAVE_GNOME
schemadir = $(GCONF_SCHEMA_FILE_DIR)
schema_DATA = $(schema_in_files:.schemas.in=.schemas)
endif
@INTLTOOL_SCHEMAS_RULE@

man_MANS = gnometris.6

EXTRA_DIST = AUTHORS \
	$(pixmap_DATA) \
	$(schema_in_files) \
	$(man_MANS)

install-data-local:
if GCONF_SCHEMAS_INSTALL
	GCONF_CONFIG_SOURCE=$(GCONF_SCHEMA_CONFIG_SOURCE) $(GCONFTOOL) --makefile-install-rule $(top_builddir)/gnometris/$(schema_DATA)
endif
	-$(mkinstalldirs) $(DESTDIR)$(scoredir)
	-touch $(DESTDIR)$(scoredir)/gnometris.scores
	-chown $(scores_user):$(scores_group) $(DESTDIR)$(scoredir)/gnometris.scores
	-chmod 664 $(DESTDIR)$(scoredir)/gnometris.scores

install-exec-hook:
	-if test "$(setgid)" = "true"; then \
	  chgrp $(scores_group) $(DESTDIR)$(bindir)/gnometris && chmod 2555 $(DESTDIR)$(bindir)/gnometris ;\
	fi

DISTCLEANFILES = $(Games_DATA) $(schema_DATA)

-include $(top_srcdir)/git.mk
