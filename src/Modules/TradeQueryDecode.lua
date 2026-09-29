-- Decode gzip-compressed trade website share queries.
-- SimpleGraphic's Inflate only supports zlib streams, so use zlib's gzip mode.
local ffi = require("ffi")
if not pcall(ffi.typeof, "pob_trade_z_stream") then
ffi.cdef[[
typedef struct {
	const unsigned char *next_in;
	unsigned int avail_in;
	unsigned long total_in;
	unsigned char *next_out;
	unsigned int avail_out;
	unsigned long total_out;
	const char *msg;
	void *state;
	void *(*zalloc)(void *, unsigned int, unsigned int);
	void (*zfree)(void *, void *);
	void *opaque;
	int data_type;
	unsigned long adler;
	unsigned long reserved;
} pob_trade_z_stream;
const char *zlibVersion(void);
int inflateInit2_(pob_trade_z_stream *, int, const char *, int);
int inflate(pob_trade_z_stream *, int);
int inflateEnd(pob_trade_z_stream *);
]]
end
local zlib = ffi.load(ffi.os == "Windows" and "zlib1" or "z")

return function(compressed)
	-- Trade queries are small; cap expansion to avoid unbounded allocations.
	local capacity = 1024 * 1024
	local output = ffi.new("unsigned char[?]", capacity)
	local stream = ffi.new("pob_trade_z_stream[1]")
	stream[0].next_in = compressed
	stream[0].avail_in = #compressed
	stream[0].next_out = output
	stream[0].avail_out = capacity
	if zlib.inflateInit2_(stream, 31, zlib.zlibVersion(), ffi.sizeof(stream[0])) ~= 0 then
		return nil
	end
	local status = zlib.inflate(stream, 4) -- Z_FINISH
	local length = tonumber(stream[0].total_out)
	local remaining = stream[0].avail_in
	zlib.inflateEnd(stream)
	if status ~= 1 or remaining ~= 0 then -- Z_STREAM_END
		return nil
	end
	return ffi.string(output, length)
end
