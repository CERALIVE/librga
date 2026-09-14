// SPDX-License-Identifier: Apache-2.0
#include <dlfcn.h>
#include <cstddef>
#include "im2d.hpp"
#include "../unit/unit_assert.h"

int main()
{
    if (!dlsym(RTLD_DEFAULT, "fake_rga_active")) return 2;
    unit_begin("Candidate C: scheduler default is legitimate input");
    unit_eq_int("default enum is zero", 0, IM_SCHEDULER_DEFAULT);
    unit_eq_int("default accepted on fresh thread", IM_STATUS_SUCCESS,
                imconfig(IM_CONFIG_SCHEDULER_CORE, IM_SCHEDULER_DEFAULT));
    unit_eq_int("explicit RGA3 core accepted", IM_STATUS_SUCCESS,
                imconfig(IM_CONFIG_SCHEDULER_CORE, IM_SCHEDULER_RGA3_CORE0));
    unit_eq_int("reset explicit core to default", IM_STATUS_SUCCESS,
                imconfig(IM_CONFIG_SCHEDULER_CORE, IM_SCHEDULER_DEFAULT));
    unit_eq_int("unsupported core rejected", IM_STATUS_ILLEGAL_PARAM,
                imconfig(IM_CONFIG_SCHEDULER_CORE, 0x10));
    return unit_report("candidate-c");
}
