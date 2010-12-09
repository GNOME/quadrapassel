/* -*- mode:C++; tab-width:8; c-basic-offset:8; indent-tabs-mode:true -*- */
/*
 * written by J. Marcin Gorycki <marcin.gorycki@intel.com>
 * massively altered for Clutter by Jason D. Clinton <me@jasonclinton.com>
 * "bastard" mode by Lubomir Rintel <lkundrak@v3.sk>
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

#include "blockops.h"
#include <cairo/cairo.h>
#include <clutter-gtk/clutter-gtk.h>
#include "tetris.h"

#define FONT "Sans"

gboolean
BlockOps::move_end (ClutterTimeline *time, BlockOps *f)
{
	return FALSE;
}

gboolean
BlockOps::explode_end (ClutterTimeline *time, BlockOps *f)
{
	Block *block = NULL;
	g_list_foreach (f->destroy_actors,
			(GFunc)clutter_actor_destroy,
			block);
	g_list_free (f->destroy_actors);
	f->destroy_actors = NULL;
	return FALSE;
}

gboolean
BlockOps::fall_end (ClutterTimeline *tml, BlockOps *f)
{
	Block *behave = NULL;
	g_list_foreach (f->fall_behaviours,
			(GFunc)clutter_behaviour_remove_all,
			behave);
	g_list_free (f->fall_behaviours);
	f->fall_behaviours = NULL;

	//After fall, start the earthquake effect
	ClutterPath *path_line = clutter_path_new ();
	clutter_path_add_move_to (path_line,
				  f->center_anchor_x,
				  f->center_anchor_y + f->cell_height * f->quake_ratio);
	clutter_path_add_line_to (path_line, f->center_anchor_x, f->center_anchor_y);
	clutter_behaviour_remove_all (f->quake_behaviour);
	clutter_behaviour_path_set_path (CLUTTER_BEHAVIOUR_PATH(f->quake_behaviour), path_line);
	clutter_behaviour_apply (f->quake_behaviour, f->playingField);
	clutter_timeline_start (f->quake_time);
	return FALSE;
}

BlockOps::BlockOps() :
	destroy_actors(NULL),
	fall_behaviours(NULL),
	quake_ratio(0.0),
	background(NULL),
	foreground(NULL),
	width(0),
	height(0),
	cell_width(0),
	cell_height(0),
	cache(NULL),
	themeID(0),
	blocknr(0),
	rot(0),
	color(0),
	animate(true),
	backgroundImage(NULL),
	center_anchor_x(0),
	center_anchor_y(0),
	FALL_TIMING(360),
	QUAKE_TIMING(720)
{
	w = gtk_clutter_embed_new ();

	g_signal_connect (w, "size_allocate", G_CALLBACK (resize), this);

	gtk_widget_set_size_request (w, COLUMNS*190/LINES, 190);

	ClutterActor *stage;
	stage = gtk_clutter_embed_get_stage (GTK_CLUTTER_EMBED (w));

	playingField = clutter_group_new ();
	clutter_stage_add (stage, playingField);
	
	move_time = clutter_timeline_new (60);
	g_signal_connect (move_time, "completed", G_CALLBACK
			  (BlockOps::move_end), this);
	move_alpha = clutter_alpha_new_full (move_time,
					     CLUTTER_EASE_IN_QUAD);

	fall_time = clutter_timeline_new (FALL_TIMING);
	g_signal_connect (fall_time, "completed", G_CALLBACK
			  (BlockOps::fall_end), this);
	fall_alpha = clutter_alpha_new_full (fall_time,
					     CLUTTER_EASE_IN_QUAD);

	explode_time = clutter_timeline_new (720);
	g_signal_connect (explode_time, "completed", G_CALLBACK
			  (BlockOps::explode_end), this);
	explode_alpha = clutter_alpha_new_full (explode_time,
						CLUTTER_EASE_OUT_QUINT);
	explode_fade_behaviour = clutter_behaviour_opacity_new (explode_alpha,
								255, 0);
	explode_scale_behaviour = clutter_behaviour_scale_new (explode_alpha,
								1.0, 1.0,
								2.0, 2.0);

	quake_time = clutter_timeline_new (QUAKE_TIMING);
	quake_alpha = clutter_alpha_new_full (quake_time,
					      CLUTTER_EASE_OUT_BOUNCE);
	quake_behaviour = clutter_behaviour_path_new_with_knots (quake_alpha,
								 NULL, 0);

	field = new Block*[COLUMNS];
	backfield = new Block*[COLUMNS];
	for (int i = 0; i < COLUMNS; ++i) {
		field[i] = new Block[LINES];
		backfield[i] = new Block[LINES];
		for (int j = 0; j < LINES; ++j) {
			field[i][j].bindAnimations (this);
		}
	}
}

BlockOps::~BlockOps()
{
	for (int i = 0; i < COLUMNS; ++i)
		delete[] field[i];

	delete[] field;
	
	g_object_unref (move_time);
	g_object_unref (fall_time);
	g_object_unref (explode_time);
	g_object_unref (explode_fade_behaviour);
	g_object_unref (explode_scale_behaviour);
	g_object_unref (quake_time);
	g_object_unref (quake_behaviour);
}

bool
BlockOps::blockOkHere(int x, int y, int b, int r)
{
	x -= 2;

	for (int x1 = 0; x1 < 4; ++x1)
	{
		for (int y1 = 0; y1 < 4; ++y1)
		{
			if (blockTable[b][r][x1][y1] && (x1 + x < 0))
				return false;
			if (blockTable[b][r][x1][y1] && (x1 + x >= COLUMNS))
				return false;
			if (blockTable[b][r][x1][y1] && (y1 + y >= LINES))
				return false;
			if (blockTable[b][r][x1][y1] && field[x + x1][y1 + y].what == LAYING)
				return false;
		}
	}

	return true;
}

int
BlockOps::getLinesToBottom()
{
	int lines = LINES;

	for (int x = 0; x < 4; ++x)
	{
		for (int y = 3; y >= 0; --y)
		{
			if (!blockTable[blocknr][rot][x][y])
				continue;
			int yy = posy + y;
			for (; yy < LINES; ++yy)
			{
				if (field[posx + x - 2][yy].what == LAYING)
					break;
			}
			int tmp = yy - posy - y;
			if (lines > tmp)
				lines = tmp;
		}
	}

	return lines;
}

bool
BlockOps::moveBlockLeft()
{
	bool moved = false;

	if (blockOkHere(posx - 1, posy, blocknr, rot))
	{
		--posx;
		moveBlockInField(-1, 0);
		moved = true;
	}

	return moved;
}

bool
BlockOps::moveBlockRight()
{
	bool moved = false;

	if (blockOkHere(posx + 1, posy, blocknr, rot))
	{
		++posx;
		moveBlockInField(1, 0);
		moved = true;
	}

	return moved;
}

bool
BlockOps::rotateBlock(bool rotateCCW)
{
	bool moved = false;

	int r = rot;

	if ( rotateCCW )
	{
		if (--r < 0) r = 3;
	}
	else
	{
		if (++r >= 4) r = 0;
	}

	if (blockOkHere(posx, posy, blocknr, r))
	{
		putBlockInField(EMPTY);
		rot = r;
		putBlockInField(FALLING);
		moved = true;
	}

	return moved;
}

bool
BlockOps::moveBlockDown()
{
	bool fallen = false;

	if (!blockOkHere(posx, posy + 1, blocknr, rot))
		fallen = true;

	if (!fallen)
	{
		++posy;
		moveBlockInField(0, 1);
	}

	return fallen;
}

int
BlockOps::dropBlock()
{
	int count = 0;

	while (!moveBlockDown())
		count++;

	return count;
}

void
BlockOps::fallingToLaying()
{
	for (int x = 0; x < COLUMNS; ++x) {
		for (int y = 0; y < LINES; ++y) {
			Block *cell = &field[x][y];
			if (cell->what == FALLING) {
				cell->what = LAYING;
				if (!animate)
					continue;
				clutter_actor_set_position (cell->actor,
							    cell->x, cell->y);
				clutter_behaviour_remove_all (cell->move_behaviour);
			}
		}
	}
}

void
BlockOps::eliminateLine(int l)
{
	for (int x = 0; x < COLUMNS; ++x)
	{
		Block *cell = &field[x][l];
		if (cell->actor) {
			gfloat cur_x, cur_y = 0;
			g_object_get (G_OBJECT (cell->actor), "x", &cur_x, "y", &cur_y, NULL);
			clutter_actor_raise_top (cell->actor);
			ClutterPath *path_line = clutter_path_new ();
			clutter_path_add_move_to (path_line, cur_x, cur_y);
			clutter_path_add_line_to (path_line,
			                          cur_x + g_random_int_range (-60 - cell_width / 4, 60),
			                          cur_y + g_random_int_range (-60 - cell_height / 4, 60));
			clutter_behaviour_path_set_path (CLUTTER_BEHAVIOUR_PATH(cell->explode_move_behaviour),
			                                 CLUTTER_PATH(path_line));
			clutter_behaviour_apply (CLUTTER_BEHAVIOUR(cell->explode_move_behaviour), cell->actor);
			clutter_behaviour_apply (CLUTTER_BEHAVIOUR(explode_fade_behaviour), cell->actor);
			clutter_behaviour_apply (CLUTTER_BEHAVIOUR(explode_scale_behaviour), cell->actor);
			destroy_actors = g_list_prepend (destroy_actors, cell->actor);
			cell->actor = NULL;
		}
	}
}

bool
BlockOps::checkFullLine(int l)
{
	bool f = true;
	for (int x = 0; x < COLUMNS; ++x)
	{
		if (field[x][l].what != LAYING)
		{
			f = false;
			break;
		}
	}

	return f;
}

int
BlockOps::checkFullLines()
{
	// we can have at most 4 full lines (vertical block)
	int num_full_lines = 0;
	clutter_behaviour_remove_all (explode_fade_behaviour);
	clutter_behaviour_remove_all (explode_scale_behaviour);

	for (int y = MIN (posy + 4, LINES - 1); y >= 0; --y)
	{
		if (checkFullLine (y))
		{
			++num_full_lines;
			eliminateLine(y);
		}
		else if (num_full_lines > 0)
		{
			for (int x = 0; x < COLUMNS; ++x)
			{
				field[x][y + num_full_lines].moveFrom (field[x][y], this);
			}
		}
	}

	if (num_full_lines > 0)
	{
		clutter_timeline_set_duration (fall_time, FALL_TIMING / (5 - num_full_lines));
		clutter_timeline_set_duration (quake_time, QUAKE_TIMING / (5 - num_full_lines));
		clutter_timeline_start (fall_time);
		clutter_timeline_start (explode_time);
		quake_ratio = ((float) num_full_lines) / 4.0;
	}

	return num_full_lines;
}

void
BlockOps::saveField ()
{
	for (int y = 0; y < LINES; y++)
		for (int x = 0; x < COLUMNS; x++)
			backfield[x][y] = field[x][y];
}

void
BlockOps::restoreField ()
{
	for (int y = 0; y < LINES; y++)
		for (int x = 0; x < COLUMNS; x++)
			field[x][y] = backfield[x][y];
}

/*
 * An implementation of "Bastard" algorithm 
 * it comes from Federico Poloni's "bastet"
 */

