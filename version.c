#if defined(FUNCPROTO) || defined(__STDC__) || defined(__cplusplus) || defined(c_plusplus)
#ifndef ARGS
#define ARGS(args) args
#endif
#else
#ifndef ARGS
#define ARGS(args) (/*args*/)
#endif
#endif

#include <stdio.h>
#include "config.h"

static char *EVPath_version = "EVPath Version 2.1.3 -- Fri Nov 17 12:51:47 EST 2006\n";

void EVprint_version(){
    printf("%s",EVPath_version);
}

