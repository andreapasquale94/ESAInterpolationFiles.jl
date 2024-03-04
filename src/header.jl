
struct IPFHeader
    type::Int
    version::Int
    n_columns::Int
    n_derivatives::Int
    n_blocks::Int
    user_header::Vector{Int32}
    tail_offset::Int
    block_header_size::Int
    bigend::Bool
    record_size::UInt
end

function Base.show(io::IO, h::IPFHeader)
    print(io, "IPFHeader(")
    print(io, "type=$(h.type), ")
    print(io, "version=$(h.version), ")
    print(io, "n_columns=$(h.n_columns), ")
    print(io, "n_derivatives=$(h.n_derivatives), ")
    print(io, "n_blocks=$(h.n_blocks), ")
    print(io, "user_header=$(Int.(h.user_header)), ")
    print(io, "tail_offset=$(h.tail_offset), ")
    print(io, "block_header_size=$(h.block_header_size), ")
    print(io, "bigend=$(h.bigend), ")
    print(io, "record_size=$(h.record_size)")
    print(io, ")")
end

@inbounds function IPFHeader(array::Vector{UInt8})

    # Read the magic string (8 bytes)
    @views magic = String(array[1:8])
    if magic != "ESAFDIPF"
        throw(
            ErrorException("Corrupted file, magic number is wrong!")
        ) 
    end

    # Read endianness indicator (4 bytes)
    tmp = get_int32(array, 8, false)
    bend = !(tmp == 1)
    if tmp == (1 << 24)
        bend = true
    end

    # Read version number (uint32, 4 bytes)
    version = get_int32(array, 12, bend)
    # Read key type (int32, 4 bytes)
    key_type = get_int32(array, 16, bend)
    # Read value type (int32, 4 bytes)
    value_type = get_int32(array, 20, bend)
    if key_type != 3 || value_type != 3
        throw(
            ErrorException("Type not handles. Only doubles are handled (i.e. type = 3).")
        )
    end
    # byte size of keys and values
    key_bsize = 8 
    value_bsize = 8

    # Read other entries
    n_cols = get_int32(array, 24, bend)
    if n_cols == 0
        error("The file has no columns and is invalid!")
    end
    n_der = get_int32(array, 28, bend)
    file_type =  get_int32(array, 32, bend)
    n_blocks = get_int64(array, 36, bend)

    tail_offset = get_int64(array, 44, bend)
    if tail_offset > length(array)
        throw(
            ErrorException("Corrupted file: file tail offset is larger than file size!")
        )
    end

    padding = 2*key_bsize # 2*sizeof(double)
    off = 52 + padding
    
    user_file_header_size = get_int32(array, off, bend)
    user_block_header_size = get_int32(array, off+4, bend)

    Δ = user_file_header_size * 4 - 1
    @views user_header = reinterpret(Int32, array[77:77+Δ])

    record_size = key_bsize + n_cols*(n_der+1)*value_bsize # this depends on key/value types

    return IPFHeader(
        file_type, version, n_cols, n_der, n_blocks, user_header, tail_offset, 
        user_block_header_size, bend, record_size
    )

end