void
BlockOps::bastardPick ()
{
	int scores[tableSize];
	int blocks[tableSize];
	int chance[tableSize];

	animate = false;
	/* This generates a priority for each block */
	saveField ();
	for (blocknr = 0; blocknr < tableSize; blocknr++)
	{
		scores[blocknr] = -32000;
		for (rot = 0; rot < 4; rot++)
		{
			for (posx = 0; posx < COLUMNS; posx++)
			{
				int this_score = 0;
				int x, y;

				if (!blockOkHere(posx, posy = 0, blocknr, rot))
					continue;

				dropBlock();
				fallingToLaying();

				/* Count the completed lines */
				for (y = MIN (posy + 4, LINES); y > 0; --y) {
					if (checkFullLine(y)) {
						this_score += 5000;
					}
				}

				/* Count heights of columns */
				for (x = 0; x < COLUMNS; x++)
				{
					for (y = 0; y < LINES; y++)
						if (field[x][y].what == LAYING)
							break;
					this_score -= 5 * (LINES - y);
				}

				restoreField ();
				if (scores[blocknr] < this_score)
					scores[blocknr] = this_score;
			}
		}
	}

	for (int i = 0; i < tableSize; i++) {
		/* Initialize chances table */
		chance[i] = 100;
		/* Initialize block/priority table */
		blocks[i] = i;
		/* Perturb score (-2 to +2), to avoid stupid tie handling */
		scores[i] += g_random_int_range(-2, 2);
	}

	/* Sorts blocks by priorities, worst (interesting to us) first*/
	for (int i = 0; i < tableSize; i++)
	{
		for (int ii = 0; ii < tableSize - 1; ii++)
		{
			if (scores[blocks[ii]] > scores[blocks[ii+1]])
			{
				int t = blocks[ii];
				blocks[ii] = blocks[ii+1];
				blocks[ii+1] = t;
			}
		}
	}

	/* Lower the chances we're giving the worst one */
	chance[0] = 75;
	chance[1] = 92;
	chance[2] = 98;

	/* Actually choose a piece */
	int rnd = g_random_int_range(0, 99);
	for (int i = 0; i < tableSize; i++)
	{
		blocknr = blocks[i];
		if (rnd < chance[i])
			break;
	}

	/* This will almost certainly not given next */
	blocknr_next = blocks[tableSize-1];
	animate = true;
}

