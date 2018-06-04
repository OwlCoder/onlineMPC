%% Paper Implementation
%  Fast Nonlinear MPC for Unified Traj Optimization and Tracking
%  Algorithm 1: SLQ Algorithm
%  Biorobotics Lab
%  Carnegie Mellon University
%  29 May 2018
%%
format compact; close all; clear; clc; 

PLOTTING = 1 % to plot or not to plot

% -----------------------------------------%
% ----------- desired trajectory --------------%
% -----------------------------------------%

Dyn_desired = @Aug_Dyn ;% desired dynamics
% Dyn_desired = @Simp_Dyn ;% desired dynamics
xfd = [3/4*pi;0.2] ;% final conditions (DESIRED)
umaxd = 1 ;%upper control bound (optimization variable) 

% -----------------------------------------%
% ----------- nominal trajectory -------------%
% -----------------------------------------%

%  Nominal Control Trajectory for Simple Damped Pendulum
Dyn_nominal = @Simp_Dyn ;% nominal dynamics
xfn = [pi;0] ;% final conditions (NOMINAL)
umaxn = 1 ;%upper control bound (optimization variable) 

% How linearization of A, Boccurs: finite diff vs analytical
% A_calculation = @A_xPartial ;% generic finite diff for any dynamics 
% B_calculation = @B_uPartial ;% generic finite diff for any dynamics
A_calculation = @A_Simp_analytical ;% analytical A for Simplified Pendulum
B_calculation = @B_Simp_analytical ;% analytical B for Simplified Pendulum

%% GIVEN

% -----------------------------------------%
% ---------- system dynamics ---------------%
% -----------------------------------------%
%  Simple Damped Pendulum (Function at end)

global x0 Nx Nu

x0 = [0;0] ;% initial conditions
Nx = size(x0,1) ;% size of x parameters
Nu = 1 ;% size of control parameters

global Q R Qf
Q = 1*eye(Nx) ; 
Qf = 2000*Q ;
R = 1*eye(Nu) ;

save LOAD_given.mat
%{

global xf N dt
T = 10 ;% [sec] total time 
freq = 10 ;% [Hz] frequency 
dt = 1/freq ;% [sec] discrete time step 
N = floor(T/dt)+1 ;% number of collocation points

% -----------------------------------------%
% ------------ cost function ----------------%
% -----------------------------------------%
%  (function at end)

% -----------------------------------------%
% --------- initial stable control law ----------%
% -----------------------------------------%

A = [] ;%empty because no linear equations
b = [] ;%empty because no linear equations
Aeq = [] ;%empty because no linear equations
beq = [] ;%empty because no linear equations

options =optimoptions(@fmincon,'TolFun',0.00000001,'MaxIter',10000,...
    'MaxFunEvals',100000,'Display','iter','DiffMinChange',0.001,'Algorithm','sqp');

COSTFUN = @(params) cost_to_minimize(params) ;

% First run gets nominal trajectory, second run gets desired trajectory
for m = 1:2
    if m==1   % Desired Trajectory (may not be feasible)
        xf = xfd ;
        umax = umaxd ;
        CONSTRAINTFUN = @(params) nonlinconstraints(params,Dyn_desired) ;        
    else         % Nominal Trajectory (feasible)
        umax = umaxn ;
        xf = xfn ;
        CONSTRAINTFUN = @(params) nonlinconstraints(params,Dyn_nominal);
    end

    UB = [inf*ones(Nx,N);
             umax*ones(Nu,N)];
    LB = -UB;
    params0 = [x0, zeros(Nx,N-2), xf;
                      zeros(Nu,N)];
    
    params = fmincon(COSTFUN,params0,A,b,Aeq,beq,LB,UB,CONSTRAINTFUN,options);

    X{m} = params(1:Nx,:) ;
    U{m} = params(Nx+1:Nx+Nu,:) ;
end

global xd ud xnom unom
% interpolate collocation points
t_ = 0:dt:T ;
freq = 100;% [Hz] frequency 
dt = 1/freq ;% [sec] discrete time step 
N = floor(T/dt)+1 ;% number of collocation points
t = 0:dt:T ;%

save('LOAD_collocation.mat')
%}
load LOAD_collocation.mat
load LOAD_given.mat

xd = interp1(t_',X{1}',t)' ;% interpolate states
ud = interp1(t_',U{1}',t) ;% interpolate control
xnom = interp1(t_',X{2}',t)' ;% interpolate states
unom = interp1(t_',U{2}',t) ;% interpolate control

