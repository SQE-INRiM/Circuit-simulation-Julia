#-------------------------------------SIMULATION AT LOW PUMP POWER-------------------------------------------

function simulate_low_pump_power(sim_vars, circuit, circuitdefs)

    
    # Initialize arrays for simulation output
    outvalsS21phidcSweep = zeros(Complex{Float64}, length(sim_vars[:ws]), length(sim_vars[:phidcSweep]))
    outvalsS12phidcSweep = zeros(Complex{Float64}, length(sim_vars[:ws]), length(sim_vars[:phidcSweep]))
    outvalsS11phidcSweep = zeros(Complex{Float64}, length(sim_vars[:ws]), length(sim_vars[:phidcSweep]))
    outvalsS22phidcSweep = zeros(Complex{Float64}, length(sim_vars[:ws]), length(sim_vars[:phidcSweep]))
    outvalsS21PhasephidcSweep = zeros(Float64, length(sim_vars[:ws]), length(sim_vars[:phidcSweep]))
    
    println("1. Simulation at low pump power")
    
    # Run the simulation at low pump power
    @time for (k, phidcLocal) in enumerate(sim_vars[:phidcSweep])
        sources = [
            (mode=(0,), port=3, current=phidcLocal * (2 * 280 * 1e-6)),
            (mode=(1,), port=1, current=sim_vars[:Ip]),
        ]
        sol = hbsolve(
            sim_vars[:ws], sim_vars[:wp], sources, (1,), (1,),
            circuit, circuitdefs;
            dc=true, threewavemixing=true, fourwavemixing=true, iterations=sim_vars[:Niterations]
        )
        outvalsS21phidcSweep[:, k] = sol.linearized.S((0,), 2, (0,), 1, :)
        outvalsS12phidcSweep[:, k] = sol.linearized.S((0,), 1, (0,), 2, :)
        outvalsS11phidcSweep[:, k] = sol.linearized.S((0,), 1, (0,), 1, :)
        outvalsS22phidcSweep[:, k] = sol.linearized.S((0,), 2, (0,), 2, :)
        outvalsS21PhasephidcSweep[:, k] = unwrap(angle.(sol.linearized.S((0,), 2, (0,), 1, :)))
    end

    return outvalsS21phidcSweep, outvalsS12phidcSweep, outvalsS11phidcSweep, outvalsS22phidcSweep, outvalsS21PhasephidcSweep

end 





function calculation_lines_low_pump_power(outvalsS21PhasephidcSweep, params, sim_vars)


    wp = 2*pi* round(sim_vars[:fp], digits=-8)                              #Put the nearest wp value included inside ws. The reason of this line is because for computational reason the wp cannot be a value of ws.
    wphalf = 2*pi* round(sim_vars[:fp]/2, digits=-8)  

    phidcIndex = findall(x -> x == params[:phidc], sim_vars[:phidcSweep])
    wpIndex = findall(x -> x == wp, sim_vars[:ws])
    wphalfIndex = findall(x -> x == wphalf, sim_vars[:ws])
    
    wp=sim_vars[:ws][wpIndex]
    wphalf=sim_vars[:ws][wphalfIndex]

    #linear relation
    y1=-outvalsS21PhasephidcSweep[10, phidcIndex] / params[:N]
    y2=-outvalsS21PhasephidcSweep[1, phidcIndex] / params[:N]
    x1=sim_vars[:ws][10]
    x2=sim_vars[:ws][1]

    m = (y1-y2)/(x1-x2)
    q = y2-m*x2
    
    
    #line passing throug wp
    y1=-outvalsS21PhasephidcSweep[wpIndex[1], phidcIndex] / params[:N]
    y2=-outvalsS21PhasephidcSweep[1, phidcIndex] / params[:N]
    x1=sim_vars[:ws][wpIndex[1]]
    x2=sim_vars[:ws][1]

    m_p = (y1-y2)/(x1-x2)
    q_p = y2-m_p*x2
    

    #line passing throug wp/2 
    y1=-outvalsS21PhasephidcSweep[wphalfIndex[1], phidcIndex] / params[:N]
    y2=-outvalsS21PhasephidcSweep[1, phidcIndex] / params[:N]
    x1=sim_vars[:ws][wphalfIndex[1]]
    x2=sim_vars[:ws][1]

    m_phalf=(y1-y2)/(x1-x2)
    q_phalf = y2-m_phalf*x2



    #line passing throug wp and wp-n 
    y1=-outvalsS21PhasephidcSweep[wpIndex[1]-4, phidcIndex] / params[:N]
    y2=-outvalsS21PhasephidcSweep[wpIndex[1]-17, phidcIndex] / params[:N]
    x1=sim_vars[:ws][wpIndex[1]-4]
    x2=sim_vars[:ws][wpIndex[1]-17]
    
    m_stopband=(y1-y2)/(x1-x2)
    q_stopband = y2-m_stopband*x2   


    return m, q, m_p, q_p, m_phalf, q_phalf, m_stopband, q_stopband

