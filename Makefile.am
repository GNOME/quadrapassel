SUBDIRS = pix

if BUILD_HELP
SUBDIRS += help
endif

bin_PROGRAMS=quadrapassel

quadrapassel_SOURCES = \
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

quadrapassel_CPPFLAGS = \
	-I$(top_srcdir) \
	$(AM_CPPFLAGS)

quadrapassel_CXXFLAGS = \
	$(GTK_CFLAGS) \
	$(CLUTTER_GTK_CFLAGS) \
	$(CLUTTER_CFLAGS) \
	$(AM_CXXFLAGS)

quadrapassel_LDADD = \
	$(top_builddir)/libgames-support/libgames-support.la \
	$(CLUTTER_GTK_LIBS) \
	$(CLUTTER_LIBS) \
	$(GTK_LIBS) \
	$(INTLLIBS)

if HAVE_GNOME
quadrapassel_CXXFLAGS += $(GNOME_CFLAGS)
quadrapassel_LDADD += $(GNOME_LIBS)
endif

if HAVE_RSVG
quadrapassel_CXXFLAGS += $(RSVG_CFLAGS) 
quadrapassel_LDADD += $(RSVG_LIBS)
endif

if WITH_GTHREAD
quadrapassel_CXXFLAGS += $(GHTREAD_CFLAGS)
quadrapassel_LDADD += $(GTHREAD_LIBS)
endif

pixmapdir = $(pkgdatadir)/quadrapassel/pixmaps
pixmap_DATA = quadrapassel.svg

Gamesdir = $(datadir)/applications
Games_in_files = quadrapassel.desktop.in.in
Games_DATA = $(Games_in_files:.desktop.in.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

schema_in_files = quadrapassel.schemas.in
if HAVE_GNOME
schemadir = $(GCONF_SCHEMA_FILE_DIR)
schema_DATA = $(schema_in_files:.schemas.in=.schemas)
endif
@INTLTOOL_SCHEMAS_RULE@

man_MANS = quadrapassel.6

EXTRA_DIST = AUTHORS \
	$(pixmap_DATA) \
	$(schema_in_files) \
	$(man_MANS)

install-data-local:
if GCONF_SCHEMAS_INSTALL
	GCONF_CONFIG_SOURCE=$(GCONF_SCHEMA_CONFIG_SOURCE) $(GCONFTOOL) --makefile-install-rule $(top_builddir)/quadrapassel/$(schema_DATA)
endif
	-$(mkinstalldirs) $(DESTDIR)$(scoredir)
	-touch $(DESTDIR)$(scoredir)/quadrapassel.scores
	-chown $(scores_user):$(scores_group) $(DESTDIR)$(scoredir)/quadrapassel.scores
	-chmod 664 $(DESTDIR)$(scoredir)/quadrapassel.scores

install-exec-hook:
	-if test "$(setgid)" = "true"; then \
	  chgrp $(scores_group) $(DESTDIR)$(bindir)/quadrapassel && chmod 2555 $(DESTDIR)$(bindir)/quadrapassel ;\
	fi

DISTCLEANFILES = $(Games_DATA) $(schema_DATA)

-include $(top_srcdir)/git.mk
