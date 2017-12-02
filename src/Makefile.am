bin_PROGRAMS = quadrapassel

quadrapassel_SOURCES = \
	config.vapi \
	quadrapassel.vala \
	preview.vala \
	game.vala \
	game-view.vala \
	history.vala \
	score-dialog.vala

quadrapassel_CFLAGS = \
	-DVERSION=\"$(VERSION)\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DDATA_DIRECTORY=\"$(datadir)/quadrapassel\" \
	-DSOUND_DIRECTORY=\"$(datadir)/quadrapassel/sounds\" \
	-DLOCALEDIR=\"$(datadir)/locale\" \
	$(QUADRAPASSEL_CFLAGS) \
	-w

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
	--pkg libmanette-0.2

quadrapassel_LDADD = \
	$(QUADRAPASSEL_LIBS)

CLEANFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala, $(SOURCES))) \
	*_vala.stamp

-include $(top_srcdir)/git.mk
