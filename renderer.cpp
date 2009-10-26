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

#include <config.h>
#include <string.h>
#include <glib/gi18n.h>

#include "renderer.h"

const ThemeTableEntry ThemeTable[] = {{N_("Plain"), "plain"},
				      {N_("Tango Flat"), "tangoflat"},
				      {N_("Tango Shaded"), "tangoshaded"},
				      {NULL, NULL}};


guint themeNameToNumber (const gchar *id)
{
	guint i;
	const ThemeTableEntry *t;

	if (id == NULL)
		return 0;

	t = ThemeTable;
	i = 0;
	while (t->id) {
		if (strcmp (t->id, id) == 0)
			return i;
		t++;
		i++;
	}

	return 0;
}

Renderer * rendererFactory (guint id)
{
	Renderer *r;
	switch (id) {
	case 2:
		r = new TangoBlock (TRUE);
		break;
	case 1:
		r = new TangoBlock (FALSE);
		break;
	case 0:
	default:
		r = new Renderer ();
	}
	return r;
}

/* The Renderer class is a basic drawing class that is structured to
   be easily customised by subclasses. Override drawCell to customise
   the drawing of one cell. */

/* Note that the default renderer is designed to be reasonably fast
   and flexible, not flashy. */

void Renderer::drawCell (cairo_t *cr, guint color)
{
	const gdouble colours[7][3] = {{1.0, 0.0, 0.0},
				       {0.0, 1.0, 0.0},
				       {0.0, 0.0, 1.0},
				       {1.0, 1.0, 1.0},
				       {1.0, 1.0, 0.0},
				       {1.0, 0.0, 1.0},
				       {0.0, 1.0, 1.0}};

	color = CLAMP (color, 0, 6);

	cairo_set_source_rgb(cr, colours[color][0],
				colours[color][1],
				colours[color][2]);
	cairo_paint (cr);
}

TangoBlock::TangoBlock (gboolean grad) : Renderer ()
{
	usegrads = grad;
}

void TangoBlock::drawCell (cairo_t *cr, guint color)
{
	cairo_pattern_t *pat = NULL;
	/* the following garbage is derived from the official tango style guide */
	const gdouble colours[8][3][3] = {
					  {{0.93725490196078431, 0.16078431372549021, 0.16078431372549021},
					   {0.8, 0.0, 0.0},
					   {0.64313725490196083, 0.0, 0.0}}, /* red */

					  {{0.54117647058823526, 0.88627450980392153, 0.20392156862745098},
					   {0.45098039215686275, 0.82352941176470584, 0.086274509803921567},
					   {0.30588235294117649, 0.60392156862745094, 0.023529411764705882}}, /* green */

					  {{0.44705882352941179, 0.62352941176470589, 0.81176470588235294},
					   {0.20392156862745098, 0.396078431372549, 0.64313725490196083},
					   {0.12549019607843137, 0.29019607843137257, 0.52941176470588236}}, /* blue */

					  {{0.93333333333333335, 0.93333333333333335, 0.92549019607843142},
					   {0.82745098039215681, 0.84313725490196079, 0.81176470588235294},
					   {0.72941176470588232, 0.74117647058823533, 0.71372549019607845}}, /* white */

					  {{0.9882352941176471, 0.9137254901960784, 0.30980392156862746},
					   {0.92941176470588238, 0.83137254901960789, 0.0},
					   {0.7686274509803922, 0.62745098039215685, 0.0}}, /* yellow */

					  {{0.67843137254901964, 0.49803921568627452, 0.6588235294117647},
					   {0.45882352941176469, 0.31372549019607843, 0.4823529411764706},
					   {0.36078431372549019, 0.20784313725490197, 0.4}}, /* purple */

					  {{0.9882352941176471, 0.68627450980392157, 0.24313725490196078},
					   {0.96078431372549022, 0.47450980392156861, 0.0},
					   {0.80784313725490198, 0.36078431372549019, 0.0}}, /* orange (replacing cyan) */

					  {{0.33, 0.34, 0.32},
					   {0.18, 0.2, 0.21},
					   {0.10, 0.12, 0.13}} /* grey */
					 };

	color = CLAMP (color, 0, 6);

	if (usegrads) {
		 pat = cairo_pattern_create_linear (0.35, 0, 0.55, 0.9);
		 cairo_pattern_add_color_stop_rgb (pat, 0.0, colours[color][0][0],
						   colours[color][0][1],
						   colours[color][0][2]);
		 cairo_pattern_add_color_stop_rgb (pat, 1.0, colours[color][1][0],
						   colours[color][1][1],
						   colours[color][1][2]);
		 cairo_set_source (cr, pat);
	} else {
		 cairo_set_source_rgb (cr, colours[color][0][0],
				       colours[color][0][1],
				       colours[color][0][2]);
	}

	drawRoundedRectangle (cr, 0.05, 0.05, 0.9, 0.9, 0.2);
	cairo_fill_preserve (cr);  /* fill with shaded gradient */


	if (usegrads)
		cairo_pattern_destroy(pat);
	cairo_set_source_rgb(cr, colours[color][2][0],
			     colours[color][2][1],
			     colours[color][2][2]);

	cairo_set_line_width (cr, 0.1);
	cairo_stroke (cr);  /* add darker outline */

	drawRoundedRectangle (cr, 0.15, 0.15, 0.7, 0.7, 0.08);
	if (usegrads) {
		pat = cairo_pattern_create_linear (-0.3, -0.3, 0.8, 0.8);
		switch (color) { /* yellow and white blocks need a brighter highlight */
		case 3:
		case 4:
			cairo_pattern_add_color_stop_rgba (pat, 0.0, 1.0,
							   1.0,
							   1.0,
							   1.0);
			cairo_pattern_add_color_stop_rgba (pat, 1.0, 1.0,
							   1.0,
							   1.0,
							   0.0);
			break;
		default:
			cairo_pattern_add_color_stop_rgba (pat, 0.0, 0.9295,
							   0.9295,
							   0.9295,
							   1.0);
			cairo_pattern_add_color_stop_rgba (pat, 1.0, 0.9295,
							   0.9295,
							   0.9295,
							   0.0);
			break;
		}
		cairo_set_source (cr, pat);
	} else {
		cairo_set_source_rgba (cr, 1.0,
				       1.0,
				       1.0,
				       0.35);
	}
	cairo_stroke (cr);  /* add inner edge highlight */

	if (usegrads)
		cairo_pattern_destroy (pat);
}

void TangoBlock::drawRoundedRectangle (cairo_t * cr, gdouble x, gdouble y, gdouble w, gdouble h, gdouble r)
{
	cairo_move_to(cr, x+r, y);
	cairo_line_to(cr, x+w-r, y);
	cairo_curve_to(cr, x+w-(r/2), y, x+w, y+(r/2), x+w, y+r);
	cairo_line_to(cr, x+w, y+h-r);
	cairo_curve_to(cr, x+w, y+h-(r/2), x+w-(r/2), y+h, x+w-r, y+h);
	cairo_line_to(cr, x+r, y+h);
	cairo_curve_to(cr, x+(r/2), y+h, x, y+h-(r/2), x, y+h-r);
	cairo_line_to(cr, x, y+r);
	cairo_curve_to(cr, x, y+(r/2), x+(r/2), y, x+r, y);
}