end

function calculation_metric_lines(outvalsS21PhasephidcSweep, params, sim_vars)

    m, _, m_p, _, m_phalf, _, m_stopband, _ = calculation_lines_low_pump_power(outvalsS21PhasephidcSweep, params, sim_vars)

    alpha_lin=atan(m[1])
    alpha_wp=atan(m_p[1])
    alpha_wphalf=atan(m_phalf[1])
    alpha_stopband =atan(m_stopband[1])

    return alpha_wphalf, alpha_wp, alpha_lin, alpha_stopband

end




function plot_low_pump_power(outvalsS21phidcSweep, outvalsS11phidcSweep, outvalsS21PhasephidcSweep, params, sim_vars)

    # Generate plots-----------------------------------------------------------------------

    p1 = plot(
        sim_vars[:phidcSweep],
        sim_vars[:ws] / (2 * pi * 1e9),
        10 * log10.(abs2.(outvalsS11phidcSweep)),
        seriestype=:heatmap,
        c=cgrad(:viridis),
        clim=(-30, 0),
        xlabel=L"\phi / \phi_{0}",
        ylabel=L"f / GHz",
        title=L"S_{11} / dB",
        legend=false,
        colorbar=true
    )


    p2 = plot(
        sim_vars[:phidcSweep],
        sim_vars[:ws] / (2 * pi * 1e9),
        10 * log10.(abs2.(outvalsS21phidcSweep)),
        seriestype=:heatmap,
        c=:viridis,
        clim=(-5, 0),
        xlabel=L"\phi / \phi_{0}",
        ylabel=L"f / GHz",
        title=L"S_{21} / dB",
        legend=false,
        colorbar=true
    )

    p3 = plot(
        sim_vars[:phidcSweep],
        sim_vars[:ws] / (2 * pi * 1e9),
        20 * log10.(1 .- abs2.(outvalsS11phidcSweep) .- abs2.(outvalsS21phidcSweep)),
        seriestype=:heatmap,
        c=:viridis,
        clim=(-40, 0),
        xlabel=L"\phi / \phi_{0}",
        ylabel=L"f / GHz",
        title="Internal Losses / dB",
        legend=false,
        colorbar=true
    )

    
    phidcIndex = findall(x -> x == params[:phidc], sim_vars[:phidcSweep])

    p4 = plot(
        sim_vars[:ws] / (2 * pi * 1e9),
        -outvalsS21PhasephidcSweep[:, phidcIndex] / params[:N],
        xlabel=L"f / GHz",
        ylabel=L"k / rad \cdot cells^{-1}",
        title="Dispersion relation",
        ylim=(0.0, 1.5),
        legend=true,
        colorbar=true,
        label="",
        framestyle=:box
    )


    m, q, m_p, q_p, m_phalf, q_phalf, m_stopband, q_stopband = calculation_lines_low_pump_power(outvalsS21PhasephidcSweep, params, sim_vars)



    plot!(p4, sim_vars[:ws] / (2 * pi * 1e9), m .* sim_vars[:ws] .+ q, label="linear relation", color=:orange)
    plot!(p4, sim_vars[:ws] / (2 * pi * 1e9), m_p .* sim_vars[:ws] .+ q_p, label="wp line", color=:darkblue)
    #plot!(p4, sim_vars[:ws] / (2 * pi * 1e9), m_phalf .* sim_vars[:ws] .+ q_phalf, label="wp/2 line", color=:green)
    plot!(p4, sim_vars[:ws] / (2 * pi * 1e9), m_stopband .* sim_vars[:ws] .+ q_stopband, label="stopband line", color=:darkred)



    # Plot customization
    vline!(p1, [params[:phidc]], width=2, style=:dash, color=:black)
    vline!(p2, [params[:phidc]], width=2, style=:dash, color=:black)
    vline!(p3, [params[:phidc]], width=2, style=:dash, color=:black)

    hline!(p1, [(sim_vars[:fp]/2)/1e9], width=1, color=:gray, style=:dash, label="")
    hline!(p1, [((sim_vars[:fp]/2)-1e9)/1e9], width=2, color=:darkblue, label="")
    hline!(p1, [((sim_vars[:fp]/2)+1e9)/1e9], width=2, color=:darkblue, label="")

    hline!(p2, [(sim_vars[:fp]/2)/1e9], width=1, color=:gray, style=:dash, label="")
    hline!(p2, [((sim_vars[:fp]/2)-1e9)/1e9], width=2, color=:darkblue, label="")
    hline!(p2, [((sim_vars[:fp]/2)+1e9)/1e9], width=2, color=:darkblue, label="")
    
    hline!(p1, [sim_vars[:wp][1] / (2 * pi * 1e9)], width=2, color=:black)
    hline!(p2, [sim_vars[:wp][1] / (2 * pi * 1e9)], width=2, color=:black)
    hline!(p3, [sim_vars[:wp][1] / (2 * pi * 1e9)], width=2, color=:black)   
    
    
    hline!(p1, [(1 / 2) * sim_vars[:wp][1] / (2 * pi * 1e9)], width=1, style=:dash, color=:gray)
    hline!(p2, [(1 / 2) * sim_vars[:wp][1] / (2 * pi * 1e9)], width=1, style=:dash, color=:gray)
    hline!(p1, [(3 / 2) * sim_vars[:wp][1] / (2 * pi * 1e9)], width=1, style=:dash, color=:gray)
    hline!(p2, [(3 / 2) * sim_vars[:wp][1] / (2 * pi * 1e9)], width=1, style=:dash, color=:gray)
    hline!(p1, [2 * sim_vars[:wp][1] / (2 * pi * 1e9)], width=1, color=:gray)
    hline!(p2, [2 * sim_vars[:wp][1] / (2 * pi * 1e9)], width=1, color=:gray)


    vline!(p4, [sim_vars[:wp][1] / (2 * pi * 1e9)], width=2, color=:black, label="")
    vline!(p4, [(1 / 2) * sim_vars[:wp][1] / (2 * pi * 1e9)], width=2, style=:dash, color=:gray, label="")
    vline!(p4, [(3 / 2) * sim_vars[:wp][1] / (2 * pi * 1e9)], width=2, style=:dash, color=:gray, label="")
    vline!(p4, [2 * sim_vars[:wp][1] / (2 * pi * 1e9)], width=2, color=:gray,label="")


    return  p1, p2, p3, p4

