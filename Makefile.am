SUBDIRS = src data

if BUILD_HELP
SUBDIRS += help
endif

install-data-local:
	-$(mkinstalldirs) $(DESTDIR)$(scoredir)
	-touch $(DESTDIR)$(scoredir)/quadrapassel.scores
	-chown $(scores_user):$(scores_group) $(DESTDIR)$(scoredir)/quadrapassel.scores
	-chmod 664 $(DESTDIR)$(scoredir)/quadrapassel.scores

-include $(top_srcdir)/git.mk
