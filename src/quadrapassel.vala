/*
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public class Quadrapassel : Adw.Application
{
    /* Application settings */
    private Settings settings;

    /* Main window */
    private Gtk.Window window;
    private Gtk.EventControllerKey event_controller_key;
    private Gtk.MenuButton menu_button;

    /* AspectFrame for the game */
    private Gtk.AspectFrame game_aspect;

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

    private History history;

    private SimpleAction pause_action;

    private Gtk.Button pause_play_button;

    private Gtk.Dialog preferences_dialog;
    private Gtk.SpinButton starting_level_spin;
    private Preview theme_preview;
    private Gtk.SpinButton fill_height_spinner;
    private Gtk.SpinButton fill_prob_spinner;
    private Gtk.CheckButton do_preview_toggle;
    private Gtk.CheckButton difficult_blocks_toggle;
    private Gtk.CheckButton rotate_counter_clock_wise_toggle;
    private Gtk.CheckButton show_shadow_toggle;
    private Gtk.CheckButton sound_toggle;
    private Gtk.ListStore controls_model;

    private Manette.Monitor manette_monitor;

    private const GLib.ActionEntry[] action_entries =
    {
        { "new-game",      new_game_cb    },
        { "pause",         pause_cb       },
        { "scores",        scores_cb      },
        { "menu",          menu_cb },
        { "preferences",   preferences_cb },
        { "help",          help_cb        },
        { "about",         about_cb       },
        { "quit",          quit_cb        }
    };

    public Quadrapassel ()
    {
        Object (application_id: "org.gnome.Quadrapassel", flags: ApplicationFlags.FLAGS_NONE);
    }

    protected override void startup ()
    {
        base.startup ();

        Adw.StyleManager.get_default ().set_color_scheme (FORCE_DARK);

        add_action_entries (action_entries, this);
        set_accels_for_action ("app.new-game", {"<Primary>n"});
        set_accels_for_action ("app.pause", {"Pause"});
        set_accels_for_action ("app.menu", {"F10"});
        set_accels_for_action ("app.help", {"F1"});
        set_accels_for_action ("app.quit", {"<Primary>q"});
        pause_action = lookup_action ("pause") as SimpleAction;

        settings = new Settings ("org.gnome.Quadrapassel");

        window = new Gtk.ApplicationWindow (this);
        window.icon_name = "org.gnome.Quadrapassel";
        window.title = _("Quadrapassel");

        event_controller_key = new Gtk.EventControllerKey ();
        event_controller_key.key_pressed.connect (key_press_event_cb);
        event_controller_key.key_released.connect (key_release_event_cb);
        ((Gtk.Widget)window).add_controller (event_controller_key);

        window.set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));
        if (settings.get_boolean ("window-is-maximized"))
            window.maximize ();

        var headerbar = new Gtk.HeaderBar ();
        window.set_titlebar (headerbar);

        var menu = new Menu ();
        var section = new Menu ();
        menu.append_section (null, section);
        section.append (_("_New Game"), "app.new-game");
        section.append (_("_Scores"), "app.scores");
        section = new Menu ();
        menu.append_section (null, section);
        section.append (_("_Preferences"), "app.preferences");
        section.append (_("_Help"), "app.help");
        section.append (_("_About Quadrapassel"), "app.about");
        menu_button = new Gtk.MenuButton ();
        menu_button.set_icon_name ("open-menu-symbolic");
        menu_button.set_menu_model (menu);

        headerbar.pack_end (menu_button);

        var game_grid = new Gtk.Grid ();
        window.set_child (game_grid);

        view = new GameView ();
        view.hexpand = true;
        view.vexpand = true;
        view.theme = settings.get_string ("theme");
        view.mute = !settings.get_boolean ("sound");
        view.show_shadow = settings.get_boolean ("show-shadow");
        view.game = new Game (20, 10, 1, 20, 10); // Game board size, changed width to 10
        game_aspect = new Gtk.AspectFrame (0.5f, 0.5f, 10.0f/20.0f, false); // change to 10 from 14
        game_aspect.set_size_request (200, 400);
        game_aspect.set_child (view);
        game_aspect.receives_default = true;
        game_aspect.focusable = true;
        game_aspect.margin_end = 12;
        game_grid.attach (game_aspect, 0, 1, 2, 17);

        pause_play_button = new Gtk.Button ();
        pause_play_button.set_icon_name ("media-playback-start-symbolic");
        pause_play_button.action_name = "app.new-game";
        pause_play_button.tooltip_text = _("Start a new game");
        pause_play_button.add_css_class ("pause-play-button");
        pause_play_button.set_receives_default (false);

        var preview_label = new Gtk.Label (null);
        preview_label.set_markup("<span color='gray'>%s</span>".printf (_("Next")));
        preview_label.halign = CENTER;
        preview_label.valign = CENTER;
        game_grid.attach (preview_label, 2, 0, 1, 1);

        var preview_frame = new Gtk.AspectFrame (0.5f, 0.5f, 1.0f, false);
        preview_frame.hexpand = true;
        preview_frame.vexpand = true;
        preview_frame.set_size_request (120, 120);
        preview = new Preview (preview_frame);
        preview.theme = settings.get_string ("theme");
        preview.enabled = settings.get_boolean ("do-preview");
        preview_frame.set_child (preview);

        game_grid.attach (preview_frame, 2, 1, 1, 3);

        var label = new Gtk.Label (null);
        label.set_markup ("<span color='gray'>%s</span>".printf (_("Score")));
        label.halign = CENTER;
        label.valign = CENTER;
        game_grid.attach (label, 2, 5, 1, 1);
        score_label = new Gtk.Label ("<big>-</big>");
        score_label.use_markup = true;
        score_label.halign = CENTER;
        score_label.valign = CENTER;
        game_grid.attach (score_label, 2, 6, 1, 2);

        label = new Gtk.Label (null);
        label.set_markup ("<span color='gray'>%s</span>".printf (_("Lines")));
        label.halign = CENTER;
        label.valign = CENTER;
        game_grid.attach (label, 2, 9, 1, 1);
        n_destroyed_label = new Gtk.Label ("<big>-</big>");
        n_destroyed_label.set_use_markup (true);
        n_destroyed_label.halign = CENTER;
        n_destroyed_label.valign = CENTER;
        game_grid.attach (n_destroyed_label, 2, 10, 1, 2);

        label = new Gtk.Label (null);
        label.set_markup ("<span color='gray'>%s</span>".printf (_("Level")));
        label.halign = CENTER;
        label.valign = CENTER;
        game_grid.attach (label, 2, 13, 1, 1);
        level_label = new Gtk.Label ("<big>-</big>");
        level_label.use_markup = true;
        level_label.halign = CENTER;
        level_label.valign = CENTER;
        game_grid.attach (level_label, 2, 14, 1, 2);

        game_grid.attach (pause_play_button, 2, 16, 1, 2);

        manette_monitor = new Manette.Monitor ();
        manette_monitor.device_connected.connect (manette_device_connected_cb);
        var manette_iterator = manette_monitor.iterate ();
        Manette.Device manette_device = null;
        while (manette_iterator.next (out manette_device))
            manette_device_connected_cb (manette_device);

        history = new History (Path.build_filename (Environment.get_user_data_dir (), "quadrapassel", "history"));
        history.load ();

        pause_action.set_enabled (false);
    }

    protected override void shutdown ()
    {
        base.shutdown ();

        /* Save window state */
        settings.set_int ("window-width", window.get_width());
        int width, height;
        window.get_default_size (out width, out height);

        /* Save window state */
        settings.set_int ("window-width", width);
        settings.set_int ("window-height", height);
        settings.set_boolean ("window-is-maximized", window.maximized);

        /* Record the score if the game isn't over. */
        if (game != null && !game.game_over && game.score > 0)
        {
            var date = new DateTime.now_local ();
            var entry = new HistoryEntry (date, game.score);
            history.add (entry);
            history.save ();
        }
    }

    protected override void activate ()
    {
        window.present ();
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

    private void preferences_cb ()
    {
        if (preferences_dialog != null)
        {
            preferences_dialog.present ();
            return;
        }

        preferences_dialog = new Gtk.Dialog.with_buttons (_("Preferences"),
                                                          window,
                                                          Gtk.DialogFlags.USE_HEADER_BAR,
                                                          null);
        preferences_dialog.add_css_class ("margin-6");
        var vbox = (Gtk.Box) preferences_dialog.get_content_area ();
        vbox.set_spacing (2);
        preferences_dialog.close.connect (preferences_dialog_close_cb);
        preferences_dialog.response.connect (preferences_dialog_response_cb);

        var notebook = new Gtk.Notebook ();
        notebook.add_css_class ("margin-6");
        vbox.append (notebook);

        var grid = new Gtk.Grid ();
        grid.set_row_spacing (6);
        grid.set_column_spacing (12);
        grid.add_css_class ("margin-12");
        var label = new Gtk.Label (_("Game"));
        notebook.append_page (grid, label);

        /* pre-filled rows */
        label = new Gtk.Label.with_mnemonic (_("_Number of pre-filled rows:"));
        label.valign = CENTER;
        label.halign = START;
        label.set_hexpand (true);
        grid.attach (label, 0, 0, 1, 1);

        var adj = new Gtk.Adjustment (settings.get_int ("line-fill-height"), 0, 15, 1, 5, 0);
        // the maximum should be at least 4 less than the new game height but as long as the game height is a magic 20 and not a setting, we can keep it at 15
        fill_height_spinner = new Gtk.SpinButton (adj, 10, 0);
        fill_height_spinner.set_update_policy (Gtk.SpinButtonUpdatePolicy.ALWAYS);
        fill_height_spinner.set_snap_to_ticks (true);
        fill_height_spinner.value_changed.connect (fill_height_spinner_value_changed_cb);
        grid.attach (fill_height_spinner, 1, 0, 1, 1);
        label.set_mnemonic_widget (fill_height_spinner);

        /* pre-filled rows density */
        label = new Gtk.Label.with_mnemonic (_("_Density of blocks in a pre-filled row:"));
        label.valign = CENTER;
        label.halign = START;
        label.hexpand = true;
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
        label.valign = CENTER;
        label.halign = START;
        label.hexpand = true;
        grid.attach (label, 0, 2, 1, 1);

        adj = new Gtk.Adjustment (settings.get_int ("starting-level"), 1, 20, 1, 5, 0);
        starting_level_spin = new Gtk.SpinButton (adj, 10.0, 0);
        starting_level_spin.set_update_policy (Gtk.SpinButtonUpdatePolicy.ALWAYS);
        starting_level_spin.set_snap_to_ticks (true);
        starting_level_spin.value_changed.connect (starting_level_value_changed_cb);
        grid.attach (starting_level_spin, 1, 2, 1, 1);
        label.set_mnemonic_widget (starting_level_spin);

        sound_toggle = new Gtk.CheckButton.with_mnemonic (_("_Enable sounds"));
        sound_toggle.set_active (settings.get_boolean ("sound"));
        sound_toggle.toggled.connect (sound_toggle_toggled_cb);
        grid.attach (sound_toggle, 0, 3, 2, 1);

        difficult_blocks_toggle = new Gtk.CheckButton.with_mnemonic (_("Choose difficult _blocks"));
        difficult_blocks_toggle.set_active (settings.get_boolean ("pick-difficult-blocks"));
        difficult_blocks_toggle.toggled.connect (difficult_blocks_toggled_cb);
        grid.attach (difficult_blocks_toggle, 0, 4, 2, 1);

        do_preview_toggle = new Gtk.CheckButton.with_mnemonic (_("_Preview next block"));
        do_preview_toggle.set_active (settings.get_boolean ("do-preview"));
        do_preview_toggle.toggled.connect (do_preview_toggle_toggled_cb);
        grid.attach (do_preview_toggle, 0, 5, 2, 1);

        /* rotate counter clock wise */
        rotate_counter_clock_wise_toggle = new Gtk.CheckButton.with_mnemonic (_("_Rotate blocks counterclockwise"));
        rotate_counter_clock_wise_toggle.set_active (settings.get_boolean ("rotate-counter-clock-wise"));
        rotate_counter_clock_wise_toggle.toggled.connect (set_rotate_counter_clock_wise);
        grid.attach (rotate_counter_clock_wise_toggle, 0, 6, 2, 1);

        show_shadow_toggle = new Gtk.CheckButton.with_mnemonic (_("Show _where the block will land"));
        show_shadow_toggle.set_active (settings.get_boolean ("show-shadow"));
        show_shadow_toggle.toggled.connect (user_target_toggled_cb);
        grid.attach (show_shadow_toggle, 0, 7, 2, 1);

        /* controls page */
        controls_model = new Gtk.ListStore (4, typeof (string), typeof (string), typeof (uint), typeof (uint));
        Gtk.TreeIter iter;
        controls_model.append (out iter);
        var keyval = settings.get_int ("key-left");
        controls_model.set (iter, 0, "key-left", 1, _("Move left"), 2, keyval);
        controls_model.append (out iter);
        keyval = settings.get_int ("key-right");
        controls_model.set (iter, 0, "key-right", 1, _("Move right"), 2, keyval);
        controls_model.append (out iter);
        keyval = settings.get_int ("key-down");
        controls_model.set (iter, 0, "key-down", 1, _("Move down"), 2, keyval);
        controls_model.append (out iter);
        keyval = settings.get_int ("key-drop");
        controls_model.set (iter, 0, "key-drop", 1, _("Drop"), 2, keyval);
        controls_model.append (out iter);
        keyval = settings.get_int ("key-rotate");
        controls_model.set (iter, 0, "key-rotate", 1, _("Rotate"), 2, keyval);
        controls_model.append (out iter);
        keyval = settings.get_int ("key-pause");
        controls_model.set (iter, 0, "key-pause", 1, _("Pause"), 2, keyval);
        var controls_view = new Gtk.TreeView.with_model (controls_model);
        controls_view.headers_visible = false;
        controls_view.enable_search = false;
        var label_renderer = new Gtk.CellRendererText ();
        controls_view.insert_column_with_attributes (-1, "Control", label_renderer, "text", 1);
        var key_renderer = new Gtk.CellRendererAccel ();
        key_renderer.editable = true;
        key_renderer.accel_mode = Gtk.CellRendererAccelMode.OTHER;
        key_renderer.accel_edited.connect (accel_edited_cb);
        key_renderer.accel_cleared.connect (accel_cleared_cb);
        controls_view.insert_column_with_attributes (-1, "Key", key_renderer, "accel-key", 2, "accel-mods", 3);

        var controls_list = new Gtk.ScrolledWindow ();
        controls_list.add_css_class ("margin-12");

        controls_list.hscrollbar_policy = Gtk.PolicyType.NEVER;
        controls_list.vscrollbar_policy = Gtk.PolicyType.ALWAYS;
        controls_list.set_child (controls_view);
        label = new Gtk.Label (_("Controls"));
        notebook.append_page (controls_list, label);

        /* theme page */
        vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        vbox.add_css_class ("margin-12");
        label = new Gtk.Label (_("Theme"));
        notebook.append_page (vbox, label);

        var theme_combo = new Gtk.ComboBoxText ();
        vbox.append (theme_combo);
        var theme_store = new Gtk.ListStore (2, typeof (string), typeof (string));
        theme_combo.model = theme_store;

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

        theme_store.append (out iter);
        theme_store.set (iter, 0, _("Modern"), 1, "modern", -1);
        if (settings.get_string ("theme") == "modern")
            theme_combo.set_active_iter (iter);

        theme_combo.changed.connect (theme_combo_changed_cb);

        var theme_preview_frame = new Gtk.AspectFrame (0.5f, 0.5f, 1.0f, false);
        theme_preview_frame.hexpand = true;
        theme_preview_frame.vexpand = true;
        theme_preview_frame.set_size_request (120, 120);
        theme_preview = new Preview (theme_preview_frame);
        theme_preview.theme = settings.get_string ("theme");
        theme_preview.game = new Game ();
        theme_preview_frame.set_child (theme_preview);
        theme_preview.theme = settings.get_string ("theme");
        vbox.append (theme_preview_frame);

        preferences_dialog.show ();
    }

    private void sound_toggle_toggled_cb ()
    {
        var play_sound = sound_toggle.get_active ();
        settings.set_boolean ("sound", play_sound);
        view.mute = !play_sound;
    }

    private void do_preview_toggle_toggled_cb ()
    {
        var preview_enabled = do_preview_toggle.get_active ();
        settings.set_boolean ("do-preview", preview_enabled);
        preview.enabled = preview_enabled;
    }

    private void difficult_blocks_toggled_cb ()
    {
        settings.set_boolean ("pick-difficult-blocks", difficult_blocks_toggle.get_active ());
    }

    private void set_rotate_counter_clock_wise ()
    {
        settings.set_boolean ("rotate-counter-clock-wise", rotate_counter_clock_wise_toggle.get_active ());
    }

    private void user_target_toggled_cb ()
    {
        var show_shadow = show_shadow_toggle.get_active ();
        settings.set_boolean ("show-shadow", show_shadow);
        view.show_shadow = show_shadow;
    }

    private void accel_edited_cb (Gtk.CellRendererAccel cell, string path_string, uint keyval, Gdk.ModifierType mask, uint hardware_keycode)
    {
        var path = new Gtk.TreePath.from_string (path_string);
        if (path == null)
            return;

        Gtk.TreeIter iter;
        if (!controls_model.get_iter (out iter, path))
            return;


        if (keyval == settings.get_int ("key-left")|| 
            keyval == settings.get_int ("key-right") || 
            keyval == settings.get_int ("key-down") || 
            keyval == settings.get_int ("key-drop") || 
            keyval == settings.get_int ("key-rotate") || 
            keyval == settings.get_int ("key-pause"))
        {
            // Throw up a dialog
            var dialog = new Gtk.MessageDialog (null, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.OK, _("Unable to change key, as this key already exists"));
            dialog.set_title (Environment.get_application_name ());
            dialog.show ();
            dialog.destroy ();
            return;
        }
        else
        {
            string? key = null;
            controls_model.get (iter, 0, out key);
            if (key == null)
                return;

            controls_model.set (iter, 2, keyval);
            settings.set_int (key, (int) keyval);
        }
    }

    private void accel_cleared_cb (Gtk.CellRendererAccel cell, string path_string)
    {
        var path = new Gtk.TreePath.from_string (path_string);
        if (path == null)
            return;

        Gtk.TreeIter iter;
        if (!controls_model.get_iter (out iter, path))
            return;

        string? key = null;
        controls_model.get (iter, 0, out key);
        if (key == null)
            return;

        controls_model.set (iter, 2, 0);
        settings.set_int (key, 0);
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
            game.paused = !game.paused;
    }

    private void quit_cb ()
    {
        window.destroy ();
    }

    private void manette_device_connected_cb (Manette.Device manette_device)
    {
        manette_device.button_press_event.connect (manette_button_press_event_cb);
        manette_device.button_release_event.connect (manette_button_release_event_cb);
    }

    private void manette_button_press_event_cb (Manette.Event event)
    {
        if (game == null)
            return;

        uint16 button;
        if (!event.get_button (out button))
            return;

        if (button == InputEventCode.BTN_START || button == InputEventCode.BTN_SELECT)
        {
            if (!game.game_over)
                game.paused = !game.paused;
            return;
        }

        if (game.paused)
            return;

        if (button == InputEventCode.BTN_DPAD_LEFT)
        {
            game.move_left ();
            return;
        }
        else if (button == InputEventCode.BTN_DPAD_RIGHT)
        {
            game.move_right ();
            return;
        }
        else if (button == InputEventCode.BTN_A)
        {
            game.rotate_left ();
            return;
        }
        else if (button == InputEventCode.BTN_B)
        {
            game.rotate_right ();
            return;
        }
        else if (button == InputEventCode.BTN_DPAD_DOWN)
        {
            game.set_fast_forward (true);
            return;
        }
        else if (button == InputEventCode.BTN_DPAD_UP)
        {
            game.drop ();
            return;
        }
    }

    private void manette_button_release_event_cb (Manette.Event event)
    {
        if (game == null)
            return;

        uint16 button;
        if (!event.get_button (out button))
            return;

        if (button == InputEventCode.BTN_DPAD_LEFT ||
            button == InputEventCode.BTN_DPAD_RIGHT)
        {
            game.stop_moving ();
            return;
        }
        else if (button == InputEventCode.BTN_DPAD_DOWN)
        {
            game.set_fast_forward (false);
            return;
        }
    }

    private bool key_press_event_cb (Gtk.EventControllerKey controller,
                                     uint keyval,
                                     uint keycode,
                                     Gdk.ModifierType state)
    {
        keyval = upper_key (keyval);

        if (game != null)
        {
            if (game.game_over && keyval == upper_key (settings.get_int ("key-start")))
            {
                new_game();
            }
        }

        if (game == null) {
            // Pressing pause with no game will start a new game.
            if (keyval == upper_key (settings.get_int ("key-pause")))
            {
                new_game ();
                return true;
            }

            return false;
        }

        if (keyval == upper_key (settings.get_int ("key-pause")))
        {
            if (!game.game_over)
                game.paused = !game.paused;
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

    private void key_release_event_cb (Gtk.EventControllerKey controller,
                                       uint keyval1,
                                       uint keycode,
                                       Gdk.ModifierType state)
    {
        var keyval = upper_key (keyval1);

        if (game == null)
            return;

        if (keyval == upper_key (settings.get_int ("key-left")) ||
            keyval == upper_key (settings.get_int ("key-right")))
        {
            game.stop_moving ();
            return;
        }
        else if (keyval == upper_key (settings.get_int ("key-down")))
        {
            game.set_fast_forward (false);
            return;
        }
    }

    private uint upper_key (uint keyval)
    {
        if (keyval > 255)
            return keyval;
        return ((char) keyval).toupper ();
    }

    private void new_game_cb ()
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

        // Set game dimension, change to 10
        game = new Game (20, 10,
                         settings.get_int ("starting-level"),
                         settings.get_int ("line-fill-height"),
                         settings.get_int ("line-fill-probability"),
                         settings.get_boolean ("pick-difficult-blocks"));

        game.pause_changed.connect (pause_changed_cb);
        game.shape_landed.connect (shape_landed_cb);
        game.complete.connect (complete_cb);
        game_aspect.grab_focus();
        preview.game = game;
        view.game = game;

        game.start ();

        update_score ();
        pause_action.set_enabled (true);
        pause_play_button.action_name = "app.pause";
    }

    private void pause_changed_cb ()
    {
        if (game.paused)
        {
            pause_play_button.set_icon_name ("media-playback-start-symbolic");
            pause_play_button.tooltip_text = _("Unpause the game");
        }
        else
        {
            pause_play_button.set_icon_name ("media-playback-pause-symbolic");
            pause_play_button.tooltip_text = _("Pause the game");

            // Focus the game aspect again
            game_aspect.grab_focus();
        }
    }

    private void shape_landed_cb (int[] lines, List<Block> line_blocks)
    {
        update_score ();
    }

    private void complete_cb ()
    {
        pause_action.set_enabled (false);
        pause_play_button.set_icon_name ("view-refresh-symbolic");
        pause_play_button.action_name = "app.new-game";
        pause_play_button.tooltip_text = _("Start a new game");

        if (game.score > 0)
        {
            var date = new DateTime.now_local ();
            var entry = new HistoryEntry (date, game.score);
            history.add (entry);
            history.save ();

            show_scores(entry, true);
        }
    }

    private void score_dialog_cb(Gtk.Dialog dialog, int response) {
        if (response == Gtk.ResponseType.OK) {
            new_game();
        }

        dialog.destroy();
    }

    private void show_scores (HistoryEntry? selected_entry = null, bool show_close = false)
    {
        var dialog = new ScoreDialog (history, selected_entry, show_close);
        dialog.modal = true;
        dialog.transient_for = window;
        dialog.response.connect(score_dialog_cb);
        dialog.show();
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

        score_label.set_markup ("<big>%d</big>".printf (score));
        level_label.set_markup ("<big>%d</big>".printf (level));
        n_destroyed_label.set_markup ("<big>%d</big>".printf (n_lines_destroyed));
    }

    private void help_cb ()
    {
        Gtk.show_uri (window, "help:quadrapassel", Gdk.CURRENT_TIME);
    }

    private void about_cb ()
    {
        string[] authors = { "GNOME Games Team", "Maintainer: John Ward<john@johnward.net>", null };
        string[] documenters = { "Angela Boyle", null };

        Gtk.show_about_dialog (window,
                               "program-name", _("Quadrapassel"),
                               "version", VERSION,
                               "comments", _("A classic game where you rotate blocks to make complete rows, but don't pile your blocks too high or it's game over!"),
                               "copyright", "Copyright © 1999 J. Marcin Gorycki, 2000–2015 Others",
                               "license-type", Gtk.License.GPL_2_0,
                               "authors", authors,
                               "documenters", documenters,
                               "translator-credits", _("translator-credits"),
                               "logo-icon-name", "org.gnome.Quadrapassel",
                               "website", "https://wiki.gnome.org/Apps/Quadrapassel",
                               null);
    }

    private void menu_cb ()
    {
        menu_button.activate ();
    }

    private void scores_cb ()
    {
        show_scores ();
    }

    public static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        Environment.set_application_name (_("Quadrapassel"));

        Gtk.Window.set_default_icon_name ("quadrapassel");
        var app = new Quadrapassel ();
        return app.run (args);
    }
}