end





#------------------------------------------METRIC CALCULATIONS-------------------------------------------------------

# This is the file that map the alpha value of the SNAIL to the corresponded flux value in order to have the best theoretical 3WM

lines = readlines("G:/Shared drives/SuperQuElectronics/Students Folders/Emanuele Palumbo/flux_curve.txt")

global alpha_map = [] 
global flux_map = []

for line in lines
    # Split the line by commas and parse the values
    parts = split(line, ",")
    push!(alpha_map, parse(Float64, parts[1])) 
    push!(flux_map, parse(Float64, parts[2]))  

end


function find_flux_from_alpha(params_temp)

        # Find flux value and index 
        alpha_temp=round(params_temp[:alphaSNAIL], digits=2)
        #println("alpha_temp: ", alpha_temp)
        flux_value = round(flux_map[findall(x -> x == alpha_temp, alpha_map)][1], digits=2)
        #println("flux_value: ", flux_value)

        return flux_value

end    


function maxS11val_BandFreq_FixFlux(outvalsS11phidcSweep, params_temp, sim_vars)
    
    S11 = 10 * log10.(abs2.(outvalsS11phidcSweep))

    # Find frequency range (band is between f = (6, 8) GHz with fp/2=7 GHz) 
    fphalf = round(sim_vars[:fp]/2, digits=-8)
    w_lb = 2*pi*((fphalf)-1e9)
    w_ub = 2*pi*((fphalf)+1e9)
    w_lb_index = argmin(abs.(sim_vars[:ws] .- w_lb))
    w_ub_index = argmin(abs.(sim_vars[:ws] .- w_ub))

    #println("Flux value: ", params_temp[:phidc])
    flux_index = findall(x -> x == params_temp[:phidc], sim_vars[:phidcSweep])
    #println("flux_index: ", flux_index)


    # Finding a vector of S11 value in the frequency band at the best flux value

    S11_new=S11[w_lb_index:w_ub_index,flux_index[1]]
    #println(S11_new)
    max_value=maximum(S11_new)
    #println(max_value)

    return max_value

