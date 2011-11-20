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

#include <config.h>

#include <dirent.h>
#include <string.h>
#include <math.h>
#include <ctype.h>

#include <gdk/gdkkeysyms.h>
#include <gio/gio.h>

#include <libgames-support/games-controls.h>
#include <libgames-support/games-frame.h>
#include <libgames-support/games-help.h>
#include <libgames-support/games-runtime.h>
#include <libgames-support/games-sound.h>
#include <libgames-support/games-stock.h>
#include <libgames-support/games-pause-action.h>

#include "tetris.h"
#include "blocks.h"
#include "scoreframe.h"
#include "highscores.h"
#include "preview.h"
#include "blockops.h"
#include "renderer.h"

int LINES = 20;
int COLUMNS = 14;

int BLOCK_SIZE = 40;

int blocknr_next = -1;
int rot_next = -1;
int color_next = -1;

bool random_block_colors = false;
bool bastard_mode = false;
bool do_preview = true;
bool default_bgimage = false;
bool rotateCounterClockWise = true;

#define TETRIS_OBJECT "gnometris-tetris-object"

#define TILE_THRESHOLD 65

#define DEFAULT_WIDTH 500
#define DEFAULT_HEIGHT 550

enum {
	URI_LIST,
	TEXT_PLAIN,
	COLOUR,
	RESET
};

Tetris::Tetris(int cmdlLevel):
	themeno (0),
	field(0),
	paused(false),
	timeoutId(0),
	onePause(false),
	inPlay(false),
	bgimage(0),
	setupdialog(0),
	cmdlineLevel(cmdlLevel),
	fastFall(false),
	dropBlock(false)
{
	GtkUIManager *ui_manager;
	GtkAccelGroup *accel_group;
	GtkActionGroup *action_group;
	GtkWidget *vbox;
	GtkWidget *aspect_frame;
	GtkWidget *menubar;

	gchar *outdir;
	const char *dname;

	const GtkTargetEntry targets[] = {{(gchar*) "text/uri-list", 0, URI_LIST},
					  {(gchar*) "property/bgimage", 0, URI_LIST},
					  {(gchar*) "text/plain", 0, TEXT_PLAIN},
					  {(gchar*) "STRING", 0, TEXT_PLAIN},
					  {(gchar*) "application/x-color", 0, COLOUR},
					  {(gchar*) "x-special/gnome-reset-background", 0, RESET}};

	const GtkActionEntry actions[] = {
	{ "GameMenu", NULL, N_("_Game") },
	{ "SettingsMenu", NULL, N_("_Settings") },
	{ "HelpMenu", NULL, N_("_Help") },
	{ "NewGame", GAMES_STOCK_NEW_GAME, NULL, NULL, NULL, G_CALLBACK (gameNew) },
	{ "Scores", GAMES_STOCK_SCORES, NULL, NULL, NULL, G_CALLBACK (gameTopTen) },
	{ "EndGame", GAMES_STOCK_END_GAME, NULL, NULL, NULL, G_CALLBACK (gameEnd) },
	{ "Quit", GTK_STOCK_QUIT, NULL, NULL, NULL, G_CALLBACK (gameQuit) },
	{ "Preferences", GTK_STOCK_PREFERENCES, NULL, NULL, NULL, G_CALLBACK (gameProperties) },
	{ "Contents", GAMES_STOCK_CONTENTS, NULL, NULL, NULL, G_CALLBACK (gameHelp) },
	{ "About", GTK_STOCK_ABOUT, NULL, NULL, NULL, G_CALLBACK (gameAbout) }
	};

	const char ui_description[] =
	"<ui>"
	"  <menubar name='MainMenu'>"
	"    <menu action='GameMenu'>"
	"      <menuitem action='NewGame'/>"
	"      <menuitem action='Pause'/>"
	"      <separator/>"
	"      <menuitem action='Scores'/>"
	"      <menuitem action='EndGame'/>"
	"      <separator/>"
	"      <menuitem action='Quit'/>"
	"    </menu>"
	"    <menu action='SettingsMenu'>"
	"      <menuitem action='Preferences'/>"
	"    </menu>"
	"    <menu action='HelpMenu'>"
	"      <menuitem action='Contents'/>"
	"      <menuitem action='About'/>"
	"    </menu>"
	"  </menubar>"
	"</ui>";


	/* Locate our background image. */

	outdir = g_build_filename (g_get_user_data_dir (), "quadrapassel", NULL);
	g_mkdir_with_parents (outdir, 0700);
	bgPixmap = g_build_filename (outdir, "background.bin", NULL);
	g_free (outdir);

	/*  Use default background image, if none found in user's home dir.*/
	if (!g_file_test (bgPixmap, G_FILE_TEST_EXISTS)) {
		dname = games_runtime_get_directory (GAMES_RUNTIME_GAME_PIXMAP_DIRECTORY);
		defaultPixmap = g_build_filename (dname, "quadrapassel.svg", NULL);
		default_bgimage = true;
	}

	w = gtk_window_new (GTK_WINDOW_TOPLEVEL);
	gtk_window_set_title (GTK_WINDOW (w), _("Quadrapassel"));

	g_signal_connect (w, "delete_event", G_CALLBACK (gameQuit), this);
	gtk_drag_dest_set (w, GTK_DEST_DEFAULT_ALL, targets,
			   G_N_ELEMENTS(targets),
			   GDK_ACTION_MOVE);
	g_signal_connect (G_OBJECT (w), "drag_data_received",
			  G_CALLBACK (dragDrop), this);
	g_signal_connect (G_OBJECT (w), "focus_out_event",
			  G_CALLBACK (focusOut), this);

	line_fill_height = 0;
	line_fill_prob = 5;

	gtk_window_set_default_size (GTK_WINDOW (w), DEFAULT_WIDTH, DEFAULT_HEIGHT);
	games_conf_add_window (GTK_WINDOW (w), KEY_SAVED_GROUP);

	preview = new Preview ();
	field = new BlockOps ();

	initOptions ();

	/* prepare menus */
	games_stock_init ();
	action_group = gtk_action_group_new ("MenuActions");
	gtk_action_group_set_translation_domain (action_group, GETTEXT_PACKAGE);
	gtk_action_group_add_actions (action_group, actions, G_N_ELEMENTS (actions), this);
	ui_manager = gtk_ui_manager_new ();
	gtk_ui_manager_insert_action_group (ui_manager, action_group, 0);
	gtk_ui_manager_add_ui_from_string (ui_manager, ui_description, -1, NULL);
	accel_group = gtk_ui_manager_get_accel_group (ui_manager);
	gtk_window_add_accel_group (GTK_WINDOW (w), accel_group);

	new_game_action = gtk_action_group_get_action (action_group, "NewGame");
	pause_action = GTK_ACTION (games_pause_action_new ("Pause"));
    g_signal_connect (G_OBJECT (pause_action), "state-changed", G_CALLBACK (gamePause), this);
	gtk_action_group_add_action_with_accel (action_group, pause_action, NULL);
	scores_action = gtk_action_group_get_action (action_group, "Scores");
	end_game_action = gtk_action_group_get_action (action_group, "EndGame");
	preferences_action = gtk_action_group_get_action (action_group, "Preferences");

	menubar = gtk_ui_manager_get_widget (ui_manager, "/MainMenu");

	GtkWidget * hb = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);

	vbox = gtk_box_new (GTK_ORIENTATION_VERTICAL, 0);
	gtk_container_add (GTK_CONTAINER (w), vbox);
	gtk_box_pack_start (GTK_BOX (vbox), menubar, FALSE, FALSE, 0);
	gtk_box_pack_start (GTK_BOX (vbox), hb, TRUE, TRUE, 0);

	aspect_frame = gtk_aspect_frame_new (NULL, 0.5, 0.5, (float) COLUMNS / (float) LINES, FALSE);
	gtk_frame_set_shadow_type (GTK_FRAME (aspect_frame), GTK_SHADOW_NONE);
	gtk_container_add (GTK_CONTAINER (aspect_frame), field->getWidget());

	gtk_widget_set_events(w, gtk_widget_get_events(w) |
			      GDK_KEY_PRESS_MASK | GDK_KEY_RELEASE_MASK);

	GtkWidget *vb1 = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
	gtk_container_set_border_width(GTK_CONTAINER(vb1), 10);
	gtk_box_pack_start(GTK_BOX(vb1), aspect_frame, TRUE, TRUE, 0);
	gtk_box_pack_start(GTK_BOX(hb), vb1, TRUE, TRUE, 0);

	setupPixmap();

	g_signal_connect (w, "key_press_event", G_CALLBACK (keyPressHandler), this);
	g_signal_connect (w, "key_release_event", G_CALLBACK (keyReleaseHandler), this);

	GtkWidget *vb2 = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
	gtk_container_set_border_width(GTK_CONTAINER(vb2), 10);
	gtk_box_pack_end(GTK_BOX(hb), vb2, 0, 0, 0);

	gtk_box_pack_start(GTK_BOX(vb2), preview->getWidget(), FALSE, FALSE, 0);

	scoreFrame = new ScoreFrame(cmdlineLevel);

	gtk_box_pack_end(GTK_BOX(vb2), scoreFrame->getWidget(), TRUE, FALSE, 0);
	high_scores = new HighScores ();

	setOptions ();

	themeList = NULL;

	gtk_widget_show_all(w);

	gtk_action_set_sensitive(pause_action, FALSE);
	gtk_action_set_sensitive(end_game_action, FALSE);
	gtk_action_set_sensitive(preferences_action, TRUE);

	confNotifyID = g_signal_connect (games_conf_get_default (),
					 "value-changed",
					 G_CALLBACK (confNotify),
					 this);
}

