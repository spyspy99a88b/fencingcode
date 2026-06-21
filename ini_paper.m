% Paper-aligned initial conditions for the fencing simulation.
% This file keeps ini.m untouched and only adjusts the display scenario.
clc;

%% 1. Target initial state
p00 = [-7; -2];
v00 = [0.1; 0.1];

%% 2. Communication topology and target pinning
A_raw1 = [0 1 1 0 1 1;
          1 0 1 1 0 1;
          1 1 0 1 0 0;
          0 1 1 0 1 0;
          1 0 0 1 0 1;
          1 1 0 0 1 0];
A_raw2 = [0 1 0 1 0 0;
          1 0 1 1 0 0;
          0 1 0 1 0 0;
          1 1 1 0 0 0;
          0 0 0 0 0 0;
          0 0 0 0 0 0];

beta1 = [0; 1; 0; 0; 1; 1];
beta2 = [0; 1; 1; 0; 0; 0];

%% 3. Nominal offset data retained for model compatibility
R = 10;
p_off_set1 = [R*cos(0) R*cos(pi/3) R*cos(2*pi/3) R*cos(pi) R*cos(4*pi/3) R*cos(5*pi/3);
              R*sin(0) R*sin(pi/3) R*sin(2*pi/3) R*sin(pi) R*sin(4*pi/3) R*sin(5*pi/3)];
p_off_set2 = [R*cos(0) R*cos(pi/2) R*cos(2*pi/2) R*cos(3*pi/2) R*cos(4*pi/3) R*cos(5*pi/3);
              R*sin(0) R*sin(pi/2) R*sin(2*pi/2) R*sin(3*pi/2) R*sin(4*pi/3) R*sin(5*pi/3)];

%% 4. Observer and desired-position initial conditions
% Observer estimates remain scattered to show prescribed-time recovery.
p_hat_p10 = [-8;  8];
p_hat_v10 = [ 0;  0];
p_d_10    = [12; -18];

p_hat_p20 = [ 8;  5];
p_hat_v20 = [ 0;  0];
p_d_20    = [22;   2];

p_hat_p30 = [ 5; -5];
p_hat_v30 = [ 0;  0];
p_d_30    = [-20; 16];

p_hat_p40 = [-5; -5];
p_hat_v40 = [ 0;  0];
p_d_40    = [-36;  2];

p_hat_p50 = [-8;  0];
p_hat_v50 = [ 0;  0];
p_d_50    = [-30; -22];

p_hat_p60 = [ 8;  0];
p_hat_v60 = [ 0;  0];
p_d_60    = [ 0; -30];

USE_RESTART    = 1;
USE_SELF_ORDER = 1;
USE_PPC        = 1;
USE_SAT        = 1;

disp('Paper-aligned initialization loaded.');
