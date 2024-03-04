export IPF

struct IPF
    filepath::String
    header::IPFHeader
    blocks::Vector{IPFBlockInfo}
    first_key::Float64 
    last_key::Float64
    array::Vector{UInt8}
end

function IPF(filepath::String)
    array = Mmap.mmap(filepath)
    # Construct header
    header = IPFHeader(array)

    # Read first and last key
    first_key = get_float(array, 52, header.bigend)
    last_key = get_float(array, 60, header.bigend)

    # Build blocks info
    blocks = blocks_info(array, header.tail_offset, header)

    # Create Ipf file
    return IPF(filepath, header, blocks, first_key, last_key, array)
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
    throw(ErrorException("Cannot find block that contains key = $(key)."))
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

function get_block_maxsize(file::IPF)
    maxs = 0
    for b in file.blocks
        b.n_records > maxs ? maxs = b.n_records : nothing 
    end
    return maxs 
end