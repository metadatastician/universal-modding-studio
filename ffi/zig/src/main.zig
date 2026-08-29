// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
// main.zig -- C-compatible FFI exports for the IDApTIK UMS level editor.
// Author: Jonathan D.A. Jewell
//
// This module is the sole entry point for foreign callers — the host
// via ipc_handlers.zig, or any C-ABI consumer.  Every exported function uses
// `callconv(.c)` and operates on the C-ABI types defined in types.zig.
//
// Lifecycle:
//   1. `idaptik_ums_create_level`   -- allocate + zero-initialise a LevelData
//   2. `idaptik_ums_add_*`          -- populate the level incrementally
//   3. `idaptik_ums_set_*`          -- set singular config fields
//   4. `idaptik_ums_validate_level` -- run all proof checks at runtime
//   5. `idaptik_ums_admit_level_json` -- validate the complete JSON boundary
//   6. `idaptik_ums_serialize_level` / `idaptik_ums_deserialize_level`
//   7. `idaptik_ums_destroy_level`  -- free the LevelData
//
// Memory ownership: the library owns all LevelData allocations.  Callers
// MUST NOT free the pointer themselves; always use `destroy_level`.

const std = @import("std");
const types = @import("types");
const validate = @import("validate");
const json_admission = @import("json_admission");
const json_codec = @import("json_codec");

// Pull in all domain FFI modules so their `export fn` declarations
// are compiled and linked into the shared library.
comptime {
    _ = @import("ipc_handlers");
    _ = @import("inventory");
    _ = @import("enemies");
    _ = @import("mission");
    _ = @import("wiring");
    _ = @import("proven_bridge");
    _ = @import("multiplayer");
    _ = @import("game_systems");
}

/// Global general-purpose allocator used for all heap allocations.
/// Using the page allocator keeps us free of libc dependency.
var gpa = std.heap.page_allocator;

// =========================================================================
// Lifecycle: create / destroy
// =========================================================================

/// Allocate and zero-initialise a new LevelData on the heap.
///
/// Returns a pointer to the new level, or null if allocation fails.
/// The caller is responsible for eventually calling `idaptik_ums_destroy_level`.
pub export fn idaptik_ums_create_level() callconv(.c) ?*types.LevelData {
    const owned = json_codec.createOwned(gpa) catch return null;
    return &owned.level;
}

/// Free a LevelData previously created by `idaptik_ums_create_level`.
///
/// After this call the pointer is dangling and MUST NOT be used again.
/// Passing null is a safe no-op.
pub export fn idaptik_ums_destroy_level(level: ?*types.LevelData) callconv(.c) void {
    if (level) |lv| {
        json_codec.destroyOwned(gpa, lv);
    }
}

// =========================================================================
// Add functions: append to dynamic arrays
// =========================================================================

/// Append a device to the level's device list.
///
/// Returns `true` on success, `false` if the device array is at capacity.
pub export fn idaptik_ums_add_device(
    level: ?*types.LevelData,
    spec: ?*const types.DeviceSpec,
) callconv(.c) bool {
    const lv = level orelse return false;
    const s = spec orelse return false;
    if (lv.devices_len >= types.MAX_DEVICES) return false;
    lv.devices[lv.devices_len] = s.*;
    lv.devices_len += 1;
    return true;
}

/// Append a zone to the level's zone list.
///
/// Returns `true` on success, `false` if the zone array is at capacity.
pub export fn idaptik_ums_add_zone(
    level: ?*types.LevelData,
    zone: ?*const types.Zone,
) callconv(.c) bool {
    const lv = level orelse return false;
    const z = zone orelse return false;
    if (lv.zones_len >= types.MAX_ZONES) return false;
    lv.zones[lv.zones_len] = z.*;
    lv.zones_len += 1;
    return true;
}

/// Append a guard to the level's guard list.
///
/// Returns `true` on success, `false` if the guard array is at capacity.
pub export fn idaptik_ums_add_guard(
    level: ?*types.LevelData,
    guard: ?*const types.GuardPlacement,
) callconv(.c) bool {
    const lv = level orelse return false;
    const g = guard orelse return false;
    if (lv.guards_len >= types.MAX_GUARDS) return false;
    lv.guards[lv.guards_len] = g.*;
    lv.guards_len += 1;
    return true;
}

/// Append a dog to the level's dog list.
///
/// Returns `true` on success, `false` if the dog array is at capacity.
pub export fn idaptik_ums_add_dog(
    level: ?*types.LevelData,
    dog: ?*const types.DogPlacement,
) callconv(.c) bool {
    const lv = level orelse return false;
    const d = dog orelse return false;
    if (lv.dogs_len >= types.MAX_DOGS) return false;
    lv.dogs[lv.dogs_len] = d.*;
    lv.dogs_len += 1;
    return true;
}

