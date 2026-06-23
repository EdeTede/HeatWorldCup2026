function WorldCupHeatModel
% Two-node football core-temperature model for the 2026 World Cup.
% Run with no arguments. Prints the tables and writes the four figures
% next to this file. Edit only the variables in the block below.

%% ============================ EDITABLE VARIABLES ============================
% Player
P.Mass              = 78;        %Body mass in kg (tournament middle, Mohr et al. 2012)
P.Height            = 1.82;      %Stature in m
P.CBody             = 3490;      %Specific heat of body tissue in J/kg/C
P.Lambda            = 2426;      %Latent heat of sweat evaporation in J/g
P.Tc0               = 37.0;      %Initial core temperature in C
P.Tsk0              = 33.5;      %Initial skin temperature in C

% Thermoregulation (Gagge controller)
P.Csw               = 210;       %Sweating gain in g/h/m2/C
P.SweatMax          = 1500;      %Maximum sweat rate in g/h/m2

% Metabolic heat production
P.PlayHeatPerKg     = 1750/78;   %In-play running heat in W/kg (Bangsbo 2006)
P.StopHeatPerKg     = 240/78;    %Out-of-play walking heat in W/kg
P.Pace              = 0.019;     %Intensity reduction per C WBGT above reference (Mohr et al. 2012)
P.PaceRef           = 16;        %WBGT below which there is no pacing in C

% Rest-period cooling
P.MethodRates       = struct('passive',0.045,'fan',0.07,'towel',0.13,'immersion',0.25); %In-play break cooling rate in C/min (Brown et al. 2024)
P.TcFloor           = 37.0;      %Core cannot be cooled below this in C
P.HtBaserate        = struct('passive',0.022,'fan',0.028,'towel',0.033,'immersion',0.060); %Half-time cooling baseline in C/min
P.CoolGrad          = 0.19;      %Extra cooling per C above 37 over a 15-min half-time
P.CoolSinkGain      = 0.8;       %Afterdrop reservoir charge per unit of cooling. This sets how much of the cooling applied during a break is stored for later rather than spent immediately.
P.CoolSinkTau       = 8;         %Afterdrop bleed-back time constant in min. This sets how fast the stored cold empties back into the core once play resumes.
P.CoolSinkMax       = 0.22;      %Afterdrop reservoir cap in C (Brown et al. 2024). This is the most extra core cooling the reservoir can ever deliver, about 0.22 C.
P.HtSinkFrac        = 0.5;       %Multiplier on the afterdrop banked at half-time and pre-extra-time, set below 1 because it is less effective than during an in-play break.

% Match structure
P.AddedTime         = 5;         %Added time per half in min (2022 to 2026 timekeeping)
P.VPlay             = 2.0;       %Air speed while running in m/s
P.VStop             = 0.8;       %Air speed while walking in m/s
P.VSeat             = 0.2;       %Air speed while resting in m/s
P.TPlay             = 26;        %In-play phase length in s (Siegle and Lames 2012)
P.DstopNew          = 12;        %New-law stoppage length in s (8-second goalkeeper rule)
P.DstopOld0         = 19;        %Old-law stoppage baseline in s (Siegle and Lames 2012)
P.DstopOldCap       = 30;        %Old-law stoppage ceiling in heat in s
P.BreakMin          = 22.5;      %Hydration break timing within each half in min
P.BreakLen          = 3;         %Hydration break duration in min
P.SubTimes          = [60 70 80];%Second-half substitution times in clock min
P.SubOld            = 30;        %Old-law time to leave the field in s
P.SubNew            = 10;        %New-law time to leave the field in s (IFAB 2026)
P.ExtraTime         = true;      %Include extra time
P.LagTau            = 0;         %Metabolic response lag in s, applied to the change in heat production when the ball goes in and out of play (0 for instant)