bool
BlockOps::generateFallingBlock()
{
	if (bastard_mode)
	{
		bastardPick();
		color_next = -1;
	}
	else
	{
		blocknr = blocknr_next == -1 ? g_random_int_range(0, tableSize) :
			blocknr_next;
		blocknr_next = g_random_int_range(0, tableSize);
	}

	posx = COLUMNS / 2 + 1;
	posy = 0;

	rot = rot_next == -1 ? g_random_int_range(0, 4) : rot_next;
	int cn = random_block_colors ? g_random_int_range(0, NCOLOURS) :
		blocknr % NCOLOURS;
	color = color_next == -1 ? cn : color_next;

	rot_next = g_random_int_range(0, 4);
	color_next = random_block_colors ? g_random_int_range(0, NCOLOURS) :
		blocknr_next % NCOLOURS;

	if (!blockOkHere(posx, posy, blocknr, rot))
		return false;

	return true;
}

void
BlockOps::emptyField(int filled_lines, int fill_prob)
{
	int blank;

	for (int y = 0; y < LINES; ++y)
	{
		// Allow for at least one blank per line
		blank = g_random_int_range(0, COLUMNS);

		for (int x = 0; x < COLUMNS; ++x)
		{
			Block *cell = &field[x][y];
			cell->what = EMPTY;
			cell->emptyCell ();

			if ((y>=(LINES - filled_lines)) && (x != blank) &&
			    ((g_random_int_range(0, 10)) < fill_prob)) {
				guint tmpColor = g_random_int_range(0, NCOLOURS);
				cell->what = LAYING;
				cell->color = tmpColor;
				cell->createActor (playingField,
				                   blocks_cache_get_block_texture_by_id (cache, tmpColor),
				                   cell_width, cell_height);
				g_object_set (G_OBJECT(cell->actor), "sync-size", true, NULL);
				clutter_actor_set_position (CLUTTER_ACTOR(cell->actor),
				                            x*(cell_width), y*(cell_height));
			}
		}
	}
}

