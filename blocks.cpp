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

#include "blocks.h"
#include "blockops.h"

Block::Block ():
	what(EMPTY),
	actor(NULL),
	x(0),
	y(0),
	move_behaviour(NULL),
	fall_behaviour(NULL),
	explode_move_behaviour(NULL),
	move_path(NULL)
{}

Block::~Block ()
{
	if (actor)
		clutter_actor_destroy (CLUTTER_ACTOR(actor));
	if (move_behaviour)
		g_object_unref (move_behaviour);
	if (fall_behaviour)
		g_object_unref (fall_behaviour);
	if (explode_move_behaviour)
		g_object_unref (explode_move_behaviour);
}

void
Block::emptyCell ()
{
	if (actor) {
		clutter_actor_destroy (CLUTTER_ACTOR(actor));
		actor = NULL;
	}
	if (move_behaviour)
		clutter_behaviour_remove_all (move_behaviour);
	if (fall_behaviour)
		clutter_behaviour_remove_all (fall_behaviour);
	if (explode_move_behaviour)
		clutter_behaviour_remove_all (explode_move_behaviour);
}

void
Block::createActor (ClutterActor *chamber, CoglHandle texture_source, gint pxwidth, gint pxheight)
{
	actor = clutter_texture_new ();
	clutter_texture_set_cogl_texture (CLUTTER_TEXTURE(actor),
	                                  texture_source);
	clutter_group_add (CLUTTER_GROUP (chamber), actor);
	clutter_actor_set_position (CLUTTER_ACTOR(actor), x, y);
}

void
Block::bindAnimations (BlockOps *f)
{
	move_path = clutter_path_new ();
	move_behaviour = clutter_behaviour_path_new (f->move_alpha,
	                                             move_path);
	fall_behaviour = clutter_behaviour_path_new_with_knots (f->fall_alpha,
								NULL, 0);
	explode_move_behaviour = clutter_behaviour_path_new_with_knots (f->explode_alpha,
									NULL, 0);
}

Block&
Block::moveFrom (Block& b, BlockOps *f)
{
	if (this != &b) {
		what = b.what;
		b.what = EMPTY;
		color = b.color;
		b.color = 0;
		if (b.actor) {
			ClutterPath *path = clutter_path_new ();
			clutter_path_add_move_to (path, b.x, b.y);
			clutter_path_add_line_to (path, x, y);
			clutter_behaviour_path_set_path (CLUTTER_BEHAVIOUR_PATH(fall_behaviour),
			                                 CLUTTER_PATH(path));
			clutter_behaviour_apply (fall_behaviour, b.actor);
			f->fall_behaviours = g_list_prepend (f->fall_behaviours, fall_behaviour);
		}
		actor = b.actor;
		b.actor = NULL;
	}
	return *this;
}

