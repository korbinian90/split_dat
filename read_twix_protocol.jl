## Adapted from Philipp Ehses read_twix_hdr.m
function read_twix_protocol(filename; scan=1)
    protocol = Dict()
    open(filename) do io
        file_header = read(io, HeaderInfo)
        offset = file_header.meas_offset[scan]
        seek(io, offset + 4)

        n_entries = 1 * read(io, UInt32)
        for _ in 1:n_entries
            name = join([read(io, Char) for _ in 1:10])
            name = parse_entry_name(name)
            seek(io, position(io) + length(name) - 9)
            len = read(io, UInt32)

            buffer = join([read(io, Char) for _ in 1:len])
            buffer = delete_empty_lines(buffer)

            protocol[name] = parse_buffer(buffer)
        end
    end
    return protocol
end

function parse_entry_name(name)
    return match(r"^\w*", name).match
end

function delete_empty_lines(buffer)
    return replace(buffer, r"\n\s*\n" => "")
end

function parse_buffer(buffer)
    regex = r"### ASCCONV BEGIN[^\n]*\n(.*)\s### ASCCONV END ###"s # s required to match newlines for capture group
    ascconv = eachmatch(regex, buffer) # extract ascconv parts
    xprot = replace(buffer, regex => "") # remove ascconv parts

    prot = parse_xprot(xprot)

    for asc in ascconv
        parse_ascconv!(prot, asc.match)
    end

    return prot
end

function parse_xprot(buffer)
    prot = Dict()
    tokens = eachmatch(r"<Param(?:Bool|Long|String)\.\"(\w+)\">\s*{([^}]*)", buffer)
    tokens_double = eachmatch(r"<ParamDouble\.\"(\w+)\">\s*{\s*(<Precision>\s*[0-9]*)?\s*([^}]*)", buffer)
    tokens = append!(collect(tokens), tokens_double)
    for t in tokens
        token_list = collect(t)
        name = valid_name(first(token_list))
        prot[name] = parse_value(last(token_list))
    end
    return prot
end

function valid_name(str)
    if !startswith(str, r"[A-Za-z]")
        return "x" * str
    end
    return str
end

function parse_value(str)
    str = replace(str, r"(\"*)|( *<\w*> *[^\n]*)" => "")
    for type in [Int, Float64]
        try
            return parse(type, str)
        catch
        end
        try
            return parse.(type, split(str))
        catch
        end
    end
    return strip(str)
end

function parse_ascconv!(prot, buffer)
    for m in eachmatch(r"(?<name>\S*)\s*=\s*(?<value>\S*)", buffer)
        value = parse_value(m["value"])
        v = eachmatch(r"(?<array_name>\w+)\[(?<ix>[0-9]+)\]|(?<name>\w+)", m["name"])

        valid = true
        great_parent = prot
        access = ""
        parent = prot
        for vk in v
            if length(vk.match) < 1
                valid = false
                break
            end
            if !isletter(vk.match[1])
                valid = false
                break
            end
            if !isnothing(vk[:name]) # normal value
                if !haskey(parent, vk[:name])
                    parent[vk[:name]] = Dict()
                end
                great_parent = parent
                access = vk[:name]
                parent = parent[access]
            else # array value
                if !haskey(parent, vk[:array_name])
                    parent[vk[:array_name]] = Any[Dict()]
                elseif parent[vk[:array_name]] isa Dict
                    parent[vk[:array_name]] = Any[Dict()]
                end
                while length(parent[vk[:array_name]]) < index(vk)
                    push!(parent[vk[:array_name]], Dict())
                end
                great_parent = parent
                access = (vk[:array_name], index(vk))
                parent = parent[access[1]][access[2]]
            end
        end
        if valid
            if access isa Tuple
                great_parent[access[1]][access[2]] = value
            else
                great_parent[access] = value
            end
        end
    end
end

index(vk) = parse(Int, vk["ix"]) + 1
