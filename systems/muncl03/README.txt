
Cluster is configured to assigned nodes exclusively via
SelectType=select/linear

MI350P nodes are configured with multithreading:
Thread(s) per core: 2

Above settings have implications on NAMD and other codes.

Trying to workaround these settings with:
#SBATCH --threads-per-core=1

And NAMD by manually selecting the cores assigned,
otherwise run the risk of assigning all and decrease
performance.

ROCR_VISIBLE_DEVICES is undefined in MI350P
