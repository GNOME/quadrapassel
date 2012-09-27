bin_PROGRAMS = quadrapassel

quadrapassel_SOURCES = \
	config.vapi \
	quadrapassel.vala \
	preview.vala \
	game.vala \
	game-view.vala \
	history.vala

quadrapassel_CFLAGS = \
	-DVERSION=\"$(VERSION)\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DDATA_DIRECTORY=\"$(datadir)/quadrapassel\" \
	-DSOUND_DIRECTORY=\"$(datadir)/quadrapassel/sounds\" \
	-DLOCALEDIR=\"$(datadir)/locale\" \
	$(GTK_CFLAGS) \
	$(RSVG_CFLAGS) \
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
	--pkg libcanberra-gtk

quadrapassel_LDADD = \
	$(CANBERRA_GTK_LIBS) \
	$(CLUTTER_GTK_LIBS) \
	$(CLUTTER_LIBS) \
	$(GTK_LIBS) \
	$(RSVG_LIBS) \
	$(INTLLIBS)

CLEANFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala, $(SOURCES))) \
	*_vala.stamp

-include $(top_srcdir)/git.mk