Tetris::~Tetris()
{
	delete field;
	delete preview;
	delete scoreFrame;
	delete high_scores;

	if (bgimage)
		g_object_unref (G_OBJECT (bgimage));

	if (bgPixmap)
		g_free(bgPixmap);
	if (defaultPixmap)
		g_free(defaultPixmap);

	if (confNotifyID != 0)
		g_signal_handler_disconnect (games_conf_get_default (), confNotifyID);
}

void
Tetris::setupdialogDestroy(GtkWidget *widget, void *d)
{
	Tetris *t = (Tetris*) d;
	if (t->setupdialog) {
		delete t->theme_preview;
		gtk_widget_destroy(t->setupdialog);
	}
	t->setupdialog = 0;
	gtk_action_set_sensitive(t->new_game_action, TRUE);
}

void
Tetris::setupdialogResponse (GtkWidget *dialog, gint response_id, void *d)
{
	setupdialogDestroy (NULL, d);
}

void
Tetris::setupPixmap()
{
	if (bgimage)
		g_object_unref (G_OBJECT (bgimage));

	if (!usebg)
		bgimage = NULL;
	else {
		if (g_file_test (bgPixmap, G_FILE_TEST_EXISTS))
			bgimage = gdk_pixbuf_new_from_file (bgPixmap, NULL);
		else if (g_file_test (defaultPixmap, G_FILE_TEST_EXISTS))
			bgimage = gdk_pixbuf_new_from_file (defaultPixmap, NULL);
		else
			bgimage = NULL;
	}

	/* A nasty hack to tile the image if it looks tileable (i.e. it
	 * is small enough. */
	if (bgimage && !default_bgimage) {
		int width, height;
		int bgwidth, bgheight;

		bgwidth = COLUMNS*BLOCK_SIZE;
		bgheight = LINES*BLOCK_SIZE;

		width = gdk_pixbuf_get_width (bgimage);
		height = gdk_pixbuf_get_height (bgimage);

		/* The heuristic is, anything less than 65 pixels on a side,
		 * or is square and smaller than the playing field is tiled. */
		/* Note that this heuristic fails for the standard nautilus
		 * background burlap.jpg because it is 97x91 */
		if ((width < TILE_THRESHOLD) || (height < TILE_THRESHOLD) ||
		    ((width == height) && (width < bgwidth))) {
			GdkPixbuf * temp;
			int i, j;

			temp = gdk_pixbuf_new (GDK_COLORSPACE_RGB, TRUE, 8,
						bgwidth, bgheight);

			for (i=0; i<=bgwidth/width; i++) {
				for (j=0; j<=bgheight/height; j++) {
					int x, y, ww, hh;

					x = i*width;
					y = j*height;
					ww = MIN (width, bgwidth - x);
					hh = MIN (height, bgheight - y);

					gdk_pixbuf_copy_area (bgimage, 0, 0,
							      ww, hh, temp,
							      x, y);
				}
			}
			g_object_unref (bgimage);
			bgimage = temp;
		}
	}

	if (field)
	{
		if (bgimage)
			field->setBackground (bgimage);
		else
			field->setBackground (&bgcolour);
	}

	if (preview)
	{
		/* FIXME: We should do an update once the preview actually
		 * uses the background pixbuf. */
	}
}

