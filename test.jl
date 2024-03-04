
using Ipf
using StaticArrays
using PreallocationTools
f = IPF("leo1.orb")
b = f.blocks[1]

function get_records(file, blockid)

    block = file.blocks[blockid]
    records = Vector{Vector{Float64}}()
    for i in 1:block.n_records
        offset = block.offset + file.header.block_header_size*4 + (i-1)*file.header.record_size
        push!(
            records, 
            reinterpret(Float64, file.array[offset+1: offset+file.header.record_size])
        )
    end
    return records
end


struct Cache{T}
    x::Vector{T}
    y::Vector{Vector{T}}
    l::Vector{T}
    buff::Vector{T}

    function Cache{T}(maxdim::Int, cols::Int) where T 
        l = ones(T, maxdim)
        buff = zeros(T, cols)
        k = zeros(T, maxdim)
        v = [zeros(T, cols) for _ in 1:maxdim]
        return new{T}(k, v, l, buff)
    end
end

@inbounds function lagrange(cache::Cache{T}, order, cols, x) where T
    n = order+1

    # Reset cache
    fill!(cache.buff, zero(T))
    fill!(cache.l, one(T))

    for j in 1:n, i in 1:n 
        if i ≠ j 
            cache.l[j] *= (x - cache.x[i])/(cache.x[j] - cache.x[i])
        end
    end

    for k in 1:cols, j in 1:n
        cache.buff[k] += cache.l[j] * cache.y[j][k]
    end

    return @views cache.buff[1:cols]
end

# find block
bid = Ipf.find_block(f, 7336.5)
b = f.blocks[bid]
rid = Ipf.find_record(f, b, 7336.5)
records = get_records(f, bid)

# create cache
order = 3
subset = @views records[rid-(order÷2):rid+(order+1)÷2]
c = Cache{Float64}(order+1, 6)
for i in eachindex(subset)
    c.x[i] = subset[i][1]
    @views c.y[i] .= subset[i][2:7]
end

# eval
lagrange(c, order, 6, 7336.5)