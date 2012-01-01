/* -*- mode:C++; tab-width:8; c-basic-offset:8; indent-tabs-mode:true -*- */
/* sound.cpp - play sounds.
 *
 * Copyright 2005 (c) Callum McKenzie
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

#include <gdk/gdk.h>
#include <canberra-gtk.h>

#include "sound.h"

static gboolean enabled = TRUE;

void
sound_enable (gboolean enable)
{
	enabled = enable;
}

gboolean
sound_is_enabled (void)
{
	return enabled;
}

void
sound_play (const gchar *name)
{
	gchar *filename, *path;

	if (!enabled)
		return;

	filename = g_strdup_printf ("%s.ogg", name);
	path = g_build_filename (SOUND_DIRECTORY, filename, NULL);
	g_free (filename);

	ca_context_play (ca_gtk_context_get_for_screen (gdk_screen_get_default ()),
	                 0,
	                 CA_PROP_MEDIA_NAME, name,
	                 CA_PROP_MEDIA_FILENAME, path, NULL);
	g_free (path);
}