%% START FIRST WHILE LOOP
global Wp pp

Wp = Qf ;
pp = 1 ;

% Initial Difference and Cost
delx = xnom - xd ;
delu = unom - ud ;
J = cost_endpoint(xnom,unom) + cost_running(delx,delu) ;
        
for i = 1:N-1
        u_ = unom(:,i) ;
        x_ = xnom(:,i) ;
%         A{i} = A_calculation(x_,u_,Dyn_nominal) ; %linearization of A
%         B{i} = B_calculation(x_,u_,Dyn_nominal) ; %linearization of B
%         
        A_ = A_calculation(x_,u_,Dyn_nominal) ; %linearization of A
        B_ = B_calculation(x_,u_,Dyn_nominal) ; %linearization of B
        [A{i}, B{i}] = linearize(A_,B_) ;
        
end

[l,K,P,p] = Ricatti(delx,delu,A,B) ;
% J = Cost_TaylorExpansion(delx,delu,p,P) ;

l_total = 20 ;% max number of iterations
l_search_total = 50 ;% max number of line searches
EXIT = 0 ;
u_stored = unom ;
u_converge = 1 ;% difference from u last to u new
CONVERGED = 0 ; 

l = zeros(1,N-1) ;%memory preallocation
K = zeros(N-1,2) ;%memory preallocation
for i = 1:N-1
    A{i} = zeros(Nx,Nx) ;%memory preallocation
    B{i} = zeros(Nx,Nu) ;%memory preallocation
end
U_ = zeros(Nu,N) ;%memory preallocation
X_ = zeros(Nx,N) ;%memory preallocation

if PLOTTING == 1
    PLOTTER(1,[t;xnom;unom;xd;ud]);
end

%%
l_iter = 1 ;
tic
timer = cputime ;
while (l_iter < l_total) && (~CONVERGED) 

    % -----------------------------------------%
    % ------ simulate system dynamics -----------%
    % -----------------------------------------% 
    % precomputed initial or used from last iteration
    
        
    % -----------------------------------------%
    % ---- linearize system dynamics along --------%
    % ---- the nominal trajectory -----------------%
    % -----------------------------------------%  
    for i = 1:N-1
        u_ = unom(:,i) ;% linearize about nominal trajectory
        x_ = xnom(:,i) ;
        
        % partials wrt state and control: A & B from 0 to tf-1
%         A{i} = A_calculation(x_,u_,Dyn_nominal) ; %linearization of A
%         B{i} = B_calculation(x_,u_,Dyn_nominal) ; %linearization of B

%         
        A_ = A_calculation(x_,u_,Dyn_nominal) ; %linearization of A
        B_ = B_calculation(x_,u_,Dyn_nominal) ; %linearization of B
        [A{i}, B{i}] = linearize(A_,B_) ;
%    
    end  
    
    % -----------------------------------------%
    % ------ quadratize cost function -------------%
    % ------ along the trajectory -----------------%
    % -----------------------------------------%  
    % precomputed initial or used from last iteration
    
    fprintf('Cost: %6.2f \n',J)

    % -----------------------------------------%
    % ------ backwards solve ricatti-like ----------%
    % ------ difference equations ----------------%
    % -----------------------------------------%
    
    [l,K,P,p] = Ricatti(delx,delu,A,B) ;
    
    %% LINE SEARCH: START SECOND WHILE LOOP

    alpha = 1 ;
    l_search = 1; 
    J_ = 1e10 ;% arbitrary high cost
    
    while (l_search < l_search_total) && (J_ > J)
    
        % -----------------------------------------%
        % ---------- update the control & ------------%
        % ---------- forward simulate dynamics ------%
        % -----------------------------------------%   
        
        x_ = x0 ;
        X_(:,1) = x_ ;
        for i = 1:N-1 
%             u_ = ud(:,i) + alpha*l(i) + K(i,:)*(x_ - xnom(:,i)) ;   
            u_ = unom(:,i) + alpha*l(i) + K(i,:)*(x_ - xnom(:,i)) ;               
            x_ = x_ + Dyn_nominal(x_,u_)*dt ;

            U_(:,i) = u_ ;
            X_(:,i+1) = x_ ;
        end  
        U_(:,end) = zeros(Nu,1) ;
        
        % -----------------------------------------%
        % ---------- compute new cost --------------%
        % -----------------------------------------% 

        delx = X_ - xd ;%
        delu = U_ - ud ;%
        J_ = cost_endpoint(X_,U_) + cost_running(delx,delu) ;
