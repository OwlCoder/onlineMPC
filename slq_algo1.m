function slq_algo1
%% writing a good code
% all functions, structs and classes- Camel case
% all variables-underscore
oldpath=path;
path(oldpath,'/home/Naman/Downloads/myAutomaticDifferentiation')

%% main
modelParams=setParams();
% load initial trajectory
load('trajectory.mat', 'trajectory');
trajectory.x=trajectory.x';
trajectory.x=[0 0;trajectory.x']';
trajectory.u=trajectory.u';
%repeat until max number of iterations or converged (l(t)<l_t)
while max_iter<10000
    %simulate the trajectory
    for time_iter=1:modelParams.dt:modelParams.T
        A(time_iter)=
    end
    if norm(l)<10e-5
        break
    end
end

%% Given
    function modelParams=setParams()
        modelParams.g=1;%9.8
        modelParams.length=1;
        modelParams.dt=0.1;
        modelParams.T=10; %N=T/dt
        modelParams.Qt=diag([10,10]);
        modelParams.Qf=diag([100,100]);
        modelParams.Rt=1;
    end

    %% dynamics of a simple pendulum
    % params x: state vector 2x1
    % params u: input vector 1
    % params modelParams: struct
    %returns xNext: 2x1
    function xNext=simplePendDynamics(x,u, modelParams)
        xdot(1)=x(2);
        xdot(2)=-(modelParams.g/modelParams.length)*sin(x(1))+u;
        xNext=x+xdot*modelParams.dt;
    end

    %% cost function : objective is to minimize this
    % params x: state vector 2x(N+1) -> (0,dt,...,T) where N=T/dt
    % params u: input vector 1x(N)
    % params trajectory: struct (x,u)
    function J = costFunction(x,u, modelParams, trajectory)
        recurr_cost=0;
        for t=1:size(x,2)-1
            error_traj=x(:,t)-trajectory.x(:,t);
            recurr_cost=recurr_cost+ error_traj'*modelParams.Qt*error_traj+...
                u(:,t)'*modelParams.Rt*u(:,t);
        end
        error_goal=x(:,end)-trajectory.x(:,end);
        J= error_goal'*modelParams.Qf*error_goal + recurr_cost;
    end
   
    %% linearization of system dynamics at trajectory points
    function A,B=linDynamics(modelParams,trajectory)
    end
end