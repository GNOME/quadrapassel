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

#include <config.h>

#include <glib-object.h>
#include <cairo.h>
#include <cogl/cogl.h>

#include "blocks.h"
#include "renderer.h"
#include "blocks-cache.h"

#include <libgames-support/games-debug.h>

struct _BlocksCachePrivate
{
  guint theme;
  guint size;

  CoglHandle *colours;

#ifdef GNOME_ENABLE_DEBUG
  guint n_calls;
  guint cache_hits;
#endif
};

enum
{
  PROP_0,
  PROP_THEME,
  PROP_SIZE
};

/* This is an invalid value for a CoglHandle, and distinct from COGL_INVALID_HANDLE */
#define FAILED_HANDLE ((gpointer) 0x1)
#define IS_FAILED_HANDLE(ptr) (G_UNLIKELY ((ptr) == FAILED_HANDLE))

/* Logging */
#ifdef GNOME_ENABLE_DEBUG
#define LOG_CALL(obj) obj->priv->n_calls++
#define LOG_CACHE_HIT(obj) obj->priv->cache_hits++
#define LOG_CACHE_MISS(obj)
#else
#define LOG_CALL(obj)
#define LOG_CACHE_HIT(obj)
#define LOG_CACHE_MISS(obj)
#endif /* GNOME_ENABLE_DEBUG */

#if G_BYTE_ORDER == G_LITTLE_ENDIAN
#define CLUTTER_CAIRO_TEXTURE_PIXEL_FORMAT COGL_PIXEL_FORMAT_BGRA_8888_PRE
#else
#define CLUTTER_CAIRO_TEXTURE_PIXEL_FORMAT COGL_PIXEL_FORMAT_ARGB_8888_PRE
#endif

static void blocks_cache_dispose (GObject *object);
static void blocks_cache_finalize (GObject *object);

G_DEFINE_TYPE (BlocksCache, blocks_cache, G_TYPE_OBJECT);

#define BLOCKS_CACHE_GET_PRIVATE(obj) (G_TYPE_INSTANCE_GET_PRIVATE ((obj), TYPE_BLOCKS_CACHE, BlocksCachePrivate))

/* Helper functions */

static void
blocks_cache_clear (BlocksCache *cache)
{
  BlocksCachePrivate *priv = cache->priv;
  int i;

  _games_debug_print (GAMES_DEBUG_BLOCKS_CACHE,
                      "blocks_cache_clear\n");

  for (i = 0; i < NCOLOURS; i++) {
    CoglHandle handle = priv->colours[i];

    if (handle != COGL_INVALID_HANDLE &&
        !IS_FAILED_HANDLE (handle)) {
#if CLUTTER_CHECK_VERSION(1, 2, 0)
      cogl_handle_unref (handle);
#else
      cogl_texture_unref (handle);
#endif
    }

    priv->colours[i] = COGL_INVALID_HANDLE;
  }
}

static void
blocks_cache_unset_theme (BlocksCache *cache)
{
  BlocksCachePrivate *priv = cache->priv;

  priv->theme = NULL;
}

/* Class implementation */

static void
blocks_cache_init (BlocksCache *self)
{
  BlocksCachePrivate *priv;

  priv = self->priv = BLOCKS_CACHE_GET_PRIVATE (self);

  priv->colours = static_cast<void**>(g_malloc0 (sizeof (CoglHandle) * NCOLOURS));
}

static void
blocks_cache_dispose (GObject *object)
{
  BlocksCache *cache = BLOCKS_CACHE (object);

  blocks_cache_clear (cache);
  blocks_cache_unset_theme (cache);

  G_OBJECT_CLASS (blocks_cache_parent_class)->dispose (object);
}

static void
blocks_cache_finalize (GObject *object)
{
  BlocksCache *cache = BLOCKS_CACHE (object);
  BlocksCachePrivate *priv = cache->priv;

  g_free (priv->colours);

#ifdef GNOME_ENABLE_DEBUG
  _GAMES_DEBUG_IF (GAMES_DEBUG_BLOCKS_CACHE) {
    _games_debug_print (GAMES_DEBUG_BLOCKS_CACHE,
                        "BlocksCache %p statistics: %u calls with %u hits and %u misses for a hit/total of %.3f\n",
                        cache, priv->n_calls, priv->cache_hits, priv->n_calls - priv->cache_hits,
                        priv->n_calls > 0 ? (double) priv->cache_hits / (double) priv->n_calls : 0.0);
  }
#endif

  G_OBJECT_CLASS (blocks_cache_parent_class)->finalize (object);
}

static void
blocks_cache_set_property (GObject *self,
                           guint property_id,
                           const GValue *value,
                           GParamSpec *pspec)
{
  BlocksCache *cache = BLOCKS_CACHE (self);

  switch (property_id) {
    case PROP_THEME:
      blocks_cache_set_theme (cache, g_value_get_uint (value));
      break;

    case PROP_SIZE:
      blocks_cache_set_size (cache, g_value_get_uint (value));
      break;

    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (self, property_id, pspec);
      break;
    }
}

static void
blocks_cache_get_property (GObject *self,
                           guint property_id,
                           GValue *value,
                           GParamSpec *pspec)
{
  BlocksCache *cache = BLOCKS_CACHE (self);

  switch (property_id) {
    case PROP_THEME:
      g_value_set_object (value, GUINT_TO_POINTER(blocks_cache_get_theme (cache)));
      break;

    case PROP_SIZE:
      g_value_set_object (value, GUINT_TO_POINTER(blocks_cache_get_size (cache)));
      break;

    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (self, property_id, pspec);
      break;
    }
}