end





#------------------------------------------SIMULATION AT FIXED FLUX---------------------------------------------------


function simulate_at_fixed_flux(params, sim_vars, circuit, circuitdefs)
    
    # Accessing ws inside the sim_vars dictionary
    outvalsS21IpSweep = zeros(Complex{Float64}, length(sim_vars[:ws]), length(sim_vars[:IpSweep]))
    outvalsS12IpSweep = zeros(Complex{Float64}, length(sim_vars[:ws]), length(sim_vars[:IpSweep]))
    outvalsS11IpSweep = zeros(Complex{Float64}, length(sim_vars[:ws]), length(sim_vars[:IpSweep]))
    outvalsS22IpSweep = zeros(Complex{Float64}, length(sim_vars[:ws]), length(sim_vars[:IpSweep]))


    println("2. Simulation at fixed flux")

    @time for (k, IpSweepLocal) in enumerate(sim_vars[:IpSweep])
        sources = [
            (mode=(0,), port=3, current=params[:phidc] * (2 * 280 * 1e-6)),
            (mode=(1,), port=1, current=IpSweepLocal),
        ]
        
        sol = hbsolve(sim_vars[:ws], sim_vars[:wp], sources, sim_vars[:Nmodulationharmonics], sim_vars[:Npumpharmonics],
                    circuit, circuitdefs; dc=true, threewavemixing=true, fourwavemixing=true, iterations=sim_vars[:Niterations])
        outvalsS21IpSweep[:, k] = sol.linearized.S((0,), 2, (0,), 1, :)
        outvalsS12IpSweep[:, k] = sol.linearized.S((0,), 1, (0,), 2, :)
        outvalsS11IpSweep[:, k] = sol.linearized.S((0,), 1, (0,), 1, :)
        outvalsS22IpSweep[:, k] = sol.linearized.S((0,), 2, (0,), 2, :)
    end

    return outvalsS21IpSweep, outvalsS12IpSweep, outvalsS11IpSweep, outvalsS22IpSweep

end


