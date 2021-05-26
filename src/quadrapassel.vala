/*
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public class Quadrapassel : Gtk.Application
{
    /* Application settings */
    private Settings settings;

    /* Main window */
    private Gtk.Window window;
    private Gtk.MenuButton menu_button;
    private int window_width;
    private int window_height;
    private bool is_maximized;
    private bool is_tiled;

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
    private Gtk.Image pause_play_button_image;

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

        Gtk.Settings.get_default ().set ("gtk-application-prefer-dark-theme", true);

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
        window.set_events (window.get_events () | Gdk.EventMask.KEY_PRESS_MASK | Gdk.EventMask.KEY_RELEASE_MASK);
        window.title = _("Quadrapassel");
        window.size_allocate.connect (size_allocate_cb);
        window.window_state_event.connect (window_state_event_cb);
        window.key_press_event.connect (key_press_event_cb);
        window.key_release_event.connect (key_release_event_cb);
        window.set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));
        if (settings.get_boolean ("window-is-maximized"))
            window.maximize ();

        var headerbar = new Gtk.HeaderBar ();
        headerbar.show_close_button = true;
        headerbar.set_title (_("Quadrapassel"));
        headerbar.show ();
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
        menu_button.set_image (new Gtk.Image.from_icon_name ("open-menu-symbolic", Gtk.IconSize.BUTTON));
        menu_button.show ();
        menu_button.set_menu_model (menu);

        headerbar.pack_end(menu_button);

        var game_grid = new Gtk.Grid ();
        game_grid.set_column_homogeneous (true);
        window.add (game_grid);

        view = new GameView ();
        view.theme = settings.get_string ("theme");
        view.mute = !settings.get_boolean ("sound");
        view.show_shadow = settings.get_boolean ("show-shadow");
        view.game = new Game (20, 10, 1, 20, 10); // Game board size, changed width to 10
        view.show ();
        var game_aspect = new Gtk.AspectFrame (null, 0.5f, 0.5f, 10.0f/20.0f, false); // change to 10 from 14
        game_aspect.show ();
        game_aspect.add (view);
        game_aspect.border_width = 1;
        game_grid.attach (game_aspect, 0, 1, 2, 17);

        pause_play_button = new Gtk.Button ();
        pause_play_button_image = new Gtk.Image.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.DIALOG);
        pause_play_button.add (pause_play_button_image);
        pause_play_button.action_name = "app.new-game";
        pause_play_button.tooltip_text = _("Start a new game");
        pause_play_button.margin = 30;
        pause_play_button_image.show ();
        pause_play_button.show ();

        var preview_frame = new Gtk.AspectFrame (_("Next"), 0.5f, 0.5f, 1.0f, false);
        preview_frame.set_label_align (0.5f, 1.0f);
        preview = new Preview (preview_frame);
        preview.theme = settings.get_string ("theme");
        preview.enabled = settings.get_boolean ("do-preview");
        preview_frame.add (preview);
        preview_frame.show ();
        preview.show ();

        game_grid.attach (preview_frame, 2, 1, 1, 3);
        game_grid.show ();

        var label = new Gtk.Label (null);
        label.set_markup ("<span color='gray'>%s</span>".printf (_("Score")));
        label.set_alignment (0.5f, 0.5f);
        label.show ();
        game_grid.attach (label, 2, 5, 1, 1);
        score_label = new Gtk.Label ("<big>-</big>");
        score_label.set_use_markup (true);
        score_label.set_alignment (0.5f, 0.0f);
        score_label.show ();
        game_grid.attach (score_label, 2, 6, 1, 2);

        label = new Gtk.Label (null);
        label.set_markup ("<span color='gray'>%s</span>".printf (_("Lines")));
        label.set_alignment (0.5f, 0.5f);
        label.show ();
        game_grid.attach (label, 2, 9, 1, 1);
        n_destroyed_label = new Gtk.Label ("<big>-</big>");
        n_destroyed_label.set_use_markup (true);
        n_destroyed_label.set_alignment (0.5f, 0.0f);
        n_destroyed_label.show ();
        game_grid.attach (n_destroyed_label, 2, 10, 1, 2);

        label = new Gtk.Label (null);
        label.set_markup ("<span color='gray'>%s</span>".printf (_("Level")));
        label.set_alignment (0.5f, 0.5f);
        label.show ();
        game_grid.attach (label, 2, 13, 1, 1);
        level_label = new Gtk.Label ("<big>-</big>");
        level_label.set_use_markup (true);
        level_label.set_alignment (0.5f, 0.0f);
        level_label.show ();
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

    private void size_allocate_cb (Gtk.Allocation allocation)
    {
        if (is_maximized || is_tiled)
            return;
        window.get_size (out window_width, out window_height);
    }

    private bool window_state_event_cb (Gdk.EventWindowState event)
    {
        if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
            is_maximized = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;
        /* We don’t save this state, but track it for saving size allocation */
        if ((event.changed_mask & Gdk.WindowState.TILED) != 0)
            is_tiled = (event.new_window_state & Gdk.WindowState.TILED) != 0;
        return false;
    }

    protected override void shutdown ()
    {
        base.shutdown ();

        /* Save window state */
        settings.set_int ("window-width", window_width);
        settings.set_int ("window-height", window_height);
        settings.set_boolean ("window-is-maximized", is_maximized);

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
        preferences_dialog.set_border_width (5);
        var vbox = (Gtk.Box) preferences_dialog.get_content_area ();
        vbox.set_spacing (2);
        preferences_dialog.close.connect (preferences_dialog_close_cb);
        preferences_dialog.response.connect (preferences_dialog_response_cb);

        var notebook = new Gtk.Notebook ();
        notebook.set_border_width (5);
        vbox.pack_start (notebook, true, true, 0);

        var grid = new Gtk.Grid ();
        grid.set_row_spacing (6);
        grid.set_column_spacing (12);
        grid.border_width = 12;
        var label = new Gtk.Label (_("Game"));
        notebook.append_page (grid, label);

        /* pre-filled rows */
        label = new Gtk.Label.with_mnemonic (_("_Number of pre-filled rows:"));
        label.set_alignment (0, 0.5f);
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

        var controls_list = new Gtk.ScrolledWindow (null, null);
        controls_list.border_width = 12;
        controls_list.hscrollbar_policy = Gtk.PolicyType.NEVER;
        controls_list.vscrollbar_policy = Gtk.PolicyType.ALWAYS;
        controls_list.shadow_type = Gtk.ShadowType.IN;
        controls_list.add (controls_view);
        label = new Gtk.Label (_("Controls"));
        notebook.append_page (controls_list, label);

        /* theme page */
        vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        vbox.set_border_width (12);
        label = new Gtk.Label (_("Theme"));
        notebook.append_page (vbox, label);

        var theme_combo = new Gtk.ComboBox ();
        vbox.pack_start (theme_combo, false, true, 0);
        var theme_store = new Gtk.ListStore (2, typeof (string), typeof (string));
        theme_combo.model = theme_store;
        var renderer = new Gtk.CellRendererText ();
        theme_combo.pack_start (renderer, true);
        theme_combo.add_attribute (renderer, "text", 0);

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

        theme_preview = new Preview (null);
        theme_preview.game = new Game ();
        theme_preview.theme = settings.get_string ("theme");
        vbox.pack_start (theme_preview, true, true, 0);

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
            dialog.run ();
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

    private bool key_press_event_cb (Gtk.Widget widget, Gdk.EventKey event)
    {
        var keyval = upper_key (event.keyval);

        if (game.game_over && keyval == upper_key (settings.get_int ("key-start")))
        {
            new_game();
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

    private bool key_release_event_cb (Gtk.Widget widget, Gdk.EventKey event)
    {
        var keyval = upper_key (event.keyval);

        if (game == null)
            return false;

        if (keyval == upper_key (settings.get_int ("key-left")) ||
            keyval == upper_key (settings.get_int ("key-right")))
        {
            game.stop_moving ();
            return true;
        }
        else if (keyval == upper_key (settings.get_int ("key-down")))
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
        game = new Game (20, 10, settings.get_int ("starting-level"), settings.get_int ("line-fill-height"), settings.get_int ("line-fill-probability"), settings.get_boolean ("pick-difficult-blocks"));
        game.pause_changed.connect (pause_changed_cb);
        game.shape_landed.connect (shape_landed_cb);
        game.complete.connect (complete_cb);
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
            pause_play_button_image.set_from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.DIALOG);
            pause_play_button.tooltip_text = _("Unpause the game");
        }
        else
        {
            pause_play_button_image.set_from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.DIALOG);
            pause_play_button.tooltip_text = _("Pause the game");
        }
    }

    private void shape_landed_cb (int[] lines, List<Block> line_blocks)
    {
        update_score ();
    }

    private void complete_cb ()
    {
        pause_action.set_enabled (false);
        pause_play_button_image.set_from_icon_name ("view-refresh-symbolic" , Gtk.IconSize.DIALOG);
        pause_play_button.action_name = "app.new-game";
        pause_play_button.tooltip_text = _("Start a new game");

        if (game.score > 0)
        {
            var date = new DateTime.now_local ();
            var entry = new HistoryEntry (date, game.score);
            history.add (entry);
            history.save ();

            if (show_scores (entry, true) == Gtk.ResponseType.OK)
                new_game ();
        }
    }

    private int show_scores (HistoryEntry? selected_entry = null, bool show_close = false)
    {
        var dialog = new ScoreDialog (history, selected_entry, show_close);
        dialog.modal = true;
        dialog.transient_for = window;

        var result = dialog.run ();
        dialog.destroy ();

        return result;
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
        try
        {
            Gtk.show_uri (window.get_screen (), "help:quadrapassel", Gtk.get_current_event_time ());
        }
        catch (Error e)
        {
            warning ("Failed to show help: %s", e.message);
        }
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
        return app.run (args);
    }
}
