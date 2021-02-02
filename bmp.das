options remove_unused_symbols = false
options indenting = 4

module bmp shared

require fio
require math
require strings

struct FileHolder
    f: fio::FILE const?

[private]
def write(var res: FileHolder; data)
    res.f |> fwrite(data)

[private]
def write(var res: array<uint8>; data: uint8)
    res |> push(data)

[private]
def write(var res: array<uint8>; data: uint)
    res |> push(uint8(data & 0xFF))
    res |> push(uint8(data >> 8u & 0xFF))
    res |> push(uint8(data >> 16u & 0xFF))
    res |> push(uint8(data >> 24u & 0xFF))

[private]
def write(var res: array<uint8>; d: int)
    write(res, uint(d))

[private]
def write(var res: array<uint8>; data: uint16)
    res |> push(uint8(uint(data) & 0xFF))
    res |> push(uint8(uint(data) >> 8u & 0xFF))

[private]
def write(var res: array<uint8>; data: array<uint8>)
    for it in data
        res |> push(it)

[private]
def write_header(var res; width, height: int): void
    let pixelDataOffset = 54u // 14 + 40
    res |> write(uint8('B'))
    res |> write(uint8('M'))
    res |> write(pixelDataOffset + uint(width * height * 3))
    res |> write(uint(0)) // reservedBytes
    res |> write(pixelDataOffset)

[private]
def write_info_header(var res; width, height: int): void
    res |> write(uint(40)) // sizeOfThisHeader
    res |> write(width)
    res |> write(height)
    res |> write(uint16(1)) // numberOfColorPlanes
    res |> write(uint16(24)) // colorDepth
    res |> write(uint(0)) // compressionMethod
    res |> write(uint(0)) // rawBitmapDataSize
    res |> write(3780) // horizontalResolution
    res |> write(3780) // verticalResolution
    res |> write(uint(0)) // colorTableEntries
    res |> write(uint(0)) // importantColors 


[private]
def write(var s; width, height: int; blk: block<(var b:array<uint8>):void>): void
    verify(width % 4 == 0)
    s |> write_header(width, height)
    s |> write_info_header(width, height)
    var b: array<uint8>
    invoke(blk, b)
    assert(length(b) == width * height * 3)
    write(s, b)


def linear_to_SRGB(color: float3)
    var x = float4(color.x, color.y, color.z, 1.0)
    x = max(x, float4(0));
    x = max(1.055 * pow(x, float4(0.416666667)) - float4(0.055), float4(0));
    return pack_float_to_byte(x.zyxw * float4(255.0))


[private]
def convert(arr:array<float3>; width, height: int; var bytes:array<uint8>)
    bytes |> resize(width * height * 3)
    for i, f3c in iter_range(arr), arr
        let color = linear_to_SRGB(f3c)
        let x = i % width
        let y = i / width
        let idx = (height - y - 1) * width + x
        bytes[idx * 3] = uint8(color & 0xFF)
        bytes[idx * 3 + 1] = uint8((color >> 8u) & 0xFF)
        bytes[idx * 3 + 2] = uint8((color >> 16u) & 0xFF)


def writeFile(fileName: string; width, height: int; blk: block<(var b:array<uint8>):void>): bool
    verify(width % 4 == 0)
    var saved = false
    fopen(fileName, "wb") <| $ (fbmp)
        if fbmp != null
            var fileHolder = [[FileHolder f = fbmp]]
            write(fileHolder, width, height, blk)
            saved = true
    return saved


def writeFile(fileName: string; width, height:int; arr:array<float3>): bool
    verify(width * height == length(arr))
    return writeFile(fileName, width, height) <| $ (bytes)
        convert(arr, width, height, bytes)


def writeArray(var res: array<uint8>; width, height: int; blk: block<(var b:array<uint8>):void>)
    write(res, width, height, blk)


def writeArray(var res: array<uint8>; width, height:int; arr:array<float3>)
    verify(width * height == length(arr))
    writeArray(res, width, height) <| $ (bytes)
        convert(arr, width, height, bytes)
