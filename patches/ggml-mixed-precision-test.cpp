#include "ggml.h"
#include "ggml-cpu.h"
#include <cmath>
#include <cstdio>
#include <initializer_list>
using Binary = ggml_tensor *(*)(ggml_context *, ggml_tensor *, ggml_tensor *);
static bool check(Binary operation, int kind, bool strided) {
    ggml_init_params params = { 16*1024*1024, nullptr, false };
    auto *ctx = ggml_init(params);
    auto *a = ggml_new_tensor_1d(ctx, GGML_TYPE_F32, 4);
    auto *storage = ggml_new_tensor_2d(ctx, GGML_TYPE_F16, 2, 2);
    auto *b = strided ? ggml_view_1d(ctx, storage, 2, 0) : ggml_new_tensor_1d(ctx, GGML_TYPE_F16, 2);
    // A strided view exercises the element-by-element path.
    if (strided) { b->nb[0] = 2 * sizeof(ggml_fp16_t); }
    float *av = (float *)a->data;
    auto *bv = (ggml_fp16_t *)b->data;
    for (int i=0;i<4;i++) av[i] = float(i+5);
    bv[0] = ggml_fp32_to_fp16(1.0f);
    bv[strided ? 2 : 1] = ggml_fp32_to_fp16(2.0f);
    auto *result = operation(ctx, a, b);
    auto *graph = ggml_new_graph(ctx);
    ggml_build_forward_expand(graph, result);
    if (ggml_graph_compute_with_ctx(ctx, graph, 2) != GGML_STATUS_SUCCESS) return false;
    float *out = (float *)result->data;
    bool ok = true;
    for (int i=0;i<4;i++) {
       float y = i%2 ? 2.0f : 1.0f;
       float expected = kind == 0 ? av[i]+y : kind == 1 ? av[i]-y : kind == 2 ? av[i]*y : av[i]/y;
       if (std::fabs(out[i] - expected) > 0.001f) ok = false;
    }
    ggml_free(ctx);
    return ok;
}
int main() {
    Binary operations[] = { ggml_add, ggml_sub, ggml_mul, ggml_div };
    for (int i=0;i<4;i++) for (bool strided : {false, true})
        if (!check(operations[i], i, strided)) return 1;
    std::puts("mixed-precision arithmetic and broadcast: 8 checks passed");
}
