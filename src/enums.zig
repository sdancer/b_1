//! BUILD Engine Enumerations and Flags
//! Port from: NBlood/source/build/include/buildtypes.h, build.h, polymost.h

const std = @import("std");

// =============================================================================
// Render Mode
// =============================================================================

pub const RendMode = enum(i32) {
    classic = 0,
    polymost = 3,
    polymer = 4,
};

// =============================================================================
// Sprite cstat Flags (buildtypes.h lines 117-145)
// =============================================================================

pub const CstatSprite = struct {
    pub const BLOCK: u16 = 1 << 0;
    pub const TRANSLUCENT: u16 = 1 << 1;
    pub const XFLIP: u16 = 1 << 2;
    pub const YFLIP: u16 = 1 << 3;
    pub const ALIGNMENT: u16 = (1 << 4) | (1 << 5);
    pub const ONE_SIDED: u16 = 1 << 6;
    pub const YCENTER: u16 = 1 << 7;
    pub const BLOCK_HITSCAN: u16 = 1 << 8;
    pub const TRANSLUCENT_INVERT: u16 = 1 << 9;
    pub const RESERVED1: u16 = 1 << 10; // used by Duke 3D (Polymost)
    pub const RESERVED2: u16 = 1 << 11; // used by Duke 3D (EDuke32 game code extension)
    pub const RESERVED3: u16 = 1 << 12; // used by Shadow Warrior, Blood
    pub const RESERVED4: u16 = 1 << 13; // used by Duke 3D (Polymer), Shadow Warrior, Blood
    pub const RESERVED5: u16 = 1 << 14; // used by Duke 3D (Polymer), Shadow Warrior, Blood
    pub const INVISIBLE: u16 = 1 << 15;

    // Alignment values
    pub const ALIGNMENT_FACING: u16 = 0;
    pub const ALIGNMENT_WALL: u16 = 1 << 4;
    pub const ALIGNMENT_FLOOR: u16 = 1 << 5;
    pub const ALIGNMENT_SLOPE: u16 = (1 << 4) | (1 << 5);
    pub const ALIGNMENT_MASK: u16 = (1 << 4) | (1 << 5);
};

// =============================================================================
// Wall cstat Flags (buildtypes.h lines 149-167)
// =============================================================================

pub const CstatWall = struct {
    pub const BLOCK: u16 = 1 << 0;
    pub const BOTTOM_SWAP: u16 = 1 << 1;
    pub const ALIGN_BOTTOM: u16 = 1 << 2;
    pub const XFLIP: u16 = 1 << 3;
    pub const MASKED: u16 = 1 << 4;
    pub const ONE_WAY: u16 = 1 << 5;
    pub const BLOCK_HITSCAN: u16 = 1 << 6;
    pub const TRANSLUCENT: u16 = 1 << 7;
    pub const YFLIP: u16 = 1 << 8;
    pub const TRANS_FLIP: u16 = 1 << 9;
    pub const YAX_UPWALL: u16 = 1 << 10; // EDuke32 extension
    pub const YAX_DOWNWALL: u16 = 1 << 11; // EDuke32 extension
    pub const ROTATE_90: u16 = 1 << 12; // EDuke32 extension
    pub const RESERVED1: u16 = 1 << 13;
    pub const RESERVED2: u16 = 1 << 14; // used by Shadow Warrior, Blood
    pub const RESERVED3: u16 = 1 << 15; // used by Shadow Warrior, Blood
};

// =============================================================================
// Rotatesprite Orientation Flags (build.h lines 235-262)
// =============================================================================

