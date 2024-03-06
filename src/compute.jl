export compute

function compute(file::IPF, e::Number)
    return compute(file, get_block(file, e), e)
end

function compute(file::IPF, block::IPFBlockInfo, e::Number)
    header = file.header
    cache = file.cache

    # Get maximum order 
    order = header.user_header[2]
    n_records = block.n_records

    # Find record
    rid = find_record(file, block, e)

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

    get_records!(cache.y, file, block, left, points)

    if header.n_derivatives > 0
        return hermite(cache, order, header.n_columns, e)
    else 
        return lagrange(cache, order, header.n_columns, e)
    end
end
