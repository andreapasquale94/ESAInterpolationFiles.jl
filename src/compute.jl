export compute

function compute(file::IPFFile, e::Number)
    header = file.header
    cache = file.cache

    # Get maximum order 
    order = header.user_header[2]

    # Find block & records
    bid = find_block(file, e)
    block = file.blocks[bid]
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
    @show left 
    @show right
    @show points 

    get_records!(cache.y, file, block, left, points)

    if header.n_derivatives > 0
        return hermite(cache, order, header.n_columns, e)
    else 
        return lagrange(cache, order, header.n_columns, e)
    end
end