void
Tetris::confNotify (GamesConf *conf, const char *group, const char *key, gpointer data)
{
	if (!group)
		return;

	Tetris *t = (Tetris *) data;

	t->initOptions ();
	t->setOptions ();
}

char *
Tetris::confGetString (const char *group, const char *key, const char *default_val)
{
	return games_conf_get_string_with_default (group, key, default_val);
}

int
Tetris::confGetInt (const char *group, const char *key, int default_val)
{
	return games_conf_get_integer_with_default (group, key, default_val);
}

gboolean
Tetris::confGetBoolean (const char *group, const char *key, gboolean default_val)
{
	gboolean val;
	GError *error = NULL;

	val = games_conf_get_boolean (group, key, &error);
	if (error) {
		g_error_free (error);
		val = default_val;
	}

	return val;
}

void
Tetris::initOptions ()
{
	gchar *bgcolourstr;

	themeno = themeNameToNumber (confGetString (KEY_OPTIONS_GROUP, KEY_THEME, "plain"));
	field->setTheme (themeno);
	preview->setTheme (themeno);

	startingLevel = confGetInt (KEY_OPTIONS_GROUP, KEY_STARTING_LEVEL, 1);
	if (startingLevel < 1)
		startingLevel = 1;
	if (startingLevel > 20)
		startingLevel = 20;

	games_sound_enable (confGetBoolean (KEY_OPTIONS_GROUP, KEY_SOUND, TRUE));

	do_preview = confGetBoolean (KEY_OPTIONS_GROUP, KEY_DO_PREVIEW, TRUE);

	if (preview) {
		preview->enable(do_preview);
	}

	random_block_colors = confGetBoolean (KEY_OPTIONS_GROUP, KEY_RANDOM_BLOCK_COLORS, TRUE);

	bastard_mode = confGetBoolean (KEY_OPTIONS_GROUP, KEY_BASTARD_MODE, FALSE);

	rotateCounterClockWise = confGetBoolean (KEY_OPTIONS_GROUP, KEY_ROTATE_COUNTER_CLOCKWISE, TRUE);

	line_fill_height = confGetInt (KEY_OPTIONS_GROUP, KEY_LINE_FILL_HEIGHT, 0);
	if (line_fill_height < 0)
		line_fill_height = 0;
	if (line_fill_height > 19)
		line_fill_height = 19;

	line_fill_prob = confGetInt (KEY_OPTIONS_GROUP, KEY_LINE_FILL_PROBABILITY, 0);
	if (line_fill_prob < 0)
		line_fill_prob = 0;
	if (line_fill_prob > 10)
		line_fill_prob = 10;

	moveLeft = games_conf_get_keyval_with_default (KEY_CONTROLS_GROUP, KEY_MOVE_LEFT, GDK_KEY_Left);
	moveRight = games_conf_get_keyval_with_default (KEY_CONTROLS_GROUP, KEY_MOVE_RIGHT, GDK_KEY_Right);
	moveDown = games_conf_get_keyval_with_default (KEY_CONTROLS_GROUP, KEY_MOVE_DOWN, GDK_KEY_Down);
	moveDrop = games_conf_get_keyval_with_default (KEY_CONTROLS_GROUP, KEY_MOVE_DROP, GDK_KEY_Pause);
	moveRotate = games_conf_get_keyval_with_default (KEY_CONTROLS_GROUP, KEY_MOVE_ROTATE, GDK_KEY_Up);
	movePause = games_conf_get_keyval_with_default (KEY_CONTROLS_GROUP, KEY_MOVE_PAUSE, GDK_KEY_space);

	bgcolourstr = confGetString (KEY_OPTIONS_GROUP, KEY_BG_COLOUR, "Black");
	gdk_color_parse (bgcolourstr, &bgcolour);
	g_free (bgcolourstr);

	usebg = confGetBoolean (KEY_OPTIONS_GROUP, KEY_USE_BG_IMAGE, TRUE);
}

void
Tetris::setOptions ()
{
	if (setupdialog) {
		gtk_spin_button_set_value (GTK_SPIN_BUTTON (sentry), startingLevel);
		gtk_spin_button_set_value (GTK_SPIN_BUTTON (fill_prob_spinner), line_fill_prob);
		gtk_spin_button_set_value (GTK_SPIN_BUTTON (fill_height_spinner), line_fill_height);
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (sound_toggle), games_sound_is_enabled ());
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (do_preview_toggle), do_preview);
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (random_block_colors_toggle), random_block_colors);
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (bastard_mode_toggle), bastard_mode);
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (rotate_counter_clock_wise_toggle), rotateCounterClockWise);

		if (theme_preview) {
			theme_preview->setTheme (themeno);
		}
	}

	scoreFrame->setLevel (startingLevel);
	scoreFrame->setStartingLevel (startingLevel);
	setupPixmap ();
}