void
BlockOps::emptyField(void)
{
	emptyField(0,5);
}

void
BlockOps::putBlockInField (SlotType fill)
{
	for (int x = 0; x < 4; ++x) {
		for (int y = 0; y < 4; ++y) {
			if (blockTable[blocknr][rot][x][y]) {
				int i = posx - 2 + x;
				int j = y + posy;

				Block *cell = &field[i][j];
				cell->what = fill;
				if (fill == FALLING) {
					cell->color = color;
					cell->createActor (playingField,
					                   blocks_cache_get_block_texture_by_id (cache, color),
					                   cell_width, cell_height);
				} else {
					cell->color = color;
					cell->emptyCell ();
				}
			}
		}
	}
}

void
BlockOps::moveBlockInField (gint x_trans, gint y_trans)
{
	ClutterActor *temp_actors[4][4] = {{0, }};

	for (int x = 0; x < 4; ++x) {
		for (int y = 0; y < 4; ++y) {
			if (blockTable[blocknr][rot][x][y]) {
				int i = posx - 2 + x;
				int j = y + posy;
				Block *source_cell = &field[i-x_trans][j-y_trans];

				temp_actors[x][y] = source_cell->actor;
				source_cell->what = EMPTY;
				source_cell->actor = NULL;
				if (animate && source_cell->move_behaviour)
					clutter_behaviour_remove_all (CLUTTER_BEHAVIOUR(source_cell->move_behaviour));
			}
		}
	}
	for (int x = 0; x < 4; ++x) {
		for (int y = 0; y < 4; ++y) {
			if (blockTable[blocknr][rot][x][y]) {
				gint i = posx - 2 + x;
				gint j = y + posy;
				Block *cell = &field[i][j];

				cell->what = FALLING;
				cell->color = color;
				cell->actor = temp_actors[x][y];
				if (animate) {
					gfloat cur_x, cur_y = 0.0;
					g_object_get (G_OBJECT (cell->actor), "x", &cur_x, "y", &cur_y, NULL);
					clutter_path_clear (CLUTTER_PATH(cell->move_path));
					clutter_path_add_move_to (cell->move_path, cur_x, cur_y);
					clutter_path_add_line_to (cell->move_path, cell->x, cell->y);
					clutter_behaviour_remove_all (CLUTTER_BEHAVIOUR(cell->move_behaviour));
					clutter_behaviour_apply (cell->move_behaviour, cell->actor);
				}
			}
		}
	}
	if (animate)
		clutter_timeline_start (move_time);
}

