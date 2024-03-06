export IPFFile, find_block, get_record, get_record!, find_record, get_records

struct IPFFile
    filepath::String
    header::IPFHeader
    blocks::Vector{IPFBlockInfo}
    first_key::Float64 
    last_key::Float64
    array::Vector{UInt8}
    cache::InterpCache{Float64}
end

function IPFFile(filepath::String)
    array = Mmap.mmap(filepath)

    # Construct header
    header = IPFHeader(array)

    # Read first and last key
    first_key = get_float(array, 52, header.bigend)
    last_key = get_float(array, 60, header.bigend)

    # Build blocks info
    blocks = blocks_info(array, header.tail_offset, header)

    cache = InterpCache{Float64}(
        header.user_header[2]+1, 
        header.n_columns*(1 + header.n_derivatives) + 1, 
        header.n_derivatives > 0 ? 2 : 1
    )

    # Create Ipf file
    return IPFFile(filepath, header, blocks, first_key, last_key, array, cache)
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

function Base.show(io::IO, f::IPFFile)
    print(io, "IPFFile(")
    print(io, "file='$(f.filepath)', ")
    print(io, "n_blocks=$(f.header.n_blocks), ")
    print(io, "first_key=$(f.first_key), ")
    print(io, "last_key=$(f.last_key)")
    print(io, ")")
end

function find_block(file::IPFFile, key::Number)
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

function get_record!(cache::AbstractVector, file::IPFFile, bid::Integer, rid::Integer)
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

function get_record(file::IPFFile, bid::Integer, rid::Integer)
    dim = file.header.record_size ÷ 8 
    cache = zeros(Float64, dim)
    get_record!(cache, file, bid, rid)
    return cache
end

function get_records!(out, file::IPFFile, b::IPFBlockInfo, first::Int, count::Int)
    # Find offset of the first element
    offset = b.offset + file.header.block_header_size*4 
    offset += (first-1)*file.header.record_size

    # Dimension of the record (in Float64) 
    dim = file.header.record_size ÷ 8 
    for i in 1:count
        k = offset +  (i-1)*file.header.record_size
        for j in 1:dim 
            out[i][j] = get_float(
                file.array, k+(j-1)*8, file.header.bigend
            )
        end
    end
    nothing
end

function get_records!(out, file::IPFFile, bid::Int, first::Int, count::Int)
    get_records!(out, file, file.blocks[bid], first, count)
    nothing
end

function get_records(file::IPFFile, block::IPFBlockInfo)
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

function get_records(file::IPFFile, bid::Integer)
    block = file.blocks[bid]
    return get_records(file, block)
end

function find_record(file::IPFFile, block::IPFBlockInfo, key::Number)
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

function find_record(file::IPFFile, bid::Integer, key::Number)
    block = file.blocks[bid]
    return find_record(file, block, key)
end

function get_block_maxsize(file::IPFFile)
    maxs = 0
    for b in file.blocks
        b.n_records > maxs ? maxs = b.n_records : nothing 
    end
    return maxs 
end