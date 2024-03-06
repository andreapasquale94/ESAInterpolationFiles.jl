
using Ipf


# ---------------------------------------------------------------
# HERMITE

f = IPF("sol.orb")
e = 11202.75
e = 8673.932
# e = 7339.21782
# find block
bid = Ipf.find_block(f, e)
b = f.blocks[bid]
rid = Ipf.find_record(f, b, e)
records = get_records(f, bid)

# create cache
order = 11
subset = @views records[max(1, rid-(order÷2)):rid+(order+1)÷2]
c2 = Ipf.InterpCache{Float64}(order+1, 12, 2)
for i in eachindex(subset)
    @views c2.y[i] .= subset[i]
end

# eval
Ipf.hermite(c2, length(subset)-1, 6, e)


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
c = Ipf.InterpCache{Float64}(order+1, 6, 1)
for i in eachindex(subset)
    @views c.y[i] .= subset[i]
end

# eval
Ipf.lagrange(c, order, 6, e)