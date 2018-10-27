summarize(A) = vec(mean(mapslices(x -> sum(x) , A, dims = 3), dims = 1))
summarize_diff(A) = vec(mean(diff(mapslices(sum, A, dims = 3)[:,:,1], dims = 2), dims = 1))

function cleanup!(A)
    for i in 1:size(A,1)
        for j in 2:size(A,2)
            if all(x -> ismissing(x), A[i,j,:])
                A[i,j,:] = A[i,j-1,:]
            end
        end
    end
    A
end

function ma(x::Vector{T}, k::Int) where T<:AbstractFloat
    n = length(x)
    y = fill(zero(T), n)
    for i in 1:n
        start = max(1, i - k)
        finish = min(n, i)
        y[i] = mean(x[start:finish])
    end
    return y[k:end]
end


function refresh_identifiers(n = 5)
    global pal =  Colors.distinguishable_colors(n, parse.(Colorant, ["dodgerblue", "green"]))
    global labels = ["Bulk crafting, current system",  "Playset-by-playset crafting, current system",
    "Playset-by-playset crafting, duplicate prevention", "Bulk crafting, duplicate prevention",
    "3 then 4 playset crafting, current system"]
end

function cumulativeplot(A)
    col = "#" * hex( popfirst!(pal) )
    label = popfirst!(labels)
    
    plot(summarize(A), label = label, color = col)
end

function diffplot(D, yline, w = 30)
    mD = ma(D,w)
    col = "#" * hex(popfirst!(pal))
    label = popfirst!(labels)
    plot(w:(w+length(mD)-1), mD, color = col, label = label)
    axhline(y = yline, linestyle = "dashed", color = col)
end



function ff1_dom(x)
    x["set"] == :DOM && x["rarity"] == 3 &&
    !in(x["name"], ["Chandra's Outburst", "Firesong and Sunspeaker", "Niambi, Faithful Healer"])
end

function ff1_grn(x)
    x["set"] == :GRN && x["rarity"] == 3 &&
    !in(x["name"], ["Ral's Dispersal", "Vraska's Stoneglare"])
end


function ff1_xln(x)
    x["set"] == :XLN && x["rarity"] == 3 &&
    !in(x["name"], ["Sun-Blessed Mount", "Grasping Current"])
end


function ff2_xln(x)
    in(x["name"],
    [
    "Search for Azcanta // Azcanta, the Sunken Ruin",
    "Vraska's Contempt",
    "Settle the Wreckage",
    "Drowned Catacomb",
    "Growing Rites of Itlimoc // Itlimoc, Cradle of the Sun",
    "Legion's Landing // Adanto, the First Fort",
    "Sunpetal Grove",
    "Vanquisher's Banner",
    "Glacial Fortress",
    "Dragonskull Summit",
    "Treasure Map // Treasure Cove",
    "Sorcerous Spyglass",
    "Primal Amulet // Primal Wellspring",
    "Hostage Taker",
    "Rootbound Crag",
    "Thaumatic Compass // Spires of Orazca",
    "Ripjaw Raptor",
    "Shapers' Sanctuary",
    "Arguel's Blood Fast // Temple of Aclazotz",
    "Deathgorge Scavenger",
    "Sunbird's Invocation",
    "Regisaur Alpha",
    "River's Rebuke"
    ]
    )
end



function ff2_dom(x)
    in(x["name"],
    [
    "Sulfur Falls",
    "Woodland Cemetery",
    "Goblin Chainwhirler",
    "Clifftop Retreat",
    "Shalai, Voice of Plenty",
    "Steel Leaf Champion",
    "Isolated Chapel",
    "Helm of the Host",
    "Hinterland Harbor",
    "Gilded Lotus",
    "Benalish Marshal",
    "Tempest Djinn"
    ]
    )
end

function ff2_grn(x)
    in(x["name"],
    [
    "Assassin's Trophy",
    "Steam Vents",
    "Risk Factor",
    "Watery Grave",
    "Sacred Foundry",
    "Overgrown Tomb",
    "Temple Garden",
    "Runaway Steam-Kin",
    "Knight of Autumn",
    "Ionize",
    "Experimental Frenzy",
    "Mission Briefing",
    "Chromatic Lantern",
    "Legion Warboss",
    "Pelt Collector",
    "Expansion // Explosion",
    "Thief of Sanity",
    "Niv-Mizzet, Parun",
    "Deafening Clarion",
    "Ritual of Soot",
    "Find // Finality",
    "Venerated Loxodon",
    "Beast Whisperer",
    "Tajic, Legion's Edge"
    ]
    )
end

function case(filterfun, setfun, sets; nsim = 200)
    pars = SimParameters(
    bonus_packs = Dict{Symbol,Int}(),
    track_collection_progress = true,
    max_track_progress_packs = 600,
    nextset = setfun,
    )
    
    par2 = deepcopy(pars)
    par2.prevent_duplicates = true
    
    rares = filter(filterfun, card_db)
    ix3 = findall(filterfun, card_db)
    
    deck = [map(x -> (x["name"], 4), rares)]
    deck2 = map(x -> [x], deck[1])
    deck3 = vcat(
        collect( [(n,3)] for (n,a) in deck[1] ),
        collect( [(n,4)] for (n,a) in deck[1] )
    );
    
    deck = deckinfo.(deck)
    deck3 = deckinfo.(deck3)
    deck2 = deckinfo.(deck2)
    
    output = Vector{ArenaSim.SimOutput}()

    push!(output, simulate(nsim, deck; parameters=pars, sets = sets))
    push!(output, simulate(nsim, deck2; parameters=pars, sets = sets))
    push!(output, simulate(nsim, deck2; parameters=par2, sets = sets))
    push!(output, simulate(nsim, deck; parameters=par2, sets = sets))
    push!(output, simulate(nsim, deck3; parameters=pars, sets = sets))
    
    cumulative = map(x -> cleanup!(x.collection_progress)[:,:,ix3], output)
    difference = map(x -> summarize_diff(x), cumulative)
    
    height = 6
    figure(figsize = (height*634/475,height))
    refresh_identifiers()
    for a in cumulative
        cumulativeplot(a)
    end
    legend(fontsize = 8)
    ymax = maximum(map(x -> maximum(summarize(x)), cumulative))
    yticks(0:4:ymax, fontsize = 7)
    grid()
    xlabel("Packs opened")
    ylabel("Average desired rares acquired")
    tight_layout()

    lines = map(x -> summarize(x), cumulative)
    lines = map(x -> last(x) / length(x), lines)
    
    figure(figsize = (height*634/475,height))
    refresh_identifiers()
    for (i,d) in enumerate(difference)
        diffplot(d, lines[i])
    end
    legend(fontsize=7)
    xlabel("Packs opened")
    ylabel("Average desired rares per pack in previous 30 packs")
    tight_layout()
end