void
Tetris::setSound (GtkWidget *widget, gpointer data)
{
	games_conf_set_boolean (KEY_OPTIONS_GROUP, KEY_SOUND,
				gtk_toggle_button_get_active (GTK_TOGGLE_BUTTON (widget)));
}

void
Tetris::setSelectionPreview(GtkWidget *widget, void *d)
{
	games_conf_set_boolean (KEY_OPTIONS_GROUP, KEY_DO_PREVIEW,
				gtk_toggle_button_get_active (GTK_TOGGLE_BUTTON (widget)));
}

void
Tetris::setSelectionBlocks(GtkWidget *widget, void *d)
{
	games_conf_set_boolean (KEY_OPTIONS_GROUP, KEY_RANDOM_BLOCK_COLORS,
				gtk_toggle_button_get_active (GTK_TOGGLE_BUTTON (widget)));
}

void
Tetris::setBastardMode(GtkWidget *widget, void *d)
{
	games_conf_set_boolean (KEY_OPTIONS_GROUP, KEY_BASTARD_MODE,
				gtk_toggle_button_get_active (GTK_TOGGLE_BUTTON (widget)));

	/* Disable the preview option to indicate that it is
		unavailable in bastard mode */
	Tetris *t = (Tetris*) d;
	gtk_widget_set_sensitive(t->do_preview_toggle,
		gtk_toggle_button_get_active (GTK_TOGGLE_BUTTON (widget)) ? FALSE : TRUE);
}

void
Tetris::setRotateCounterClockWise(GtkWidget *widget, void *d)
{
	games_conf_set_boolean (KEY_OPTIONS_GROUP, KEY_ROTATE_COUNTER_CLOCKWISE,
				gtk_toggle_button_get_active (GTK_TOGGLE_BUTTON (widget)));
}

void
Tetris::setSelection(GtkWidget *widget, void *data)
{
	Tetris *t;
	t = (Tetris *)data;

	t->themeno = gtk_combo_box_get_active (GTK_COMBO_BOX (widget));
	t->field->setTheme (t->themeno);
	games_conf_set_string (KEY_OPTIONS_GROUP, KEY_THEME,
			       ThemeTable[t->themeno].id);
}

void
Tetris::lineFillHeightChanged (GtkWidget *spin, gpointer data)
{
	gint value = gtk_spin_button_get_value_as_int (GTK_SPIN_BUTTON (spin));
	games_conf_set_integer (KEY_OPTIONS_GROUP, KEY_LINE_FILL_HEIGHT, value);
}

void
Tetris::lineFillProbChanged (GtkWidget *spin, gpointer data)
{
	gint value = gtk_spin_button_get_value_as_int (GTK_SPIN_BUTTON (spin));
	games_conf_set_integer (KEY_OPTIONS_GROUP, KEY_LINE_FILL_PROBABILITY, value);
}

void
Tetris::startingLevelChanged (GtkWidget *spin, gpointer data)
{
	gint value = gtk_spin_button_get_value_as_int (GTK_SPIN_BUTTON (spin));
	games_conf_set_integer (KEY_OPTIONS_GROUP, KEY_STARTING_LEVEL, value);
}