function find_best_IpGain(outvalsS21IpSweep, sim_vars)

    S21 = 10 * log10.(abs2.(outvalsS21IpSweep))

    fphalf = round(sim_vars[:fp]/2, digits=-8)
    w_lb = 2*pi*((fphalf)-1e9)
    w_ub = 2*pi*((fphalf)+1e9)
    w_lb_index = argmin(abs.(sim_vars[:ws] .- w_lb))
    w_ub_index = argmin(abs.(sim_vars[:ws] .- w_ub))

    mean_ref = -30
    IpGainBest = 0
    best_index = 0

    for (index, Ip) in enumerate(sim_vars[:IpSweep])
        
        mean_temp = mean(S21[w_lb_index:w_ub_index, index])
        #println("mean single: ", mean_temp)
        #println("Ip: ", Ip)
        #println("IpIdx: ", index)

        if mean_temp > mean_ref

            mean_ref = mean_temp
            #println("mean best: ", mean_ref)
            IpGainBest = Ip
            #println("IpGainBest: ", IpGainBest)
            best_index = index
            #println("IpGainBestIdx: ", best_index)
        
        end
    end

    return IpGainBest, best_index

end



function plot_at_fixed_flux(outvalsS21IpSweep, outvalsS11IpSweep, sim_vars)

    # Generate plots-----------------------------------------------------------------------------------------------
    
    cmap = cgrad([:darkblue, :white, :darkred])

    p1p = plot(
        sim_vars[:IpSweep] / 1e-6,
        sim_vars[:ws] / (2 * pi * 1e9),
        10 * log10.(abs2.(outvalsS11IpSweep)),
        seriestype=:heatmap,
        c = cmap,
        clim=(-20, 20),
        xlabel=L"I_{p} / \mu A",
        ylabel=L"f / GHz",
        legend=false,
        colorbar=true
    )

    p2p = plot(
        sim_vars[:IpSweep] / 1e-6,
        sim_vars[:ws] / (2 * pi * 1e9),
        10 * log10.(abs2.(outvalsS21IpSweep)),
        seriestype=:heatmap,
        c = cmap,
        clim=(-20, 20),
        xlabel=L"I_{p} / \mu A",
        ylabel=L"f / GHz",
        legend=false,
        colorbar=true
    )

    IpGain, IpIndex = find_best_IpGain(outvalsS21IpSweep, sim_vars)
    sim_vars[:IpGain]=IpGain

    p5 = plot(
        sim_vars[:ws] / (2 * pi * 1e9),
        10 * log10.(abs2.(outvalsS21IpSweep)[:, IpIndex]),
        xlabel=L"f / GHz",
        ylabel=L"S_{21} / dB",
        title="Gain Profile",
        legend=false,
        colorbar=true,
        framestyle=:box
    )


    vline!(p1p, [sim_vars[:IpGain] / 1e-6], width=2, color=:black)
    vline!(p2p, [sim_vars[:IpGain] / 1e-6], width=2, color=:black)
    hline!(p1p, [sim_vars[:wp][1] / (2 * pi * 1e9)], width=2, color=:black)
    hline!(p2p, [sim_vars[:wp][1] / (2 * pi * 1e9)], width=2, color=:black)

    hline!(p1p, [(1 / 2) * sim_vars[:wp][1] / (2 * pi * 1e9)], width=2, style=:dash, color=:gray)
    hline!(p2p, [(1 / 2) * sim_vars[:wp][1] / (2 * pi * 1e9)], width=2, style=:dash, color=:gray)
    hline!(p1p, [(3 / 2) * sim_vars[:wp][1] / (2 * pi * 1e9)], width=2, style=:dash, color=:gray)
    hline!(p2p, [(3 / 2) * sim_vars[:wp][1] / (2 * pi * 1e9)], width=2, style=:dash, color=:gray)
    hline!(p1p, [2 * sim_vars[:wp][1] / (2 * pi * 1e9)], width=2, color=:gray)
    hline!(p2p, [2 * sim_vars[:wp][1] / (2 * pi * 1e9)], width=2, color=:gray)

    vline!(p5, [sim_vars[:wp][1] / (2 * pi * 1e9)], width=2, color=:black)
    vline!(p5, [(1 / 2) * sim_vars[:wp][1] / (2 * pi * 1e9)], width=2, style=:dash, color=:gray, label="")
    vline!(p5, [(3 / 2) * sim_vars[:wp][1] / (2 * pi * 1e9)], width=2, style=:dash, color=:gray, label="")
    vline!(p5, [2 * sim_vars[:wp][1] / (2 * pi * 1e9)], width=2, color=:gray,label="")
    vline!(p5, [((sim_vars[:fp]/2)-1e9)/1e9], width=2, color=:darkblue, label="")
    vline!(p5, [((sim_vars[:fp]/2)+1e9)/1e9], width=2, color=:darkblue, label="")


    return p1p, p2p, p5

