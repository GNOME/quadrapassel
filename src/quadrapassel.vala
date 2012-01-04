public class Quadrapassel
{
    /* Application settings */
    private Settings settings;

    /* Main window */
    private Gtk.Window main_window;

    /* Game being played */
    private Game? game = null;

    /* Rendering of game */
    private GameView view;

    /* Preview of the next shape */
    private Preview preview;

    /* Label showing current score */
    private Gtk.Label score_label;

    /* Label showing the number of lines destroyed */
    private Gtk.Label n_destroyed_label;

    /* Label showing the current level */
    private Gtk.Label level_label;

    private GnomeGamesSupport.Scores high_scores;

    private GnomeGamesSupport.PauseAction pause_action;

    private Gtk.Dialog preferences_dialog;
    private Gtk.SpinButton starting_level_spin;
    private Preview theme_preview;
    private Gtk.SpinButton fill_height_spinner;
    private Gtk.SpinButton fill_prob_spinner;
    private Gtk.CheckButton do_preview_toggle;
    private Gtk.CheckButton difficult_blocks_toggle;
    private Gtk.CheckButton rotate_counter_clock_wise_toggle;
    private Gtk.CheckButton use_target_toggle;
    private Gtk.CheckButton sound_toggle;

    private const Gtk.ActionEntry actions[] =
    {
        { "GameMenu", null, N_("_Game") },
        { "SettingsMenu", null, N_("_Settings") },
        { "HelpMenu", null, N_("_Help") },
        { "NewGame", GnomeGamesSupport.STOCK_NEW_GAME, null, null, null, new_game_cb },
        { "Scores", GnomeGamesSupport.STOCK_SCORES, null, null, null, scores_cb },
        { "Quit", Gtk.Stock.QUIT, null, null, null, quit_cb },
        { "Preferences", Gtk.Stock.PREFERENCES, null, null, null, preferences_cb },
        { "Contents", GnomeGamesSupport.STOCK_CONTENTS, null, null, null, help_cb },
        { "About", Gtk.Stock.ABOUT, null, null, null, about_cb }
    };

    public Quadrapassel ()
    {
        var ui_description =
        "<ui>" +
        "  <menubar name='MainMenu'>" +
        "    <menu action='GameMenu'>" +
        "      <menuitem action='NewGame'/>" +
        "      <menuitem action='_pause'/>" +
        "      <separator/>" +
        "      <menuitem action='Scores'/>" +
        "      <separator/>" +
        "      <menuitem action='Quit'/>" +
        "    </menu>" +
        "    <menu action='SettingsMenu'>" +
        "      <menuitem action='Preferences'/>" +
        "    </menu>" +
        "    <menu action='HelpMenu'>" +
        "      <menuitem action='Contents'/>" +
        "      <menuitem action='About'/>" +
        "    </menu>" +
        "  </menubar>" +
        "</ui>";

        settings = new Settings ("org.gnome.quadrapassel");

        main_window = new Gtk.Window (Gtk.WindowType.TOPLEVEL);
        main_window.set_title (_("Quadrapassel"));

        main_window.delete_event.connect (window_delete_event_cb);

        main_window.set_default_size (500, 550);
        //games_conf_add_window (main_window, KEY_SAVED_GROUP);

        view = new GameView ();
        view.theme = settings.get_string ("theme");
        view.mute = !settings.get_boolean ("sound");

        preview = new Preview ();
        preview.theme = settings.get_string ("theme");
        preview.enabled = settings.get_boolean ("do-preview");

        /* prepare menus */
        GnomeGamesSupport.stock_init ();
        var action_group = new Gtk.ActionGroup ("MenuActions");
        action_group.set_translation_domain (GETTEXT_PACKAGE);
        action_group.add_actions (actions, this);
        var ui_manager = new Gtk.UIManager ();
        ui_manager.insert_action_group (action_group, 0);
        try
        {
            ui_manager.add_ui_from_string (ui_description, -1);
        }
        catch (Error e)
        {
        }
        main_window.add_accel_group (ui_manager.get_accel_group ());

        pause_action = new GnomeGamesSupport.PauseAction ("_pause");
        pause_action.state_changed.connect (pause_cb);
        action_group.add_action_with_accel (pause_action, null);

        var menubar = ui_manager.get_widget ("/MainMenu");

        var hb = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        main_window.add (vbox);
        vbox.pack_start (menubar, false, false, 0);
        vbox.pack_start (hb, true, true, 0);

        main_window.set_events (main_window.get_events () | Gdk.EventMask.KEY_PRESS_MASK | Gdk.EventMask.KEY_RELEASE_MASK);

        var vb1 = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        vb1.set_border_width (10);
        vb1.pack_start (view, true, true, 0);
        hb.pack_start (vb1, true, true, 0);

        main_window.key_press_event.connect (key_press_event_cb);
        main_window.key_release_event.connect (key_release_event_cb);

        var vb2 = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        vb2.set_border_width (10);
        hb.pack_end (vb2, false, false, 0);

        vb2.pack_start (preview, false, false, 0);

        var score_grid = new Gtk.Grid ();

        var label = new Gtk.Label (_("Score:"));
        label.set_alignment (0.0f, 0.5f);
        score_grid.attach (label, 0, 0, 1, 1);
        score_label = new Gtk.Label ("0");
        score_label.set_alignment (1.0f, 0.5f);
        score_grid.attach (score_label, 1, 0, 1, 1);

        label = new Gtk.Label (_("Lines:"));
        label.set_alignment (0.0f, 0.5f);
        score_grid.attach (label, 0, 1, 1, 1);
        n_destroyed_label = new Gtk.Label ("0");
        n_destroyed_label.set_alignment (1.0f, 0.5f);
        score_grid.attach (n_destroyed_label, 1, 1, 1, 1);

        label = new Gtk.Label (_("Level:"));
        label.set_alignment (0.0f, 0.5f);
        score_grid.attach (label, 0, 2, 1, 1);
        level_label = new Gtk.Label ("0");
        level_label.set_alignment (1.0f, 0.5f);
        score_grid.attach (level_label, 1, 2, 1, 1);

        vb2.pack_end (score_grid, true, false, 0);

        high_scores = new GnomeGamesSupport.Scores ("quadrapassel",
                                                    new GnomeGamesSupport.ScoresCategory[0],
                                                    null,
                                                    null,
                                                    0,
                                                    GnomeGamesSupport.ScoreStyle.PLAIN_DESCENDING);

        pause_action.sensitive = false;
    }

    public void show ()
    {
        main_window.show_all ();
    }

    private void preferences_dialog_close_cb ()
    {
        preferences_dialog.destroy ();
        preferences_dialog = null;
    }

    private void preferences_dialog_response_cb (int response_id)
    {
        preferences_dialog_close_cb ();
    }

    private void preferences_cb (Gtk.Action action)
    {
        if (preferences_dialog != null)
        {
            preferences_dialog.present ();
            return;
        }

        preferences_dialog = new Gtk.Dialog.with_buttons (_("Quadrapassel Preferences"), main_window, (Gtk.DialogFlags)0, Gtk.Stock.CLOSE, Gtk.ResponseType.CLOSE, null);
        preferences_dialog.set_border_width (5);
        var vbox = (Gtk.Box) preferences_dialog.get_content_area ();
        vbox.set_spacing (2);
        preferences_dialog.close.connect (preferences_dialog_close_cb);
        preferences_dialog.response.connect (preferences_dialog_response_cb);

        var notebook = new Gtk.Notebook ();
        notebook.set_border_width (5);
        vbox.pack_start (notebook, true, true, 0);

        vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 18);
        vbox.set_border_width (12);
        var label = new Gtk.Label (_("Game"));
        notebook.append_page (vbox, label);

        var frame = new GnomeGamesSupport.Frame (_("Setup"));
        var grid = new Gtk.Grid ();
        grid.set_row_spacing (6);
        grid.set_column_spacing (12);

        /* pre-filled rows */
        label = new Gtk.Label.with_mnemonic (_("_Number of pre-filled rows:"));
        label.set_alignment (0, 0.5f);
        label.set_hexpand (true);
        grid.attach (label, 0, 0, 1, 1);

        var adj = new Gtk.Adjustment (settings.get_int ("line-fill-height"), 0, game.height - 1, 1, 5, 0);
        fill_height_spinner = new Gtk.SpinButton (adj, 10, 0);
        fill_height_spinner.set_update_policy (Gtk.SpinButtonUpdatePolicy.ALWAYS);
        fill_height_spinner.set_snap_to_ticks (true);
        fill_height_spinner.value_changed.connect (fill_height_spinner_value_changed_cb);
        grid.attach (fill_height_spinner, 1, 0, 2, 1);
        label.set_mnemonic_widget (fill_height_spinner);

        /* pre-filled rows density */
        label = new Gtk.Label.with_mnemonic (_("_Density of blocks in a pre-filled row:"));
        label.set_alignment (0, 0.5f);
        label.set_hexpand (true);
        grid.attach (label, 0, 1, 1, 1);

        adj = new Gtk.Adjustment (settings.get_int ("line-fill-probability"), 0, 10, 1, 5, 0);
        fill_prob_spinner = new Gtk.SpinButton (adj, 10, 0);
        fill_prob_spinner.set_update_policy (Gtk.SpinButtonUpdatePolicy.ALWAYS);
        fill_prob_spinner.set_snap_to_ticks (true);
        fill_prob_spinner.value_changed.connect (fill_prob_spinner_value_changed_cb);
        grid.attach (fill_prob_spinner, 1, 1, 1, 1);
        label.set_mnemonic_widget (fill_prob_spinner);

        /* starting level */
        label = new Gtk.Label.with_mnemonic (_("_Starting level:"));
        label.set_alignment (0, 0.5f);
        label.set_hexpand (true);
        grid.attach (label, 0, 2, 1, 1);

        adj = new Gtk.Adjustment (settings.get_int ("starting-level"), 1, 20, 1, 5, 0);
        starting_level_spin = new Gtk.SpinButton (adj, 10.0, 0);
        starting_level_spin.set_update_policy (Gtk.SpinButtonUpdatePolicy.ALWAYS);
        starting_level_spin.set_snap_to_ticks (true);
        starting_level_spin.value_changed.connect (starting_level_value_changed_cb);
        grid.attach (starting_level_spin, 1, 2, 1, 1);
        label.set_mnemonic_widget (starting_level_spin);

        frame.add (grid);
        vbox.pack_start (frame, false, false, 0);

        frame = new GnomeGamesSupport.Frame (_("Operation"));
        var fvbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);

        sound_toggle = new Gtk.CheckButton.with_mnemonic (_("_Enable sounds"));
        sound_toggle.set_active (settings.get_boolean ("sound"));
        sound_toggle.toggled.connect (sound_toggle_toggled_cb);
        fvbox.pack_start (sound_toggle, false, false, 0);

        do_preview_toggle = new Gtk.CheckButton.with_mnemonic (_("_Preview next block"));
        do_preview_toggle.set_active (settings.get_boolean ("do-preview"));
        do_preview_toggle.toggled.connect (do_preview_toggle_toggled_cb);
        fvbox.pack_start (do_preview_toggle, false, false, 0);

        difficult_blocks_toggle = new Gtk.CheckButton.with_mnemonic (_("Choose difficult _blocks"));
        difficult_blocks_toggle.set_active (settings.get_boolean ("pick-difficult-blocks"));
        difficult_blocks_toggle.toggled.connect (difficult_blocks_toggled_cb);
        fvbox.pack_start (difficult_blocks_toggle, false, false, 0);

        /* rotate counter clock wise */
        rotate_counter_clock_wise_toggle = new Gtk.CheckButton.with_mnemonic (_("_Rotate blocks counterclockwise"));
        rotate_counter_clock_wise_toggle.set_active (settings.get_boolean ("rotate-counter-clock-wise"));
        rotate_counter_clock_wise_toggle.toggled.connect (set_rotate_counter_clock_wise);
        fvbox.pack_start (rotate_counter_clock_wise_toggle, false, false, 0);

        use_target_toggle = new Gtk.CheckButton.with_mnemonic (_("Show _where the block will land"));
        fvbox.pack_start (use_target_toggle, false, false, 0);

        frame.add (fvbox);
        vbox.pack_start (frame, false, false, 0);

        frame = new GnomeGamesSupport.Frame (_("Theme"));
        grid = new Gtk.Grid ();
        grid.set_border_width (0);
        grid.set_row_spacing (6);
        grid.set_column_spacing (12);

        /* controls page */
        vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        vbox.set_border_width (12);
        label = new Gtk.Label (_("Controls"));
        notebook.append_page (vbox, label);

        frame = new GnomeGamesSupport.Frame (_("Keyboard Controls"));
        vbox.pack_start (frame, true, true, 0);

        fvbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        frame.add (fvbox);

        var controls_list = new GnomeGamesSupport.ControlsList (settings);
        controls_list.add_controls ("key-left", _("Move left"), 0,
                                    "key-right", _("Move right"), 0,
                                    "key-down", _("Move down"), 0,
                                    "key-drop", _("Drop"), 0,
                                    "key-rotate", _("Rotate"), 0,
                                    "key-pause", _("_pause"), 0,
                                    null);

        fvbox.pack_start (controls_list, true, true, 0);

        /* theme page */
        vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        vbox.set_border_width (12);
        label = new Gtk.Label (_("Theme"));
        notebook.append_page (vbox, label);

        frame = new GnomeGamesSupport.Frame (_("Block Style"));
        vbox.pack_start (frame, true, true, 0);

        fvbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        frame.add (fvbox);

        var theme_combo = new Gtk.ComboBox ();
        var theme_store = new Gtk.ListStore (2, typeof (string), typeof (string));
        theme_combo.model = theme_store;
        var renderer = new Gtk.CellRendererText ();
        theme_combo.pack_start (renderer, true);
        theme_combo.add_attribute (renderer, "text", 0);

        Gtk.TreeIter iter;

        theme_store.append (out iter);
        theme_store.set (iter, 0, _("Plain"), 1, "plain", -1);
        if (settings.get_string ("theme") == "plain")
            theme_combo.set_active_iter (iter);

        theme_store.append (out iter);
        theme_store.set (iter, 0, _("Tango Flat"), 1, "tangoflat", -1);
        if (settings.get_string ("theme") == "tangoflat")
            theme_combo.set_active_iter (iter);

        theme_store.append (out iter);
        theme_store.set (iter, 0, _("Tango Shaded"), 1, "tangoshaded", -1);
        if (settings.get_string ("theme") == "tangoshaded")
            theme_combo.set_active_iter (iter);

        theme_store.append (out iter);
        theme_store.set (iter, 0, _("Clean"), 1, "clean", -1);
        if (settings.get_string ("theme") == "clean")
            theme_combo.set_active_iter (iter);

        theme_combo.changed.connect (theme_combo_changed_cb);
        fvbox.pack_start (theme_combo, false, false, 0);

        theme_preview = new Preview ();
        theme_preview.game = new Game ();
        theme_preview.theme = settings.get_string ("theme");
        fvbox.pack_start (theme_preview, true, true, 0);

        preferences_dialog.show_all ();
    }

    private void sound_toggle_toggled_cb ()
    {
        var play_sound = sound_toggle.get_active ();
        settings.set_boolean ("sound", play_sound);
        view.mute = !play_sound;
    }

    private void do_preview_toggle_toggled_cb ()
    {
        var do_preview = do_preview_toggle.get_active ();
        settings.set_boolean ("do-preview", do_preview);
        preview.enabled = do_preview;
    }

    private void difficult_blocks_toggled_cb ()
    {
        settings.set_boolean ("pick-difficult-blocks", difficult_blocks_toggle.get_active ());
    }

    private void set_rotate_counter_clock_wise ()
    {
        settings.set_boolean ("rotate-counter-clock-wise", rotate_counter_clock_wise_toggle.get_active ());
    }

    private void theme_combo_changed_cb (Gtk.ComboBox widget)
    {
        Gtk.TreeIter iter;
        widget.get_active_iter (out iter);
        string theme;
        widget.model.get (iter, 1, out theme);
        view.theme = theme;
        preview.theme = theme;
        if (theme_preview != null)
            theme_preview.theme = theme;
        settings.set_string ("theme", theme);
    }

    private void fill_height_spinner_value_changed_cb (Gtk.SpinButton spin)
    {
        int value = spin.get_value_as_int ();
        settings.set_int ("line-fill-height", value);
    }

    private void fill_prob_spinner_value_changed_cb (Gtk.SpinButton spin)
    {
        int value = spin.get_value_as_int ();
        settings.set_int ("line-fill-probability", value);
    }

    private void starting_level_value_changed_cb (Gtk.SpinButton spin)
    {
        int value = spin.get_value_as_int ();
        settings.set_int ("starting-level", value);
    }

    private void pause_cb ()
    {
        if (game != null)
            game.paused = pause_action.get_is_paused ();
    }

    private bool window_delete_event_cb (Gtk.Widget window, Gdk.EventAny event)
    {
        quit ();
        return true;
    }

    private void quit_cb (Gtk.Action action)
    {
        quit ();
    }

    private void quit ()
    {
        /* Record the score if the game isn't over. */
        if (game != null && game.score > 0)
            high_scores.add_plain_score (game.score);

        Gtk.main_quit ();
    }

    private bool key_press_event_cb (Gtk.Widget widget, Gdk.EventKey event)
    {
        var keyval = upper_key (event.keyval);

        if (game == null)
            return false;

        if (keyval == upper_key (settings.get_int ("key-pause")))
        {
            pause_action.set_is_paused (!pause_action.get_is_paused ());
            return true;
        }

        if (game.paused)
            return false;

        if (keyval == upper_key (settings.get_int ("key-left")))
        {
            game.move_left ();
            return true;
        }
        else if (keyval == upper_key (settings.get_int ("key-right")))
        {
            game.move_right ();
            return true;
        }
        else if (keyval == upper_key (settings.get_int ("key-rotate")))
        {
            if (settings.get_boolean ("rotate-counter-clock-wise"))
                game.rotate_left ();
            else
                game.rotate_right ();
            return true;
        }
        else if (keyval == upper_key (settings.get_int ("key-down")))
        {
            game.set_fast_forward (true);
            return true;
        }
        else if (keyval == upper_key (settings.get_int ("key-drop")))
        {
            game.drop ();
            return true;
        }

        return false;
    }

    private bool key_release_event_cb (Gtk.Widget widget, Gdk.EventKey event)
    {
        var keyval = upper_key (event.keyval);

        if (game == null)
            return false;

        if (keyval == upper_key (settings.get_int ("key-down")))
        {
            game.set_fast_forward (false);
            return true;
        }

        return false;
    }

    private uint upper_key (uint keyval)
    {
        if (keyval > 255)
            return keyval;
        return ((char) keyval).toupper ();
    }

    private void new_game_cb (Gtk.Action action)
    {
        new_game ();
    }
    
    private void new_game ()
    {
        if (game != null)
        {
            game.stop ();
            SignalHandler.disconnect_matched (game, SignalMatchType.DATA, 0, 0, null, null, this);
        }

        game = new Game (20, 14, settings.get_int ("starting-level"), settings.get_int ("line-fill-height"), settings.get_int ("line-fill-probability"), settings.get_boolean ("pick-difficult-blocks"));
        game.shape_landed.connect (shape_landed_cb);
        game.complete.connect (complete_cb);
        preview.game = game;
        view.game = game;

        game.start ();

        update_score ();
        pause_action.sensitive = true;
    }

    private void shape_landed_cb (int[] lines, List<Block> line_blocks)
    {
        update_score ();
    }

    private void complete_cb ()
    {
        pause_action.sensitive = false;
        if (game.score > 0)
        {
            var pos = high_scores.add_plain_score (game.score);
            var dialog = new GnomeGamesSupport.ScoresDialog (main_window, high_scores, _("Quadrapassel Scores"));
            var title = _("Puzzle solved!");
            var message = _("You didn't make the top ten, better luck next time.");
            if (pos == 1)
                message = _("Your score is the best!");
            else if (pos > 1)
                message = _("Your score has made the top ten.");
            dialog.set_message ("<b>%s</b>\n\n%s".printf (title, message));
            dialog.set_buttons (GnomeGamesSupport.ScoresButtons.QUIT_BUTTON | GnomeGamesSupport.ScoresButtons.NEW_GAME_BUTTON);
            if (pos > 0)
                dialog.set_hilight (pos);

            switch (dialog.run ())
            {
            case Gtk.ResponseType.REJECT:
                Gtk.main_quit ();
                break;
            default:
                new_game ();
                break;
            }
            dialog.destroy ();
        }
    }

    private void update_score ()
    {
        var score = 0;
        var level = 0;
        var n_lines_destroyed = 0;

        if (game != null)
        {
            score = game.score;
            level = game.level;
            n_lines_destroyed = game.n_lines_destroyed;
        }

        score_label.set_text ("%d".printf (score));
        level_label.set_text ("%d".printf (level));
        n_destroyed_label.set_text ("%d".printf (n_lines_destroyed));
    }

    private void help_cb (Gtk.Action action)
    {
        try
        {
            Gtk.show_uri (main_window.get_screen (), "ghelp:quadrapassel", Gtk.get_current_event_time ());
        }
        catch (Error e)
        {
            warning ("Failed to show help: %s", e.message);
        }
    }

    private void about_cb (Gtk.Action action)
    {
        string[] authors = { "Gnome Games Team", null };
        string[] documenters = { "Angela Boyle", null };

        Gtk.show_about_dialog (main_window,
                               "program-name", _("Quadrapassel"),
                               "version", VERSION,
                               "comments", _("A classic game of fitting falling blocks together.\n\nQuadrapassel is a part of GNOME Games."),
                               "copyright", "Copyright \xc2\xa9 1999 J. Marcin Gorycki, 2000-2009 Others",
                               "license", GnomeGamesSupport.get_license (_("Quadrapassel")),
                               "website-label", _("GNOME Games web site"),
                               "authors", authors,
                               "documenters", documenters,
                               "translator-credits", _("translator-credits"),
                               "logo-icon-name", "quadrapassel",
                               "website", "http://wwmain_window.gnome.org/projects/gnome-games/",
                               "wrap-license", true,
                               null);
    }

    private void scores_cb (Gtk.Action action)
    {
        var dialog = new GnomeGamesSupport.ScoresDialog (main_window, high_scores, _("Quadrapassel Scores"));
        dialog.run ();
        dialog.destroy ();
    }

    public static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        GnomeGamesSupport.scores_startup ();
    
        var context = new OptionContext ("");

        context.add_group (Gtk.get_option_group (true));
        context.add_group (Clutter.get_option_group_without_init ());

        try
        {
            context.parse (ref args);
        }
        catch (Error e)
        {
            stderr.printf ("%s\n", e.message);
            return Posix.EXIT_FAILURE;
        }

        Environment.set_application_name (_("Quadrapassel"));

        Gtk.Window.set_default_icon_name ("quadrapassel");

        try
        {
            GtkClutter.init_with_args (ref args, "", new OptionEntry[0], null);
        }
        catch (Error e)
        {
            var dialog = new Gtk.MessageDialog (null, Gtk.DialogFlags.MODAL, Gtk.MessageType.ERROR, Gtk.ButtonsType.NONE, "Unable to initialize Clutter:\n%s", e.message);
            dialog.set_title (Environment.get_application_name ());
            dialog.run ();
            dialog.destroy ();
            return Posix.EXIT_FAILURE;
        }

        var app = new Quadrapassel ();
        app.show ();

        Gtk.main ();

        return Posix.EXIT_SUCCESS;
    }
}
