# hls_memcopy_1024
This is an action using HLS, 1024b. 

Also used to test the throughput of 

* Host -> FPGA_RAM
* FPGA_RAM -> Host
* FPGA (DDR -> RAM)
* FPGA (RAM -> DDR)

But HLS is not as efficient as hdl_single_engine. It has wasted some cycles between transactions. 

## hw_test

```
$ cd actions/hls_memcopy_1024/tests
$ sudo ./hw_throughput_test.sh -dINCR
```

Temporal results: (**TODO**: to be deleted)
```
+-------------------------------------------------------------------------------+
|            OC-Accel hls_memcopy_1024 Throughput (MBytes/s)                    |
+-------------------------------------------------------------------------------+
       bytes   Host->FPGA_RAM   FPGA_RAM->Host   FPGA(DDR->RAM)   FPGA(RAM->DDR)
 -------------------------------------------------------------------------------
         512           25.600           25.600           25.600           25.600
        1024           51.200           51.200           51.200           48.762
        2048          102.400          102.400          102.400          102.400
        4096          204.800          204.800          204.800          215.579
        8192          409.600          409.600          390.095          431.158
       16384          780.190          780.190          862.316          780.190
       32768         1560.381         1489.455         1560.381         1365.333
       65536         2849.391         2621.440         2849.391         2340.571
      131072         5242.880         4096.000         4519.724         3360.821
      262144         8192.000         5957.818         6553.600         4369.067
      524288        11650.844         7825.194         8738.133         5140.078
     1048576        14768.676         8738.133        10082.462         5637.505
     2097152        17331.835         9709.037        10979.853         5907.470
     4194304        18808.538        10699.755        11554.556         6087.524
     8388608        19737.901        12246.143        11848.316         6168.094
    16777216        20164.923        15155.570        12000.870         6213.784
    33554432        20177.049        17943.547        12082.979         6228.779
    67108864        19872.332        19480.077        12120.077         6238.623
   134217728        19790.287        20086.460        12138.711         6242.685
   268435456        19907.702        20418.001        12146.401         6245.299
   536870912        19959.510        20592.647        12151.349         6246.389
  1073741824        19975.849        20682.689        12153.137         6246.607
```

!!!Note
    There is an issue in the coding of the last column "FPGA(RAM->DDR)". It should be doubled. Hasn't fixed yet.
