# Pi Cluster Benchmarks

I test a variety of use-cases using my Pi clusters.

This folder contains some playbooks and guides for different types of benchmarking I do.

More benchmarks will be added over time.

## Top500 High Performance Linpack (HPL)

I like to run the HPL benchmark on my clusters to see where they fall in the historic [Top500 supercomputing list](https://top500.org).

My automated Top500 HPL benchmark code is located in a separate repository: [Top500 Benchmark - HPL Linpack](https://github.com/geerlingguy/top500-benchmark).

## `disk-benchmark.sh`

The `disk-benchmark` script is what I use to test various storage media with the Raspberry Pi.

As a rule of thumb, NVMe devices will max out the Pi's PCIe bus (around 400 MB/sec), while microSD and eMMC storage on the Pi tops out under 100 MB/sec, at least as of the Pi 4 generation.

See the `disk-benchmark.sh` comments for usage examples.

## `stress-ng`

The `stress.yml` playbook hammers all CPU cores on all nodes simultaneously. This can be useful to measure the maximum power draw under CPU load, and to test whether the Pis in the cluster are getting enough power to run stably (especially when overclocked).

To run it, run the following command within the main `pi-cluster` directory (up one level):

```
ansible-playbook benchmarks/stress.yml
```

Run it with a longer `stress_time` if you really want to test thermals and make sure your cluster doesn't overheat.
