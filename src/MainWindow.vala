/*
* Copyright (c) 2017 Lains
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/
using Gtk;
using Granite;

namespace Quilter {
    public class MainWindow : Gtk.Window {
        public Widgets.StatusBar statusbar;
        public Widgets.Headerbar toolbar;
        public Widgets.SourceView edit_view_content;
        public Widgets.Preview preview_view_content;
        public Gtk.Grid grid;
        public SimpleActionGroup actions { get; construct; }
        public const string ACTION_PREFIX = "win.";
        public const string ACTION_CHEATSHEET = "action_cheatsheet";
        public const string ACTION_PREFS = "action_preferences";
        public const string ACTION_EXPORT_PDF = "action_export_pdf";
        public const string ACTION_EXPORT_HTML = "action_export_html";
        public static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();

        private const GLib.ActionEntry[] action_entries = {
            { ACTION_CHEATSHEET, action_cheatsheet },
            { ACTION_PREFS, action_preferences },
            { ACTION_EXPORT_PDF, action_export_pdf },
            { ACTION_EXPORT_HTML, action_export_html }
        };

        public bool is_fullscreen {
            get {
                var settings = AppSettings.get_default ();
                return settings.fullscreen;
            }
            set {
                var settings = AppSettings.get_default ();
                settings.fullscreen = value;

                if (settings.fullscreen) {
                    fullscreen ();
                } else {
                    unfullscreen ();
                }
            }
        }

        public MainWindow (Gtk.Application application) {
            Object (application: application,
                    resizable: true,
                    title: _("Quilter"),
                    height_request: 600,
                    width_request: 700);

            statusbar.update_wordcount ();
            statusbar.update_linecount ();
            statusbar.update_readtimecount ();
            show_statusbar ();

            var settings = AppSettings.get_default ();
            settings.changed.connect (() => {
                show_statusbar ();
            });

            edit_view_content.changed.connect (() => {
                schedule_timer ();
                statusbar.update_wordcount ();
                statusbar.update_linecount ();
                statusbar.update_readtimecount ();
            });

            key_press_event.connect ((e) => {
                uint keycode = e.hardware_keycode;
                if ((e.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                    if (match_keycode (Gdk.Key.q, keycode)) {
                        this.destroy ();
                    }
                }
                if ((e.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                    if (match_keycode (Gdk.Key.s, keycode)) {
                        try {
                            Services.FileManager.save ();
                        } catch (Error e) {
                            warning ("Unexpected error during open: " + e.message);
                        }
                    }
                }
                if ((e.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                    if (match_keycode (Gdk.Key.o, keycode)) {
                        try {
                            Services.FileManager.open ();
                        } catch (Error e) {
                            warning ("Unexpected error during open: " + e.message);
                        }
                    }
                }
                if ((e.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                    if (match_keycode (Gdk.Key.h, keycode)) {
                        var cheatsheet_dialog = new Widgets.Cheatsheet (this);
                        cheatsheet_dialog.show_all ();
                    }
                }
                if ((e.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                    if (match_keycode (Gdk.Key.z, keycode)) {
                        Widgets.SourceView.buffer.undo ();
                    }
                }
                if ((e.state & Gdk.ModifierType.CONTROL_MASK + Gdk.ModifierType.SHIFT_MASK) != 0) {
                    if (match_keycode (Gdk.Key.z, keycode)) {
                        Widgets.SourceView.buffer.redo ();
                    }
                }
                if (match_keycode (Gdk.Key.F11, keycode)) {
                    is_fullscreen = !is_fullscreen;
                }
                if (match_keycode (Gdk.Key.F1, keycode)) {
                    debug ("Press to change view...");
                    if (toolbar.stack.get_visible_child_name () == "preview_view") {
                        toolbar.stack.set_visible_child (toolbar.edit_view);
                    } else if (toolbar.stack.get_visible_child_name () == "edit_view") {
                        toolbar.stack.set_visible_child (toolbar.preview_view);
                    }
                    return true;
                }
                return false;
            });
        }

        construct {
            var settings = AppSettings.get_default ();
            var provider = new Gtk.CssProvider ();
            provider.load_from_resource ("/com/github/lainsce/quilter/app-main-stylesheet.css");
            Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var toolbar = new Widgets.Headerbar ();
            toolbar.title = this.title;
            toolbar.has_subtitle = false;
            this.set_titlebar (toolbar);

            actions = new SimpleActionGroup ();
            actions.add_action_entries (action_entries, this);
            insert_action_group ("win", actions);

            statusbar = new Widgets.StatusBar ();

            grid = new Gtk.Grid ();
            grid.orientation = Gtk.Orientation.VERTICAL;
            grid.add (toolbar.stack);
            grid.add (statusbar);
            grid.show_all ();
            this.add (grid);

            int x = settings.window_x;
            int y = settings.window_y;
            int h = settings.window_height;
            int w = settings.window_width;

            if (x != -1 && y != -1) {
                this.move (x, y);
            }
            if (w != 0 && h != 0) {
                this.resize (w, h);
            }

            this.window_position = Gtk.WindowPosition.CENTER;
            this.show_all ();
        }

        protected bool match_keycode (int keyval, uint code) {
            Gdk.KeymapKey [] keys;
            Gdk.Keymap keymap = Gdk.Keymap.get_for_display (Gdk.Display.get_default ());
            if (keymap.get_entries_for_keyval (keyval, out keys)) {
                foreach (var key in keys) {
                    if (code == key.keycode)
                        return true;
                    }
                }

            return false;
        }

        public override bool delete_event (Gdk.EventAny event) {
            int x, y, w, h;
            get_position (out x, out y);
            get_size (out w, out h);

            var settings = AppSettings.get_default ();
            settings.window_x = x;
            settings.window_y = y;
            settings.window_width = w;
            settings.window_height = h;

            if (settings.last_file != null) {
                debug ("Saving working file...");
                Services.FileManager.save_work_file ();
            } else if (settings.last_file == "New Document") {
                debug ("Saving cache...");
                Services.FileManager.save_tmp_file ();
            }
            return false;
        }

        private void action_preferences () {
            var dialog = new Widgets.Preferences (this);
            dialog.set_modal (true);
            dialog.show_all ();
        }

        private void action_cheatsheet () {
            var dialog = new Widgets.Cheatsheet (this);
            dialog.set_modal (true);
            dialog.show_all ();
        }

        private void action_export_pdf () {
            Services.ExportUtils.export_pdf ();
        }

        private void action_export_html () {
            Services.ExportUtils.export_html ();
        }

        private async void schedule_timer () {
            Timeout.add (10, () => {
                render_func ();
                return false;
            }, 
            GLib.Priority.DEFAULT);
        }

        private bool render_func () {
            if (edit_view_content.is_modified) {
                preview_view_content.update_html_view ();
                edit_view_content.is_modified = false;
            } else {
                edit_view_content.is_modified = true;
            }
            return false;
        }

        public void show_statusbar () {
            var settings = AppSettings.get_default ();
            statusbar.reveal_child = settings.statusbar;
        }
    }
}