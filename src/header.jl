struct IPFHeader
    type::Int32
    version::UInt32
    n_columns::UInt32
    n_derivatives::UInt32
    n_blocks::UInt64
    user_header::Vector{Int32}
    tail_offset::Int
    block_header_size::UInt32
    is_bigendian::Bool
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
    print(io, "is_bigendian=$(h.is_bigendian), ")
    print(io, "record_size=$(h.record_size)")
    print(io, ")")
end

@inbounds function IPFHeader(array::Vector{UInt8})

    @views begin
        # Read the magic string (8 bytes)
        magic = String(array[1:8])
        if magic != "ESAFDIPF"
            throw(
                ErrorException("Corrupted file, magic number is wrong!")
            ) 
        end

        # Read endianness indicator (4 bytes)
        tmp = reinterpret(UInt32, array[9:12])[1]
        endianess = !(tmp == 1)
        if tmp == (1 << 24)
            endianess = 1
        end

        # Read version number (uint32, 4 bytes)
        version = reinterpret(UInt32, array[13:16])[1]
        # Read key type (int32, 4 bytes)
        key_type = reinterpret(UInt32, array[17:20])[1]
        # Read value type (int32, 4 bytes)
        value_type = reinterpret(UInt32, array[21:24])[1]
        if key_type != 3 || value_type != 3
            throw(
                ErrorException("Type not handles. Only doubles are handled (i.e. type = 3).")
            )
        end
        # byte size of keys and values
        key_bsize = 8 
        value_bsize = 8

        # Read other entries
        n_cols = reinterpret(UInt32, array[25:28])[1]
        if n_cols == 0
            error("The file has no columns and is invalid!")
        end
        n_deriv = reinterpret(UInt32, array[29:32])[1]
        file_type = reinterpret(UInt32, array[33:36])[1]
        n_blocks = reinterpret(UInt64, array[37:44])[1]

        tail_offset = reinterpret(UInt64, array[45:52])[1] + 1
        if tail_offset > length(array)
            throw(
                ErrorException("Corrupted file: file tail offset is larger than file size!")
            )
        end

        padding = 2*key_bsize + 1 # 2*sizeof(double) + 1 (as julia is 1-indexed)
        off = 52 + padding
        user_file_header_size = reinterpret(UInt32, array[off:off+3])[1]
        user_block_header_size = reinterpret(UInt32, array[off+4:off+7])[1]

        Δ = user_file_header_size * 4 - 1
        user_header = reinterpret(UInt32, array[77:77+Δ])

        record_size = key_bsize + n_cols*(n_deriv+1)*value_bsize # this depends on key/value types
    end

    return IPFHeader(
        file_type, version, n_cols, n_deriv, n_blocks, user_header, tail_offset, 
        user_block_header_size, endianess, record_size
    )

end