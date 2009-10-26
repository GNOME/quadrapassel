/* -*- mode:C++; tab-width:8; c-basic-offset:8; indent-tabs-mode:true -*- */
#ifndef __blocks_h__
#define __blocks_h__

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

#include <clutter/clutter.h>
#include <cogl/cogl.h>

class BlockOps;

#define NCOLOURS 7

enum SlotType {
	EMPTY,
	FALLING,
	LAYING
};

class Block {
public:
	Block ();
	~Block ();

	void emptyCell ();

	Block& moveFrom (Block &b, BlockOps *f);

	SlotType what;
	guint color;
	ClutterActor *actor;

	gfloat x;
	gfloat y;

	void createActor (ClutterActor *chamber, CoglHandle texture_source, gint pxwidth, gint pxheight);
	void bindAnimations (BlockOps *f);

	/* Every block will have a unique position*/
	ClutterBehaviour *move_behaviour;
	ClutterBehaviour *fall_behaviour;
	ClutterBehaviour *explode_move_behaviour;
	ClutterPath *move_path;
};

extern int blockTable[][4][4][4];
extern int tableSize;

extern int sizeTable[][4][2];
extern int sizeTSize;

extern int offsetTable[][4][2];
extern int offsetTSize;

#endif // __blocks_h__