static void
blocks_cache_class_init (BlocksCacheClass *klass)
{
  GObjectClass *gobject_class = G_OBJECT_CLASS (klass);
  GParamSpec *pspec;

  gobject_class->dispose = blocks_cache_dispose;
  gobject_class->finalize = blocks_cache_finalize;
  gobject_class->set_property = blocks_cache_set_property;
  gobject_class->get_property = blocks_cache_get_property;

  g_type_class_add_private (klass, sizeof (BlocksCachePrivate));

  pspec = g_param_spec_uint ("theme", NULL, NULL,
                               0, 2, 0,
                               static_cast<GParamFlags>(G_PARAM_WRITABLE |
                               G_PARAM_CONSTRUCT_ONLY |
                               G_PARAM_STATIC_NAME |
                               G_PARAM_STATIC_NICK |
                               G_PARAM_STATIC_BLURB));
  g_object_class_install_property (gobject_class, PROP_THEME, pspec);

  pspec = g_param_spec_uint ("size", NULL, NULL,
                               0, 2048, 32,
                               static_cast<GParamFlags>(G_PARAM_WRITABLE |
                               G_PARAM_CONSTRUCT_ONLY |
                               G_PARAM_STATIC_NAME |
                               G_PARAM_STATIC_NICK |
                               G_PARAM_STATIC_BLURB));
  g_object_class_install_property (gobject_class, PROP_SIZE, pspec);
}

/* Public API */

/**
 * blocks_cache_new:
 *
 * Returns: a new #BlocksCache object
 */
BlocksCache *
blocks_cache_new (void)
{
  return static_cast<BlocksCache*>(g_object_new (TYPE_BLOCKS_CACHE, NULL));
}

/**
 * blocks_cache_set_theme:
 * @cache:
 * @theme:
 *
 * Sets the block theme.
 */
void
blocks_cache_set_theme (BlocksCache *cache,
                        guint theme)
{
  BlocksCachePrivate *priv = cache->priv;

  g_return_if_fail (IS_BLOCKS_CACHE (cache));

  if (priv->theme == theme)
    return;

  blocks_cache_clear (cache);
  blocks_cache_unset_theme (cache);

  priv->theme = theme;
  g_object_notify (G_OBJECT (cache), "theme");
}

/**
 * blocks_cache_get_theme:
 * @cache:
 *
 * Returns: the the block theme of @cache
 */
guint
blocks_cache_get_theme (BlocksCache *cache)
{
  g_return_val_if_fail (IS_BLOCKS_CACHE (cache), NULL);

  return cache->priv->theme;
}

/**
 * blocks_cache_set_size:
 * @cache:
 * @size:
 *
 * Sets the block size.
 */
void
blocks_cache_set_size (BlocksCache *cache,
                        guint size)
{
  BlocksCachePrivate *priv = cache->priv;

  g_return_if_fail (IS_BLOCKS_CACHE (cache));

  if (priv->size == size)
    return;

  blocks_cache_clear (cache);

  priv->size = size;
  g_object_notify (G_OBJECT (cache), "size");
}

/**
 * blocks_cache_get_size:
 * @cache:
 *
 * Returns: the the block size of @cache
 */
guint
blocks_cache_get_size (BlocksCache *cache)
{
  g_return_val_if_fail (IS_BLOCKS_CACHE (cache), NULL);

  return cache->priv->size;
}

/**
 * blocks_cache_get_block_texture_by_id:
 * @cache:
 * @colour:
 *
 * Returns: a cached #CoglHandle for @colour.
 */
CoglHandle
blocks_cache_get_block_texture_by_id (BlocksCache *cache,
                                      guint colour)
{
  BlocksCachePrivate *priv = cache->priv;
  CoglHandle handle;

  g_return_val_if_fail (colour < NCOLOURS , NULL);

  LOG_CALL (cache);

  handle = priv->colours[colour];
  if (IS_FAILED_HANDLE (handle)) {
    LOG_CACHE_HIT (cache);
    return COGL_INVALID_HANDLE;
  }

  if (handle == COGL_INVALID_HANDLE) {
    guint rowstride = cairo_format_stride_for_width (CAIRO_FORMAT_ARGB32, priv->size);
    guchar *cr_surface_data = static_cast<guchar*>(g_malloc0 (priv->size * rowstride));
    cairo_surface_t *cr_surface =
      cairo_image_surface_create_for_data (cr_surface_data, CAIRO_FORMAT_ARGB32,
                                           priv->size, priv->size, rowstride);

    LOG_CACHE_MISS (cache);

    Renderer *renderer = rendererFactory (priv->theme);
    cairo_t *cr = cairo_create (cr_surface);

    if (!cr) {
      priv->colours[colour] = FAILED_HANDLE;
      return COGL_INVALID_HANDLE;
    }

    cairo_scale (cr, 1.0 * priv->size, 1.0 * priv->size);
    renderer->drawCell (cr, colour);
    cairo_destroy (cr);

    handle = cogl_texture_new_from_data (priv->size, priv->size,
                                         COGL_TEXTURE_NONE,
                                         CLUTTER_CAIRO_TEXTURE_PIXEL_FORMAT,
                                         COGL_PIXEL_FORMAT_ANY,
                                         rowstride,
                                         cr_surface_data);
    cairo_surface_destroy (cr_surface);
    g_free (cr_surface_data);
    delete renderer;

    if (handle == COGL_INVALID_HANDLE) {
      priv->colours[colour] = FAILED_HANDLE;
      return COGL_INVALID_HANDLE;
    }

    priv->colours[colour] = handle;
  } else {
    LOG_CACHE_HIT (cache);
  }

  return handle;
}