pub const RSFlags = struct {
    pub const TRANS1: u32 = 1;
    pub const AUTO: u32 = 2;
    pub const YFLIP: u32 = 4;
    pub const NOCLIP: u32 = 8;
    pub const TOPLEFT: u32 = 16;
    pub const TRANS2: u32 = 32;
    pub const TRANS_MASK: u32 = TRANS1 | TRANS2;
    pub const NOMASK: u32 = 64;
    pub const PERM: u32 = 128;

    pub const ALIGN_L: u32 = 256;
    pub const ALIGN_R: u32 = 512;
    pub const ALIGN_MASK: u32 = ALIGN_L | ALIGN_R;
    pub const STRETCH: u32 = 1024;

    pub const FULL16: u32 = 2048;
    pub const LERP: u32 = 4096;
    pub const FORCELERP: u32 = 8192;
    pub const NOPOSLERP: u32 = 16384;
    pub const NOZOOMLERP: u32 = 32768;
    pub const NOANGLERP: u32 = 65536;

    // ROTATESPRITE_MAX-1 is the mask of all externally available orientation bits
    pub const MAX: u32 = 131072;

    pub const CENTERORIGIN: u32 = 1 << 30;
};

// =============================================================================
// Dameth Flags (polymost.h lines 224-267)
// =============================================================================

pub const Dameth = struct {
    pub const NOMASK: i32 = 0;
    pub const MASK: i32 = 1;
    pub const TRANS1: i32 = 2;
    pub const TRANS2: i32 = 3;
    pub const MASKPROPS: i32 = 3;
    pub const CLAMPED: i32 = 4;
    pub const WALL: i32 = 32; // signals a texture for a wall (for r_npotwallmode)
    pub const INDEXED: i32 = 512;
    pub const N64: i32 = 1024;
    pub const N64_INTENSIVITY: i32 = 2048;
    pub const N64_SCALED: i32 = 2097152;

    // used internally by polymost_domost
    pub const BACKFACECULL: i32 = -1;

    // used internally by uploadtexture
    pub const NODOWNSIZE: i32 = 4096;
    pub const HI: i32 = 8192;
    pub const NOFIX: i32 = 16384;
    pub const NOTEXCOMPRESS: i32 = 32768;
    pub const HASALPHA: i32 = 65536;
    pub const ONEBITALPHA: i32 = 131072;
    pub const ARTIMMUNITY: i32 = 262144;
    pub const HASFULLBRIGHT: i32 = 524288;
    pub const NPOTWALL: i32 = 1048576;

    pub const UPLOADTEXTURE_MASK: i32 = HI | NODOWNSIZE | NOFIX | NOTEXCOMPRESS |
        HASALPHA | ONEBITALPHA | ARTIMMUNITY | HASFULLBRIGHT | NPOTWALL;
};

// =============================================================================
// Pth Flags (polymost.h lines 290-313)
// =============================================================================

pub const PthFlags = struct {
    pub const CLAMPED: u16 = 1;
    pub const HIGHTILE: u16 = 2;
    pub const SKYBOX: u16 = 4;
    pub const HASALPHA: u16 = 8;
    pub const HASFULLBRIGHT: u16 = 16;
    pub const NPOTWALL: u16 = Dameth.WALL; // r_npotwallmode=1 generated texture
    pub const FORCEFILTER: u16 = 64;
    pub const INVALIDATED: u16 = 128;
    pub const NOTRANSFIX: u16 = 256; // fixtransparency() bypassed
    pub const INDEXED: u16 = 512;
    pub const ONEBITALPHA: u16 = 1024;
    pub const N64: u16 = 2048;
    pub const N64_INTENSIVITY: u16 = 4096;
    pub const N64_SCALED: u16 = 8192;
    // temporary until I create separate flags for samplers
    pub const DEPTH_SAMPLER: u16 = 16384;
    pub const TEMP_SKY_HACK: u16 = 32768;
};

// =============================================================================
// GL Sampler Types (glbuild.h lines 27-43)
// =============================================================================

pub const SamplerType = enum(i32) {
    invalid = -1,
    none = 0,
    nearest_clamp = 1,
    nearest_wrap = 2,
    linear_clamp = 3,
    linear_wrap = 4,
    nearest_nearest_clamp = 5,
    nearest_nearest_wrap = 6,
    clamp = 7,
    wrap_t = 8,
    wrap_s = 9,
    wrap_both = 10,
    depth = 11,
};

