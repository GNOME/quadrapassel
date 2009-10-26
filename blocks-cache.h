/*
  Copyright © 2008 Neil Roberts
  Copyright © 2008 Christian Persch
  Copyright © 2009 Jason D. Clinton

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef BLOCKS_CACHE_H
#define BLOCKS_CACHE_H

#include <glib-object.h>
#include <cogl/cogl.h>

G_BEGIN_DECLS

#define TYPE_BLOCKS_CACHE            (blocks_cache_get_type())
#define BLOCKS_CACHE(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), TYPE_BLOCKS_CACHE, BlocksCache))
#define BLOCKS_CACHE_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass), TYPE_BLOCKS_CACHE, BlocksCacheClass))
#define IS_BLOCKS_CACHE(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), TYPE_BLOCKS_CACHE))
#define IS_BLOCKS_CACHE_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), TYPE_BLOCKS_CACHE))
#define BLOCKS_CACHE_GET_CLASS(obj)  (G_TYPE_INSTANCE_GET_CLASS ((obj), TYPE_BLOCKS_CACHE, BlocksCacheClass))

typedef struct _BlocksCache        BlocksCache;
typedef struct _BlocksCacheClass   BlocksCacheClass;
typedef struct _BlocksCachePrivate BlocksCachePrivate;

struct _BlocksCacheClass
{
  GObjectClass parent_class;
};

struct _BlocksCache
{
  GObject parent;

  BlocksCachePrivate *priv;
};

GType blocks_cache_get_type (void);

BlocksCache *blocks_cache_new (void);

void blocks_cache_set_theme (BlocksCache *cache,
                             guint theme);

guint blocks_cache_get_theme (BlocksCache *cache);

void blocks_cache_set_size (BlocksCache *cache,
                            guint size);

guint blocks_cache_get_size (BlocksCache *cache);

CoglHandle blocks_cache_get_block_texture_by_id (BlocksCache *cache,
                                                 guint colour);

G_END_DECLS

#endif /* BLOCKS_CACHE_H */
