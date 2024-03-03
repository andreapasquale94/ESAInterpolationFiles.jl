export IPF

struct IPF{N}
    filepath::String
    header::IPFHeader
    blocks::Vector{IPFBlockInfo{N}}
    first_key::N 
    last_key::N
    array::Vector{UInt8}
end

function IPF(filepath::String)
    array = Mmap.mmap(filepath)
    header = IPFHeader(array)
    @inbounds @views begin
        first_key = reinterpret(Float64, array[53:60])[1]
        last_key = reinterpret(Float64, array[61:68])[1]
    end
    blocks = blocks_info(Float64, array, header.tail_offset)
    return IPF{Float64}(filepath, header, blocks, first_key, last_key, array)
end

function Base.show(io::IO, f::IPF)
    print(io, "IPF(")
    print(io, "file='$(f.filepath)', ")
    print(io, "n_blocks=$(f.header.n_blocks), ")
    print(io, "first_key=$(f.first_key), ")
    print(io, "last_key=$(f.last_key)")
    print(io, ")")
end