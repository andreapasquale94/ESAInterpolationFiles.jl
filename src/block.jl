struct IPFBlockInfo
    start_key::Float64
    end_key::Float64
    offset::Int
    n_records::Int
    header::Vector{Int32}
end

function Base.show(io::IO, b::IPFBlockInfo)
    print(io, "IPFBlockInfo(")
    print(io, "header=$(Int.(b.header)), "),
    print(io, "$(b.start_key), ")
    print(io, "$(b.end_key), ")
    print(io, "$(b.offset), ")
    print(io, "$(b.n_records)")
    print(io, ")")
end

@inbounds function IPFBlockInfo(array, offset, block_header_size, bend)
    block_start_key = get_float(array, offset, bend)
    block_end_key = get_float(array, offset+8, bend)
    block_offset = get_int64(array, offset+16, bend)
    n_records = get_int64(array, offset+24, bend)
    @views header = reinterpret(UInt32, array[block_offset+1 : block_offset+block_header_size*4])
    return IPFBlockInfo(block_start_key, block_end_key, block_offset, n_records, header)
end