/// Append a drone to the level's drone list.
///
/// Returns `true` on success, `false` if the drone array is at capacity.
pub export fn idaptik_ums_add_drone(
    level: ?*types.LevelData,
    drone: ?*const types.DronePlacement,
) callconv(.c) bool {
    const lv = level orelse return false;
    const dr = drone orelse return false;
    if (lv.drones_len >= types.MAX_DRONES) return false;
    lv.drones[lv.drones_len] = dr.*;
    lv.drones_len += 1;
    return true;
}

// =========================================================================
// Set functions: singular config fields
// =========================================================================

/// Set the mission configuration for the level.
///
/// Returns `true` on success, `false` if either pointer is null.
pub export fn idaptik_ums_set_mission(
    level: ?*types.LevelData,
    mission: ?*const types.MissionConfig,
) callconv(.c) bool {
    const lv = level orelse return false;
    const m = mission orelse return false;
    lv.mission = m.*;
    return true;
}

/// Set the physical world configuration for the level.
///
/// Returns `true` on success, `false` if either pointer is null.
pub export fn idaptik_ums_set_physical(
    level: ?*types.LevelData,
    physical: ?*const types.PhysicalConfig,
) callconv(.c) bool {
    const lv = level orelse return false;
    const p = physical orelse return false;
    lv.physical = p.*;
    return true;
}

// =========================================================================
// Validation
// =========================================================================

/// Run all four cross-domain validation checks on the level.
///
/// This is the runtime materialisation of the erased proof fields in
/// `Validation.ValidatedLevel`.  The checks are:
///   1. Defence targets reference real devices.
///   2. Every guard's zone exists in the zone list.
///   3. Zone transitions are monotonically ordered by X.
///   4. If PBX is enabled, its IP is in the device registry.
///
/// Returns a `ValidationResult` with per-check booleans and an overall flag.
pub export fn idaptik_ums_validate_level(
    level: ?*const types.LevelData,
) callconv(.c) types.ValidationResult {
    const lv = level orelse return .{
        .valid = false,
        .defence_targets_valid = false,
        .guards_in_zones = false,
        .zones_ordered = false,
        .pbx_consistent = false,
    };
    return validate.validateLevel(lv);
}

// =========================================================================
// Serialisation (JSON)
// =========================================================================

/// Serialise a LevelData to JSON, writing into a caller-provided buffer.
///
/// Parameters:
///   - `level`: pointer to the LevelData to serialise.
///   - `buf`:   pointer to the output buffer.
///   - `buf_len`: size of the output buffer in bytes.
///
/// Returns the number of bytes written on success.
/// Returns 0 if the buffer is too small or any pointer is null.
///
/// The output is valid UTF-8 JSON without a trailing null terminator.
pub export fn idaptik_ums_serialize_level(
    level: ?*const types.LevelData,
    buf: ?[*]u8,
    buf_len: usize,
) callconv(.c) usize {
    const lv = level orelse return 0;
    const buffer = buf orelse return 0;

    var fbs = std.io.fixedBufferStream(buffer[0..buf_len]);
    const writer = fbs.writer();

    json_codec.serializeLevelJson(gpa, lv, writer) catch return 0;

    return fbs.pos;
}

/// Deserialise a LevelData from a JSON buffer.
///
/// Parameters:
///   - `data`: pointer to the JSON input (need not be null-terminated).
///   - `data_len`: length of the JSON input in bytes.
///
/// Returns a heap-allocated LevelData on success, or null on failure.
/// The caller is responsible for freeing via `idaptik_ums_destroy_level`.
pub export fn idaptik_ums_deserialize_level(
    data: ?[*]const u8,
    data_len: usize,
) callconv(.c) ?*types.LevelData {
    const input = data orelse return null;
    if (data_len == 0) return null;

    return json_codec.deserializeLevelJson(gpa, input[0..data_len]) catch null;
}

/// Parse and validate a complete snake_case LevelData JSON document against
/// the same bounded representation and four admission conditions exercised by
/// the Idris2 ProvenBridge. This does not allocate or return a C LevelData.
pub export fn idaptik_ums_admit_level_json(
    data: ?[*]const u8,
    data_len: usize,
) callconv(.c) bool {
    const input = data orelse return false;
    if (data_len == 0 or data_len > json_admission.max_level_json_bytes) return false;
    json_admission.admitLevelJson(gpa, input[0..data_len]) catch return false;
    return true;
}
