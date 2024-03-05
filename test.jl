
using Ipf
using StaticArrays
using PreallocationTools

struct InterpCache{T}
    x::Vector{T}
    y::Vector{Vector{T}}

    # buffers
    l::Vector{Vector{T}}
    buff::Vector{T}

    function InterpCache{T}(maxdim::Int, cols::Int, diff::Int) where T 
        k = zeros(T, maxdim)
        v = [zeros(T, cols) for _ in 1:maxdim]
        l = [ones(T, maxdim) for _ in 1:diff]
        buff = zeros(T, cols)
        return new{T}(k, v, l, buff)
    end
end

@inbounds function lagrange(cache::InterpCache{T}, order, cols, x) where T
    n = order+1
    # Reset cache
    fill!(cache.buff, zero(T))
    fill!(cache.l[1], one(T))

    for j in 1:n, i in 1:n 
        if i ≠ j 
            cache.l[1][j] *= (x - cache.x[i])/(cache.x[j] - cache.x[i])
        end
    end

    for k in 1:cols, j in 1:n
        cache.buff[k] += cache.l[1][j] * cache.y[j][k]
    end

    return @views cache.buff[1:cols]
end

@inbounds function hermite(cache::InterpCache{T}, order, cols, x) where T 
    n = order+1
    fill!(cache.buff, zero(T))
    fill!(cache.l[1], one(T))
    fill!(cache.l[2], zero(T))

    for j in 1:n, i in 1:n
        if i ≠ j 
            Δx = cache.x[j] - cache.x[i]
            cache.l[1][j] *= (x - cache.x[i])/Δx
            cache.l[2][j] += 1/Δx
        end
    end

    for k in 1:cols, j in 1:n
        Δx = x - cache.x[j]
        l² = cache.l[1][j] * cache.l[1][j]
        ϕ = (1 - 2*Δx*cache.l[2][j]) * l²
        ψ = Δx * l²
        cache.buff[k] += ϕ * cache.y[j][k] + ψ * cache.y[j][cols+k]
    end

    return @views cache.buff[1:cols]
end

# ---------------------------------------------------------------
# LAGRANGE
f = IPF("leo1.orb")
e = 7336.5

# find block
bid = Ipf.find_block(f, e)
b = f.blocks[bid]
rid = Ipf.find_record(f, b, e)
records = get_records(f, bid)

# create cache
order = 11
subset = @views records[rid-(order÷2):rid+(order+1)÷2]
c = InterpCache{Float64}(order+1, 6, 1)
for i in eachindex(subset)
    c.x[i] = subset[i][1]
    @views c.y[i] .= subset[i][2:7]
end

# eval
lagrange(c, order, 6, e)

# ---------------------------------------------------------------
# HERMITE
f = IPF("sol.orb")
e = 7350.0

# find block
bid = Ipf.find_block(f, e)
b = f.blocks[bid]
rid = Ipf.find_record(f, b, e)
records = get_records(f, bid)

# create cache
order = 11
subset = @views records[rid-(order÷2):rid+(order+1)÷2]
c2 = InterpCache{Float64}(order+1, 12, 2)
for i in eachindex(subset)
    c2.x[i] = subset[i][1]
    @views c2.y[i] .= subset[i][2:end]
end

# eval
hermite(c2, order, 6, e)