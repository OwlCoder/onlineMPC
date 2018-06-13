function modelParams=setParams()
%% algo 1

    modelParams.g=1;%9.8
    modelParams.m=1;
    modelParams.length=1;
    modelParams.c=0.3;
    
    modelParams.dt=0.1;
    modelParams.T=10; %N=T/dt
    modelParams.N=modelParams.T/modelParams.dt+1;
    
    modelParams.Qt=diag([10,10]);
    modelParams.Qf=diag([100,100]);
    modelParams.Rt=1;
    
    modelParams.x_init=[0;0];
    modelParams.u_lim=1;
    
    modelParams.gen_traj=0;
    modelParams.viz=0;
    modelParams.ls_steps=20;
    modelParams.alpha_d=1.1;
    
    modelParams.traj_track=0; % 0 if goal tracking
    
%% algo 2

    modelParams.policy_lag=0;
    modelParams.Q_lqr=diag([10,10]);
    modelParams.mpc_steps=10;
    modelParams.goal=[pi;0];
    
    % waypoints params
    modelParams.wp_bool=0;
    modelParams.num_wp=2;
    modelParams.states = [pi/6 -pi/2;...
                            0 -0.5];
    modelParams.rho_p  = [100 0.5];
    modelParams.t_p    = [10*modelParams.dt 30*modelParams.dt];
    modelParams.weight_p = diag([1000,0]);
end