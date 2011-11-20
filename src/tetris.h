/* -*- mode:C++; tab-width:8; c-basic-offset:8; indent-tabs-mode:true -*- */
#ifndef __tetris_h__
#define __tetris_h__

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

#include <config.h>

#include <glib/gi18n.h>
#include <gtk/gtk.h>
//#include <gdk-pixbuf/gdk-pixbuf.h>

#include <libgames-support/games-conf.h>

#define KEY_OPTIONS_GROUP             "options"
#define KEY_BG_COLOUR                 "bgcolor"
#define KEY_BLOCK_PIXMAP              "block_pixmap"
#define KEY_DO_PREVIEW                "do_preview"
#define KEY_LINE_FILL_HEIGHT          "line_fill_height"
#define KEY_LINE_FILL_PROBABILITY     "line_fill_probability"
#define KEY_BASTARD_MODE              "bastard_mode"
#define KEY_RANDOM_BLOCK_COLORS       "random_block_colors"
#define KEY_ROTATE_COUNTER_CLOCKWISE  "rotate_counter_clock_wise"
#define KEY_SOUND                     "sound"
#define KEY_STARTING_LEVEL            "starting_level"
#define KEY_THEME                     "theme"
#define KEY_USE_BG_IMAGE              "usebgimage"
#define KEY_USE_TARGET                "use_target"

#define KEY_CONTROLS_GROUP  "controls"
#define KEY_MOVE_DOWN       "key_down"
#define KEY_MOVE_DROP       "key_drop"
#define KEY_MOVE_LEFT       "key_left"
#define KEY_MOVE_PAUSE      "key_pause"
#define KEY_MOVE_RIGHT      "key_right"
#define KEY_MOVE_ROTATE     "key_rotate"

#define KEY_SAVED_GROUP     "saved"

extern int LINES;
extern int COLUMNS;

extern int BLOCK_SIZE;

extern int color_next;
extern int blocknr_next;
extern int rot_next;

extern bool random_block_colors;
extern bool bastard_mode;
extern bool do_preview;

class Preview;
class BlockOps;
class ScoreFrame;
class HighScores;

class Tetris {
public:
	Tetris (int cmdlLevel);
	~Tetris ();

	GtkWidget *getWidget () {
		return w;
	}
	void togglePause ();
	void generate ();
	void endOfGame ();
	void setupPixmap ();

private:
	GtkWidget * w;

	GList *themeList;

	char *bgPixmap;
	char *defaultPixmap;
	gint themeno;

	BlockOps *field;
	Preview *preview;
	ScoreFrame *scoreFrame;
	HighScores *high_scores;

	gulong confNotifyID;

	bool paused;
	int timeoutId;
	bool onePause;

	bool inPlay;
	bool useTarget;

	void generateTimer (int level);

	static gint keyPressHandler (GtkWidget * widget, GdkEvent * event,
			       Tetris * t);
	static gint keyReleaseHandler (GtkWidget * widget, GdkEvent * event,
				 Tetris * t);
	static gchar *decodeDropData (gchar * data, gint type);
	void saveBgOptions ();
	static void decodeColour (guint16 * data, Tetris * t);
	static void resetColour (Tetris * t);
	static void dragDrop (GtkWidget * widget, GdkDragContext * context,
			gint x, gint y, GtkSelectionData * data,
			guint info, guint time, Tetris * t);
	static gboolean configure (GtkWidget * widget, GdkEventConfigure * event,
			     Tetris * t);
	static int timeoutHandler (void *d);
	static int gameQuit (GtkAction * action, void *d);
	static int gameNew (GtkAction * action, void *d);
	static int focusOut (GtkWidget * widget, GdkEvent * e, Tetris * t);
	static int gamePause (GtkAction * action, void *d);
	static int gameEnd (GtkAction * action, void *d);
	static int gameHelp (GtkAction * action, void *d);
	static int gameAbout (GtkAction * action, void *d);
	static int gameTopTen (GtkAction * action, void *d);
	static int gameProperties (GtkAction * action, void *d);
	static void setupdialogDestroy (GtkWidget * widget, void *d);
	static void setupdialogResponse (GtkWidget * dialog, gint response_id,
				   void *d);
	static void setSound (GtkWidget * widget, gpointer data);
	static void setSelectionPreview (GtkWidget * widget, void *d);
	static void setSelectionBlocks (GtkWidget * widget, void *d);
	static void setBastardMode (GtkWidget * widget, void *d);
	static void setRotateCounterClockWise (GtkWidget * widget, void *d);
	static void setTarget (GtkWidget * widget, void *d);
	static void setSelection (GtkWidget * widget, void *data);
	static void setBGSelection (GtkWidget * widget, void *data);

	static void lineFillHeightChanged (GtkWidget * spin, gpointer data);
	static void lineFillProbChanged (GtkWidget * spin, gpointer data);
	static void startingLevelChanged (GtkWidget * spin, gpointer data);

	static void confNotify (GamesConf *conf, const char *group,
				const char *key, gpointer data);
	static gchar *confGetString (const char *group, const char *key,
				     const char *default_val);
	static int confGetInt (const char *group, const char *key,
			       int default_val);
	static gboolean confGetBoolean (const char *group, const char *key,
					gboolean default_val);
	void initOptions ();
	void setOptions ();
	void writeOptions ();
	void manageFallen ();

	GdkPixbuf *bgimage;
	gboolean usebg;

	GdkColor bgcolour;

	GtkWidget *setupdialog;
	GtkWidget *sentry;
	int startingLevel;
	int cmdlineLevel;

	int line_fill_height;
	int line_fill_prob;

	GtkWidget *fill_height_spinner;
	GtkWidget *fill_prob_spinner;
	GtkWidget *do_preview_toggle;
	GtkWidget *random_block_colors_toggle;
	GtkWidget *bastard_mode_toggle;
	GtkWidget *rotate_counter_clock_wise_toggle;
	GtkWidget *useTargetToggle;
	GtkWidget *sound_toggle;

	Preview *theme_preview;

	int moveLeft;
	int moveRight;
	int moveDown;
	int moveDrop;
	int moveRotate;
	int movePause;

	GtkAction *new_game_action;
	GtkAction *pause_action;
	GtkAction *resume_action;
	GtkAction *scores_action;
	GtkAction *end_game_action;
	GtkAction *preferences_action;

	bool fastFall;
	bool dropBlock;
};

#endif // __tetris_h__
