/*
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public class ScoreDialog : Gtk.Dialog
{
    private History history;
    private HistoryEntry? selected_entry = null;
    private Gtk.ListStore score_model;
    private Gtk.TreeView scores;

    public ScoreDialog (History history, HistoryEntry? selected_entry = null, bool show_close = false)
    {
        this.history = history;
        history.entry_added.connect (entry_added_cb);
        this.selected_entry = selected_entry;

        if (show_close)
        {
            add_button (_("_Close"), Gtk.ResponseType.CLOSE);
            add_button (_("New Game"), Gtk.ResponseType.OK);
        }
        else
            add_button (_("_OK"), Gtk.ResponseType.DELETE_EVENT);
        set_size_request (200, 300);

        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
        vbox.border_width = 6;
        vbox.show ();
        get_content_area ().pack_start (vbox, true, true, 0);

        var scroll = new Gtk.ScrolledWindow (null, null);
        scroll.shadow_type = Gtk.ShadowType.ETCHED_IN;
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.show ();
        vbox.pack_start (scroll, true, true, 0);

        score_model = new Gtk.ListStore (3, typeof (string), typeof (string), typeof (int));

        scores = new Gtk.TreeView ();
        var renderer = new Gtk.CellRendererText ();
        scores.insert_column_with_attributes (-1, _("Date"), renderer, "text", 0, "weight", 2);
        renderer = new Gtk.CellRendererText ();
        renderer.xalign = 1.0f;
        scores.insert_column_with_attributes (-1, _("Score"), renderer, "text", 1, "weight", 2);
        scores.model = score_model;
        scores.show ();
        scroll.add (scores);

        var entries = history.entries.copy ();
        entries.sort (compare_entries);
        foreach (var entry in entries)
            entry_added_cb (entry);
    }

    private static int compare_entries (HistoryEntry a, HistoryEntry b)
    {
        if (a.score != b.score)
            return b.score - a.score;
        return a.date.compare (b.date);
    }

    private void entry_added_cb (HistoryEntry entry)
    {
        var date_label = entry.date.format ("%d/%m/%Y");
        var score_label = "%i".printf (entry.score);

        int weight = Pango.Weight.NORMAL;
        if (entry == selected_entry)
            weight = Pango.Weight.BOLD;

        Gtk.TreeIter iter;
        score_model.append (out iter);
        score_model.set (iter, 0, date_label, 1, score_label, 2, weight);

        if (entry == selected_entry)
        {
            var piter = iter;
            if (score_model.iter_previous (ref piter))
            {
                var ppiter = piter;
                if (score_model.iter_previous (ref ppiter))
                    piter = ppiter;
            }
            else
                piter = iter;
            scores.scroll_to_cell (score_model.get_path (piter), null, false, 0, 0);
        }
    }
}