% Drinking
P.DrinkRate         = 1.5;       %Ad-libitum drinking rate during non-play time in L/h (Kurdak et al. 2010)
P.SweatReportScale  = 1.5;       %Scale evaporated sweat to total secreted sweat (Maughan et al. 2004)

% Players for the body-size comparison, as [mass in kg, height in m]
LittleValbuena      = [68, 1.74];%Smallest 2026 player
AverageJoeBell      = [78, 1.82];%Typical 2026 player
FatRonaldo          = [98, 1.99];%Largest 2026 player

%% ============================ DERIVED (do not edit) =========================
P = DeriveParams(P);
OutDir = fileparts(mfilename('fullpath'));
Blue = [0.16 0.44 0.59]; Orange = [0.90 0.44 0.32]; NbCol = [0.62 0.00 0.03];

%% ============================ VALIDATION ====================================
Val = {'Mohr cool',21,0.55,38.8; 'Ozgunen',34,0.38,39.1; 'Ozgunen humid',36,0.61,39.6; ...
       'Brown',40,0.41,39.3; 'Mohr hot-dry',43,0.12,39.7}; %Study, Ta, RH, measured peak core
fprintf('\nVALIDATION (reference match, 90 min)\n%-16s %-6s %-9s %-7s %s\n','study','WBGT','measured','model','diff');
Err = 0;
for I = 1:size(Val,1)
    R = SimulateMatch('ref', Val{I,2}, Val{I,3}, P, false);
    D = R.peak - Val{I,4}; Err = Err + D^2;
    fprintf('%-16s %-6.0f %-9.1f %-7.2f %+0.2f\n', Val{I,1}, R.wbgt, Val{I,4}, R.peak, D);
end
fprintf('RMSE = %.2f C\n', sqrt(Err/size(Val,1)));

%% ============================ KEY-POINT TABLE ===============================
PrintKeypoints(P);

%% ============================ COOLING-BREAK EFFECT ==========================
fprintf('\nCOOLING-BREAK EFFECT (core at end of normal time: new game vs same game, no in-play break)\n');
for W = [28 32]
    Ta = TaForWbgt(W, 0.50);
    Rn = SimulateMatch('new', Ta, 0.50, P); Rb = SimulateMatch('new_nb', Ta, 0.50, P);
    Cn = TcAt(Rn, SegT(Rn,'Second Half',2)); Cb = TcAt(Rb, SegT(Rb,'Second Half',2));
    fprintf('  WBGT %d C: the break lowers core by %.2f C at full time\n', W, Cb-Cn);
end
fprintf('  (Brown et al. 2024 measured 0.39 C at WBGT 32, 95%% CI 0.21 to 0.57)\n');

%% ============================ FIGURE 1: traces by WBGT ======================
Wlevels = [24 26 28 30 32];
F1 = figure('Color','w','Position',[60 60 1280 720]);
for I = 1:numel(Wlevels)
    Ta = TaForWbgt(Wlevels(I), 0.50);
    A = SimulateMatch('old', Ta, 0.50, P);
    B = SimulateMatch('new', Ta, 0.50, P);
    Cnb = SimulateMatch('new_nb', Ta, 0.50, P);
    Ax = subplot(2,3,I); hold(Ax,'on');
    HO = plot(Ax,A.t,A.Tc,'Color',Blue,'LineWidth',1);
    HN = plot(Ax,B.t,B.Tc,'Color',Orange,'LineWidth',1);
    HNB = plot(Ax,RemapTime(Cnb,B.segs),Cnb.Tc,'--','Color',NbCol,'LineWidth',1);
    yline(Ax,39.5,'--','Color',[0.88 0.56 0.04]); yline(Ax,40,'-','Color',[0.76 0.07 0.15]);
    ylim(Ax,[37.0 40.4]); xlim(Ax,[0 B.t(end)]); LabelPeriods(Ax,B.segs);
    title(Ax,sprintf('WBGT %d C  |  peak old %.1f, new %.1f, no-break %.1f',Wlevels(I),A.peak,B.peak,Cnb.peak));
    if I==1, legend([HO HN HNB],{'Old rules','New rules','New, no break'},'Location','southeast','FontSize',7); end
    ylabel(Ax,'core (C)');
