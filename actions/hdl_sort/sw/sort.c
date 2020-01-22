/*
 * Copyright 2019 International Business Machines
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <errno.h>
#include <malloc.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <time.h>
#include <math.h>
#include <getopt.h>
#include <ctype.h>

#include <libosnap.h>
#include <osnap_tools.h>

#include "sort.h"

/*  defaults */
#define ACTION_WAIT_TIME    50   /* Default in sec */

#define MEGAB       (1024*1024ull)
#define GIGAB       (1024 * MEGAB)

#define VERBOSE0(log, fmt, ...) do {         \
        printf(fmt, ## __VA_ARGS__);    \
        fprintf(log, fmt, ## __VA_ARGS__);    \
    } while (0)

#define VERBOSE1(fmt, ...) do {         \
        if (verbose_level > 0)          \
            printf(fmt, ## __VA_ARGS__);    \
    } while (0)

#define VERBOSE2(fmt, ...) do {         \
        if (verbose_level > 1)          \
            printf(fmt, ## __VA_ARGS__);    \
    } while (0)


#define VERBOSE3(fmt, ...) do {         \
        if (verbose_level > 2)          \
            printf(fmt, ## __VA_ARGS__);    \
    } while (0)

#define VERBOSE4(fmt, ...) do {         \
        if (verbose_level > 3)          \
            printf(fmt, ## __VA_ARGS__);    \
    } while (0)

static const char* version = GIT_VERSION;
static  int verbose_level = 0;

static uint64_t get_usec (void)
{
    struct timeval t;

    gettimeofday (&t, NULL);
    return t.tv_sec * 1000000 + t.tv_usec;
}


static void* alloc_mem (uint32_t align, uint64_t bytes)
{
    void* a;
    uint64_t bytes2 = bytes + align;

    VERBOSE2 ("%s Enter Align: %d Size: %ld\n", __func__, align, bytes);

    if (posix_memalign ((void**)&a, align, bytes2) != 0) {
        perror ("FAILED: posix_memalign()");
        return NULL;
    }

    VERBOSE2 ("%s Exit %p\n", __func__, a);
    return a;
}

static void free_mem (void* a)
{
    VERBOSE2 ("Free Mem %p\n", a);

    if (a) {
        free (a);
    }
}


/* Action or Kernel Write and Read are 32 bit MMIO */
static void action_write (FILE* log, struct snap_card* h, uint32_t addr, uint32_t data)
{
    int rc;

    rc = snap_action_write32 (h, (uint64_t)addr, data);

    if (0 != rc) {
        VERBOSE0 (log, "Write MMIO 32 Err\n");
    }

    return;
}

static uint32_t action_read (FILE* log, struct snap_card* h, uint32_t addr)
{
    int rc;
    uint32_t data;

    rc = snap_action_read32 (h, (uint64_t)addr, &data);

    if (0 != rc) {
        VERBOSE0 (log, "Read MMIO 32 Err\n");
    }

    return data;
}


static void mem_init (void* mem_addr, uint32_t init_data, uint64_t total_bytes)
{

    uint8_t* ptr = (uint8_t*) mem_addr;
    uint32_t fill_data = init_data;
    uint64_t cnt = 0;

    do {
        * (ptr) = (fill_data) & 0xFF;
        * (ptr + 1) = (fill_data >> 8) & 0xFF;
        * (ptr + 2) = (fill_data >> 16) & 0xFF;
        * (ptr + 3) = (fill_data >> 24) & 0xFF;

        cnt += 4;
        fill_data ++;
        ptr += 4;
    } while (cnt < total_bytes);

}


/*
 * Return 0 if buffer is equal,
 * Return index+1 if not equal
 */
static uint64_t mem_check (uint8_t* src, uint8_t* dest, uint64_t len)
{
    uint64_t i;

    for (i = 0; i < len; i++) {
        if (*src != *dest) {
            return i + 1;
        }

        src++;
        dest++;
    }

    return 0;
}

static int run_single_engine (struct snap_card* h,
                              void* dsc_base,
                              void* cmpl_base,
                              FILE* log
                             )
{
    int rc         = 0;
    uint32_t pasid;

    VERBOSE0 (log, " ----- START SNAP_CONTROL ----- \n");
    pasid = snap_action_get_pasid (h);
    VERBOSE0 (log, "PASID of this process: %u\n", pasid);

    VERBOSE0 (log, " ----- CONFIG PARAMETERS ----- \n");
    VERBOSE0 (log, "Descriptor address = %p\n", dsc_base);
    action_write (log, h, REG_MP_INIT_ADDR_LO, (uint32_t) (((uint64_t) dsc_base) & 0xffffffff));
    action_write (log, h, REG_MP_INIT_ADDR_HI, (uint32_t) ((((uint64_t) dsc_base) >> 32) & 0xffffffff));
    action_write (log, h, REG_MP_CMPL_ADDR_LO, (uint32_t) (((uint64_t) cmpl_base) & 0xffffffff));
    action_write (log, h, REG_MP_CMPL_ADDR_HI, (uint32_t) ((((uint64_t) cmpl_base) >> 32) & 0xffffffff));

    VERBOSE0 (log, " ----- Tell AFU to kick off AXI transactions ----- \n");
    action_write (log, h, REG_MP_CONTROL, 0x00000001);
    rc = 1;

    return rc; //1 means successful
}

static struct snap_action* get_action (FILE* log, struct snap_card* handle,
                                       snap_action_flag_t flags, uint32_t timeout)
{
    struct snap_action* act;

    act = snap_attach_action (handle, ACTION_TYPE_HDL_SORT,
                              flags, timeout);

    if (NULL == act) {
        VERBOSE0 (log, "Error: Can not attach Action: %x\n", ACTION_TYPE_HDL_SORT);
        VERBOSE0 (log, "       Try to run snap_main tool\n");
    }

    return act;
}

static void usage (FILE* log, const char* prog)
{
    VERBOSE0 (log, "SNAP String Match (Regular Expression Match) Tool.\n");
    VERBOSE0 (log, "Usage: %s\n"
             "    -h, --help              | Prints usage information\n"
             "    -v, --verbose           | Verbose mode\n"
             "    -C, --card <cardno>     | Card to be used for operation\n"
             "    -V, --version           | Print Version\n"
             //              "    -q, --quiet          | quiece output\n"
             "    -t, --timeout           | Timeout after N sec (default 1 sec)\n"
             , prog);
}

static int sort (int argc, char* argv[], int id)
{
    char device[64];
    struct snap_card* dn;   /* lib snap handle */
    int card_no = 0;
    int cmd;
    int rc = 1;
    int i;
    uint32_t timeout = ACTION_WAIT_TIME;
    snap_action_flag_t attach_flags = 0;
    struct snap_action* act = NULL;
    void* src_base = NULL;
    int * dsc_base;
    void* cmpl_base = NULL;
    void* tgt_base = NULL;
    void* exp_buff = NULL;
    uint32_t init_rdata, init_wdata;
    uint64_t time_used = 100;
    pid_t pid;
    FILE* log;
    char file_name[256];

    pid = getpid();
    sprintf (file_name, "proc_%d_%d.log", id, pid);
    log = fopen (file_name, "w");

    //Default value
    init_rdata = id * 1024;
    init_wdata = id * 1024;

    if (NULL == log) {
        VERBOSE0 (log, "Unable to open log file handler\n");
        return -1;
    }

    VERBOSE0 (log, "Process %d running ... \n", pid);

    while (1) {
        int option_index = 0;
        static struct option long_options[] = {
            { "help", no_argument, NULL, 'h' },
            { "card", required_argument, NULL, 'C' },
            { "verbose", no_argument, NULL, 'v' },
            { "version", no_argument, NULL, 'V' },
            //    { "quiet"      , no_argument       , NULL , 'q' } ,
            { "timeout", required_argument, NULL, 't' },
            { "irq", no_argument, NULL, 'I' },
            { 0, no_argument, NULL, 0   }
        };
        cmd = getopt_long (argc, argv, "hC:vVt:Iw:d:D:n:N:p:P:",
                           long_options, &option_index);

        if (cmd == -1) { /* all params processed ? */
            break;
        }

        switch (cmd) {
        case 'v':   /* verbose */
            verbose_level++;
            break;

        case 'V':   /* version */
            VERBOSE0 (log, "%s\n", version);
            exit (EXIT_SUCCESS);;

        case 'h':   /* help */
            usage (log, argv[0]);
            exit (EXIT_SUCCESS);;

        case 'C':   /* card */
            card_no = strtol (optarg, (char**)NULL, 0);
            break;

        case 't':
            timeout = strtol (optarg, (char**)NULL, 0); /* in sec */
            break;

        case 'I':      /* irq */
            attach_flags = SNAP_ACTION_DONE_IRQ | SNAP_ATTACH_IRQ;
            break;

        default:
            usage (log, argv[0]);
            exit (EXIT_FAILURE);
        }

    }  // while(1)

    //-------------------------------------------------
    // Open Card
    //-------------------------------------------------
    VERBOSE2 ("Open Card: %d\n", card_no);

    if (card_no == 0) {
        snprintf (device, sizeof (device) - 1, "IBM,oc-snap");
    } else {
        snprintf (device, sizeof (device) - 1, "/dev/ocxl/IBM,oc-snap.000%d:00:00.1.0", card_no);
    }

    dn = snap_card_alloc_dev (device, SNAP_VENDOR_ID_IBM, SNAP_DEVICE_ID_SNAP);

    if (NULL == dn) {
        errno = ENODEV;
        VERBOSE0 (log, "ERROR: snap_card_alloc_dev(%s)\n", device);
        return -1;
    }

    //-------------------------------------------------
    // Attach Action
    //-------------------------------------------------

    VERBOSE0 (log, "Start to get action.\n");
    act = get_action (log, dn, attach_flags, timeout);
    if (NULL == act) {
        goto __exit1;
    }

    //-------------------------------------------------
    // Prepare buffers
    //-------------------------------------------------

    VERBOSE0 (log, "Prepare source and tgt buffers.\n");

    src_base  = alloc_mem (4096, 8192); // src address must be 4KB alignment
    tgt_base = alloc_mem (4096, 8192); // targer address must be 4KB alignment
    dsc_base = alloc_mem (4096, 4096);
    cmpl_base = alloc_mem (4096, 4096);
    exp_buff  = alloc_mem (4096, 8192);

    VERBOSE0 (log, "Source address is: %p\n", src_base);
    VERBOSE0 (log, "Target address is: %p\n", tgt_base);
    VERBOSE0 (log, "Completion address is: %p\n", cmpl_base);

    mem_init (src_base, init_rdata, 8192);
    mem_init (exp_buff, init_wdata, 8192);
    memset (dsc_base, 0, 4096);
    memset (cmpl_base, 0, 4096);
    memset (tgt_base, 0, 8192);

    *dsc_base = 0x12345678;
    *(dsc_base + 1) = 0x10101010;
    *(dsc_base + 2) = (uint32_t) (((uint64_t) tgt_base) & 0xffffffff);
    *(dsc_base + 3) = (uint32_t) ((((uint64_t) tgt_base) >> 32) & 0xffffffff);
    *(dsc_base + 4) = (uint32_t) (((uint64_t) src_base) & 0xffffffff);
    *(dsc_base + 5) = (uint32_t) ((((uint64_t) src_base) >> 32) & 0xffffffff);
    *(dsc_base + 31) = 0x0;

    //-------------------------------------------------
    // Start Engine and wait done
    //-------------------------------------------------
    VERBOSE0 (log, "Start AFU.\n");
    rc = run_single_engine (dn,
                            dsc_base,cmpl_base,
                            log
                           );
    sleep(30);
    //-------------------------------------------------
    // Checkings
    //-------------------------------------------------
    if (rc == 1) {
        VERBOSE0 (log, "AFU finishes.\n");
    }



    //-------------------------------------------------
    // Detach, Cleanup and Exit
    //-------------------------------------------------
    VERBOSE2 ("Detach action: %p\n", act);
    snap_detach_action (act);

__exit1:
    VERBOSE2 ("Free Card Handle: %p\n", dn);
    snap_card_free (dn);

    free_mem (src_base);
    free_mem (dsc_base);
    free_mem (cmpl_base);
    free_mem (exp_buff);
    free_mem (tgt_base);

    if (rc != 0) {
        VERBOSE0 (log, "End of Test rc = 0x%x. \n", rc);
    }

    fclose (log);

    return rc;
}

int main (int argc, char* argv[])
{
    int num_processes = 4;
    int rc = 0;
    int failing = -1;
    pid_t pid;
    int i, j;

    for (i = 0; i < num_processes; i++) {
        if (!fork()) {
            exit (sort (argc, argv, i));
        }
    }

    for (i = 0; i < num_processes; i++) {
        pid = wait (&j);

        if (pid && j) {
            rc++;

            if (failing == -1) {
                failing = pid;
            }
        }
    }

    if (rc) {
        fprintf (stderr, "%d test(s) failed. Check Process %d, maybe others\n", rc, failing);
    } else {
        printf ("Test successful\n");
    }

    return rc;
}

