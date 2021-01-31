options remove_unused_symbols = false
options indenting = 4

module bmp shared

require fio
require math

[private]
def write_header(f: fio::FILE const?; width,height: int): void
    let pixelDataOffset = 54u // 14 + 40
    f |> fwrite(uint8('B'))
    f |> fwrite(uint8('M'))
    f |> fwrite(pixelDataOffset + uint(width * height * 3))
    f |> fwrite(uint(0)) // reservedBytes
    f |> fwrite(pixelDataOffset)

[private]
def write_info_header(f: fio::FILE const?; width,height: int): void
    f |> fwrite(uint(40)) // sizeOfThisHeader
    f |> fwrite(width)
    f |> fwrite(height)
    f |> fwrite(uint16(1)) // numberOfColorPlanes
    f |> fwrite(uint16(24)) // colorDepth
    f |> fwrite(uint(0)) // compressionMethod
    f |> fwrite(uint(0)) // rawBitmapDataSize
    f |> fwrite(3780) // horizontalResolution
    f |> fwrite(3780) // verticalResolution
    f |> fwrite(uint(0)) // colorTableEntries
    f |> fwrite(uint(0)) // importantColors 


def save_BMP(fileName: string; width, height: int; blk: block<(var b:array<uint8>):void>): bool
    verify(width % 4 == 0)
    var saved = false
    fopen(fileName, "wb") <| $ (fbmp)
        if fbmp != null
            fbmp |> write_header(width, height)
            fbmp |> write_info_header(width, height)
            var b: array<uint8>
            invoke(blk, b)
            assert(length(b) == width * height * 3)
            fwrite(fbmp, b)
            saved = true
    return saved

def linear_to_SRGB(color: float3)
    var x = float4(color.x, color.y, color.z, 1.0)
    x = max(x, float4(0));
    x = max(1.055 * pow(x, float4(0.416666667)) - float4(0.055), float4(0));
    return pack_float_to_byte(x.zyxw * float4(255.0))

def save_BMP(fileName: string; width, height:int; arr:array<float3>): bool
    if width * height != length(arr)
        return false
    return save_BMP(fileName, width, height) <| $ (bytes)
        bytes |> resize(width * height * 3)
        for i, f3c in iter_range(arr), arr
            let color = linear_to_SRGB(f3c)
            let x = i % width
            let y = i / width
            let idx = (height - y - 1) * width + x
            bytes[idx * 3] = uint8(color & 0xFF)
            bytes[idx * 3 + 1] = uint8((color >> 8u) & 0xFF)
            bytes[idx * 3 + 2] = uint8((color >> 16u) & 0xFF)
