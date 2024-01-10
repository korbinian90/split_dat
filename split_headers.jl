include("read_twix_protocol.jl")

function split_dat_metabolite(filename, f_out; metabolite)
    println("writing metabolite:")
    select = scan -> scan.dims[SET] in metabolite
    split_dat(filename, f_out, select)
end

function split_dat_water(filename, f_out)
    println("writing water:")
    select = scan -> scan.ice_param[6] == 1
    split_dat(filename, f_out, select)
end

function split_dat(filename, f_out, select)
    n_channels = length(read_twix_protocol(filename)["MeasYaps"]["sCoilSelectMeas"]["aRxCoilSelectData"][1]["asList"])

    out = open(f_out, "w")
    open(filename) do io
        set_offset = 40 + 8 + 9 * 2
        i_water = 0

        file_header = read(io, HeaderInfo)
        offset = file_header.meas_offset[1]
        seek(io, offset)

        pos = position(io)
        # seek io to beginning of file
        seek(io, 0)
        write(out, read(io, offset))

        for i_scan = 1:file_header.n_scans
            write_and_skip_twix!(io, out)

            while true
                pos_begin = position(io)
                scan = read(io, ScanHeaderVD)

                if scan.type == :ACQEND
                    seek(io, pos_begin)
                    write(out, read(io, 352))
                    pos = position(io)
                    # adjust in file position to be multiple of 512
                    if mod(pos, 512) > 0
                        pos = pos + 512 - mod(pos, 512)
                    end
                    seek(io, pos)
                    # adjust out file position to be multiple of 512
                    pos_write = position(out)
                    if mod(pos_write, 512) > 0
                        pos_write2 = pos_write + 512 - mod(pos_write, 512)
                        write(out, zeros(UInt8, pos_write2 - pos_write))
                    end
                    break
                end

                if scan.type == :SYNCDATA
                    len = 1728
                    seek(io, pos_begin)
                    write(out, read(io, len))
                    continue
                end

                seek_to_next_header!(io, scan.data_position, n_channels)
                pos_next = position(io)
                nbytes = pos_next - pos_begin

                # Decide which scan goes to which file
                if scan.type == :ONLINE
                    if select(scan)
                        seek(io, pos_begin)
                        bytes = read(io, nbytes)
                        bytes[set_offset+1] = i_water
                        i_water += 1
                        write(out, bytes)
                    else
                        seek(io, pos_next) # skip others
                    end
                else # write all non :ONLINE scans
                    seek(io, pos_begin)
                    write(out, read(io, nbytes))
                end
            end
        end
    end
    close(out)
end

function write_and_skip_twix!(io, out)
    pos_begin = position(io)
    skip_twix(io)
    pos = position(io)    
    # write twix header
    seek(io, pos_begin)
    write(out, read(io, pos - pos_begin))
end

function skip_twix(io)
    header_length = read(io, UInt32)
    seek(io, position(io) + header_length - 4)
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
    elseif mask[6]
        return :SYNCDATA
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