int
Tetris::gameProperties(GtkAction *action, void *d)
{
	GtkWidget *notebook;
	GtkWidget *vbox;
	GtkWidget *label;
	GtkWidget *frame;
	GtkWidget *table;
	GtkWidget *fvbox;
	GtkAdjustment *adj;
	GtkWidget *controls_list;

	Tetris *t = (Tetris*) d;

	if (t->setupdialog) {
		gtk_window_present (GTK_WINDOW(t->setupdialog));
		return FALSE;
	}

	/* create the dialog */
	t->setupdialog =
		gtk_dialog_new_with_buttons(_("Quadrapassel Preferences"),
					    GTK_WINDOW (t->w),
					    (GtkDialogFlags)0,
					    GTK_STOCK_CLOSE, GTK_RESPONSE_CLOSE,
					    NULL);
	gtk_container_set_border_width (GTK_CONTAINER (t->setupdialog), 5);
	vbox = gtk_dialog_get_content_area (GTK_DIALOG (t->setupdialog));
	gtk_box_set_spacing (GTK_BOX (vbox), 2);
	g_signal_connect (t->setupdialog, "close",
			  G_CALLBACK (setupdialogDestroy), d);
	g_signal_connect (t->setupdialog, "response",
			  G_CALLBACK (setupdialogResponse), d);

	notebook = gtk_notebook_new ();
	gtk_container_set_border_width (GTK_CONTAINER (notebook), 5);
	gtk_box_pack_start (GTK_BOX(vbox), notebook, TRUE, TRUE, 0);

	/* game page */
	vbox = gtk_box_new (GTK_ORIENTATION_VERTICAL, 18);
	gtk_container_set_border_width (GTK_CONTAINER (vbox), 12);
	label = gtk_label_new (_("Game"));
	gtk_notebook_append_page (GTK_NOTEBOOK(notebook), vbox, label);

	frame = games_frame_new (_("Setup"));
	table = gtk_table_new (3, 2, FALSE);
	gtk_table_set_row_spacings (GTK_TABLE (table), 6);
	gtk_table_set_col_spacings (GTK_TABLE (table), 12);

	/* pre-filled rows */
	label = gtk_label_new_with_mnemonic (_("_Number of pre-filled rows:"));
	gtk_misc_set_alignment (GTK_MISC (label), 0, 0.5);
	gtk_table_attach (GTK_TABLE (table), label, 0, 1, 0, 1,
			  (GtkAttachOptions) GTK_FILL,
			  (GtkAttachOptions) 0,
			  0, 0);

	adj = gtk_adjustment_new (t->line_fill_height, 0, LINES-1, 1, 5, 0);
	t->fill_height_spinner = gtk_spin_button_new (GTK_ADJUSTMENT (adj), 10, 0);
	gtk_spin_button_set_update_policy
		(GTK_SPIN_BUTTON (t->fill_height_spinner), GTK_UPDATE_ALWAYS);
	gtk_spin_button_set_snap_to_ticks
		(GTK_SPIN_BUTTON (t->fill_height_spinner), TRUE);
	g_signal_connect (t->fill_height_spinner, "value_changed",
			  G_CALLBACK (lineFillHeightChanged), t);
	gtk_table_attach_defaults (GTK_TABLE (table), t->fill_height_spinner, 1, 2, 0, 1);
	gtk_label_set_mnemonic_widget (GTK_LABEL (label), t->fill_height_spinner);

	/* pre-filled rows density */
	label = gtk_label_new_with_mnemonic (_("_Density of blocks in a pre-filled row:"));
	gtk_misc_set_alignment (GTK_MISC (label), 0, 0.5);
	gtk_table_attach (GTK_TABLE (table), label, 0, 1, 1, 2,
			  (GtkAttachOptions) GTK_FILL,
			  (GtkAttachOptions) 0,
			  0, 0);

	adj = gtk_adjustment_new (t->line_fill_prob, 0, 10, 1, 5, 0);
	t->fill_prob_spinner = gtk_spin_button_new (GTK_ADJUSTMENT (adj), 10, 0);
	gtk_spin_button_set_update_policy (GTK_SPIN_BUTTON (t->fill_prob_spinner),
					  GTK_UPDATE_ALWAYS);
	gtk_spin_button_set_snap_to_ticks
		(GTK_SPIN_BUTTON (t->fill_prob_spinner), TRUE);
	g_signal_connect (t->fill_prob_spinner, "value_changed",
		          G_CALLBACK (lineFillProbChanged), t);
	gtk_table_attach_defaults (GTK_TABLE (table), t->fill_prob_spinner, 1, 2, 1, 2);
	gtk_label_set_mnemonic_widget (GTK_LABEL (label), t->fill_prob_spinner);

	/* starting level */
	label = gtk_label_new_with_mnemonic (_("_Starting level:"));
	gtk_misc_set_alignment (GTK_MISC (label), 0, 0.5);
	gtk_table_attach (GTK_TABLE (table), label, 0, 1, 2, 3,
			  (GtkAttachOptions) GTK_FILL,
			  (GtkAttachOptions) 0,
			  0, 0);

	adj = gtk_adjustment_new (t->startingLevel, 1, 20, 1, 5, 0);
	t->sentry = gtk_spin_button_new (GTK_ADJUSTMENT (adj), 10.0, 0);
	gtk_spin_button_set_update_policy (GTK_SPIN_BUTTON (t->sentry),
					   GTK_UPDATE_ALWAYS);
	gtk_spin_button_set_snap_to_ticks (GTK_SPIN_BUTTON (t->sentry), TRUE);
	g_signal_connect (t->sentry, "value_changed",
			  G_CALLBACK (startingLevelChanged), t);
	gtk_table_attach_defaults (GTK_TABLE (table), t->sentry, 1, 2, 2, 3);
	gtk_label_set_mnemonic_widget (GTK_LABEL (label), t->sentry);

	gtk_container_add (GTK_CONTAINER (frame), table);
	gtk_box_pack_start (GTK_BOX (vbox), frame,
			    FALSE, FALSE, 0);

	frame = games_frame_new (_("Operation"));
	fvbox = gtk_box_new (GTK_ORIENTATION_VERTICAL, 6);

	/* sound */
	t->sound_toggle =
		gtk_check_button_new_with_mnemonic (_("_Enable sounds"));
	gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON (t->sound_toggle),
				     games_sound_is_enabled ());
	g_signal_connect (t->sound_toggle, "clicked",
			  G_CALLBACK (setSound), d);
	gtk_box_pack_start (GTK_BOX (fvbox), t->sound_toggle, 0, 0, 0);

	/* preview next block */
	t->do_preview_toggle =
		gtk_check_button_new_with_mnemonic (_("_Preview next block"));
	gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON (t->do_preview_toggle),
				     do_preview);
	g_signal_connect (t->do_preview_toggle, "clicked",
			  G_CALLBACK (setSelectionPreview), d);
	gtk_box_pack_start (GTK_BOX (fvbox), t->do_preview_toggle, 0, 0, 0);

	/* random blocks */
	t->random_block_colors_toggle =
		gtk_check_button_new_with_mnemonic (_("_Use random block colors"));
	gtk_toggle_button_set_active
		(GTK_TOGGLE_BUTTON (t->random_block_colors_toggle),
		 random_block_colors);
	g_signal_connect (t->random_block_colors_toggle, "clicked",
			  G_CALLBACK (setSelectionBlocks), d);
	gtk_box_pack_start (GTK_BOX (fvbox), t->random_block_colors_toggle,
			    0, 0, 0);

	/* bastard mode */
	t->bastard_mode_toggle =
		gtk_check_button_new_with_mnemonic (_("Choose difficult _blocks"));
	gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON (t->bastard_mode_toggle),
				     bastard_mode);
	g_signal_connect (t->bastard_mode_toggle, "clicked",
			  G_CALLBACK (setBastardMode), d);
	gtk_box_pack_start (GTK_BOX (fvbox), t->bastard_mode_toggle, 0, 0, 0);

	/* If bastard mode is active then disable the preview option
		to indicate that it is unavailable in bastard mode */
	if(gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON (t->bastard_mode_toggle)))
	{
		gtk_widget_set_sensitive(t->do_preview_toggle, FALSE);
	}

	/* rotate counter clock wise */
 	t->rotate_counter_clock_wise_toggle =
		gtk_check_button_new_with_mnemonic (_("_Rotate blocks counterclockwise"));
 	gtk_toggle_button_set_active
		(GTK_TOGGLE_BUTTON (t->rotate_counter_clock_wise_toggle),
		 rotateCounterClockWise);
	g_signal_connect (t->rotate_counter_clock_wise_toggle, "clicked",
			  G_CALLBACK (setRotateCounterClockWise), d);
 	gtk_box_pack_start (GTK_BOX (fvbox), t->rotate_counter_clock_wise_toggle,
			    0, 0, 0);

	t->useTargetToggle = gtk_check_button_new_with_mnemonic (_("Show _where the block will land"));
 	gtk_box_pack_start (GTK_BOX (fvbox), t->useTargetToggle,
			    0, 0, 0);

	gtk_container_add (GTK_CONTAINER (frame), fvbox);
	gtk_box_pack_start (GTK_BOX (vbox), frame,
			    FALSE, FALSE, 0);

	frame = games_frame_new (_("Theme"));
	table = gtk_table_new (2, 2, FALSE);
	gtk_container_set_border_width (GTK_CONTAINER (table), 0);
	gtk_table_set_row_spacings (GTK_TABLE (table), 6);
	gtk_table_set_col_spacings (GTK_TABLE (table), 12);

	/* controls page */
	vbox = gtk_box_new (GTK_ORIENTATION_VERTICAL, 0);
	gtk_container_set_border_width (GTK_CONTAINER (vbox), 12);
	label = gtk_label_new (_("Controls"));
	gtk_notebook_append_page (GTK_NOTEBOOK(notebook), vbox, label);

	frame = games_frame_new (_("Keyboard Controls"));
	gtk_container_add (GTK_CONTAINER (vbox), frame);

	fvbox = gtk_box_new (GTK_ORIENTATION_VERTICAL, 6);
	gtk_container_add (GTK_CONTAINER (frame), fvbox);

	controls_list = games_controls_list_new (KEY_CONTROLS_GROUP);
	games_controls_list_add_controls (GAMES_CONTROLS_LIST (controls_list),
					  KEY_MOVE_LEFT, _("Move left"), GDK_KEY_Left,
					  KEY_MOVE_RIGHT, _("Move right"), GDK_KEY_Right,
					  KEY_MOVE_DOWN, _("Move down"), GDK_KEY_Down,
					  KEY_MOVE_DROP, _("Drop"), GDK_KEY_Pause,
					  KEY_MOVE_ROTATE, _("Rotate"), GDK_KEY_Up,
					  KEY_MOVE_PAUSE, _("Pause"), GDK_KEY_space,
					  NULL);

	gtk_box_pack_start (GTK_BOX (fvbox), controls_list, TRUE, TRUE, 0);

	/* theme page */
	vbox = gtk_box_new (GTK_ORIENTATION_VERTICAL, 0);
	gtk_container_set_border_width (GTK_CONTAINER (vbox), 12);
	label = gtk_label_new (_("Theme"));
	gtk_notebook_append_page (GTK_NOTEBOOK(notebook), vbox, label);

	frame = games_frame_new (_("Block Style"));
	gtk_container_add (GTK_CONTAINER (vbox), frame);

	fvbox = gtk_box_new (GTK_ORIENTATION_VERTICAL, 6);
	gtk_container_add (GTK_CONTAINER (frame), fvbox);

	GtkWidget *omenu = gtk_combo_box_text_new ();
	const ThemeTableEntry *entry = ThemeTable;
	while (entry->id) {
		gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (omenu), entry->name);
		entry++;
	}
	gtk_combo_box_set_active (GTK_COMBO_BOX (omenu), t->themeno);
	g_signal_connect (omenu, "changed", G_CALLBACK (setSelection), t);
	gtk_box_pack_start (GTK_BOX (fvbox), omenu, FALSE, FALSE, 0);

	t->theme_preview = new Preview();
	t->theme_preview->setTheme (t->themeno);
	gtk_box_pack_start(GTK_BOX(fvbox), t->theme_preview->getWidget(), TRUE, TRUE, 0);

	t->theme_preview->previewBlock(4, 0, TRUE);

	gtk_widget_show_all (t->setupdialog);
	gtk_action_set_sensitive(t->new_game_action, FALSE);

	return TRUE;
}