// =============================================================================
// Tile Shade Modes (polymost.h lines 134-139)
// =============================================================================

pub const TileShadeModes = enum(i32) {
    none = 0,
    shadetable = 1,
    texture = 2,
};

// =============================================================================
// Texture Invalidation Types (polymost.h lines 81-86)
// =============================================================================

pub const InvalidateType = enum(i32) {
    all = 0,
    art = 1,
    all_non_indexed = 2,
    art_non_indexed = 3,
};

// =============================================================================
// Polymer Material Bits (polymer.h lines 66-89)
// =============================================================================

pub const PrBit = enum(i32) {
    header = 0, // must be first
    anim_interpolation = 1,
    lighting_pass = 2,
    normal_map = 3,
    art_map = 4,
    diffuse_map = 5,
    diffuse_detail_map = 6,
    diffuse_modulation = 7,
    diffuse_map2 = 8,
    highpalookup_map = 9,
    specular_map = 10,
    specular_material = 11,
    mirror_map = 12,
    fog = 13,
    glow_map = 14,
    projection_map = 15,
    shadow_map = 16,
    light_map = 17,
    spot_light = 18,
    point_light = 19,
    footer = 20, // must be just before last
    count = 21, // must be last
};

// =============================================================================
// Cutscene Flags (build.h lines 1572-1577)
// =============================================================================

pub const CutsceneFlags = struct {
    pub const FORCEFILTER: i32 = 1;
    pub const FORCENOFILTER: i32 = 2;
    pub const TEXTUREFILTER: i32 = 4;
    pub const FILTERMASK: i32 = FORCEFILTER | FORCENOFILTER | TEXTUREFILTER;
};

// =============================================================================
// Texture Filter Modes (build.h lines 1586-1589)
// =============================================================================

pub const TexFilter = enum(i32) {
    off = 0, // GL_NEAREST
    on = 5, // GL_LINEAR_MIPMAP_LINEAR
};

// =============================================================================
// Sector/Floor stat bits (from buildtypes.h comments)
// =============================================================================

pub const SectorStat = struct {
    pub const PARALLAX: u16 = 1 << 0;
    pub const GROUDRAW: u16 = 1 << 1;
    pub const SWAPXY: u16 = 1 << 2;
    pub const DOUBLE_SMOOSH: u16 = 1 << 3;
    pub const XFLIP: u16 = 1 << 4;
    pub const YFLIP: u16 = 1 << 5;
    pub const ALIGN_FIRST_WALL: u16 = 1 << 6;
    pub const MASKED: u16 = 0b10 << 7;
    pub const TRANS_MASKED: u16 = 0b01 << 7;
    pub const TRANS_MASKED_REV: u16 = 0b11 << 7;
    pub const BLOCKING: u16 = 1 << 9;
    pub const YAX: u16 = 1 << 10;
    pub const HITSCAN: u16 = 1 << 11;
};

// =============================================================================
// Tests
// =============================================================================

test "sprite alignment values" {
    try std.testing.expectEqual(@as(u16, 0), CstatSprite.ALIGNMENT_FACING);
    try std.testing.expectEqual(@as(u16, 16), CstatSprite.ALIGNMENT_WALL);
    try std.testing.expectEqual(@as(u16, 32), CstatSprite.ALIGNMENT_FLOOR);
    try std.testing.expectEqual(@as(u16, 48), CstatSprite.ALIGNMENT_SLOPE);
}

test "rotatesprite flag values" {
    try std.testing.expectEqual(@as(u32, 1), RSFlags.TRANS1);
    try std.testing.expectEqual(@as(u32, 33), RSFlags.TRANS_MASK);
    try std.testing.expectEqual(@as(u32, 131072), RSFlags.MAX);
}

test "render modes" {
    try std.testing.expectEqual(@as(i32, 0), @intFromEnum(RendMode.classic));
    try std.testing.expectEqual(@as(i32, 3), @intFromEnum(RendMode.polymost));
    try std.testing.expectEqual(@as(i32, 4), @intFromEnum(RendMode.polymer));
}
