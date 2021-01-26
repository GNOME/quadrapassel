using Gst;

public class StreamPlayer {

    // thread to play the music
    private MainLoop loop = new MainLoop ();
    
    // Player element
    private dynamic Element player;
    

    private void foreach_tag (Gst.TagList list, string tag) {
        switch (tag) {
        case "title":
            string tag_string;
            list.get_string (tag, out tag_string);
            stdout.printf ("tag: %s = %s\n", tag, tag_string);
            break;
        default:
            break;
        }
    }

    private bool bus_callback (Gst.Bus bus, Gst.Message message) {
        switch (message.type) {
        case MessageType.ERROR:
            GLib.Error err;
            string debug;
            message.parse_error (out err, out debug);
            stdout.printf ("Error: %s\n", err.message);
            loop.quit ();
            break;
        case MessageType.EOS:
            stdout.printf ("end of stream\n");
            break;
        case MessageType.STATE_CHANGED:
            Gst.State oldstate;
            Gst.State newstate;
            Gst.State pending;
            message.parse_state_changed (out oldstate, out newstate,
                                         out pending);
            stdout.printf ("state changed: %s->%s:%s\n",
                           oldstate.to_string (), newstate.to_string (),
                           pending.to_string ());
            break;
        case MessageType.TAG:
            Gst.TagList tag_list;
            stdout.printf ("taglist found\n");
            message.parse_tag (out tag_list);
            tag_list.foreach ((TagForeachFunc) foreach_tag);
            break;
        default:
            break;
        }

        return true;
    }

    public void stop() {
        player.set_state(State.READY);
        loop.quit();
    }

    public void play (string filename) {

        var path = GLib.Path.build_filename (SOUND_DIRECTORY, filename);
        path = "file:" + path;
        stdout.printf ("Path: %s\n", path);

        player = ElementFactory.make ("playbin", "play");

        //string cur_dir = GLib.Environment.get_current_dir();

        player.uri = path;

        Gst.Bus bus = player.get_bus ();
        bus.add_watch (0, bus_callback);

        player.set_state (State.PLAYING);

        loop.run ();
    }
}