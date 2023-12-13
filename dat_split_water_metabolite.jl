include("headers.jl")
include("split_headers.jl")

filename_dat = "location/test.dat"
filename_water = joinpath(out_path, "split_water.dat")
filename_metabolite = joinpath(out_path, "split_metabolite.dat")

out_path = splitdir(filename_dat)[1] # change out_path to save in a different folder

split_dat_water(filename_dat, filename_water)
split_dat_metabolite(filename_dat, filename_metabolite; metabolite=3:18)
