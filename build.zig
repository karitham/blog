const std = @import("std");
const zine = @import("zine");

pub fn build(b: *std.Build) !void {
    zine.addWebsite(b, .{}, b.default_step, .{
        .layouts_dir_path = "layouts",
        .content_dir_path = "content",
        .assets_dir_path = "static",
        .host_url = "https://blog.karitham.dev",
        .title = "Kar's blog",
    });
}
