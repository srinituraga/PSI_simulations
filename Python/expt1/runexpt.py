import os, sys
sys.path.append('/groups/turaga/turagalab/SLAPmi/Python')
import SLAPMi

(Y,Sk,Fk,Su,Fu, GT) = SLAPMi.prepexpt()
Sk,Fk,Su,Fu = SLAPMi.reconstruct_cpu(Y[:,:25],Sk,Fk[:,:25],Su,Fu[:,:25],Nframes=200,nIter=int(1e5),eta=1e1,mu=0.7,adagrad=True, groundtruth=GT, out_fn='/groups/turaga/turagalab/SLAPmi/Python/expt1/output.mat')

