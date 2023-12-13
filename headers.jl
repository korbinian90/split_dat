# This enum definition enables the usage of the dimension code for accessing the dimension elements
@enum DIM COL = 1 LIN = 3 AVE = 4 SLI = 5 PAR = 6 ECO = 7 PHS = 8 REP = 9 SET = 10 SEG = 11 IDA = 12 IDB = 13 IDC = 14 IDD = 15 IDE = 16
Base.to_index(d::DIM) = Int(d)

# Definition of Headers as structs and how to read them
struct HeaderInfo
    n_scans
    meas_id
    file_id
    meas_offset
    meas_length
end
function Base.read(io::IO, ::Type{HeaderInfo})
    skip = read(io, UInt32)
    n_scans = read(io, UInt32)
    meas_id = read(io, UInt32)
    file_id = read(io, UInt32)
    meas_offset = zeros(Int, n_scans)
    meas_length = zeros(Int, n_scans)
    for i in 1:n_scans
        meas_offset[i] = read(io, UInt64)
        meas_length[i] = read(io, UInt64)
        seek(io, position(io) + 152 - 16)
    end
    meas_offset = meas_offset
    meas_length = meas_length
    HeaderInfo(n_scans, meas_id, file_id, meas_offset, meas_length)
end

struct ScanHeaderVD
    mask
    type
    dims
    ice_param
    data_position
end
function Base.read(io::IO, ::Type{ScanHeaderVD})
    header_start = position(io)
    mdh_byte_length = 192
    mask_offset = 40
    channel_mdh_offset_64 = 4
    ice_param_offset = 48 + (48 - 8) * 2

    seek(io, position(io) + mask_offset)
    mask_bytes = zeros(UInt8, 8)
    read!(io, mask_bytes)
    mask = get_scan_mask(mask_bytes)

    dims = zeros(Int16, 16)
    read!(io, dims)
    dims = Int.(dims)
    dims[3:end] .+= 1

    ice_param = zeros(Int16, 24)
    seek(io, header_start + ice_param_offset)
    read!(io, ice_param)

    data_start = header_start + mdh_byte_length
    adc_length = dims[COL] + channel_mdh_offset_64

    ScanHeaderVD(mask, scan_info(mask), dims, ice_param, (data_start, adc_length))
end
