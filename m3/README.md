# Using rocker-ultra rstudio.sh on M3

Here are some very specific instructions, for users of the M3 / MASSIVE HPC cluster. They may be adaptable to your HPC site - YMMV.


## Using rstudio.sh via Strudel Web (beta)

On M3 / Massive, when using Strudel (beta), copy `apps.rstudio.yaml` into your `~/.strudel2/apps.d/` directory.

Reload your Studel Web page, you should see a new RStudio in the sidebar as an option.

eg, run:
```bash
mkdir ~/.strudel2/apps.d
curl https://raw.githubusercontent.com/MonashBioinformaticsPlatform/rocker-ultra/main/m3/apps.rstudio.yaml >~/.strudel2/apps.d/apps.rstudio.yaml
```

_The example apps.rstudio.yaml uses the `IMAGE` environment variable to pull the container image from an https:// URL - this is because I was finding the regular `singularity exec` / `pull` method unreliable on the cluster. This might have been a temporary issue._

## Tunnelling to an M3 compute node

As an alternative to using Strudel, you can run your RStudio session on a compute node, via a SLURM job submission (sbatch/srun/smux), then SSH tunnel to that compute node.

Just commandline, without using `~/.ssh/config`:
```bash
# on login node, in tmux/screen (or adapt to sbatch)
srun --mem=1G --time=0-12:00 --job-name=my-rstudio ./rstudio.sh

# once running, find out which compute node it's on with squ or similar
squeue | grep my-rstudio

# we will use m3a002 in this example

# on you local machine
ssh -i ~/.ssh/m3 -J username@m3.massive.org.au -L 8787:localhost:8787 username@m3a002

# open the URL http://localhost:8787 in the browser on your laptop
```

OR, using the convenience of `~/.ssh/config`:

```
# ~/.ssh/config
Host m3
 HostName m3.massive.org.au
 User my_m3_username
 IdentityFile ~/.ssh/m3
 ForwardAgent yes
 LocalForward 8787 127.0.0.1:8787

# Other host wildcards may need to be added here over time
Host m3a* m3b* m3c* m3d* m3e* m3f* m3g* m3h* m3i* m3j*
 User my_m3_username
 IdentityFile ~/.ssh/m3
 ProxyJump m3
 LocalForward 8787 127.0.0.1:8787
```

Then just `ssh -i ~/.ssh/m3 username@m3a002` to the compute node from your laptop, and open https://localhost:8787 in your browser.