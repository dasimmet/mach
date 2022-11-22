
const std = @import("std");

pub const JSModule = struct {
    module: []const u8,
    file: []const u8,
    exportToWasm: bool = true,

    pub fn fmtImport(self: *const JSModule, alloc: std.mem.Allocator) ![]const u8{
        return std.fmt.allocPrint(alloc, "\n    import {{ {s} }} from \"./{s}\";", .{self.module, self.file});
    }
};

pub const JSModuleList = struct {
    allocator: std.mem.Allocator,
    list: std.ArrayList(JSModule),

    pub fn init(allocator: std.mem.Allocator) JSModuleList {
        return JSModuleList{
            .allocator = allocator,
            .list = std.ArrayList(JSModule).init(allocator),
        };
    }

    pub fn deinit(self: *const JSModuleList) void {
        self.list.deinit();
    }

    pub fn formatImport(self: *const JSModuleList) ![]const u8 {

        var imports = std.ArrayList([]const u8).init(self.allocator);
        defer imports.deinit();

        for (self.list.items) |js_import| {
            try imports.append(try js_import.fmtImport(self.allocator));
        }
        defer {
            for (imports.items) |it| self.allocator.free(it);
        }

        return std.mem.concat(self.allocator, u8, imports.items);
    }

    pub fn formatWasmModules(self: *const JSModuleList) ![]const u8 {
        var imports = std.ArrayList([]const u8).init(self.allocator);
        defer imports.deinit();
        for (self.list.items) |js_import| {
            if (js_import.exportToWasm) try imports.append(js_import.module);
        }
        return std.mem.join(self.allocator, ",", imports.items);
    }
};
