/* -*- mode:C++; tab-width:8; c-basic-offset:8; indent-tabs-mode:true -*- */
/*
 * written by Callum McKenzie <callum@spooky-possum.org>
 *
 * Copyright (C) 2005 by Callum McKenzie
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 * For more details see the file COPYING.
 */

#ifndef __renderer_h__
#define __renderer_h__

#include <cairo.h>
#include <glib.h>

#include "blocks.h"

struct ThemeTableEntry {
	const gchar *name;
	const gchar *id;
};

extern const ThemeTableEntry ThemeTable[];
guint themeNameToNumber (const gchar *id);

class Renderer {
public:
	virtual void drawCell (cairo_t *cr, guint color);
};

Renderer *rendererFactory (guint id);

class TangoBlock:public Renderer {
public:
	TangoBlock (gboolean grad);
	virtual void drawCell (cairo_t *cr, guint color);

protected:	
	gboolean usegrads;
};

class CleanBlock:public Renderer {
public:
	CleanBlock ();
	virtual void drawCell (cairo_t *cr, guint color);
};

void drawRoundedRectangle (cairo_t *cr, gdouble x, gdouble y, gdouble w, gdouble h, gdouble r);

#endif // __renderer_h__