%         J_ = Cost_TaylorExpansion(delx,delu,p,P) ;
        
        %%
        JSTORE(l_search) = J_ ;
        UNOM{l_search} = U_ ;
        XNOM{l_search} = X_ ;
        DELX{l_search} = delx ;
        DELU{l_search} = delu ;        
        
        % -----------------------------------------%
        % ----- decrease alpha by constant alpha_d ----%
        % -----------------------------------------% 
        
        alpha_d = 1.1 ;% guess?  
        alpha = alpha/alpha_d ;
        
        l_search = l_search + 1  ;
    end

    [J_,ind] = min(JSTORE) ;
    
    if J_ < J % xnom and unom used for next iteration
        J = J_ ;
        unom = UNOM{ind} ;
        xnom = XNOM{ind} ;
        delu = DELU{ind} ;        
        delx = DELX{ind} ;   
%         unom = U_ ;
%         xnom = X_ ;
        
        theta_norm   = norm( xnom(1,:) - xd(1,:) ) ;
        omega_norm = norm( xnom(2,:) - xd(2,:) ) ;
%         if theta_norm < 1
%             if omega_norm < 1.5
%                 CONVERGED = 1;
%             end
%         end

%         if norm(u_stored-unom) < u_converge
%             CONVERGED = 1 ;
%         end
    else
        CONVERGED = 1 ;
    end
            
    l_iter = l_iter + 1 ;
    u_stored = unom ;
    
    % PLOTTING Nominal Iteration
    if PLOTTING == 1
        PLOTTER([2;l_iter],[t;xnom;unom]);
    end
end
fprintf('Cost: %5.2f\n ',J_)
fprintf('CPU Time: %5.2f seconds \n',cputime - timer)
toc

if PLOTTING == 1
    PLOTTER(3,[]);
end

running = cost_running(delx,delu)
endpoint = cost_endpoint(delx,delu)
theta_norm
omega_norm

%% FUNCTIONS: COST
function J = cost_to_minimize(params) 
    global Nx Nu 
    x = params(1:Nx,:);
    u = params(Nx+1:Nx+Nu,:);
    
    J = cost_endpoint(x,u) + cost_running(x,u) ;
end

function endpoint = cost_endpoint(x,u)
    global xf Qf N

    xbarf = x(:,end)-xf ;% deviation from endpoint
    endpoint = xbarf'*Qf*xbarf ;
%     endpoint = endpoint*(N-1) ;
end

function running = cost_running(x,u)
    global N Q R

    running = 0 ; 
    for iter = 1:N-1
        running = running + x(:,iter)'*Q*x(:,iter)+u(iter)'*R*u(iter)  ; 
    end
%     running = running*1000/(N-1) ;
end
%{
function W = cost_waypoint(x)
    global xd N Wp pp dt

    W = 0 ;% initial waypoint cost
    for iter = 1:N-1        
        t = (iter-1)*dt ;%[sec] time
        tp = t ;% time desired waypoint is reached
        
        xhat = x(:,iter) - xd(:,iter) ;% deviation from current to waypoint state

        W = W + xhat'*Wp*xhat*sqrt(pp/(2*pi))*exp(-pp/2*(t-tp)^2); % (5) waypoint cost

    end
end

function J = Cost_TaylorExpansion(x,u,p,P)
    global Qf Q R N
    Q_ = 2*Q ;
    R_ = 2*R ;
    
    p_little_tf = x(:,end)'*Qf*x(:,end) ;
    q_little = p_little_tf ;

    endpoint = p_little_tf + x(:,end)'*p{N-1} + 1/2*x(:,end)'*P{end}*x(:,end) ;
    running = 0 ;
    for i = 1:N-1
        q_ = 2*Qf*x(:,i) ;
        r_ = 2*R_*u(:,i) ;
        running = running +...
            q_little + x(:,i)'*q_ + u(:,i)'*r_ +...
            1/2*x(:,i)'*Q_*x(:,i) + 1/2*u(:,i)'*R_*u(:,i) ;
    end
    J = endpoint + running ;

end
%}
%% FUNCTIONS: CONSTRAINTS

