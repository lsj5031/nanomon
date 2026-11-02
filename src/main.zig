//! nanomon: a small activity monitor on nanoui, laid out as Activity
//! Monitor: processes with their CPU, memory and disk, the system's below,
//! sampled every two seconds while the window shows; on macOS it lives in
//! the menu bar too, with a panel of the machine under it.
const std = @import("std");
const nanoui = @import("nanoui");
const App = @import("app.zig").App;
const menubar = @import("menubar.zig");
const log = @import("log.zig");

/// Every `std.log` message, nanomon's and nanoui's, goes to the log file: a
/// GUI app's stderr is read by no one.
pub const std_options: std.Options = .{ .log_level = .info, .logFn = log.stdLog };

pub fn main(init: std.process.Init) !void {
    log.init(init);
    defer log.deinit();
    log.info("nanomon starting: {s} build, {s}", .{ @tagName(@import("builtin").mode), @tagName(@import("builtin").os.tag) });
    // In the menu bar, closing the window leaves nanomon running there.
    const app = nanoui.App.create(init, .{ .name = "nanomon", .quit_on_last_window_closed = !menubar.supported }) catch |e| {
        log.err("can't create the app: {t}", .{e});
        return e;
    };
    defer app.destroy();
    var a: App = .init(init.gpa, init.io);
    defer a.deinit();
    a.nanoapp = app;
    a.listen(null);
    if (menubar.supported) a.clock = menubar.clock;
    a.openWindow();
    var bar: menubar.MenuBar = .{ .a = &a, .app = app };
    defer bar.deinit();
    bar.start();
    // No release is built for Windows yet: nothing to update to there.
    if (comptime @import("builtin").os.tag != .windows) {
        a.updater = try nanoui.Updater.start(init, .{
            .repo = "justrach/nanomon",
            .asset = "nanomon-macos-arm64.zip",
            .name = "nanomon",
            .changed = .{ .ctx = &a, .func = App.redraw },
        });
    }
    // Freed after the app runs: its sidebar and the update callback hold it.
    defer if (a.updater) |u| u.deinit();
    app.run() catch |e| {
        log.err("event loop stopped: {t}", .{e});
        return e;
    };
    log.info("event loop returned", .{});
}
