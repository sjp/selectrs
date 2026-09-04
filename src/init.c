
// clang-format sorts includes unless SortIncludes: Never. However, the ordering
// does matter here. So, we need to disable clang-format for safety.

// clang-format off
#include <stdint.h>
#include <Rinternals.h>
#include <R_ext/Parse.h>
// clang-format on

#include "rust/api.h"

static uintptr_t TAGGED_POINTER_MASK = (uintptr_t)1;

SEXP handle_result(SEXP res_) {
    uintptr_t res = (uintptr_t)res_;

    // An error is indicated by tag.
    if ((res & TAGGED_POINTER_MASK) == 1) {
        // Remove tag
        SEXP res_aligned = (SEXP)(res & ~TAGGED_POINTER_MASK);

        // Currently, there are two types of error cases:
        //
        //   1. Error from Rust code
        //   2. Error from R's C API, which is caught by R_UnwindProtect()
        //
        if (TYPEOF(res_aligned) == CHARSXP) {
            // In case 1, the result is an error message that can be passed to
            // Rf_errorcall() directly.
            Rf_errorcall(R_NilValue, "%s", CHAR(res_aligned));
        } else {
            // In case 2, the result is the token to restart the
            // cleanup process on R's side.
            R_ContinueUnwind(res_aligned);
        }
    }

    return (SEXP)res;
}

SEXP savvy_css_to_xpath_rust__impl(SEXP c_arg__selectors, SEXP c_arg__prefixes, SEXP c_arg__translators) {
    SEXP res = savvy_css_to_xpath_rust__ffi(c_arg__selectors, c_arg__prefixes, c_arg__translators);
    return handle_result(res);
}

SEXP savvy_selectrs_core_version__impl(void) {
    SEXP res = savvy_selectrs_core_version__ffi();
    return handle_result(res);
}

SEXP savvy_selectrs_panic_test__impl(void) {
    SEXP res = savvy_selectrs_panic_test__ffi();
    return handle_result(res);
}

SEXP savvy_valid_ns_prefixes_rust__impl(SEXP c_arg__prefixes) {
    SEXP res = savvy_valid_ns_prefixes_rust__ffi(c_arg__prefixes);
    return handle_result(res);
}


static const R_CallMethodDef CallEntries[] = {
    {"savvy_css_to_xpath_rust__impl", (DL_FUNC) &savvy_css_to_xpath_rust__impl, 3},
    {"savvy_selectrs_core_version__impl", (DL_FUNC) &savvy_selectrs_core_version__impl, 0},
    {"savvy_selectrs_panic_test__impl", (DL_FUNC) &savvy_selectrs_panic_test__impl, 0},
    {"savvy_valid_ns_prefixes_rust__impl", (DL_FUNC) &savvy_valid_ns_prefixes_rust__impl, 1},
    {NULL, NULL, 0}
};

void R_init_selectrs(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);

    // Functions for initialization, if any.

}