bool
BlockOps::isFieldEmpty (void)
{
	for (int x = 0; x < COLUMNS; x++) {
		if (field[x][LINES-1].what != EMPTY)
			return false;
	}

	return true;
}

gboolean
BlockOps::resize(GtkWidget *widget, GtkAllocation *allocation, BlockOps *field)
{
	field->width = allocation->width;
	field->height = allocation->height;

	if (field->width == 0 || field->height == 0)
		return FALSE;
	field->cell_width = field->width/COLUMNS;
	field->cell_height = field->height/LINES;
	field->rescaleField ();
	return FALSE;
}

void
BlockOps::rescaleBlockPos ()
{
	for (int y = 0; y < LINES; ++y) {
		for (int x = 0; x < COLUMNS; ++x) {
			Block *cell = &field[x][y];
			if (cell->actor) {
				clutter_actor_set_position (CLUTTER_ACTOR(cell->actor),
							    x*(cell_width), y*(cell_height));
				clutter_texture_set_cogl_texture (CLUTTER_TEXTURE(cell->actor),
				                                  blocks_cache_get_block_texture_by_id (cache, cell->color));
			}
			cell->x = x*(cell_width);
			cell->y = y*(cell_height);
		}
	}
}

void
BlockOps::rescaleField ()
{
	ClutterActor *stage;
	stage = gtk_clutter_embed_get_stage (GTK_CLUTTER_EMBED (w));

	cairo_t *bg_cr;

	if (!cache)
		cache = blocks_cache_new ();
	blocks_cache_set_theme (cache, themeID);
	blocks_cache_set_size (cache, cell_width);

	if (background) {
		clutter_actor_set_size (CLUTTER_ACTOR(background), width, height);
		clutter_cairo_texture_set_surface_size (CLUTTER_CAIRO_TEXTURE(background),
							width, height);
	} else {
		background = clutter_cairo_texture_new (width, height);
		/*FIXME jclinton: eventually allow solid color background
		 * for software rendering case */
		ClutterColor stage_color = { 0x61, 0x64, 0x8c, 0xff };
		clutter_stage_set_color (CLUTTER_STAGE (stage),
					 &stage_color);
		clutter_stage_add (stage,
				   background);
		clutter_actor_set_position (CLUTTER_ACTOR (background), 0, 0);
	}

	rescaleBlockPos ();

	if (foreground) {
		clutter_actor_set_size (CLUTTER_ACTOR(foreground),
					width, height);
		clutter_cairo_texture_set_surface_size (CLUTTER_CAIRO_TEXTURE(foreground),
							width, height);
	} else {
		foreground = clutter_cairo_texture_new (width, height);
		clutter_stage_add (stage,
				   foreground);
		clutter_actor_set_position (CLUTTER_ACTOR (foreground), 0, 0);
	}

	bg_cr = clutter_cairo_texture_create (CLUTTER_CAIRO_TEXTURE(background));
	cairo_set_operator (bg_cr, CAIRO_OPERATOR_CLEAR);
	cairo_paint(bg_cr);
	cairo_set_operator (bg_cr, CAIRO_OPERATOR_OVER);

	if (useBGImage && backgroundImage) {
		gdouble xscale, yscale;
		cairo_matrix_t m;

		/* FIXME: This doesn't handle tiled backgrounds in the obvious way. */
		gdk_cairo_set_source_pixbuf (bg_cr, backgroundImage, 0, 0);
		xscale = 1.0*gdk_pixbuf_get_width (backgroundImage)/width;
		yscale = 1.0*gdk_pixbuf_get_height (backgroundImage)/height;
		cairo_matrix_init_scale (&m, xscale, yscale);
		cairo_pattern_set_matrix (cairo_get_source (bg_cr), &m);
	} else if (backgroundColor)
		gdk_cairo_set_source_color (bg_cr, backgroundColor);
	else
		cairo_set_source_rgb (bg_cr, 0., 0., 0.);

	cairo_paint (bg_cr);
	cairo_destroy (bg_cr);
	drawMessage ();

	clutter_actor_set_position (CLUTTER_ACTOR(background), 0, 0);
	clutter_actor_lower_bottom (CLUTTER_ACTOR(background));
	clutter_actor_set_position (CLUTTER_ACTOR(foreground), 0, 0);
	clutter_actor_raise_top (CLUTTER_ACTOR(foreground));
	center_anchor_x = (width - (cell_width * COLUMNS)) / 2;
	center_anchor_y = (height - (cell_height * LINES)) / 2;
	clutter_actor_set_position (CLUTTER_ACTOR (playingField),
			center_anchor_x, center_anchor_y);
	clutter_actor_raise (CLUTTER_ACTOR (playingField),
			CLUTTER_ACTOR(background));
}

