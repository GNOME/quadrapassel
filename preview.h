/* -*- mode:C++; tab-width:8; c-basic-offset:8; indent-tabs-mode:true -*- */
#ifndef __preview_h__
#define __preview_h__

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

#include "tetris.h"
#include "blocks.h"
#include "blocks-cache.h"
#include <clutter-gtk/clutter-gtk.h>

class Preview {
public:
	Preview ();
	~Preview ();

	GtkWidget *getWidget () {
		return w;
	}

	void enable (bool enable);
	void setTheme (guint id);
	void previewBlock (int bnr, int bcolor, bool force);

private:
	GtkWidget *w;
	gint width;
	gint height;
	gint blocknr;
	gint color;
	gint themeID;
	guint cell_size;

	ClutterTimeline *piece_timeline;
	ClutterAlpha *alpha;
	ClutterBehaviour *piece_behav;

	Block **blocks;
	ClutterActor* piece;
	BlocksCache *cache;

	bool enabled;

	static gboolean resize(GtkWidget *widget, GtkAllocation *event,
			       Preview *preview);
};

#endif //__preview_h__