int
Tetris::focusOut(GtkWidget *widget, GdkEvent *e, Tetris *t)
{
	if (t->inPlay && !t->paused)
		t->togglePause();
	return TRUE;
}

int
Tetris::gamePause(GtkAction *action, void *d)
{
	Tetris *t = (Tetris*) d;
	t->togglePause();
	return TRUE;
}

int
Tetris::gameEnd(GtkAction *action, void *d)
{
	Tetris *t = (Tetris*) d;

	g_source_remove(t->timeoutId);
	t->timeoutId = 0;
	blocknr_next = -1;
	t->endOfGame();
	return TRUE;
}

int
Tetris::gameQuit(GtkAction *action, void *d)
{
	Tetris *t = (Tetris*) d;

	/* Record the score if the game isn't over. */
	if (t->inPlay && (t->scoreFrame->getScore() > 0))
		t->high_scores->add (t->scoreFrame->getScore());

	if (t->w)
		gtk_widget_destroy(t->w);
	gtk_main_quit();

	return TRUE;
}

void
Tetris::generateTimer(int level)
{
	g_return_if_fail (level > 0);

	if (timeoutId > 0)
		g_source_remove(timeoutId);

	// With 0.8, the old level 10 should be hit at about level 20.
	int intv = (int) round (80 + 800.0 * pow (0.75, level - 1));
	if (intv <= 10)
		intv = 10;

	timeoutId = g_timeout_add (intv, timeoutHandler, this);
}

void
Tetris::manageFallen()
{
	field->fallingToLaying();
	games_sound_play ("land");

	int levelBefore = scoreFrame->getLevel();

	int levelAfter = scoreFrame->scoreLines (field->checkFullLines());
	if (levelAfter != levelBefore)
		games_sound_play ("quadrapassel");
	if ((levelBefore != levelAfter) || fastFall)
		generateTimer(levelAfter);

	if (field->isFieldEmpty ())
		scoreFrame->scoreLastLineBonus ();

	generate();
}

