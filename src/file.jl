export IPF, get_block, get_record, get_records

"""
    IPF{C, V}

Struct to store ESA/ESOC Interpolation File data.

- `filepath::String`: The path to the IPF file.
- `header::IPFHeader`: The header information of the IPF file.
- `blocks::Vector{IPFBlockInfo}`: Information about the blocks within the IPF file.
- `first_key::V`: The first key value stored in the IPF file.
- `last_key::V`: The last key value stored in the IPF file.
- `array::Vector{UInt8}`: An array containing the binary data of the IPF file.
- `cache::InterpCache{C, V}`: Cache for interpolation data.

Here the parameters are the cache-type `C` and the value type `V`.

## Constructors

- `IPF{C, V}(filepath::String)`: Constructs an `IPF` object from the specified file path, 
    with the option to specify the types for cache (`C`) and values (`V`).
- `IPF(filepath::String)`: Constructs an `IPF` object with default types 
    `Float64` for both cache and values.
"""
struct IPF{cType, vType}
    filepath::String
    header::IPFHeader
    blocks::Vector{IPFBlockInfo}
    first_key::vType 
    last_key::vType
    array::Vector{UInt8}
    cache::InterpCache{cType, vType}
end

function IPF{cType, vType}(filepath::String) where {cType, vType}
    array = Mmap.mmap(filepath)

    # Construct header
    header = IPFHeader(array)

    # Read first and last key
    first_key = get_float(array, 52, header.bigend)
    last_key = get_float(array, 60, header.bigend)

    # Build blocks info
    blocks = blocks_info(array, header.tail_offset, header)

    cache = InterpCache{cType, vType}(
        header.user_header[2]+1, 
        header.n_columns*(1 + header.n_derivatives) + 1, 
        header.n_derivatives > 0 ? 2 : 1
    )

    # Create Ipf file
    return IPF{cType, vType}(filepath, header, blocks, first_key, last_key, array, cache)
end

function IPF(filepath::String)
    return IPF{Float64, Float64}(filepath)
end

function blocks_info(array::Vector{UInt8}, offset, header)
    # Construct all the ipfblockinfo structures found in the file
    blocks = Vector{IPFBlockInfo}(undef, header.n_blocks)
    step = 2*8 + 2*8
    for i in eachindex(blocks)
        blocks[i] = IPFBlockInfo(array, offset, header.block_header_size, header.bigend)
        offset += step
    end
    return blocks
end

function Base.show(io::IO, f::IPF)
    print(io, "IPF(")
    print(io, "file='$(f.filepath)', ")
    print(io, "n_blocks=$(f.header.n_blocks), ")
    print(io, "first_key=$(f.first_key), ")
    print(io, "last_key=$(f.last_key)")
    print(io, ")")
end

function find_block(file::IPF, key::Number)
    # binary search to find the block that contains the key inside
    lo = 1
    hi = length(file.blocks)
    while lo ≤ hi
        mid = lo + (hi - lo) ÷ 2
        block = file.blocks[mid]
        if key ≥ block.start_key && key < block.end_key
            return (key ≥ block.start_key && key < block.end_key) ? mid : @goto err
        elseif key < block.start_key
            hi = mid - 1
        else
            lo = mid + 1
        end
    end

    @label err 
    throw(ErrorException("Cannot find any block that contains key = $(key)."))
end

function get_block(file::IPF, key::Number)
    bid = find_block(file, key)
    return file.blocks[bid]
end

function get_record!(cache::AbstractVector, file::IPF, bid::Integer, rid::Integer)
    block = file.blocks[bid]
    # Offset to record start 
    # this include the block offset, the block header size and the previous records size
    offset = block.offset + file.header.block_header_size*4 + (rid-1)*file.header.record_size

    # Dimension of the record (in Float64) 
    dim = file.header.record_size ÷ 8 
    @assert length(cache) ≥ dim "not enough space in the cache to get the required record"
    for i in 1:dim
        cache[i] = get_float(file.array, offset + (i-1)*8, file.header.bigend)
    end
    nothing
end

function get_record(file::IPF, bid::Integer, rid::Integer)
    dim = file.header.record_size ÷ 8 
    cache = zeros(Float64, dim)
    get_record!(cache, file, bid, rid)
    return cache
end

function get_records!(
    out, file::IPF, b::IPFBlockInfo, first::Int, count::Int, 
    maxdim::Int, initdim::Int = 1
)
    # Find offset of the first element
    offset = b.offset + file.header.block_header_size*4 
    offset += (first-1)*file.header.record_size
 
    for i in 1:count
        k = offset + (i-1)*file.header.record_size
        for j in initdim:maxdim 
            out[i][j] = get_float(
                file.array, k+(j-1)*8, file.header.bigend
            )
        end
    end
    nothing
end

function get_records!(out, file::IPF, bid::Int, first::Int, count::Int)
    get_records!(out, file, file.blocks[bid], first, count)
    nothing
end

function get_records(file::IPF, block::IPFBlockInfo)
    records = Vector{Vector{Float64}}()
    for i in 1:block.n_records
        offset = block.offset + file.header.block_header_size*4 + (i-1)*file.header.record_size
        push!(
            records, 
            reinterpret(Float64, file.array[offset+1 : offset+file.header.record_size])
        )
    end
    return records
end

function get_records(file::IPF, bid::Integer)
    block = file.blocks[bid]
    return get_records(file, block)
end

function find_record(file::IPF, block::IPFBlockInfo, key::Number)
    # binary search to find the closest record 
    lo = 1 
    hi = block.n_records
    while lo ≤ hi
        mid = lo + (hi - lo) ÷ 2
        offset = block.offset + file.header.block_header_size*4 + (mid-1)*file.header.record_size
        val = get_float(file.array, offset, file.header.bigend)

        if key < val 
            hi = mid - 1
        else
            lo = mid + 1
        end
    end
    return lo-1
end

function find_record(file::IPF, bid::Integer, key::Number)
    block = file.blocks[bid]
    return find_record(file, block, key)
end

function get_block_maxsize(file::IPF)
    maxs = 0
    for b in file.blocks
        b.n_records > maxs ? maxs = b.n_records : nothing 
    end
    return maxs 
end