end




#----------------------------------------------FINAL REPORT-----------------------------------------------------------

function final_report(params, sim_vars, fixed_params, p1, p2, p3, p4, p1p, p2p, p5)


    value_fp = @sprintf("%.2f", sim_vars[:wp][1] / (2 * pi * 1e9))
    value_IpGain = @sprintf("%.4f", sim_vars[:IpGain] / (1e-6))
    value_Supercells = @sprintf("%.0f", params[:N] / params[:loadingpitch])
    value_criticalCurrentDensity = @sprintf("%.3f", params[:criticalCurrentDensity])
    value_CgDensity = @sprintf("%.1f", params[:CgDensity] / 1e-15)
    value_Cg = @sprintf("%.2f", params[:CgAreaUNLoaded] * params[:CgDensity] / 1e-15)


    empty_plot = plot([], legend=false, grid=false, framestyle=:none)  # Create an empty plot for the text

    
    annotate!(empty_plot, 0.0, 0.5, text("""
    Design parameters:
       loadingpitch = $(round(params[:loadingpitch], digits=3)),
       A_small = $(round(params[:smallJunctionArea], digits=3)) μm²,
       alphaSNAIL = $(round(params[:alphaSNAIL], digits=3)),
       LloadingCell = $(round(params[:LloadingCell], digits=3)),
       CgloadingCell = $(round(params[:CgloadingCell], digits=3)),
       CgAreaUNLOADED = $(round(params[:CgAreaUNLoaded], digits=3))
    
    Fabrication parameters:
       Jc = $(value_criticalCurrentDensity) μA/μm²,
       Cj density = $(round(fixed_params[:JosephsonCapacitanceDensity], digits=3)) fF/μm²,
       CgDielectricThickness = $(round(params[:CgDielectricThichness], digits=3)),
       Cg density = $(value_CgDensity) fF/μm²,
       Cg = $(value_Cg) fF
    
    Simulation parameters:
       Number of Cells = $(round(params[:N], digits=3)),
       Number of Supercells = $(value_Supercells),
       fp = $(value_fp) GHz,
       IpGain = $(value_IpGain) μA,
       Phi_dc = $(round(params[:phidc], digits=3)),
    
       NPumpHarm = $(round(sim_vars[:Npumpharmonics][1], digits=3)),
       NModHarm = $(round(sim_vars[:Nmodulationharmonics][1], digits=3)),
       NIter = $(round(sim_vars[:Niterations], digits=3))
    """, 12, :black, halign=:left))

    p = plot(p1, p2, p1p, p2p, p3, p4, p5, empty_plot, layout=(4, 2), margin=10Plots.mm, size=(1500, 2000))
    
    return p


end



#-----------------------------GENERAL FUNCTION FOR SIMULATION AND PLOT--------------------------------------

function simulate_and_plot(params_temp, sim_vars, fixed_params, circuit_temp, circuitdefs_temp)

    S21, _, S11, _, S21phase = simulate_low_pump_power(sim_vars, circuit_temp, circuitdefs_temp)
    p1,p2,p3,p4 = plot_low_pump_power(S21, S11, S21phase, params_temp, sim_vars)

    S21, _, S11, _ = simulate_at_fixed_flux(params_temp, sim_vars, circuit_temp, circuitdefs_temp)
    p1p, p2p, p5 = plot_at_fixed_flux(S21, S11, sim_vars)

    p_temp = final_report(params_temp, sim_vars, fixed_params, p1, p2, p3, p4, p1p, p2p, p5)

    return p_temp

end