void
BlockOps::drawMessage()
{
	PangoLayout *dummy_layout;
	PangoLayout *layout;
	PangoFontDescription *desc;
	int lw, lh;
	cairo_t *cr;
	char *msg;

	cr = clutter_cairo_texture_create (CLUTTER_CAIRO_TEXTURE(foreground));
	cairo_set_operator (cr, CAIRO_OPERATOR_CLEAR);
	cairo_paint(cr);
	cairo_set_operator (cr, CAIRO_OPERATOR_OVER);

	if (showPause)
		msg =  _("Paused");
	else if (showGameOver)
		msg = _("Game Over");
	else {
		cairo_destroy (cr);
		return;
	}

	// Center coordinates
	cairo_translate (cr, width / 2, height / 2);

	desc = pango_font_description_from_string(FONT);

	layout = pango_cairo_create_layout (cr);
	pango_layout_set_text (layout, msg, -1);

	dummy_layout = pango_layout_copy (layout);
	pango_layout_set_font_description (dummy_layout, desc);
	pango_layout_get_size (dummy_layout, &lw, &lh);
	g_object_unref (dummy_layout);

	// desired height : lh = widget width * 0.9 : lw
	pango_font_description_set_absolute_size (desc, ((float) lh / lw) * PANGO_SCALE * width * 0.7);
	pango_layout_set_font_description (layout, desc);
	pango_font_description_free (desc);

	pango_layout_get_size (layout, &lw, &lh);
	cairo_move_to (cr, -((double)lw / PANGO_SCALE) / 2, -((double)lh / PANGO_SCALE) / 2);
	pango_cairo_layout_path (cr, layout);
	cairo_set_source_rgb (cr, 0.333333333333, 0.341176470588, 0.32549019607);

	/* A linewidth of 2 pixels at the default size. */
	cairo_set_line_width (cr, width/100.0);
	cairo_stroke_preserve (cr);

	cairo_set_source_rgb (cr, 1.0, 1.0, 1.0);
	cairo_fill (cr);

	g_object_unref(layout);
	cairo_destroy (cr);
}

void
BlockOps::setBackground(GdkPixbuf *bgImage)//, bool tiled)
{
	backgroundImage = (GdkPixbuf *) g_object_ref(bgImage);
	useBGImage = true;
//	backgroundImageTiled = tiled;
}

void
BlockOps::setBackground(GdkColor *bgColor)
{
	backgroundColor = gdk_color_copy(bgColor);
	if (backgroundImage) {
		g_object_unref (backgroundImage);
		backgroundImage = NULL;
	}
	useBGImage = false;
}

void
BlockOps::showPauseMessage()
{
	showPause = true;

	drawMessage ();
}

void
BlockOps::hidePauseMessage()
{
	showPause = false;

	drawMessage ();
}

void
BlockOps::showGameOverMessage()
{
	showGameOver = true;

	drawMessage ();
}

void
BlockOps::hideGameOverMessage()
{
	showGameOver = false;

	drawMessage ();
}

void
BlockOps::setTheme (guint id)
{
	// don't waste time if theme is the same (like from initOptions)
	if (themeID == id)
		return;

	themeID = id;
	if (cache) {
		blocks_cache_set_theme (cache, themeID);
	} else {
		cache = blocks_cache_new ();
		blocks_cache_set_theme (cache, themeID);
	}
	rescaleBlockPos();
}