end
Ax = subplot(2,3,6); hold(Ax,'on'); Ws = 20:2:32; PkO = zeros(size(Ws)); PkN = PkO; PkNb = PkO;
for J = 1:numel(Ws)
    Ta = TaForWbgt(Ws(J),0.50);
    PkO(J)  = SimulateMatch('old',Ta,0.50,P).peak;
    PkN(J)  = SimulateMatch('new',Ta,0.50,P).peak;
    PkNb(J) = SimulateMatch('new_nb',Ta,0.50,P).peak;
end
plot(Ax,Ws,PkO,'-o','Color',Blue,'LineWidth',2); plot(Ax,Ws,PkN,'-o','Color',Orange,'LineWidth',2);
plot(Ax,Ws,PkNb,'--^','Color',NbCol,'LineWidth',1.5);
yline(Ax,39.5,'--','Color',[0.88 0.56 0.04]); yline(Ax,40,'-','Color',[0.76 0.07 0.15]);
xline(Ax,32,':','FIFA 32','Color',[0.42 0.30 0.57]);
xlabel(Ax,'WBGT (C)'); ylabel(Ax,'peak core (C)'); title(Ax,'Peak vs WBGT');
legend(Ax,{'Old','New','New, no break'},'Location','northwest','FontSize',7); grid(Ax,'on');
saveas(F1,fullfile(OutDir,'fig_traces_by_wbgt.png'));

%% ============================ FIGURE 2: cooling methods (bars) ==============
Methods = {'passive','fan','towel','immersion'}; Mdisp = {'passive','fan','ice towel','immersion'};
Wlev = [24 28 32]; Pk = zeros(4,3);
for W = 1:3
    Ta = TaForWbgt(Wlev(W),0.50);
    for M = 1:4, Pk(M,W) = SimulateMatch('new',Ta,0.50,P,true,Methods{M}).peak; end
end
F2 = figure('Color','w','Position',[60 60 780 480]); Ax = axes(F2); hold(Ax,'on');
Bars = bar(Ax,Pk);
yline(Ax,39.5,'--','39.5 C watch','Color',[0.88 0.56 0.04],'LabelHorizontalAlignment','left');
yline(Ax,40,'-','40 C heat stroke','Color',[0.76 0.07 0.15],'LabelHorizontalAlignment','left');
set(Ax,'XTick',1:4,'XTickLabel',Mdisp); ylim(Ax,[38.5 40.5]);
xlabel(Ax,'cooling method'); ylabel(Ax,'peak core temperature (C)');
title(Ax,'Cooling methods at matched WBGT (new game, neutral RH 50%)');
legend(Bars,{'WBGT 24','WBGT 28','WBGT 32'},'Location','northwest');
saveas(F2,fullfile(OutDir,'fig_cooling.png'));

