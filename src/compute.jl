export compute

function compute(file::IPF, key::Number)
    return compute(file, get_block(file, key), key)
end

function compute_derivative(file::IPF, key::Number)
    return compute_derivative(file, get_block(file, key), key)
end

function _update_cache!(file::IPF, block::IPFBlockInfo, key::Number)
    header = file.header
    cache = file.cache

    # Get maximum order 
    order = header.user_header[2]
    n_records = block.n_records

    # Find record
    rid = find_record(file, block, key)

    if n_records ≤ order+1
        left, right = 1, n_records 
    else
        # Find left and right records
        left = max(1, rid - (order÷2)) 
        right = min(n_records, rid + (order+1)÷2 + 1)
    end

    # Number of points/interpolation order
    points = right - left
    order = points - 1

    get_records!(
        cache.y, file, block, left, points,
        header.n_columns + 1
    )
    return header, cache, order
end

function compute(file::IPF, block::IPFBlockInfo, key::Number)

    header, cache, order = _update_cache!(file, block, key)

    if header.n_derivatives > 0
        return hermite(cache, order, header.n_columns, key)
    else 
        return lagrange(cache, order, header.n_columns, key)
    end

end

function compute_derivative(file::IPF, block::IPFBlockInfo, key::Number)
    if header.n_derivatives == 0
        throw(
            ErrorException("Cannot compute derivatives as they are not present!")
        )
    end
    header, cache, order = _update_cache!(file, block, key)
    return lagrange(cache, order, header.n_columns, key, header.n_columns)
end