% NONLINEAR CONSTRAINTS TO MINIMIZE (GENERIC PENDULUM)
function [c,ceq] = nonlinconstraints(params,Dynamics) 
    global N x0 xf Nx Nu dt 
    x = params(1:Nx,:);
    u = params(Nx+1:Nx+Nu,:);
    
    ceq_0 = x(:,1)-x0;
    ceq_f = x(:,end)-xf;
    ceq = ceq_0;
    x_dot_k = Dynamics(x(:,1),u(1));
    
    for k = 1:N-1        
        x_k = (x(:,k));
        x_k_p1 = x(:,k+1);
        x_dot_k_p1 = Dynamics(x(:,k+1),u(k+1));

        h = dt;
        x_ck = 1/2*(x_k + x_k_p1) + h/8*(x_dot_k - x_dot_k_p1);
        u_ck = (u(k)+u(k+1))/2;
        x_dot_ck = Dynamics(x_ck,u_ck);
      
        defects = (x_k - x_k_p1) + dt/6* (x_dot_k + 4*x_dot_ck + x_dot_k_p1);
        ceq = [ceq;defects];
        x_dot_k = x_dot_k_p1;
    end
    c = [] ;%inequality <= constraint
    ceq = [ceq;ceq_f] ;%equality = constraint
end

%% RICATTI

function [l,K,P,p] = Ricatti(x,u,A,B)
    global Qf R Q N

    Ptp1 = 2*Qf ;% inialize P(tf) 
    ptp1 = 2*Qf*x(:,end) ;% initialize p(tf) 
    R_ = 2*R ;% R(t) ?
    Q_ = 2*Q ;% Q(t) ?

    for i = N-1:-1:1
        q_ = 2*Q*x(:,i) ;
        r_ = 2*R*u(:,i) ;
                
        A_ = A{i} ;% recall from linearization
        B_ = B{i} ;% could move calc here if needed

        AT = A_' ;% interim calc for speed
        BT = B_' ;% interim calc for speed
        
        BTP = BT*Ptp1 ;% interim calc for speed
        H_ = R_ + BTP*B_ ;
        G_ = BTP*A_ ;
        g_ = r_ + BT*ptp1 ;
        H_inv = inv(H_) ;% interim calc for speed
        K_ = -H_inv*G_ ;%feedback update
        l_ = -H_inv*g_ ;%feedforward increment

        KTH = K_'*H_ ;% interim calc for speed
        P_ = Q_ + AT*Ptp1*A_ + KTH*K_ + K_'*G_ + G_'*K_ ;
        p_ = q_ + AT*ptp1 + KTH*l_ + K_'*g_ + G_'*l_ ;% paper says l_'*g_            

        l(i) = l_ ;% store l(t) %mx1 (control x1)
        K(i,:) = K_ ;% store K(t) %mxn (control x states)
        P{i} = P_ ;
        p{i} = p_ ;        
        
        Ptp1 = P_ ;% reset for next iteration
        ptp1 = p_ ;% reset
    end
end

%% FUNCTIONS: Partial Derivatives

% A(t) - Finite Diff partial wrt states
function A = A_xPartial(x,u,Dynamics)
    global Nx

    A = zeros(Nx,Nx);
    eps = 1e-4;

    for i = 1:Nx
        x_ = x ;
        x_(i) = x_(i)+eps ;
        f=Dynamics(x,u) ;
        f_eps=Dynamics(x_,u) ;
        A(:,i)=(f_eps-f)/eps ;
    end
end

% B(t) - Finite Diff partial wrt states
function B = B_uPartial(x,u,Dynamics)
    global Nx Nu
    
    B = zeros(Nx,Nu);
    eps = 1e-4;

    for i = 1:Nu
        u_ = u ;
        u_(i) = u_(i)+eps ;
        f=Dynamics(x,u) ;
        f_eps=Dynamics(x,u_) ;
        B(:,i)=(f_eps-f)/eps ;
    end
end

%% FUNCTIONS: DYNAMICS

% SIMPLE Damped PENDULUM DYNAMICS
function dxdt = Simp_Dyn(x,u)
    b_damp = 0.3;
    dxdt = [x(2);
                u-b_damp*x(2)-sin(x(1))];
end

function A = A_Simp_analytical(x,u,Dynamics)
    b_damp = 0.3;
    A = [0 1;
          -cos(x(1)) -b_damp];
end

function B = B_Simp_analytical(x,u,Dynamics)
    B = [0;1];
end

% AUGMENTED PENDULUM DYNAMICS
function dxdt = Aug_Dyn(x,u)

    dxdt = [x(2);
                u-(x(1)^2-1)*x(2)-sin(x(1))];