%% ============================ FIGURE 3: cooling-method traces ===============
Cm = {'passive','fan','towel','immersion'}; Cmd = {'passive','fan','ice towel + drink','immersion'};
Cc = [0.55 0.60 0.68; 0.32 0.72 0.53; 0.16 0.44 0.59; 0.62 0.00 0.03];
Practical = struct('brk','towel','ht','immersion','pre','towel'); %Towel breaks, immersion half-time
F3 = figure('Color','w','Position',[60 40 980 1000]);
for W = 1:3
    Ta = TaForWbgt(Wlev(W),0.50);
    Ax = subplot(3,1,W); hold(Ax,'on'); H = gobjects(1,5);
    for M = 1:4
        Rm = SimulateMatch('new',Ta,0.50,P,true,Cm{M});
        H(M) = plot(Ax,Rm.t,Rm.Tc,'Color',Cc(M,:),'LineWidth',1.1);
    end
    Rp = SimulateMatch('new',Ta,0.50,P,true,Practical);
    H(5) = plot(Ax,Rp.t,Rp.Tc,'--','Color',[0.40 0.18 0.55],'LineWidth',1.7);
    yline(Ax,39.5,'--','39.5 C watch','Color',[0.88 0.56 0.04],'LabelHorizontalAlignment','left');
    yline(Ax,40,'-','40 C heat stroke','Color',[0.76 0.07 0.15],'LabelHorizontalAlignment','left');
    ylim(Ax,[37.8 40.5]); xlim(Ax,[0 Rm.t(end)]); LabelPeriods(Ax,Rm.segs);
    ylabel(Ax,'core (C)');
    title(Ax,sprintf('WBGT %d C (T_a %.0f C)  -- passive hottest, immersion coolest',Wlev(W),Ta));
    if W==1, legend(H,[Cmd,{'practical: towel breaks + immersion HT'}],'Location','southeast','FontSize',7); end
end
saveas(F3,fullfile(OutDir,'fig_cooling_trace.png'));

%% ============================ FIGURE 4: body size ===========================
Bodies = {'biggest 98 kg',FatRonaldo(1),FatRonaldo(2),[0.62 0.00 0.03]; ...
          'middle 78 kg', AverageJoeBell(1),AverageJoeBell(2),[0.16 0.44 0.59]; ...
          'smallest 68 kg',LittleValbuena(1),LittleValbuena(2),[0.32 0.72 0.53]};
F4 = figure('Color','w','Position',[60 60 920 580]); Ax = axes(F4); hold(Ax,'on'); Hb = gobjects(1,3);
for B = 1:3
    Pb = P; Pb.Mass = Bodies{B,2}; Pb.Height = Bodies{B,3}; Pb = DeriveParams(Pb);
    PkN = zeros(size(Ws)); PkO = PkN; PkNb = PkN;
    for J = 1:numel(Ws)
        Ta = TaForWbgt(Ws(J),0.50);
        PkN(J)  = SimulateMatch('new',   Ta,0.50,Pb,true,Practical).peak;
        PkO(J)  = SimulateMatch('old',   Ta,0.50,Pb,true,Practical).peak;
        PkNb(J) = SimulateMatch('new_nb',Ta,0.50,Pb,true,Practical).peak;
    end
    Hb(B) = plot(Ax,Ws,PkN,'-','Color',Bodies{B,4},'LineWidth',2.2);
    plot(Ax,Ws,PkO,'--','Color',Bodies{B,4},'LineWidth',1.2);
    plot(Ax,Ws,PkNb,':','Color',Bodies{B,4},'LineWidth',1.6);
