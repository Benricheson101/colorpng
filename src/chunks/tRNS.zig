const SimpleChunkData = @import("./simple.zig").SimpleChunkData;
const PNGChunk = @import("../chunk.zig").PNGChunk;

pub const tRNS = PNGChunk(.{ 't', 'R', 'N', 'S' }, SimpleChunkData);
