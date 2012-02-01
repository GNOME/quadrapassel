bin_PROGRAMS = quadrapassel

quadrapassel_SOURCES = \
	config.vapi \
	quadrapassel.vala \
	preview.vala \
	game.vala \
	game-view.vala

quadrapassel_CFLAGS = \
	-I$(top_srcdir)/libgames-support \
	-DVERSION=\"$(VERSION)\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DDATA_DIRECTORY=\"$(datadir)/quadrapassel\" \
	-DSOUND_DIRECTORY=\"$(datadir)/quadrapassel/sounds\" \
	-DLOCALEDIR=\"$(datadir)/locale\" \
	$(GTK_CFLAGS) \
	$(CANBERRA_GTK_CFLAGS) \
	$(CLUTTER_GTK_CFLAGS) \
	$(CLUTTER_CFLAGS)

quadrapassel_VALAFLAGS = \
	--pkg posix \
	--pkg gtk+-3.0 \
	--pkg pango \
	--pkg pangocairo \
	--pkg clutter-1.0 \
	--pkg clutter-gtk-1.0 \
	--pkg cogl-1.0 \
	--pkg libcanberra \
	--pkg libcanberra-gtk \
	--vapidir $(top_srcdir)/libgames-support \
	--pkg GnomeGamesSupport-1.0

quadrapassel_LDADD = \
	$(top_builddir)/libgames-support/libgames-support.la \
	$(CANBERRA_GTK_LIBS) \
	$(CLUTTER_GTK_LIBS) \
	$(CLUTTER_LIBS) \
	$(GTK_LIBS) \
	$(INTLLIBS)

if HAVE_RSVG
quadrapassel_CFLAGS += $(RSVG_CFLAGS) 
quadrapassel_LDADD += $(RSVG_LIBS)
endif

install-exec-hook:
	-if test "$(setgid)" = "true"; then \
	  chgrp $(scores_group) $(DESTDIR)$(bindir)/quadrapassel && chmod 2555 $(DESTDIR)$(bindir)/quadrapassel ;\
	fi

CLEANFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala, $(SOURCES))) \
	*_vala.stamp

-include $(top_srcdir)/git.mk