end

function [A, B] = linearize(A,B)
    global Nx Nu dt
    
    M = [A B; zeros(1,Nx+Nu)].*dt ;
    MM = expm(M) ;
    A = MM(1:Nx,1:Nx);
    B = MM(1:Nx,Nx+1:end);
end

%% PLOTTING 
function PLOTTER(pp,stuff);
    p = pp(1) ;
    if p == 1 % PLOTTING DESIRED TRAJECTORY
        t = stuff(1,:) ;
        xnom = stuff(2:3,:) ;
        unom = stuff(4,:) ;
        xd = stuff(5:6,:) ;
        ud = stuff(7,:) ;
        figure(1), set(gcf,'color','w');
        subplot(321), hold on, 
           plot(t,ud,'LineWidth',2)
           plot(t,unom,'LineWidth',2)
           ylim([-2 2])
        subplot(323), hold on; 
           plot(t,xd(2,:),'LineWidth',2)
           plot(t,xnom(2,:),'LineWidth',2)
        subplot(325), hold on; 
           plot(t,xd(1,:),'LineWidth',2)
           plot(t,xnom(1,:),'LineWidth',2)
        subplot(3,2,[2,4,6]), hold on; 
           plot(xd(1,:),xd(2,:),'LineWidth',2)
           plot(xnom(1,:),xnom(2,:),'LineWidth',2)
        set(gcf,'position',[200 200 675 350]), hold on;   %set figure shape
    %     Plot_Title = {'\bfBuchli SLQ Algorithm'};

    elseif p == 2 % PLOTTING NOMINAL ITERATIONS
        t = stuff(1,:) ;
        xnom = stuff(2:3,:) ;
        unom = stuff(4,:) ;
        l_iter = pp(2) ;

        legend_store = {'Desired: xf = [.75\pi,0.2]','Nominal: xf = [\pi,0]'} ;
        for i = 1:l_iter
            n_iter = sprintf('Nominal Iter %2.0f',i) ;
            legend_store = [legend_store n_iter] ;
        end
        
        figure(1), hold on;
        subplot(321), hold on %PLOT control input u
           plot(t,unom,'LineWidth',1)
           ylabel({'u(t) '},'fontsize',16)%, xlim([0,t_max])
           title('Control and State Variable Trajectories  ','fontsize',16)
           set(gca,'XTicklabel',[])%, ylim([-1.1,1.1]) 
        subplot(323), hold on; %PLOT omega response
           plot(t,xnom(2,:),'LineWidth',1)
           ylabel({'dq(t) '},'fontsize',16)%, xlim([0,t_max])
           set(gca,'XTicklabel',[])%, ylim([q_dot_min-po,q_dot_max+po]) 
        subplot(325), hold on; %PLOT theta response
           plot(t,xnom(1,:),'LineWidth',1)
           ylabel({'q(t) '},'fontsize',16)%, xlim([0,t_max])
           xlabel('time (sec) ','fontsize',16)%, ylim([q_min-pt,q_max+pt])
        subplot(3,2,[2,4,6]), hold on; %Phase Plot
           plot(xnom(1,:),xnom(2,:),'LineWidth',1)
           title('Phase Space','fontsize',16)%, ylim([q_dot_min-po,q_dot_max+po])
           xlabel('q(t) ','fontsize',16)%, xlim([q_min-pt,q_max+pt])
           ylabel('dq(t) ','fontsize',16)
        legend(legend_store{1:l_iter+1})
        pause()
        
    elseif p == 3 % finish making plot look nice
        ha = axes('Position',[0 0 1 1],'Xlim',[0 1],'Ylim',[0 1],'Box','off',...
        'Visible','off','Units','normalized','clipping','off');
        text(0.5,.98,'\bfBuchli SLQ Algorithm','fontsize',18,...
            'HorizontalAlignment','center','VerticalAlignment','top');
        k = get(gcf,'children') ;%change subplot positions

        set(k(2),'position',[0.7852  0.24 0.1696 0.0429]) %Legend
        set(k(3),'position',[0.58 0.12 0.4 0.73]) %Phase
        set(k(4),'position',[0.1 0.12 0.4 0.23])  %position
        set(k(5),'position',[0.1 0.37 0.4 0.23]) %rate
        set(k(6),'position',[0.1 0.62 0.4 0.23])  %u
    end
    
end
