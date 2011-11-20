bin_PROGRAMS = quadrapassel

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

install-exec-hook:
	-if test "$(setgid)" = "true"; then \
	  chgrp $(scores_group) $(DESTDIR)$(bindir)/quadrapassel && chmod 2555 $(DESTDIR)$(bindir)/quadrapassel ;\
	fi

-include $(top_srcdir)/git.mk
