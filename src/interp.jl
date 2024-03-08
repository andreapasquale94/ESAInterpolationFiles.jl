struct InterpCache{cType, vType}
    y::Vector{Vector{vType}}

    # buffers
    l::Vector{DiffCache{Vector{cType}, Vector{cType}}}
    buff::DiffCache{Vector{cType}, Vector{cType}}

    function InterpCache{cType, vType}(max_dim::Int, cols::Int, diff::Int) where {cType, vType}
        v = [zeros(vType, cols+1) for _ in 1:max_dim]
        l = [DiffCache(ones(cType, max_dim)) for _ in 1:diff]
        buff = DiffCache(zeros(cType, cols))
        return new{cType, vType}(v, l, buff)
    end
end

@inbounds function lagrange(
    cache::InterpCache{cType, vType}, order::Int, cols::Int, x::Number, offset::Int = 1
) where {cType, vType}
    n = order+1

    # get and reset caches 
    l = get_tmp(cache.l[1], x)
    fill!(l, cType(1))
    buff = get_tmp(cache.buff, x)
    fill!(buff, cType(0))

    # update basis
    for j in 1:n, i in 1:n 
        if i ≠ j 
            l[j] *= (x - cache.y[i][1])/(cache.y[j][1] - cache.y[i][1])
        end
    end

    # update buffer
    for k in offset:offset+cols-1, j in 1:n
        buff[k] += l[j] * cache.y[j][k+1]
    end

    return @views buff[offset:offset+cols-1]
end

@inbounds function hermite(
    cache::InterpCache{cType, vType}, order::Int, cols::Int, x::Number, offset::Int = 1
) where {cType, vType}
    n = order+1

    # get and reset caches
    l1 = get_tmp(cache.l[1], x)
    fill!(l1, cType(1))
    l2 = get_tmp(cache.l[2], x)
    fill!(l2, cType(0))
    buff = get_tmp(cache.buff, x)
    fill!(buff, cType(0))

    # update basis
    for j in 1:n, i in 1:n
        if i ≠ j 
            Δx = cache.y[j][1] - cache.y[i][1]
            l1[j] *= (x - cache.y[i][1])/Δx
            l2[j] += 1/Δx
        end
    end

    # update buffer
    for k in offset:offset+cols-1, j in 1:n
        Δx = x - cache.y[j][1]
        l² = l1[j] * l1[j]
        ϕ = (1 - 2*Δx*l2[j]) * l²
        ψ = Δx * l²
        buff[k] += ϕ * cache.y[j][k+1] + ψ * cache.y[j][offset+cols+k]
    end

    return @views buff[offset:offset+cols-1]
end