int
Tetris::timeoutHandler(void *d)
{
	Tetris *t = (Tetris*) d;

	if (t->paused)
		return TRUE;

	if (t->onePause)
	{
		t->onePause = false;
		t->field->drawMessage();
	}
	else
	{
		bool res = t->field->moveBlockDown();

		if (res)
		{
			t->manageFallen();
			if (t->fastFall && t->inPlay) {
				t->fastFall = false;
			}
		}
	}

	return TRUE;
}

gboolean
Tetris::keyPressHandler(GtkWidget *widget, GdkEvent *event, Tetris *t)
{
	int keyval;
	bool res = false;

	if (t->timeoutId == 0)
		return FALSE;

	keyval = toupper(((GdkEventKey*)event)->keyval);

	if (keyval == toupper(t->movePause))
	{
		t->togglePause();
		return TRUE;
	}

	if (t->paused)
		return FALSE;

	if (keyval == toupper(t->moveLeft)) {
		res = t->field->moveBlockLeft();
		if (res)
			games_sound_play ("slide");
		t->onePause = false;
	} else if (keyval == toupper(t->moveRight)) {
		res = t->field->moveBlockRight();
		if (res)
			games_sound_play ("slide");
		t->onePause = false;
	} else if (keyval == toupper(t->moveRotate)) {
		res = t->field->rotateBlock(rotateCounterClockWise);
		if (res)
			games_sound_play ("turn");
		t->onePause = false;
	} else if (keyval == toupper(t->moveDown)) {
		if (!t->fastFall && !t->onePause) {
			t->fastFall = true;
			g_source_remove (t->timeoutId);
			t->timeoutId = g_timeout_add (10, timeoutHandler, t);
			res = true;
		}
	} else if (keyval == toupper(t->moveDrop)) {
		if (!t->dropBlock) {
			t->dropBlock = true;
			t->field->dropBlock();
			t->manageFallen();
			res = TRUE;
		}
	}

	return res;
}

gint
Tetris::keyReleaseHandler(GtkWidget *widget, GdkEvent *event, Tetris *t)
{
	bool res = false;

	if (t->timeoutId == 0)
		return FALSE;

	if (t->paused)
		return FALSE;

	int keyval = ((GdkEventKey*)event)->keyval;

	if (keyval == t->moveDown) {
		if (t->fastFall) {
			t->fastFall = false;
 			t->generateTimer(t->scoreFrame->getLevel());
		}
		res = TRUE;
	} else if (keyval == t->moveDrop) {
		t->dropBlock = false;
		res = TRUE;
	}

	return res;
}

void Tetris::saveBgOptions ()
{
	gchar cbuffer[64];

	games_conf_set_boolean (KEY_OPTIONS_GROUP, KEY_USE_BG_IMAGE, usebg);

	g_snprintf (cbuffer, sizeof (cbuffer), "#%04x%04x%04x",
		    bgcolour.red, bgcolour.green, bgcolour.blue);
	games_conf_set_string (KEY_OPTIONS_GROUP, KEY_BG_COLOUR, cbuffer);
}

void
Tetris::decodeColour (guint16 *data, Tetris *t)
{
	t->bgcolour.red = data[0];
	t->bgcolour.green = data[1];
	t->bgcolour.blue = data[2];
	/* Ignore the alpha channel. */

	t->usebg = FALSE;
	t->saveBgOptions ();
}

void
Tetris::resetColour (Tetris *t)
{
	t->bgcolour.red = 0;
	t->bgcolour.green = 0;
	t->bgcolour.blue = 0;
	/* Ignore the alpha channel. */

	t->usebg = FALSE;
	t->saveBgOptions ();
}

char *
Tetris::decodeDropData(gchar * data, gint type)
{
	gchar *start, *end;

	if (data == NULL)
		return NULL;

	if (type == TEXT_PLAIN)
		return g_strdup (data);

	if (type == URI_LIST) {
		start = data;
		/* Skip any comments. */
		if (*start == '#') {
			while (*start != '\n') {
				start++;
				if (*start == '\0')
					return NULL;
			}
			start++;
			if (*start == '\0')
				return NULL;
		}

		/* Now extract the first URI. */
		end = start;
		while ((*end != '\0') && (*end != '\r') && (*end != '\n'))
			end++;
		*end = '\0';

		return g_strdup (start);
	}

	return NULL;
}