end
Hs1 = plot(Ax,nan,nan,'-','Color','k'); Hs2 = plot(Ax,nan,nan,'--','Color','k'); Hs3 = plot(Ax,nan,nan,':','Color','k');
yline(Ax,39.5,'--','39.5 C watch','Color',[0.88 0.56 0.04],'LabelHorizontalAlignment','left');
yline(Ax,40,'-','40 C heat stroke','Color',[0.76 0.07 0.15],'LabelHorizontalAlignment','left');
xline(Ax,32,':','FIFA 32','Color',[0.42 0.30 0.57]);
xlabel(Ax,'WBGT (C)'); ylabel(Ax,'peak core temperature (C)');
title(Ax,'Body size and heat (practical cooling: ice towel breaks + immersion half-time)');
legend([Hb Hs1 Hs2 Hs3], [Bodies(:,1)', {'new (solid)','old (dashed)','no-break (dotted)'}], ...
       'Location','northwest','FontSize',8,'NumColumns',2); grid(Ax,'on');
saveas(F4,fullfile(OutDir,'fig_body_size.png'));

%% ============================ FLUID TABLE ===================================
fprintf('\nFLUID (new game, %d kg player, RH 50%%; intake = non-play drinking at %.1f L/h)\n',P.Mass,P.DrinkRate);
fprintf('%-6s %-10s %-10s %-10s %-9s\n','WBGT','sweat(L)','drink(L)','net(L)','net %BM');
for W = [24 28 32]
    Ta = TaForWbgt(W,0.50); R = SimulateMatch('new',Ta,0.50,P);
    fprintf('%-6.0f %-10.1f %-10.1f %-10.1f %-9.1f\n',W,R.sweat_L,R.intake_L,R.net_loss_L,R.net_loss_pct);
end
fprintf('\nDone. Figures written to %s\n',OutDir);
end

%% ============================ MODEL FUNCTIONS ===============================
function P = DeriveParams(P)
% Mass-dependent quantities, recomputed after any mass or height change
P.A      = 0.20247 * P.Mass^0.425 * P.Height^0.725;  %DuBois surface area in m2
P.MPlay  = P.PlayHeatPerKg * P.Mass;                 %Whole-body play heat in W
P.MStop  = P.StopHeatPerKg * P.Mass;                 %Whole-body stoppage heat in W
end

function S = TwoNodeStep(S, Ta, RH, V, MTot, P)
% Advance the core-and-skin model by one second (Gagge et al. 1971)
CoreTemp = S(1); SkinTemp = S(2); Sweat = S(4);
Metab = MTot / P.A;
WarmCore = max(0, CoreTemp - 36.8);
ColdSkin = max(0, 33.7 - SkinTemp);
WarmSkin = max(0, SkinTemp - 33.7);
SkinBloodFlow = min(90, max(0.5, (6.3 + 120*WarmCore) / (1 + 0.5*ColdSkin)));
SkinFraction = 0.0418 + 0.745/(SkinBloodFlow + 0.585);
BodyTemp = SkinFraction*SkinTemp + (1-SkinFraction)*CoreTemp;
SweatRate = min(P.SweatMax, P.Csw * max(0, BodyTemp - 36.49) * exp(WarmSkin/10.7));
SweatEvapDemand = SweatRate/3600 * P.Lambda;
ConvCoef = max(3.0, 8.3 * V^0.6);
RadCoef = 4.7;
EvapCoef = 16.5 * ConvCoef;
DryLoss = (RadCoef + ConvCoef) * 0.9 * (SkinTemp - Ta);
SkinVapPress = SatPressure(SkinTemp);
AirVapPress = RH * SatPressure(Ta);
EvapMax = max(0.001, EvapCoef * 0.9 * (SkinVapPress - AirVapPress));
SkinWettedness = min(1.0, 0.06 + 0.94*(SweatEvapDemand/EvapMax));
EvapLoss = SkinWettedness * EvapMax;
RespConv = 0.0014 * Metab * (34 - Ta);
RespEvap = 0.0173 * Metab * (5.87 - AirVapPress);
CoreSkinCond = 5.28 + 1.163*SkinBloodFlow;
CoreToSkin = CoreSkinCond * (CoreTemp - SkinTemp);
CoreCap = (1-SkinFraction) * P.Mass * P.CBody / P.A;
SkinCap = SkinFraction * P.Mass * P.CBody / P.A;
CoreTemp = CoreTemp + (Metab - (RespConv + RespEvap) - CoreToSkin) / CoreCap;
SkinTemp = SkinTemp + (CoreToSkin - DryLoss - EvapLoss) / SkinCap;
Sweat = Sweat + SweatRate/3600 * P.A;
S = [CoreTemp, SkinTemp, SkinBloodFlow, Sweat];
end

function Pkpa = SatPressure(T)
% Saturation vapour pressure in kPa (Tetens)
Pkpa = 0.6108 * exp(17.27 * T ./ (T + 237.3));
end

function W = Wbgt(Ta, RH)
% Shade wet-bulb globe temperature in C from air temperature and humidity (Stull 2011)
Rh = RH*100;
Twb = Ta .* atan(0.151977 .* sqrt(Rh + 8.313659)) ...
    + atan(Ta + Rh) - atan(Rh - 1.676331) ...
    + 0.00391838 .* Rh.^1.5 .* atan(0.023101 .* Rh) - 4.686035;
W = 0.7*Twb + 0.3*Ta;
end

function R = SimulateMatch(Scenario, Ta, RH, P, ET, Method)
% Core temperature across a match for a rule set (old, new, new_nb, ref)
if nargin < 5 || isempty(ET),     ET = P.ExtraTime; end
if nargin < 6 || isempty(Method), Method = 'towel';  end
if ischar(Method) || isstring(Method)
    BreakMethod = char(Method); HtMethod = char(Method); PreMethod = char(Method);
else
    BreakMethod = Method.brk; HtMethod = Method.ht; PreMethod = Method.pre;
end
W = Wbgt(Ta, RH);
PlayHeat = P.MPlay * (1 - P.Pace * max(0, W - P.PaceRef));
BreakRate = P.MethodRates.(BreakMethod);
switch Scenario
    case 'old'
        Dstop = round(min(P.DstopOldCap, P.DstopOld0 + (P.DstopOldCap-P.DstopOld0)*(1-exp(-0.5*max(0,W-21)))));
        DoBreak = false; HalfSecs = (45 + P.AddedTime)*60; SubDur = P.SubOld;
    case 'new'
        Dstop = P.DstopNew; DoBreak = true;  HalfSecs = (45 + P.AddedTime)*60; SubDur = P.SubNew;
    case 'new_nb'
        Dstop = P.DstopNew; DoBreak = false; HalfSecs = (45 + P.AddedTime - P.BreakLen)*60; SubDur = P.SubNew;
    case 'ref'
        Dstop = P.DstopOld0; DoBreak = false; HalfSecs = 45*60; SubDur = 0;
    otherwise
        error('Scenario must be old, new, new_nb or ref');
end
if strcmp(Scenario,'ref'), HtMethod = 'passive'; PreMethod = 'passive'; end
State = [P.Tc0, P.Tsk0, 6.3, 0];   %Core, skin, skin blood flow, cumulative sweat
MetabEff = P.MStop;
CoreTrace = zeros(1, 220*60); N = 0;
Intake = 0;
AfterdropSink = 0;
Segs = struct('name',{},'t0',{},'t1',{});
Mark('First Half',  @() PlayHalf(DoBreak, HalfSecs, false));
Mark('Half-Time',   @() EmitHalftime(15, HtMethod));
Mark('Second Half', @() PlayHalf(DoBreak, HalfSecs, true));
if ET
    Mark('Pre-ET',    @() EmitHalftime(5, PreMethod));
    Mark('ET first',  @() EtHalf());
    Mark('ET second', @() EtHalf());
end
CoreTrace = CoreTrace(1:N);
SweatLitres  = State(4)/1000 * P.SweatReportScale;
IntakeLitres = min(Intake, SweatLitres);
NetLossLitres = SweatLitres - IntakeLitres;
R = struct('t',(1:N)/60, 'Tc',CoreTrace, 'segs',Segs, 'peak',max(CoreTrace), 'endTc',CoreTrace(end), ...
           'wbgt',W, 'dstop',Dstop, 'method',BreakMethod, 'sweat_L',SweatLitres, ...
           'intake_L',IntakeLitres, 'net_loss_L',NetLossLitres, 'net_loss_pct',100*NetLossLitres/P.Mass);

    function Mark(Name, Fn)
        T0 = N/60; Fn(); Segs(end+1) = struct('name',Name,'t0',T0,'t1',N/60);
    end
    function Emit(Secs, V, MTot)
        for K = 1:Secs
            if P.LagTau > 0, MetabEff = MetabEff + (MTot - MetabEff)/P.LagTau; else, MetabEff = MTot; end
            State = TwoNodeStep(State, Ta, RH, V, MetabEff, P);
            if AfterdropSink > 0
                Bleed = AfterdropSink / (P.CoolSinkTau*60);
                State(1) = State(1) - Bleed; State(2) = State(2) - Bleed;
                AfterdropSink = max(0, AfterdropSink - Bleed);
            end
            N = N + 1; CoreTrace(N) = State(1);
        end
    end
    function EmitRest(Mins, Rate)
        Intake = Intake + P.DrinkRate * Mins/60;
        for K = 1:round(Mins*60)
            Drop = Rate/60 * max(0, State(1) - P.TcFloor)/2.0;
            State(1) = State(1) - Drop; State(2) = State(2) - Drop;
            AfterdropSink = min(P.CoolSinkMax, AfterdropSink + Drop*P.CoolSinkGain);
            N = N + 1; CoreTrace(N) = State(1);
        end
    end
    function EmitHalftime(Mins, M)
        Intake = Intake + P.DrinkRate * Mins/60;
        T0 = State(1);
        Total = P.HtBaserate.(M)*Mins + P.CoolGrad*max(0, T0 - 37)*(Mins/15);
        Total = min(Total, max(0, T0 - P.TcFloor));
        Per = Total / round(Mins*60);
        Active = ~strcmp(M,'passive');
        for K = 1:round(Mins*60)
            State(1) = State(1) - Per; State(2) = State(2) - Per;
            if Active, AfterdropSink = min(P.CoolSinkMax*P.HtSinkFrac, AfterdropSink + Per*P.CoolSinkGain); end
            N = N + 1; CoreTrace(N) = State(1);
        end
    end
    function Fill(Total, Db, DoSubs)
        T = 0; Did = false;
        SubT = (P.SubTimes - 45)*60; DoneSub = false(1, numel(SubT));
        while T < Total
            if Db && ~Did && T >= round(P.BreakMin*60)
                D = min(P.BreakLen*60, Total - T); EmitRest(D/60, BreakRate);
                T = T + D; Did = true;
                if T >= Total, break; end
            end
            if DoSubs && SubDur > 0
                for Is = 1:numel(SubT)
                    if ~DoneSub(Is) && T >= SubT(Is)
                        D = min(SubDur, Total - T); Emit(round(D), P.VStop, P.MStop);
                        Intake = Intake + P.DrinkRate * D/3600;
                        T = T + D; DoneSub(Is) = true;
                        if T >= Total, break; end
                    end
                end
                if T >= Total, break; end
            end
            D = min(P.TPlay, Total - T); Emit(round(D), P.VPlay, PlayHeat); T = T + D;
            if T >= Total, break; end
            D = min(Dstop, Total - T); Emit(round(D), P.VStop, P.MStop); T = T + D;
            Intake = Intake + P.DrinkRate * D/3600;
        end
    end
    function PlayHalf(Db, Hs, DoSubs), Fill(Hs, Db, DoSubs); end
    function EtHalf(), Fill(15*60, false, false); end
end

%% ============================ ANALYSIS HELPERS ==============================
function PrintKeypoints(P)
% Core temperature at the key points of the match, for each rule set, at a hot but playable condition
Ta = 34; RH = 0.50;
Practical = struct('brk','towel','ht','immersion','pre','towel');
Rows = {'Old rules','old','towel'; 'New rules','new','towel'; 'New + practical','new',Practical};
Pts  = {'Start','Brk1 in','Brk1 out','HT in','HT out','Brk2 in','Brk2 out','preET in','preET out','Full-time'};
fprintf('\nCORE TEMPERATURE AT KEY POINTS (T_a %d C, WBGT %.0f, RH 50%%, ice towel + drink unless noted)\n',Ta,Wbgt(Ta,RH));
fprintf('%-16s',''); fprintf('%10s',Pts{:}); fprintf('\n');
for R = 1:size(Rows,1)
    Rr = SimulateMatch(Rows{R,2}, Ta, RH, P, true, Rows{R,3});
    H0 = SegT(Rr,'Half-Time',1); H1 = SegT(Rr,'Half-Time',2); S2 = SegT(Rr,'Second Half',1);
    P0 = SegT(Rr,'Pre-ET',1);    P1 = SegT(Rr,'Pre-ET',2);    Bm = P.BreakMin; Bl = P.BreakLen;
    V = [TcAt(Rr,0), TcAt(Rr,Bm), TcAt(Rr,Bm+Bl), TcAt(Rr,H0), TcAt(Rr,H1), ...
         TcAt(Rr,S2+Bm), TcAt(Rr,S2+Bm+Bl), TcAt(Rr,P0), TcAt(Rr,P1), Rr.Tc(end)];
    fprintf('%-16s',Rows{R,1}); fprintf('%10.2f',V); fprintf('\n');
end
end

function V = TcAt(R, Minute)
% Core temperature in C at a given match time in minutes
Idx = max(1, min(numel(R.Tc), round(Minute*60)));
V = R.Tc(Idx);
end

function T = SegT(R, Name, Which)
% Start (Which=1) or end (Which=2) time in minutes of a named period
T = 0;
for I = 1:numel(R.segs)
    if strcmp(R.segs(I).name, Name)
        if Which==1, T = R.segs(I).t0; else, T = R.segs(I).t1; end
        return;
    end
end
end

function Ta = TaForWbgt(Target, RH)
% Air temperature giving a target WBGT at a humidity, by bisection
Lo = 5; Hi = 55;
for K = 1:40
    M = (Lo+Hi)/2;
    if Wbgt(M,RH) < Target, Lo = M; else, Hi = M; end
end
Ta = (Lo+Hi)/2;
end

function Tp = RemapTime(R, RefSegs)
% Stretch each of R's periods onto the matching reference period for the period x-axis
Tp = R.t;
for I = 1:numel(R.segs)
    A0 = R.segs(I).t0; A1 = R.segs(I).t1; B0 = RefSegs(I).t0; B1 = RefSegs(I).t1;
    Idx = R.t>=A0 & R.t<=A1;
    if A1>A0, Tp(Idx) = B0 + (R.t(Idx)-A0)/(A1-A0)*(B1-B0); end
end
end

function LabelPeriods(Ax, Segs)
% Make the x-axis the game periods, shading the rest intervals and naming each
Yl = get(Ax,'YLim');
Ticks = zeros(1,numel(Segs)); Lbls = cell(1,numel(Segs));
for I = 1:numel(Segs)
    Nm = Segs(I).name;
    if strcmp(Nm,'Half-Time') || strcmp(Nm,'Pre-ET')
        patch(Ax, [Segs(I).t0 Segs(I).t1 Segs(I).t1 Segs(I).t0], ...
              [Yl(1) Yl(1) Yl(2) Yl(2)], [0.90 0.92 0.96], 'EdgeColor','none', 'FaceAlpha',0.5);
    end
    if I>1, xline(Ax, Segs(I).t0, '-', 'Color',[0.85 0.85 0.85]); end
    Ticks(I) = (Segs(I).t0 + Segs(I).t1)/2;
    Lbls{I}  = Abbrev(Nm);
end
set(Ax,'XTick',Ticks,'XTickLabel',Lbls);
try, set(Ax,'XTickLabelRotation',30); catch, end
uistack(findobj(Ax,'Type','patch'),'bottom');
end

function A = Abbrev(Nm)
% Short period labels for the figure x-axis
switch Nm
    case 'First Half',  A = '1st half';
    case 'Half-Time',   A = 'HT';
    case 'Second Half', A = '2nd half';
    case 'Pre-ET',      A = 'pre-ET';
    case 'ET first',    A = 'ET1';
    case 'ET second',   A = 'ET2';
    otherwise,          A = Nm;
end
end
