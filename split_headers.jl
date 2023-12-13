function split_dat_water(filename, f_out; n_channels=32)
    out = open(f_out, "w")
    open(filename) do io
        seek_to_first_scan_header!(io)
        pos = position(io)
        # seek io to beginning of file
        seek(io, 0)
        write(out, read(io, pos))

        set_offset = 40 + 8 + 9 * 2
        i_water = 0

        while true
            pos_begin = position(io)
            scan = read(io, ScanHeaderVD)

            if scan.type == :ACQEND
                seek(io, pos_begin)
                write(out, read(io))
                break
            end

            seek_to_next_header!(io, scan.data_position, n_channels)
            pos_next = position(io)
            nbytes = pos_next - pos_begin

            # Decide which scan goes to which file
            seek(io, pos_begin)
            bytes = read(io, nbytes)
            if scan.ice_param[6] == 1 # check if it is water
                bytes[set_offset+1] = i_water
                i_water += 1
                write(out, bytes)
            else
                seek(io, pos_next) # skip others
            end
        end
    end
    close(out)
end

function split_dat_metabolite(filename, f_out; n_channels=32, metabolite)
    out = open(f_out, "w")
    open(filename) do io
        seek_to_first_scan_header!(io)
        pos = position(io)
        # seek io to beginning of file
        seek(io, 0)
        write(out, read(io, pos))

        set_offset = 40 + 8 + 9 * 2
        i_scan = 0

        while true
            pos_begin = position(io)
            scan = read(io, ScanHeaderVD)

            if scan.type == :ACQEND
                seek(io, pos_begin)
                write(out, read(io))
                break
            end

            seek_to_next_header!(io, scan.data_position, n_channels)
            pos_next = position(io)
            nbytes = pos_next - pos_begin

            # Decide which scan goes to which file
            seek(io, pos_begin)
            bytes = read(io, nbytes)
            if scan.dims[SET] in metabolite
                bytes[set_offset+1] = i_scan # Works for up to 255 sets, then the first byte needs to be addressed
                i_scan += 1
                write(out, bytes)
            else
                seek(io, pos_next)
            end
        end
    end
    close(out)
end

function split_scan_headers(filename, f1, f2, n_channels)
    o1 = open(f1, "w")
    o2 = open(f2, "w")
    open(filename) do io
        seek_to_first_scan_header!(io)
        pos = position(io)
        # seek io to beginning of file
        for o in (o1, o2)
            seek(io, 0)
            write(o, read(io, pos))
        end

        set_offset = 40 + 8 + 9 * 2
        i_water = i_scan = 0

        while true
            pos_begin = position(io)
            scan = read(io, ScanHeaderVD)

            if scan.type == :ACQEND
                for o in (o1, o2)
                    seek(io, pos_begin)
                    write(o, read(io))
                end
                break
            end

            seek_to_next_header!(io, scan.data_position, n_channels)
            pos_next = position(io)
            nbytes = pos_next - pos_begin

            # Decide which scan goes to which file
            seek(io, pos_begin)
            bytes = read(io, nbytes)
            if scan.ice_param[6] == 0 && scan.dims[SET] == 1
                bytes[set_offset+1] = i_water
                i_water += 1
                write(o1, bytes)
            elseif 3 ≤ scan.dims[SET] ≤ 18
                bytes[set_offset+1] = i_scan # Works for up to 255 sets, then the first byte needs to be addressed
                i_scan += 1
                write(o2, bytes)
            else
                seek(io, pos_next)
            end
        end
    end
end

function seek_to_first_scan_header!(io; scan=1)
    file_header = read(io, HeaderInfo)
    offset = file_header.meas_offset[scan]
    seek(io, offset)
    # skip twix header
    header_length = read(io, UInt32)
    seek(io, offset + header_length)
end

function seek_to_next_header!(io, (start, n_adc), n_channels)
    n_bytes = n_adc * n_channels * 8
    seek(io, start + n_bytes)
end

function checkVD(filename)
    startints = zeros(UInt32, 2)
    read!(filename, startints)
    return startints[1] < 10_000 && startints[2] <= 64
end

function get_scan_mask(bytes)
    str = join(reverse.(bitstring.(bytes)))
    return [c == '1' for c in str]
end

function scan_info(mask)
    if mask[1]
        return :ACQEND
    elseif mask[26]
        return :NOISADJSCAN
    elseif mask[24]
        return :PATREFANDIMASCAN
    elseif mask[23]
        return :PATREFSCAN
    elseif mask[4]
        return :ONLINE
    end
    return :OTHER
end