void
Tetris::dragDrop(GtkWidget *widget, GdkDragContext *context,
		 gint x, gint y, GtkSelectionData *data, guint info,
		 guint time, Tetris * t)
{
	gint selection_length;
	const guchar *selection_data;
	const char *fileuri;

	GError *error = NULL;
	GFile *file;
	GFile *outfile;
	GFileInfo *fileinfo;
	GFileInputStream *istream;
	GFileOutputStream *outstream;
	goffset filesize;
	gssize bytesread, byteswrote;

	GdkPixbufLoader *loader;
	GdkPixbuf *pixbuf;
	guchar *buffer;


	/* Accept a dropped filename and try and load it as the
	   background image. In the event of any kind of failure we
	   silently ignore it. */

	/* FIXME: We don't handle colour gradients (e.g. from the gimp) */

	/* FIXME: Dropped URLs from mozilla don't work (see below). */

	selection_length = gtk_selection_data_get_length (data);
	selection_data = gtk_selection_data_get_data (data);

	if (selection_length < 0) {
		gtk_drag_finish (context, FALSE, FALSE, time);
		return;
	}

	gtk_drag_finish (context, TRUE, FALSE, time);

	if (info == COLOUR) {
		if (selection_length == 8)
			decodeColour ((guint16 *)selection_data, t);
		return;
	}

	if (info == RESET) {
		resetColour (t);
		return;
	}

	fileuri = decodeDropData ((char *)selection_data, info);
	/* Silently ignore bad data. */
	if (fileuri == NULL)
		goto error_exit;

	/* Now that we have a URI we load it and test it to see if it is
	 * an image file. */

	file = g_file_new_for_uri (fileuri);
	istream = g_file_read (file, NULL, &error);

	if (error)
		goto error_exit;

	fileinfo =  g_file_input_stream_query_info (istream, (char *)G_FILE_ATTRIBUTE_STANDARD_SIZE, NULL, &error);

	if (error)
		goto error_exit_handle;

	filesize = g_file_info_get_size (fileinfo);

	buffer = (guchar *)g_malloc (filesize);
	if (buffer == NULL)
		goto error_exit_handle;

	bytesread = g_input_stream_read (G_INPUT_STREAM (istream), buffer, filesize, NULL, &error);

	/* FIXME: We should reread if not enough was read. */
	if (error || (bytesread != filesize))
		goto error_exit_buffer;

	loader = gdk_pixbuf_loader_new ();

	if (!gdk_pixbuf_loader_write (loader, buffer, filesize, NULL))
		goto error_exit_loader;

	gdk_pixbuf_loader_close (loader, NULL);

	pixbuf = gdk_pixbuf_loader_get_pixbuf (loader);
	if (pixbuf == NULL)
		goto error_exit_loader;

	g_object_ref (pixbuf);

	/* We now have an image file, in memory, that we know gdk-pixbuf
	 * can handle. Now we save it to disk. This is necessary so that
	 * "slow" URIs (e.g. http) behave well in the long run. */

	outfile = g_file_new_for_path (t->bgPixmap);
	outstream = g_file_replace (outfile, NULL, FALSE, G_FILE_CREATE_PRIVATE,
					NULL, &error);

	if (error)
		goto error_exit_loader;

	byteswrote = g_output_stream_write (G_OUTPUT_STREAM (outstream), buffer,
						bytesread, NULL, &error);

	if (byteswrote != filesize)
	    goto error_exit_saver;

	t->usebg = TRUE;
	t->saveBgOptions ();

 error_exit_saver:
	g_object_unref(outstream);
 error_exit_loader:
	g_object_unref (loader);
 error_exit_buffer:
	g_free (buffer);
 error_exit_handle:
	g_object_unref(istream);
 error_exit:
	if(error)
		g_error_free(error);
	return;
}

void
Tetris::togglePause()
{
	paused = !paused;

	if (paused)
		field->showPauseMessage();
	else
		field->hidePauseMessage();
}

void
Tetris::generate()
{
	if (field->generateFallingBlock())
	{
		field->putBlockInField(FALLING);
		preview->previewBlock(blocknr_next, color_next, FALSE);
		onePause = true;
	}
	else
	{
		g_source_remove(timeoutId);
		timeoutId = 0;
		blocknr_next = -1;

		endOfGame();
	}
}

void
Tetris::endOfGame()
{
	if (paused) togglePause();
	gtk_action_set_sensitive (pause_action, FALSE);
	gtk_action_set_sensitive (end_game_action, FALSE);
	gtk_action_set_sensitive (preferences_action, TRUE);

	color_next = -1;
	blocknr_next = -1;
	rot_next = -1;
	preview->previewBlock(-1, -1, FALSE);
	field->hidePauseMessage();
	field->showGameOverMessage();
	games_sound_play ("gameover");
	inPlay = false;

	if (scoreFrame->getScore() > 0)
	{
		int pos = high_scores->add (scoreFrame->getScore());
		high_scores->show (GTK_WINDOW (w), pos);
	}
}

int
Tetris::gameNew(GtkAction *action, void *d)
{
	Tetris *t = (Tetris*) d;

	if (t->timeoutId)
	{
		g_source_remove(t->timeoutId);
		t->timeoutId = 0;

		/* Catch the case where we started a new game without
		 * finishing the old one. */
		if ((t->scoreFrame->getScore() > 0) && t->inPlay)
			t->high_scores->add (t->scoreFrame->getScore());
	}

	t->inPlay = true;

	int level = t->cmdlineLevel ? t->cmdlineLevel : t->startingLevel;

	t->fastFall = false;

	t->scoreFrame->setLevel(level);
	t->scoreFrame->setStartingLevel(level);

	t->generateTimer (level);
	t->field->emptyField(t->line_fill_height,t->line_fill_prob);

	t->scoreFrame->resetScore();
	t->paused = false;

	t->field->generateFallingBlock();
	t->field->putBlockInField(FALLING);
	t->preview->previewBlock(blocknr_next, color_next, FALSE);

	gtk_action_set_sensitive(t->pause_action, TRUE);
	gtk_action_set_sensitive(t->end_game_action, TRUE);
	gtk_action_set_sensitive(t->preferences_action, FALSE);

	t->field->hidePauseMessage();
	t->field->hideGameOverMessage();

	games_sound_play ("quadrapassel");

	return TRUE;
}

int
Tetris::gameHelp(GtkAction *action, void *data)
{
	Tetris *t = (Tetris*) data;
	games_help_display(t->getWidget(), "quadrapassel", NULL);
	return TRUE;
}

int
Tetris::gameAbout(GtkAction *action, void *d)
{
	Tetris *t = (Tetris*) d;

	const gchar * const authors[] = { "Gnome Games Team", NULL };

	const gchar * const documenters[] = { "Angela Boyle", NULL };

	gchar *license = games_get_license (_("Quadrapassel"));

	gtk_show_about_dialog (GTK_WINDOW (t->getWidget()),
			       "program-name", _("Quadrapassel"),
			       "version", VERSION,
			       "comments", _("A classic game of fitting falling blocks together.\n\nQuadrapassel is a part of GNOME Games."),
			       "copyright", "Copyright \xc2\xa9 1999 J. Marcin Gorycki, 2000-2009 Others",
			       "license", license,
			       "website-label", _("GNOME Games web site"),
			       "authors", authors,
			       "documenters", documenters,
			       "translator-credits", _("translator-credits"),
			       "logo-icon-name", "gnome-quadrapassel",
			       "website", "http://www.gnome.org/projects/gnome-games/",
			       "wrap-license", TRUE,
			       NULL);
	g_free (license);

	return TRUE;
}

int
Tetris::gameTopTen(GtkAction *action, void *d)
{
	Tetris *t = (Tetris*) d;
	t->high_scores->show(0);

	return TRUE;
}
