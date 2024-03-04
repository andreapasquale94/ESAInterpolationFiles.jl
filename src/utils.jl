

# Read from array the string at address with given length
function get_string(array, address::Integer, bytes::Integer)
    # address is in 0-index notation!
    @inbounds rstrip(String(@view(array[address+1:address+bytes])))
end

@inline get_num(x::Number, bend::Bool) = bend ? hton(x) : htol(x)

function get_int32(array, address::Integer, bend::Bool) 
    # address is in 0-index notation!
    ptr = unsafe_load(Ptr{Int32}(pointer(array, address+1)))
    get_num(ptr, bend)
end

function get_int64(array, address::Integer, bend::Bool) 
    # address is in 0-index notation!
    ptr = unsafe_load(Ptr{Int64}(pointer(array, address+1)))
    get_num(ptr, bend)
end

function get_float(array, address::Integer, bend::Bool) 
    # address is in 0-index notation!
    ptr = unsafe_load(Ptr{Float64}(pointer(array, address+1)))
    get_num(ptr, bend)
end

@inline @views function get_record(array, index::Integer, length::Integer)
    @inbounds return array[1+length*(index-1):length*index]
end