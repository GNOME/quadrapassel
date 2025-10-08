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
    private Adw.ApplicationWindow window;
    private Adw.HeaderBar headerbar;
    private Gtk.EventControllerKey event_controller_key;
    private Gtk.GestureSwipe swipe_gesture;
    private Gtk.GestureLongPress long_press_gesture;
    private Gtk.MenuButton menu_button;

    /* Game scores */
    private Games.Scores.Context context;

    /* AspectFrame for the game */
    private Gtk.AspectFrame game_aspect;

    /* Game being played */
    private Game? game = null;

    /* Rendering of game */
    private GameView view;

    /* The grid that holds the game view and stats */
    private Gtk.Grid game_grid;

    /* Preview of the next shape */
    private Preview preview;
    private Gtk.AspectFrame preview_frame;
    private Gtk.Label preview_label;

    /* Label showing current score */
    private Gtk.Label score_label;
    private Gtk.Label score_descriptor_label;

    /* Label showing the number of lines destroyed */
    private Gtk.Label n_destroyed_label;
    private Gtk.Label destroyed_descriptor_label;

    /* Label showing the current level */
    private Gtk.Label level_label;
    private Gtk.Label level_descriptor_label;

    private SimpleAction pause_action;

    private Gtk.Button pause_play_button;
    private Gtk.Button new_game_button;

    private Adw.PreferencesDialog preferences_dialog;
    private Preview theme_preview;

    private Manette.Monitor manette_monitor;
    private bool is_manette_button_down = false;

    private const GLib.ActionEntry[] action_entries =
    {
        { "new-game",      new_game_cb    },
        { "pause",         pause_cb       },
        { "scores",        scores_cb      },
        { "menu",          menu_cb        },
        { "theme",         theme_cb       },
        { "preferences",   preferences_cb },
        { "help",          help_cb        },
        { "about",         about_cb       },
        { "quit",          quit_cb        }
    };

    public Quadrapassel ()
    {
        Object (application_id: APP_ID, flags: ApplicationFlags.FLAGS_NONE, resource_base_path: "/org/gnome/Quadrapassel");
    }

    protected override void startup ()
    {
        base.startup ();

        Adw.StyleManager.get_default ().set_color_scheme (FORCE_DARK);

        Environment.set_application_name (_("Quadrapassel"));

        add_action_entries (action_entries, this);
        set_accels_for_action ("app.new-game", {"<Primary>n"});
        set_accels_for_action ("app.pause", {"Pause"});
        set_accels_for_action ("app.menu", {"F10"});
        set_accels_for_action ("app.help", {"F1"});
        set_accels_for_action ("app.quit", {"<Primary>q"});
        pause_action = lookup_action ("pause") as SimpleAction;

        settings = new Settings (APP_ID);
    }

    private void create_window ()
    {
        var builder = new Gtk.Builder ();
        window = new Adw.ApplicationWindow (this);
        window.set_size_request (360, 525);
        window.icon_name = APP_ID;
        window.title = _("Quadrapassel");

        var breakpoint = new Adw.Breakpoint (new Adw.BreakpointCondition.length (MAX_WIDTH, 380, PX));
        window.add_child (builder, breakpoint, null);

        event_controller_key = new Gtk.EventControllerKey ();
        event_controller_key.key_pressed.connect (key_press_event_cb);
        event_controller_key.key_released.connect (key_release_event_cb);
        ((Gtk.Widget) window).add_controller (event_controller_key);

        swipe_gesture = new Gtk.GestureSwipe ();
        swipe_gesture.swipe.connect (swipe_cb);
        long_press_gesture = new Gtk.GestureLongPress ();
        long_press_gesture.pressed.connect (long_press_cb);

        window.set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));
        if (settings.get_boolean ("window-is-maximized"))
            window.maximize ();

        var toolbar_view = new Adw.ToolbarView ();
        headerbar = new Adw.HeaderBar ();
        toolbar_view.add_child (builder, headerbar, "top");
        window.set_content (toolbar_view);

        new_game_button = new Gtk.Button.from_icon_name ("view-refresh-symbolic");
        new_game_button.set_action_name ("app.new-game");
        new_game_button.set_tooltip_text (_("Start a new game"));

        headerbar.pack_start (new_game_button);

        var menu = new Menu ();
        var section = new Menu ();
        menu.append_section (null, section);
        section.append (_("_Scores"), "app.scores");
        section.append (_("App_earance"), "app.theme");
        section.append (_("_Preferences"), "app.preferences");
        section = new Menu ();
        menu.append_section (null, section);
        section.append (_("_Keyboard Shortcuts"), "app.shortcuts");
        section.append (_("_Help"), "app.help");
        section.append (_("_About Quadrapassel"), "app.about");
        menu_button = new Gtk.MenuButton ();
        menu_button.set_icon_name ("open-menu-symbolic");
        menu_button.set_menu_model (menu);

        headerbar.pack_end (menu_button);

        game_grid = new Gtk.Grid ();
        game_grid.margin_start = 6;
        game_grid.margin_end = 6;
        game_grid.margin_bottom = 6;
        game_grid.column_spacing = 4;
        toolbar_view.set_content (game_grid);
        breakpoint.apply.connect (breakpoint_apply_cb);
        breakpoint.unapply.connect (breakpoint_unapply_cb);

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
        game_aspect.add_controller (swipe_gesture);
        game_aspect.add_controller (long_press_gesture);
        game_aspect.receives_default = true;
        game_aspect.focusable = true;
        game_aspect.margin_start = 6;
        game_aspect.margin_end = 6;
        game_aspect.margin_top = 2;
        game_aspect.margin_bottom = 6;
        game_grid.attach (game_aspect, 0, 0, 2, 17);

        pause_play_button = new Gtk.Button ();
        pause_play_button.set_icon_name ("media-playback-start-symbolic");
        pause_play_button.action_name = "app.new-game";
        pause_play_button.tooltip_text = _("Start a new game");
        pause_play_button.set_receives_default (false);
        headerbar.pack_end (pause_play_button);

        preview_label = new Gtk.Label (null);
        preview_label.set_markup("<span color='gray'>%s</span>".printf (_("Next")));
        preview_label.halign = CENTER;
        preview_label.valign = CENTER;
        game_grid.attach (preview_label, 2, 0, 1, 1);

        preview_frame = new Gtk.AspectFrame (0.5f, 0.5f, 1.0f, false);
        preview_frame.hexpand = true;
        preview_frame.vexpand = true;
        preview_frame.set_size_request (120, 120);
        preview = new Preview (preview_frame);
        preview.theme = settings.get_string ("theme");
        preview.enabled = settings.get_boolean ("do-preview");
        preview_frame.set_child (preview);

        game_grid.attach (preview_frame, 2, 1, 1, 3);

        score_descriptor_label = new Gtk.Label (null);
        score_descriptor_label.set_markup ("<span color='gray'>%s</span>".printf (_("Score")));
        score_descriptor_label.halign = CENTER;
        score_descriptor_label.valign = CENTER;
        game_grid.attach (score_descriptor_label, 2, 5, 1, 1);
        score_label = new Gtk.Label ("<big>-</big>");
        score_label.use_markup = true;
        score_label.halign = CENTER;
        score_label.valign = CENTER;
        game_grid.attach (score_label, 2, 6, 1, 2);

        destroyed_descriptor_label = new Gtk.Label (null);
        destroyed_descriptor_label.set_markup ("<span color='gray'>%s</span>".printf (_("Lines")));
        destroyed_descriptor_label.halign = CENTER;
        destroyed_descriptor_label.valign = CENTER;
        game_grid.attach (destroyed_descriptor_label, 2, 9, 1, 1);
        n_destroyed_label = new Gtk.Label ("<big>-</big>");
        n_destroyed_label.set_use_markup (true);
        n_destroyed_label.halign = CENTER;
        n_destroyed_label.valign = CENTER;
        game_grid.attach (n_destroyed_label, 2, 10, 1, 2);

        level_descriptor_label = new Gtk.Label (null);
        level_descriptor_label.set_markup ("<span color='gray'>%s</span>".printf (_("Level")));
        level_descriptor_label.halign = CENTER;
        level_descriptor_label.valign = CENTER;
        game_grid.attach (level_descriptor_label, 2, 13, 1, 1);
        level_label = new Gtk.Label ("<big>-</big>");
        level_label.use_markup = true;
        level_label.halign = CENTER;
        level_label.valign = CENTER;
        game_grid.attach (level_label, 2, 14, 1, 2);

        context = new Games.Scores.Context.with_importer_and_icon_name ("quadrapassel",
                                                                        /* Label on the scores dialog */
                                                                        _("Difficulty"),
                                                                        window,
                                                                        create_category_from_key,
                                                                        Games.Scores.Style.POINTS_GREATER_IS_BETTER,
                                                                        new Games.Scores.HistoryFileImporter (parse_old_score),
                                                                        APP_ID);

        manette_monitor = new Manette.Monitor ();
        manette_monitor.device_connected.connect (manette_device_connected_cb);
        var manette_iterator = manette_monitor.iterate ();
        Manette.Device manette_device = null;
        while (manette_iterator.next (out manette_device))
            manette_device_connected_cb (manette_device);

        pause_action.set_enabled (false);
        new_game_button.set_sensitive (false);
    }

    protected override void shutdown ()
    {
        base.shutdown ();

        /* Save window state */
        settings.set_int ("window-width", window.get_width());
        int width, height;
        window.get_default_size (out width, out height);

        settings.set_int ("window-width", width);
        settings.set_int ("window-height", height);
        settings.set_boolean ("window-is-maximized", window.maximized);

        /* Record the score if the game isn't over. */
        if (game != null && !game.game_over && game.score > 0)
        {
            context.add_score.begin (game.score, create_category_from_key (game.difficulty.to_string()), null, (object, result) => {
                try
                {
                    context.add_score.end (result);
                }
                catch (Error e)
                {
                    warning ("%s", e.message);
                }
            });
        }
    }

    protected override void activate ()
    {
        if (window == null)
            create_window ();

        window.present ();
    }

    private void breakpoint_apply_cb () {
        for (uint n_children = game_grid.observe_children ().get_n_items (); n_children > 0; n_children--)
        {
            game_grid.remove (game_grid.get_first_child ());
        }
        preview_frame.set_size_request (50, 50);
        game_grid.attach (score_descriptor_label, 0, 0, 2, 1);
        game_grid.attach (score_label, 2, 0, 2, 1);
        game_grid.attach (destroyed_descriptor_label, 4, 0, 2, 1);
        game_grid.attach (n_destroyed_label, 6, 0, 1, 1);
        game_grid.attach (level_descriptor_label, 7, 0, 2, 1);
        game_grid.attach (level_label, 9, 0, 1, 1);
        game_grid.attach (preview_label, 10, 0, 2, 1);
        game_grid.attach (preview_frame, 12, 0, 2, 1);
        game_grid.attach (game_aspect, 0, 1, 14, 17);
    }

    private void breakpoint_unapply_cb () {
        for (uint n_children = game_grid.observe_children ().get_n_items (); n_children > 0; n_children--)
        {
            game_grid.remove (game_grid.get_first_child ());
        }
        preview_frame.set_size_request (120, 120);
        game_grid.attach (game_aspect, 0, 0, 2, 18);
        game_grid.attach (preview_label, 2, 0, 1, 1);
        game_grid.attach (preview_frame, 2, 1, 1, 3);
        game_grid.attach (score_descriptor_label, 2, 5, 1, 1);
        game_grid.attach (score_label, 2, 6, 1, 2);
        game_grid.attach (destroyed_descriptor_label, 2, 9, 1, 1);
        game_grid.attach (n_destroyed_label, 2, 10, 1, 2);
        game_grid.attach (level_descriptor_label, 2, 13, 1, 1);
        game_grid.attach (level_label, 2, 14, 1, 2);
    }

    private void preferences_cb ()
    {
        preferences_dialog = new Adw.PreferencesDialog ();
        preferences_dialog.set_title (_("Preferences"));

        var game_page = new Adw.PreferencesPage ();
        game_page.set_title (_("Game"));

        var difficulty_group = new Adw.PreferencesGroup ();
        difficulty_group.set_title (_("Game Difficulty"));
        difficulty_group.set_description (_("Change how difficult the game is"));

        /* difficulty */
        // the maximum should be at least 4 less than the new game height but as long as the game height is a magic 20 and not a setting, we can keep it at 15
        var adj = new Gtk.Adjustment (settings.get_int ("difficulty"), 0, 15, 1, 5, 0);
        var difficulty_row = new Adw.SpinRow (adj, 10, 0);
        difficulty_row.set_title (_("_Difficulty"));
        difficulty_row.set_use_underline (true);
        difficulty_row.set_update_policy (Gtk.SpinButtonUpdatePolicy.ALWAYS);
        difficulty_row.set_snap_to_ticks (true);
        difficulty_row.changed.connect (() => settings.set_int ("difficulty", (int) difficulty_row.get_value ()));
        difficulty_group.add (difficulty_row);

        var difficult_blocks_toggle = new Adw.SwitchRow ();
        difficult_blocks_toggle.set_title (_("Choose difficult _blocks"));
        difficult_blocks_toggle.set_use_underline (true);
        difficult_blocks_toggle.set_active (settings.get_boolean ("pick-difficult-blocks"));
        difficult_blocks_toggle.notify["active"].connect (() => settings.set_boolean ("pick-difficult-blocks", difficult_blocks_toggle.get_active ()));
        difficulty_group.add (difficult_blocks_toggle);

        game_page.add (difficulty_group);

        var in_game_group = new Adw.PreferencesGroup ();
        in_game_group.set_title (_("In-Game"));
        in_game_group.set_description (_("Change the experience of playing a game"));

        var sound_toggle = new Adw.SwitchRow ();
        sound_toggle.set_title (_("_Enable sounds"));
        sound_toggle.set_use_underline (true);
        sound_toggle.set_active (settings.get_boolean ("sound"));
        sound_toggle.notify["active"].connect (() => {
            var play_sound = sound_toggle.get_active ();
            settings.set_boolean ("sound", play_sound);
            view.mute = !play_sound;
        });
        in_game_group.add (sound_toggle);

        var do_preview_toggle = new Adw.SwitchRow ();
        do_preview_toggle.set_title (_("_Preview next block"));
        do_preview_toggle.set_use_underline (true);
        do_preview_toggle.set_active (settings.get_boolean ("do-preview"));
        do_preview_toggle.notify["active"].connect (() => {
            var preview_enabled = do_preview_toggle.get_active ();
            settings.set_boolean ("do-preview", preview_enabled);
            preview.enabled = preview_enabled;
        });
        in_game_group.add (do_preview_toggle);

        /* rotate counter clock wise */
        var rotate_counter_clock_wise_toggle = new Adw.SwitchRow ();
        rotate_counter_clock_wise_toggle.set_title (_("_Rotate blocks counterclockwise"));
        rotate_counter_clock_wise_toggle.set_use_underline (true);
        rotate_counter_clock_wise_toggle.set_active (settings.get_boolean ("rotate-counter-clock-wise"));
        rotate_counter_clock_wise_toggle.notify["active"].connect (() => settings.set_boolean ("rotate-counter-clock-wise", rotate_counter_clock_wise_toggle.get_active ()));
        in_game_group.add (rotate_counter_clock_wise_toggle);

        var show_shadow_toggle = new Adw.SwitchRow ();
        show_shadow_toggle.set_title (_("Show _where the block will land"));
        show_shadow_toggle.set_use_underline (true);
        show_shadow_toggle.set_active (settings.get_boolean ("show-shadow"));
        show_shadow_toggle.notify["active"].connect (() => {
            var show_shadow = show_shadow_toggle.get_active ();
            settings.set_boolean ("show-shadow", show_shadow);
            view.show_shadow = show_shadow;
        });
        in_game_group.add (show_shadow_toggle);

        var game_seed = new Adw.EntryRow ();
        game_seed.set_title ("Game _seed");
        game_seed.set_use_underline (true);
        game_seed.set_text (settings.get_uint ("seed").to_string ());
        game_seed.set_sensitive (settings.get_boolean ("use-seed"));
        game_seed.changed.connect (() => { settings.set_uint ("seed", uint.parse (game_seed.get_text ())); });

        var use_seed_toggle = new Adw.SwitchRow ();
        use_seed_toggle.set_title (_("_Use a custom seed for the game"));
        use_seed_toggle.set_use_underline (true);
        use_seed_toggle.set_active (settings.get_boolean ("use-seed"));
        use_seed_toggle.notify["active"].connect (() => {
            bool active = use_seed_toggle.get_active ();
            settings.set_boolean ("use-seed", active);
            game_seed.set_sensitive (active);
        });

        in_game_group.add (use_seed_toggle);
        in_game_group.add (game_seed);

        game_page.add (in_game_group);
        preferences_dialog.add (game_page);
        preferences_dialog.present (window);
    }

    private Gtk.Widget theme_update (string theme_name, Gtk.Widget theme_preview_widget)
    {
        var theme_preview_frame = theme_preview_widget as Gtk.AspectFrame;
        theme_preview = theme_preview_frame.get_child () as Preview;
        view.theme = theme_name;
        preview.theme = theme_name;
        theme_preview.theme = theme_name;
        settings.set_string ("theme", theme_name);
        return theme_preview_widget;
    }

    private void theme_cb ()
    {
        var theme_preview_frame = new Gtk.AspectFrame (0.5f, 0.5f, 1.0f, false);
        theme_preview_frame.hexpand = true;
        theme_preview_frame.vexpand = true;
        theme_preview_frame.set_size_request (150, 150);
        theme_preview_frame.margin_top = 12;
        theme_preview_frame.margin_bottom = 12;
        theme_preview = new Preview (theme_preview_frame);
        theme_preview.theme = settings.get_string ("theme");
        theme_preview.game = new Game ();
        theme_preview_frame.set_child (theme_preview);
        var dialog = new Games.ThemeSelectorDialog ({"plain", "tangoflat", "tangoshaded", "clean", "modern"},
                                                    settings.get_string ("theme"),
                                                    theme_preview_frame,
                                                    theme_update);
        dialog.present (window);
    }

    private void pause_cb ()
    {
        if (game != null)
            game.paused = !game.paused;
    }

    private void quit_cb ()
    {
        if (window != null)
            window.close ();
        base.quit ();
    }

    private void manette_device_connected_cb (Manette.Device manette_device)
    {
        manette_device.button_press_event.connect (manette_button_press_event_cb);
        manette_device.button_release_event.connect (manette_button_release_event_cb);
    }

    private void manette_button_press_event_cb (Manette.Event event)
    {
        if (is_manette_button_down)
            return;

        uint16 button;
        if (!event.get_button (out button))
            return;

        is_manette_button_down = true;

        if (button == InputEventCode.BTN_SELECT)
        {
            new_game();
            return;
        }

        if (button == InputEventCode.BTN_START)
        {
            if (game == null)
                new_game();
            else if (!game.game_over)
                game.paused = !game.paused;
            else
                new_game();

            return;
        }

        if (game == null)
            return;

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
        uint16 button;
        if (!event.get_button (out button))
            return;

        is_manette_button_down = false;

        if (game == null)
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
            if (game.game_over && keyval == upper_key (65293)) // START key
            {
                new_game();
            }
        }

        if (game == null)
        {
            // Pressing pause with no game will start a new game.
            if (keyval == upper_key (65299)) // PAUSE key
            {
                new_game ();
                return true;
            }

            return false;
        }

        if (keyval == upper_key (65299)) // PAUSE key
        {
            if (!game.game_over)
                game.paused = !game.paused;
            return true;
        }

        if (game.paused)
            return false;

        if (keyval == upper_key (65361) || keyval == upper_key (65)) // Left or A key
        {
            game.move_left ();
            return true;
        }
        else if (keyval == upper_key (65363) || keyval == upper_key (68)) // Right or D key
        {
            game.move_right ();
            return true;
        }
        else if (keyval == upper_key (65362) || keyval == upper_key (87)) // Up or W key
        {
            if (settings.get_boolean ("rotate-counter-clock-wise"))
                game.rotate_left ();
            else
                game.rotate_right ();
            return true;
        }
        else if (keyval == upper_key (65364) || keyval == upper_key (83)) // Down or S key
        {
            game.set_fast_forward (true);
            return true;
        }
        else if (keyval == upper_key (81)) // Q key
        {
            game.rotate_left ();
        }
        else if (keyval == upper_key (69)) // E key
        {
            game.rotate_right ();
        }
        else if (keyval == upper_key (32)) // Spacebar
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

        if (keyval == upper_key (65361) || // Left  key
            keyval == upper_key (65363) || // Right key
            keyval == upper_key (65)    || // A     key
            keyval == upper_key (68))      // D     key
        {
            game.stop_moving ();
            return;
        }
        else if (keyval == upper_key (65364) || // Down key
                 keyval == upper_key (83))      // S    key
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

    private void swipe_cb (double velocity_x, double velocity_y)
    {
        if (game == null || game.paused)
            return;
 
        /* For some reason tapping/clicking is treated as a swipe, but with 0 velocity.
         * Annoyingly, the release of a long press is treated as a swipe too,
         * so it is necessary to check for this. At the same time there is the feature
         * of clicking/tapping to rotate the blocks, which makes the game a lot easier
         * on mobile devices.
         */
        if (velocity_x == 0 && velocity_y == 0)
        {
            if (game.get_fast_forward ())
                {
                    game.set_fast_forward (false);
                }
            else
            {
                if (settings.get_boolean ("rotate-counter-clock-wise"))
                    game.rotate_left ();
                else
                    game.rotate_right ();
            }

            return;
        }

        double direction = (Math.atan2 (velocity_y, velocity_x) * 180) / Math.PI;
        if (direction < 0)
            direction += 360.0;

        if (direction >= 135 && direction < 225)
        {
            game.move_left ();
            game.stop_moving ();
        }

        else if (direction >= 315 || direction < 45)
        {
            game.move_right ();
            game.stop_moving ();
        }
        else if (direction >= 225 && direction < 315)
        /* Swiping up is an alternative to clicking/tapping,
         * so we use it to give the user the option of rotating blocks
         * in the opposite direction of what they set in the preferences
         */
        {
            if (settings.get_boolean ("rotate-counter-clock-wise"))
                game.rotate_right ();
            else
                game.rotate_left ();
        }
        else
            game.drop ();
    }

    private void long_press_cb (double x, double y)
    {
        if (game != null)
            game.set_fast_forward (true);
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

        if (settings.get_boolean ("use-seed"))
            Random.set_seed (settings.get_uint ("seed"));

        // Set game dimension, change to 10
        game = new Game (20, 10,
                         settings.get_int ("difficulty") /* The starting level */,
                         settings.get_int ("difficulty") /* Pre-filled lines */, 5 /* line fill density  */,
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
        new_game_button.set_sensitive (true);
        pause_play_button.action_name = "app.pause";
    }

    private void pause_changed_cb ()
    {
        if (game.paused)
        {
            pause_play_button.set_icon_name ("media-playback-start-symbolic");
            pause_play_button.tooltip_text = _("Unpause the game");
            preview.set_hidden (true);
        }
        else
        {
            pause_play_button.set_icon_name ("media-playback-pause-symbolic");
            pause_play_button.tooltip_text = _("Pause the game");
            preview.set_hidden (false);

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
        pause_play_button.set_icon_name ("media-playback-start-symbolic");
        pause_play_button.action_name = "app.new-game";
        pause_play_button.tooltip_text = _("Start the game");
        new_game_button.set_sensitive (false);

        if (game.score > 0)
        {
            context.add_score.begin (game.score, create_category_from_key (game.difficulty.to_string()), null, (object, result) => {
                try
                {
                    context.add_score.end (result);
                }
                catch (Error e)
                {
                    warning ("%s", e.message);
                }
            });
        }
    }

    private Games.Scores.Category create_category_from_key (string key)
    {
        if (key == "old-scores") {
            return new Games.Scores.Category (key, _("Old Scores"));
        }

        var tokens = key.split ("-");
        if (tokens.length != 1)
            return new Games.Scores.Category (key, tokens[0] + _("Difficult"));

        /* For the scores dialog. Just the difficulty level (a number). */
        return new Games.Scores.Category (key, key);
    }

    private int64 parse_date (string date)
    {
        if (date.length < 19 || date[4] != '-' || date[7] != '-' || date[10] != 'T' || date[13] != ':' || date[16] != ':')
            warning ("Failed to parse date: %s", date);

        var year = int.parse (date.substring (0, 4));
        var month = int.parse (date.substring (5, 2));
        var day = int.parse (date.substring (8, 2));
        var hour = int.parse (date.substring (11, 2));
        var minute = int.parse (date.substring (14, 2));
        var seconds = int.parse (date.substring (17, 2));
        try {
            var timezone = new GLib.TimeZone.identifier (date.substring (19));
            return new DateTime (timezone, year, month, day, hour, minute, seconds).to_unix ();
        } catch (GLib.Error e) {
            warning ("Failed to parse date: %s", date);
            return 0;
        }
    }

    private void parse_old_score (string line, out Games.Scores.Score score, out Games.Scores.Category category)
    {
        score = null;
        category = null;

        var tokens = line.split (" ");
        if (tokens.length != 2)
            return;

        var date = parse_date (tokens[0]);
        var points = int.parse (tokens[1]);

        if (date <= 0 || points < 0)
            return;

        score = new Games.Scores.Score (points, date);
        category = create_category_from_key ("old-scores");
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
        string[] authors = { "J. Marcin Gorycki", "Robert Ancell", "John Ward" }; // TODO get other authors
        string[] documenters = { "Angela Boyle" };

        var about = new Adw.AboutDialog () {
            application_name = _("Quadrapassel"),
            application_icon = APP_ID,
            developers = authors,
            comments = _("A classic game where you rotate blocks to make complete rows, but don't pile your blocks too high or it's game over!"),
            copyright = "Copyright © 1999 J. Marcin Gorycki, 2000–2015 Others",
            license_type = Gtk.License.GPL_2_0,
            documenters = documenters,
            translator_credits = _("translator-credits"),
            version = VERSION,
            website = "https://wiki.gnome.org/Apps/Quadrapassel",
        };

        about.present (this.active_window);
    }

    private void menu_cb ()
    {
        menu_button.activate ();
    }

    private void scores_cb ()
    {
        context.present_dialog ();
    }

    public static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        var app = new Quadrapassel ();
        return app.run (args);
    }
}