int blockTable[][4][4][4] =
{
  {
    {
    	{0, 0, 0, 0},
    	{1, 1, 1, 0},
    	{1, 0, 0, 0},
    	{0, 0, 0, 0},
    },
    {
    	{0, 1, 0, 0},
    	{0, 1, 0, 0},
    	{0, 1, 1, 0},
    	{0, 0, 0, 0},
    },
    {
    	{0, 0, 1, 0},
    	{1, 1, 1, 0},
    	{0, 0, 0, 0},
    	{0, 0, 0, 0},
    },
    {
    	{1, 1, 0, 0},
    	{0, 1, 0, 0},
    	{0, 1, 0, 0},
    	{0, 0, 0, 0},
    },

  },

  {
    {
    	{0, 0, 0, 0},
    	{1, 1, 1, 0},
    	{0, 0, 1, 0},
    	{0, 0, 0, 0},
    },
    {
    	{0, 1, 1, 0},
    	{0, 1, 0, 0},
    	{0, 1, 0, 0},
    	{0, 0, 0, 0},
    },
    {
    	{1, 0, 0, 0},
    	{1, 1, 1, 0},
    	{0, 0, 0, 0},
    	{0, 0, 0, 0},
    },
    {
    	{0, 1, 0, 0},
    	{0, 1, 0, 0},
    	{1, 1, 0, 0},
    	{0, 0, 0, 0},
    },
  },

  {
    {
  	{0, 0, 0, 0},
  	{1, 1, 1, 0},
  	{0, 1, 0, 0},
  	{0, 0, 0, 0},
    },
    {
  	{0, 1, 0, 0},
  	{0, 1, 1, 0},
  	{0, 1, 0, 0},
  	{0, 0, 0, 0},
    },
    {
  	{0, 1, 0, 0},
  	{1, 1, 1, 0},
  	{0, 0, 0, 0},
  	{0, 0, 0, 0},
    },
    {
  	{0, 1, 0, 0},
  	{1, 1, 0, 0},
  	{0, 1, 0, 0},
  	{0, 0, 0, 0},
    },
  },

  {
    {
  	{0, 0, 0, 0},
  	{0, 1, 1, 0},
  	{1, 1, 0, 0},
  	{0, 0, 0, 0},
    },
    {
  	{0, 1, 0, 0},
  	{0, 1, 1, 0},
  	{0, 0, 1, 0},
  	{0, 0, 0, 0},
    },
    {
  	{0, 1, 1, 0},
  	{1, 1, 0, 0},
  	{0, 0, 0, 0},
  	{0, 0, 0, 0},
    },
    {
  	{1, 0, 0, 0},
  	{1, 1, 0, 0},
  	{0, 1, 0, 0},
  	{0, 0, 0, 0},
    },
  },

  {
    {
  	{0, 0, 0, 0},
  	{1, 1, 0, 0},
  	{0, 1, 1, 0},
  	{0, 0, 0, 0},
    },
    {
  	{0, 0, 1, 0},
  	{0, 1, 1, 0},
  	{0, 1, 0, 0},
  	{0, 0, 0, 0},
    },
    {
  	{1, 1, 0, 0},
  	{0, 1, 1, 0},
  	{0, 0, 0, 0},
  	{0, 0, 0, 0},
    },
    {
  	{0, 1, 0, 0},
  	{1, 1, 0, 0},
  	{1, 0, 0, 0},
  	{0, 0, 0, 0},
    },
  },

  {
    {
 	{0, 0, 0, 0},
  	{1, 1, 1, 1},
  	{0, 0, 0, 0},
  	{0, 0, 0, 0},
    },
    {
  	{0, 1, 0, 0},
  	{0, 1, 0, 0},
  	{0, 1, 0, 0},
  	{0, 1, 0, 0},
    },
    {
   	{0, 0, 0, 0},
  	{1, 1, 1, 1},
  	{0, 0, 0, 0},
  	{0, 0, 0, 0},
    },
    {
  	{0, 1, 0, 0},
  	{0, 1, 0, 0},
  	{0, 1, 0, 0},
  	{0, 1, 0, 0},
    },
  },

  {
    {
  	{0, 0, 0, 0},
  	{0, 1, 1, 0},
  	{0, 1, 1, 0},
  	{0, 0, 0, 0},
    },
    {
  	{0, 0, 0, 0},
  	{0, 1, 1, 0},
  	{0, 1, 1, 0},
  	{0, 0, 0, 0},
    },
    {
  	{0, 0, 0, 0},
  	{0, 1, 1, 0},
  	{0, 1, 1, 0},
  	{0, 0, 0, 0},
    },
    {
  	{0, 0, 0, 0},
  	{0, 1, 1, 0},
  	{0, 1, 1, 0},
  	{0, 0, 0, 0},
    },
  }
};

int tableSize = sizeof(blockTable)/sizeof(blockTable[0]);

int sizeTable[][4][2] =
{
	{
		{3, 2},
		{2, 3},
		{3, 2},
		{2, 3},
	},
	{
		{3, 2},
		{2, 3},
		{3, 2},
		{2, 3},
	},
	{
		{3, 2},
		{2, 3},
		{3, 2},
		{2, 3},
	},
	{
		{3, 2},
		{2, 3},
		{3, 2},
		{2, 3},
	},
	{
		{3, 2},
		{2, 3},
		{3, 2},
		{2, 3},
	},
	{
		{4, 1},
		{1, 4},
		{4, 1},
		{1, 4},
	},
	{
		{2, 2},
		{2, 2},
		{2, 2},
		{2, 2},
	},
};

int sizeTSize = sizeof(sizeTable)/sizeof(sizeTable[0]);

int offsetTable[][4][2] =
{
	{
		{0, 1},
		{1, 0},
		{0, 0},
		{0, 0},

	},
	{
		{0, 1},
		{1, 0},
		{0, 0},
		{0, 0},
	},
	{
		{0, 1},
		{1, 0},
		{0, 0},
		{0, 0},
	},
	{
		{0, 1},
		{1, 0},
		{0, 0},
		{0, 0},
	},
	{
		{0, 1},
		{1, 0},
		{0, 0},
		{0, 0},
	},
	{
		{0, 1},
		{1, 0},
		{0, 2},
		{2, 0},
	},
	{
		{1, 1},
		{1, 1},
		{1, 1},
		{1, 1},
	},
};

int offsetTSize = sizeof(offsetTable)/sizeof(offsetTable[0]);
