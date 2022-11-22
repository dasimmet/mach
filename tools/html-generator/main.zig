const std = @import("std");

const source = @embedFile("template.html");

const app_name_needle = "{ app_name }";
const js_imports_needle = "{ js_imports }";
const js_exports_needle = "{ js_exports }";

const js = @import("jsmodule.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print("Usage: html-generator <output-name> <app-name> [<js_module> <js_file>]\n", .{});
        return;
    }

    const output_name = args[1];
    const app_name = args[2];

    const file = try std.fs.cwd().createFile(output_name, .{});
    defer file.close();

    var modules = js.JSModuleList.init(allocator);
    defer modules.deinit();

    var i: u64 = 3;
    while (i < args.len) : (i+=2) {
        try modules.list.append(js.JSModule{.module=args[i], .file=args[i+1]});
    }

    const imports = try modules.formatImport();
    defer allocator.free(imports);

    const exports = try modules.formatWasmModules();
    defer allocator.free(exports);

    std.debug.print("{s}\n{s}\n", .{imports,exports});

    var src = try allocator.alloc(u8, source.len);
    std.mem.copy(u8, src, source);

    inline for (.{
        .{app_name_needle, app_name},
        .{js_imports_needle, imports},
        .{js_exports_needle, exports},
    }) |repl| {
        const size = std.mem.replacementSize(u8, src, repl[0], repl[1]);
        const buf = try allocator.alloc(u8, size);
        _ = std.mem.replace(u8, src, repl[0], repl[1], buf);
        allocator.free(src);
        src = buf;
    }
    defer allocator.free(src);

    _ = try file.write(src);
}
