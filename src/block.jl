struct IPFBlockInfo{N}
    start_key::N
    end_key::N
    offset::UInt
    n_records::UInt
    function IPFBlockInfo(start::N, stop::N, off::UInt, nrec::UInt) where N
        return new{N}(start, stop, off, nrec)
    end
end

function Base.show(io::IO, b::IPFBlockInfo{N}) where N
    print(io, "IPFBlockInfo(")
    print(io, "$(b.start_key), ")
    print(io, "$(b.end_key), ")
    print(io, "$(b.offset), ")
    print(io, "$(b.n_records)")
    print(io, ")")
end

@inbounds function IPFBlockInfo{N}(array::Vector{UInt8}, offset::Int, size::Int=8) where N
    @views begin
        block_start_key = reinterpret(N, array[offset:offset+size-1])[1]
        block_end_key = reinterpret(N, array[offset+size:offset+2*size-1])[1]
        block_offset = reinterpret(UInt64, array[offset+2*size:offset+3*size-1])[1] + 1
        n_records = reinterpret(UInt64, array[offset+3*size:offset+4*size-1])[1]
    end
    return IPFBlockInfo(block_start_key, block_end_key, block_offset, n_records)
end

function blocks_info(::Type{N}, array::Vector{UInt8}, offset::Int) where N
    blocks = Vector{IPFBlockInfo{N}}()
    step = 2*sizeof(N) + 2*8
    while offset ≤ length(array)
        push!(
            blocks,
            IPFBlockInfo{N}(array, offset, sizeof(N))
        )
        offset += step
    end
    return blocks
end