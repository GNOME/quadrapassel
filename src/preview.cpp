/* -*- mode:C++; tab-width:8; c-basic-offset:8; indent-tabs-mode:true -*- */

/*
 * written by J. Marcin Gorycki <marcin.gorycki@intel.com>
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

#include "preview.h"

#define PREVIEW_WIDTH 4
#define PREVIEW_HEIGHT 4

Preview::Preview():
	width(0),
	height(0),
	blocknr(-1),
	color(-1),
	themeID(0),
	cell_size(20),
	cache(NULL),
	enabled(true)
{
	blocks = new Block*[PREVIEW_WIDTH];
	for (int i = 0; i < PREVIEW_WIDTH; i++) {
		blocks[i] = new Block [PREVIEW_HEIGHT];
	}

	w = gtk_clutter_embed_new();

	g_signal_connect (w, "size_allocate", G_CALLBACK (resize), this);

	/* FIXME: We should scale with the rest of the UI, but that requires
	 * changes to the widget layout - i.e. wrap the preview in an
	 * fixed-aspect box. */
	gtk_widget_set_size_request (w, 120, 120);
	ClutterActor *stage;
	stage = gtk_clutter_embed_get_stage (GTK_CLUTTER_EMBED (w));

	ClutterColor stage_color = { 0x0, 0x0, 0x0, 0xff };
	clutter_stage_set_color (CLUTTER_STAGE (stage),
				 &stage_color);
	piece = clutter_group_new ();
	clutter_group_add (CLUTTER_GROUP (stage),
			   piece);

	piece_timeline = clutter_timeline_new (180);
	alpha = clutter_alpha_new_full (piece_timeline,
			CLUTTER_EASE_IN_OUT_SINE);
	piece_behav = clutter_behaviour_scale_new (alpha,
			0.6, 0.6, 1.0, 1.0);
	clutter_actor_set_anchor_point (piece, 60, 60);
	clutter_actor_set_position (CLUTTER_ACTOR(piece), 60, 60);
	clutter_behaviour_apply (piece_behav, piece);
}

Preview::~Preview ()
{
	for (int i = 0; i < PREVIEW_WIDTH; i++)
		delete[] blocks[i];

	delete[] blocks;
	g_object_unref (cache);
}

void
Preview::enable(bool en)
{
	enabled = en;
}

void
Preview::setTheme (guint id)
{
	themeID = id;

	if (!cache)
		cache = blocks_cache_new ();
	blocks_cache_set_theme (cache, themeID);
	previewBlock (blocknr, color, TRUE);
}

void
Preview::previewBlock(gint bnr, gint bcol, bool force)
{
	ClutterActor *stage;
	stage = gtk_clutter_embed_get_stage (GTK_CLUTTER_EMBED (w));

	int x, y;
	bool disable = FALSE;

	blocknr = bnr;
	color = bcol;

	if(!force && (!do_preview || bastard_mode))
	{
		disable = TRUE;
	}

	for (x = 0; x < PREVIEW_WIDTH; x++) {
		for (y = 0; y < PREVIEW_HEIGHT; y++) {
			if (!disable && 
			    (blocknr != -1) &&
			    blockTable[blocknr][rot_next][x][y]) {
				blocks[x][y].emptyCell ();
				blocks[x][y].what = LAYING;
				blocks[x][y].createActor (piece,
				                          blocks_cache_get_block_texture_by_id (cache, color),
				                          cell_size, cell_size);
				clutter_actor_set_position (CLUTTER_ACTOR(blocks[x][y].actor),
				                            x*cell_size, y*cell_size);
			} else {
				blocks[x][y].what = EMPTY;
				if (blocks[x][y].actor)
					blocks[x][y].emptyCell ();
			}
		}
	}
	gint center_x, center_y;
	center_x = (sizeTable[blocknr][0][1] * cell_size / 2) + (offsetTable[blocknr][0][1] * cell_size);
	center_y = (sizeTable[blocknr][0][0] * cell_size / 2) + (offsetTable[blocknr][0][0] * cell_size);
	clutter_actor_set_anchor_point (piece, center_x, center_y);
	clutter_actor_set_position (CLUTTER_ACTOR(piece), width / 2, height / 2);
	clutter_timeline_start (piece_timeline);
}

gint
Preview::resize(GtkWidget *widget, GtkAllocation *allocation, Preview *p)
{
	p->width = allocation->width;
	p->height = allocation->height;
	p->cell_size = (p->width + p->height) / 2 / 5;

	if (!p->cache)
		p->cache = blocks_cache_new ();
	blocks_cache_set_size (p->cache, p->cell_size);
	p->previewBlock (p->blocknr, p->color, TRUE);
	return FALSE;
}

